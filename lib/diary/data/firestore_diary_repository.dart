import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../../utils/concurrency.dart';
import '../diary_photo_processor.dart';
import '../models/diary.dart';
import 'diary_repository.dart';

String _newPhotoId() => '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

/// [DiaryRepository]의 Firestore + Storage 구현 — 생성자 주입으로
/// [FirebaseFirestore] 인스턴스를 바꿔 끼울 수 있다(`fake_cloud_firestore`
/// 등), `UserRepository`와 같은 관례.
class FirestoreDiaryRepository implements DiaryRepository {
  FirestoreDiaryRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// 사진 한 장 안에서 원본·썸네일을 동시에 올린다("일기 수정" 지시서
  /// 1-4) — 사진 여러 장 사이의 동시 개수 제한은 [mapWithConcurrency]가
  /// 맡는다.
  static const _uploadConcurrency = 3;

  CollectionReference<Map<String, dynamic>> _diaries(String uid) =>
      _firestore.collection('users').doc(uid).collection('diaries');

  @override
  Future<DiaryPage> fetchDiaries(String uid, {int limit = 20, Object? cursor}) async {
    Query<Map<String, dynamic>> query = _diaries(uid).orderBy('date', descending: true).limit(limit);
    if (cursor is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(cursor);
    }
    final snapshot = await query.get();
    final diaries = snapshot.docs.map((doc) => Diary.fromFirestore(doc.id, doc.data())).toList();
    return DiaryPage(
      diaries: diaries,
      cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  @override
  Future<List<Diary>> fetchDiariesForMonth(String uid, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final snapshot = await _diaries(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snapshot.docs.map((doc) => Diary.fromFirestore(doc.id, doc.data())).toList();
  }

  @override
  Future<Diary?> fetchDiary(String uid, String diaryId) async {
    final doc = await _diaries(uid).doc(diaryId).get();
    final data = doc.data();
    if (data == null) return null;
    return Diary.fromFirestore(doc.id, data);
  }

  Reference _photoRef(String uid, String diaryId, String photoId) =>
      _storage.ref('diary_photos/$uid/$diaryId/$photoId.jpg');

  Reference _thumbRef(String uid, String diaryId, String photoId) =>
      _storage.ref('diary_photos/$uid/$diaryId/${photoId}_t.jpg');

  /// 이미 압축이 끝난 [processed]를 올린다 — 압축(디코딩·리사이즈·네이티브
  /// 인코딩)은 작성 화면이 사진을 고르는 즉시 미리 끝내둔 뒤 넘기므로,
  /// 여기서는 업로드(네트워크)만 맡는다("일기 수정" 지시서 1). 사진
  /// 한 장의 원본·썸네일 `putData`+`getDownloadURL`을 동시에 하고, 사진
  /// 여러 장도 최대 [_uploadConcurrency]장까지 동시에 올려 사진마다
  /// 순차로 4번 기다리던 것을 없앤다. 하나라도 실패하면 이미 올라간
  /// 파일을 지우려 시도하고 그대로 예외를 다시 던진다(부분 저장 없음).
  Future<List<DiaryPhoto>> _uploadProcessedPhotos(
    String uid,
    String diaryId,
    List<ProcessedDiaryPhoto> processed, {
    DiaryPhotoUploadProgressCallback? onProgress,
  }) async {
    if (processed.isEmpty) return const [];
    final total = processed.length;
    var completedCount = 0;
    final uploadedRefs = <Reference>[];

    Future<DiaryPhoto> uploadOne(ProcessedDiaryPhoto p, int index) async {
      final stopwatch = Stopwatch()..start();
      final photoId = _newPhotoId();
      final ref = _photoRef(uid, diaryId, photoId);
      final thumbRef = _thumbRef(uid, diaryId, photoId);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final urls = await Future.wait([
        ref.putData(p.mainBytes, metadata).then((_) {
          uploadedRefs.add(ref);
          return ref.getDownloadURL();
        }),
        thumbRef.putData(p.thumbBytes, metadata).then((_) {
          uploadedRefs.add(thumbRef);
          return thumbRef.getDownloadURL();
        }),
      ]);
      completedCount++;
      onProgress?.call(completedCount, total);
      if (kDebugMode) {
        debugPrint('[DiaryPhotoTiming] 업로드 #$index ${stopwatch.elapsedMilliseconds}ms');
      }
      return DiaryPhoto(path: urls[0], thumbPath: urls[1], width: p.width, height: p.height);
    }

    try {
      return await mapWithConcurrency(processed, _uploadConcurrency, uploadOne);
    } catch (e) {
      // 업로드 실패 — 이미 올라간 파일은 지우려 시도한다("일기 수정"
      // 지시서 1-5). 정리 자체가 실패해도(이미 지워졌거나 일시적 오류)
      // 무시하고 원래 예외를 그대로 올린다.
      for (final ref in uploadedRefs) {
        try {
          await ref.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<String> createDiary(
    String uid,
    Diary diary,
    List<ProcessedDiaryPhoto> processedPhotos, {
    DiaryPhotoUploadProgressCallback? onPhotoProgress,
  }) async {
    final docRef = _diaries(uid).doc();
    // 사진 업로드가 하나라도 실패하면 여기서 예외가 던져지고, 문서는
    // 아직 만들어지지 않은 채로 끝난다("업로드 실패 시 일기 저장 안 함").
    final photos = await _uploadProcessedPhotos(
      uid,
      docRef.id,
      processedPhotos,
      onProgress: onPhotoProgress,
    );
    await docRef.set(diary.copyWith(photos: photos).toFirestore());
    return docRef.id;
  }

  @override
  Future<void> updateDiary(
    String uid,
    Diary diary, {
    List<ProcessedDiaryPhoto> newProcessedPhotos = const [],
    List<DiaryPhoto> removedPhotos = const [],
    DiaryPhotoUploadProgressCallback? onPhotoProgress,
  }) async {
    // 새 사진 업로드가 실패하면 여기서 예외가 올라가고, 기존 문서·사진은
    // 전혀 건드리지 않은 채로 끝난다(부분 저장 없음).
    final newPhotos = await _uploadProcessedPhotos(
      uid,
      diary.id,
      newProcessedPhotos,
      onProgress: onPhotoProgress,
    );
    final removedPaths = removedPhotos.map((p) => p.path).toSet();
    final keptPhotos = diary.photos.where((p) => !removedPaths.contains(p.path)).toList();
    final toSave = diary.copyWith(photos: [...keptPhotos, ...newPhotos]);
    await _diaries(uid).doc(diary.id).update(toSave.toFirestoreUpdate());

    // 원본·썸네일 둘 다 지운다("일기 활성화" 지시서 A) — 이미 지워졌거나
    // 일시적 오류는 무시하고 계속 진행한다(펫 사진 삭제와 같은 관례,
    // 문서는 이미 갱신됐으니).
    for (final photo in removedPhotos) {
      try {
        await _storage.refFromURL(photo.path).delete();
      } catch (_) {}
      final thumbPath = photo.thumbPath;
      if (thumbPath != null) {
        try {
          await _storage.refFromURL(thumbPath).delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> deleteDiary(String uid, String diaryId) async {
    try {
      final listed = await _storage.ref('diary_photos/$uid/$diaryId').listAll();
      for (final item in listed.items) {
        await item.delete();
      }
    } catch (_) {
      // 사진이 애초에 없었거나 일시적 오류 — 문서 삭제는 계속 진행한다.
    }
    await _diaries(uid).doc(diaryId).delete();
  }
}
