import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/diary.dart';
import 'diary_repository.dart';

/// [DiaryRepository]의 Firestore + Storage 구현 — 생성자 주입으로
/// [FirebaseFirestore] 인스턴스를 바꿔 끼울 수 있다(`fake_cloud_firestore`
/// 등), `UserRepository`와 같은 관례.
///
/// 사진 업로드(네트워크)는 이 클래스가 맡지 않는다("일기 재수정" 지시서
/// 2) — [DiaryPhotoUploadQueueService]가 Storage에 직접 올리고, 끝나면
/// 그 서비스가 이 저장소와 같은 경로(`users/{uid}/diaries/{diaryId}`)의
/// `photos`/`pendingPhotoCount` 필드만 원자적으로(`FieldValue`) 갱신한다.
class FirestoreDiaryRepository implements DiaryRepository {
  FirestoreDiaryRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storageOverride = storage;

  final FirebaseFirestore _firestore;
  // Storage는 지우는 사진이 있을 때만 쓴다 — 생성자에서 바로
  // `FirebaseStorage.instance`를 건드리지 않아야(지연 평가) Storage
  // 가짜가 없는 이 프로젝트에서도 Firestore만 쓰는 메서드(createDiary,
  // 사진 제거 없는 updateDiary)를 `fake_cloud_firestore`로 테스트할 수
  // 있다.
  final FirebaseStorage? _storageOverride;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

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

  @override
  Future<String> createDiary(String uid, Diary diary, {int pendingPhotoCount = 0}) async {
    final docRef = _diaries(uid).doc();
    await docRef.set(diary.copyWith(photos: const [], pendingPhotoCount: pendingPhotoCount).toFirestore());
    return docRef.id;
  }

  @override
  Future<void> updateDiary(
    String uid,
    Diary diary, {
    List<DiaryPhoto> removedPhotos = const [],
    int newPendingPhotoCount = 0,
  }) async {
    // pendingPhotoCount는 늘어난 만큼만 원자적으로 더한다(FieldValue.
    // increment) — 호출부가 준 [diary] 객체의 그 필드 값(보통 0, 호출부가
    // 들고 있지 않은 값)으로 그냥 덮어쓰면, 아직 안 끝난 이전 업로드의
    // pendingPhotoCount를 지워버릴 수 있다. 새 사진이 없으면(0) 건드리지
    // 않는다.
    final update = diary.toFirestoreUpdate()..remove('pendingPhotoCount');
    if (newPendingPhotoCount != 0) {
      update['pendingPhotoCount'] = FieldValue.increment(newPendingPhotoCount);
    }
    await _diaries(uid).doc(diary.id).update(update);

    // 원본·썸네일 둘 다 지운다("일기 활성화" 지시서 A) — 대기열과 달리
    // 미루지 않고 바로 지운다("일기 재수정" 지시서 2-5). 이미 지워졌거나
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
