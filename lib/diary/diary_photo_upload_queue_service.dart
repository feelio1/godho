import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint, kDebugMode;

import 'diary_photo_cache.dart';
import 'diary_photo_local_store.dart';
import 'diary_photo_upload_queue.dart';
import 'models/diary.dart';

String _newQueueItemId() => '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

void _log(String message) {
  // release 빌드에서는 아무것도 찍지 않는다(기존 타이밍 로그와 같은 관례).
  if (kDebugMode) debugPrint('[DiaryPhotoUploadQueue] $message');
}

/// Firestore 문서의 `photos` 배열에 사진 하나를 더하고 `pendingPhotoCount`
/// 를 하나 줄인다 — 둘 다 원자적(`FieldValue`) 연산이라 여러 장이 동시에
/// 끝나도(동시 업로드) 경쟁 없이 안전하다("일기 재수정" 지시서 2-2).
/// Storage 의존이 없어 `fake_cloud_firestore`로 바로 테스트할 수 있다.
Future<void> appendUploadedDiaryPhoto(
  FirebaseFirestore firestore,
  String uid,
  String diaryId,
  DiaryPhoto photo,
) async {
  await firestore.collection('users').doc(uid).collection('diaries').doc(diaryId).update({
    'photos': FieldValue.arrayUnion([photo.toFirestore()]),
    'pendingPhotoCount': FieldValue.increment(-1),
  });
}

/// 압축이 끝난 사진을 로컬 파일 + 대기열에 기록하고 백그라운드에서 올리는
/// 서비스("일기 재수정" 지시서 2) — 작성 화면은 [enqueue]만 부르고
/// 업로드(네트워크)가 끝나길 기다리지 않은 채 바로 닫힌다. 앱 시작·
/// 포그라운드 복귀 시 [processPending]을 다시 불러 끊긴 업로드를 이어
/// 간다.
class DiaryPhotoUploadQueueService {
  DiaryPhotoUploadQueueService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    DiaryPhotoUploadQueueStore? store,
    DiaryPhotoCacheWriter? cacheWriter,
  })  : _firestoreOverride = firestore,
        _storageOverride = storage,
        _store = store ?? const DiaryPhotoUploadQueueStore(),
        _cacheWriter = cacheWriter ?? cacheDiaryPhotoBytesDefault;

  /// 앱 전역에서 하나만 쓴다 — 작성 화면·앱 시작 훅이 모두 이 인스턴스를
  /// 공유해야 "처리 중" 중복 실행을 막을 수 있다. 생성자에서 Firebase를
  /// 바로 건드리지 않는다(아래 lazy getter) — Firebase 초기화 전에도
  /// (게스트 전용 화면·위젯 테스트 등) 이 인스턴스를 안전하게 참조할 수
  /// 있어야 한다. 실제로 올릴 사진이 있을 때만(큐가 비어 있지 않을 때만)
  /// Firestore/Storage를 건드린다.
  static final DiaryPhotoUploadQueueService instance = DiaryPhotoUploadQueueService();

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;
  final DiaryPhotoUploadQueueStore _store;
  final DiaryPhotoCacheWriter _cacheWriter;

  /// 사진 여러 장을 동시에 올리는 상한 — 기존 즉시 업로드 경로와 같은 값.
  static const _uploadConcurrency = 3;

  bool _processing = false;
  Timer? _retryTimer;

  /// 큐가 바뀔 때마다(사진 추가·업로드 완료·실패) 값을 하나씩 올린다 —
  /// 목록·상세 화면이 이 값을 듣고 있다가 서버에 새로 올라간 사진으로
  /// 자동 교체하거나 "올리는 중" 표시를 갱신한다("일기 재수정" 지시서
  /// 2-3). 숫자 자체엔 의미가 없다(변화 신호일 뿐).
  final ValueNotifier<int> changeTick = ValueNotifier<int>(0);

  void _notifyChanged() => changeTick.value++;

  Reference _photoRef(String uid, String diaryId, String photoId) =>
      _storage.ref('diary_photos/$uid/$diaryId/$photoId.jpg');

  Reference _thumbRef(String uid, String diaryId, String photoId) =>
      _storage.ref('diary_photos/$uid/$diaryId/${photoId}_t.jpg');

  /// 압축된 사진들을 로컬 파일로 저장하고 대기열에 기록한다(기기 디스크
  /// 쓰기만이라 빠르다) — 호출부(작성 화면)는 이 메서드가 끝나면 곧바로
  /// 화면을 닫을 수 있다("일기 재수정" 지시서 2-1, 2-2). 실제 업로드는
  /// 기다리지 않고 백그라운드로 넘긴다.
  Future<void> enqueue({
    required String uid,
    required String diaryId,
    required List<QueuedDiaryPhoto> photos,
  }) async {
    if (photos.isEmpty) return;
    final items = <DiaryPhotoQueueItem>[];
    try {
      for (final qp in photos) {
        final id = _newQueueItemId();
        final mainPath = await writeDiaryPhotoQueueFile('${id}_main.jpg', qp.processed.mainBytes);
        final thumbPath = await writeDiaryPhotoQueueFile('${id}_thumb.jpg', qp.processed.thumbBytes);
        items.add(DiaryPhotoQueueItem(
          id: id,
          uid: uid,
          diaryId: diaryId,
          order: qp.order,
          mainFilePath: mainPath,
          thumbFilePath: thumbPath,
          width: qp.processed.width,
          height: qp.processed.height,
        ));
      }
    } catch (e) {
      // 로컬 파일 쓰기 자체가 실패하면(저장공간 부족 등) 이번 호출에서
      // 이미 써둔 파일만 정리하고 그대로 예외를 올린다 — 호출부가 기존
      // "일기 저장 실패" 처리로 안내한다.
      for (final item in items) {
        await deleteDiaryPhotoQueueFile(item.mainFilePath);
        await deleteDiaryPhotoQueueFile(item.thumbFilePath);
      }
      rethrow;
    }
    await _store.addAll(items);
    _notifyChanged();
    unawaited(processPending());
  }

  /// 지금 보낼 수 있는(백오프 대기 중이 아니고 포기하지 않은) 항목을
  /// 최대 [_uploadConcurrency]장까지 동시에 올린다 — 앱 시작·포그라운드
  /// 복귀 시, [enqueue] 직후, "다시 시도" 버튼에서 부른다. 이미 처리
  /// 중이면 중복 실행하지 않는다.
  Future<void> processPending() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_processing) return;
    _processing = true;
    try {
      while (true) {
        final now = DateTime.now();
        final all = await _store.load();
        if (all.isEmpty) return;
        final ready = all.where((i) => diaryPhotoUploadReadyToAttempt(i, now)).toList();
        if (ready.isEmpty) {
          _scheduleNextRetry(all, now);
          return;
        }
        await Future.wait(ready.take(_uploadConcurrency).map(_processOne));
      }
    } finally {
      _processing = false;
    }
  }

  /// 아직 백오프 대기 중인(포기하지 않은) 항목이 있으면, 그중 가장 빠른
  /// 시각에 맞춰 한 번 더 [processPending]을 부른다 — 앱이 계속 켜져
  /// 있는 동안은 사용자가 아무것도 하지 않아도 자동으로 재시도된다.
  void _scheduleNextRetry(List<DiaryPhotoQueueItem> all, DateTime now) {
    final waitingTimes = [
      for (final i in all)
        if (!diaryPhotoUploadGivenUp(i.attempts) && i.nextAttemptAt != null) i.nextAttemptAt!,
    ];
    if (waitingTimes.isEmpty) return;
    final earliest = waitingTimes.reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = earliest.difference(now);
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(processPending());
    });
  }

  Future<void> _processOne(DiaryPhotoQueueItem item) async {
    final succeeded = await _attemptUpload(item);
    if (!succeeded) {
      final attempts = item.attempts + 1;
      await _store.update(item.copyWith(
        attempts: attempts,
        nextAttemptAt: DateTime.now().add(diaryPhotoUploadBackoff(attempts)),
      ));
    }
    _notifyChanged();
  }

  /// [item.id]를 그대로 photoId로 써서, 재시도해도 항상 같은 Storage
  /// 경로에 덮어쓸 뿐 고아 파일이 쌓이지 않는다.
  Future<bool> _attemptUpload(DiaryPhotoQueueItem item) async {
    try {
      final mainFile = File(item.mainFilePath);
      final thumbFile = File(item.thumbFilePath);
      if (!await mainFile.exists() || !await thumbFile.exists()) {
        // 로컬 파일이 사라졌으면(기기 저장공간 정리 등) 재시도해도 의미가
        // 없다 — 이 항목만 포기하고 대기열에서 치운다(올리지 못했다는
        // 뜻이지만, 더 기다려도 달라지지 않는다).
        _log('로컬 파일이 사라져 포기함: ${item.id}');
        await _store.remove(item.id);
        return true;
      }
      final mainBytes = await mainFile.readAsBytes();
      final thumbBytes = await thumbFile.readAsBytes();
      final ref = _photoRef(item.uid, item.diaryId, item.id);
      final thumbRef = _thumbRef(item.uid, item.diaryId, item.id);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final urls = await Future.wait([
        ref.putData(mainBytes, metadata).then((_) => ref.getDownloadURL()),
        thumbRef.putData(thumbBytes, metadata).then((_) => thumbRef.getDownloadURL()),
      ]);
      final photo = DiaryPhoto(
        path: urls[0],
        thumbPath: urls[1],
        width: item.width,
        height: item.height,
        order: item.order,
      );
      await appendUploadedDiaryPhoto(_firestore, item.uid, item.diaryId, photo);
      // 방금 올린 바이트를 그대로 디스크 캐시에 넣어 둔다 — 목록·상세가
      // 같은 URL을 다시 받아오지 않고 바로 보여준다(기존 캐시 주입
      // 로직 재사용, "일기 재수정" 지시서 2-3).
      await cacheUploadedDiaryPhotos(
        [(url: urls[0], bytes: mainBytes), (url: urls[1], bytes: thumbBytes)],
        _cacheWriter,
      );
      await _store.remove(item.id);
      await deleteDiaryPhotoQueueFile(item.mainFilePath);
      await deleteDiaryPhotoQueueFile(item.thumbFilePath);
      return true;
    } catch (e) {
      _log('업로드 실패(재시도 예정) ${item.id}: $e');
      return false;
    }
  }

  /// 이 일기를 삭제할 때 대기열·로컬 파일도 함께 치운다("일기 재수정"
  /// 지시서 2-6) — Storage에 이미 올라간 사진은
  /// `FirestoreDiaryRepository.deleteDiary`가 따로 지운다(이 서비스는
  /// 아직 안 올라간 것만 안다).
  Future<void> cancelForDiary(String diaryId) async {
    final items = await _store.loadForDiary(diaryId);
    for (final item in items) {
      await deleteDiaryPhotoQueueFile(item.mainFilePath);
      await deleteDiaryPhotoQueueFile(item.thumbFilePath);
    }
    await _store.removeForDiary(diaryId);
    _notifyChanged();
  }

  /// 회원 탈퇴 시 이 계정의 대기열·로컬 파일을 전부 지운다("일기 재수정"
  /// 지시서 2-6).
  Future<void> cancelAllForUid(String uid) async {
    final items = await _store.load();
    for (final item in items) {
      if (item.uid != uid) continue;
      await deleteDiaryPhotoQueueFile(item.mainFilePath);
      await deleteDiaryPhotoQueueFile(item.thumbFilePath);
    }
    await _store.removeForUid(uid);
    _notifyChanged();
  }

  /// "사진을 올리지 못했어요 · 다시 시도" 버튼 — 포기한(최대 횟수를 채운)
  /// 항목도 다시 시도할 수 있게 시도 횟수를 초기화하고 바로 처리를
  /// 다시 시작한다.
  Future<void> retryDiary(String diaryId) async {
    final items = await _store.loadForDiary(diaryId);
    for (final item in items) {
      await _store.update(DiaryPhotoQueueItem(
        id: item.id,
        uid: item.uid,
        diaryId: item.diaryId,
        order: item.order,
        mainFilePath: item.mainFilePath,
        thumbFilePath: item.thumbFilePath,
        width: item.width,
        height: item.height,
      ));
    }
    _notifyChanged();
    unawaited(processPending());
  }
}
