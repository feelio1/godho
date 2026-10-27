import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  /// 원본(인쇄용, 긴 변 [kDiaryPhotoMainLongSide])·썸네일(긴 변
  /// [kDiaryPhotoThumbLongSide]) 2벌을 만들어 함께 올린다("일기 활성화"
  /// 지시서 A) — 두 벌 모두 EXIF(위치 등)를 지운 상태로 인코딩한다.
  /// 가로·세로는 실제로 처리한(추정하지 않은) 원본 쪽 값을 쓴다.
  ///
  /// 디코딩·리사이즈·인코딩([processDiaryPhotosSequentially]이 맡는다 —
  /// 한 장씩 순차로, 메인 isolate 밖에서, "일기 보완" 지시서 1)이 끝난
  /// 결과만 올린다. 디코딩에 실패한 사진(깨진 파일 등)은 그 사진만
  /// 조용히 빼고 계속 올린다 — 업로드 자체(네트워크)가 실패하면 그대로
  /// 예외가 올라가 저장을 멈춘다.
  Future<List<DiaryPhoto>> _uploadPhotos(
    String uid,
    String diaryId,
    List<File> files, {
    DiaryPhotoProgressCallback? onPhotoProgress,
    void Function()? onPhotoDecodeFailed,
  }) async {
    final processedList = await processDiaryPhotosSequentially(files, onProgress: onPhotoProgress);

    final photos = <DiaryPhoto>[];
    for (final processed in processedList) {
      if (processed == null) {
        onPhotoDecodeFailed?.call();
        continue;
      }
      final photoId = _newPhotoId();
      final ref = _photoRef(uid, diaryId, photoId);
      final thumbRef = _thumbRef(uid, diaryId, photoId);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(processed.mainBytes, metadata);
      await thumbRef.putData(processed.thumbBytes, metadata);
      final url = await ref.getDownloadURL();
      final thumbUrl = await thumbRef.getDownloadURL();
      photos.add(DiaryPhoto(path: url, thumbPath: thumbUrl, width: processed.width, height: processed.height));
    }
    return photos;
  }

  @override
  Future<String> createDiary(
    String uid,
    Diary diary,
    List<File> photoFiles, {
    DiaryPhotoProgressCallback? onPhotoProgress,
    void Function()? onPhotoDecodeFailed,
  }) async {
    final docRef = _diaries(uid).doc();
    // 사진 업로드가 하나라도 실패하면 여기서 예외가 던져지고, 문서는
    // 아직 만들어지지 않은 채로 끝난다("업로드 실패 시 일기 저장 안 함").
    final photos = await _uploadPhotos(
      uid,
      docRef.id,
      photoFiles,
      onPhotoProgress: onPhotoProgress,
      onPhotoDecodeFailed: onPhotoDecodeFailed,
    );
    await docRef.set(diary.copyWith(photos: photos).toFirestore());
    return docRef.id;
  }

  @override
  Future<void> updateDiary(
    String uid,
    Diary diary, {
    List<File> newPhotoFiles = const [],
    List<DiaryPhoto> removedPhotos = const [],
    DiaryPhotoProgressCallback? onPhotoProgress,
    void Function()? onPhotoDecodeFailed,
  }) async {
    // 새 사진 업로드가 실패하면 여기서 예외가 올라가고, 기존 문서·사진은
    // 전혀 건드리지 않은 채로 끝난다(부분 저장 없음).
    final newPhotos = await _uploadPhotos(
      uid,
      diary.id,
      newPhotoFiles,
      onPhotoProgress: onPhotoProgress,
      onPhotoDecodeFailed: onPhotoDecodeFailed,
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
