import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  /// 책 인쇄를 염두에 둔 원본 비율 유지를 위해, 업로드 전 실제 디코딩한
  /// 가로·세로를 쓴다(추정하지 않음) — "방향 개편" 지시서 C.
  Future<({int width, int height})> _decodeSize(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = (width: frame.image.width, height: frame.image.height);
    frame.image.dispose();
    return size;
  }

  Future<List<DiaryPhoto>> _uploadPhotos(String uid, String diaryId, List<File> files) async {
    final photos = <DiaryPhoto>[];
    for (final file in files) {
      final size = await _decodeSize(file);
      final ref = _photoRef(uid, diaryId, _newPhotoId());
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      photos.add(DiaryPhoto(path: url, width: size.width, height: size.height));
    }
    return photos;
  }

  @override
  Future<String> createDiary(String uid, Diary diary, List<File> photoFiles) async {
    final docRef = _diaries(uid).doc();
    // 사진 업로드가 하나라도 실패하면 여기서 예외가 던져지고, 문서는
    // 아직 만들어지지 않은 채로 끝난다("업로드 실패 시 일기 저장 안 함").
    final photos = await _uploadPhotos(uid, docRef.id, photoFiles);
    await docRef.set(diary.copyWith(photos: photos).toFirestore());
    return docRef.id;
  }

  @override
  Future<void> updateDiary(
    String uid,
    Diary diary, {
    List<File> newPhotoFiles = const [],
    List<String> removedPhotoPaths = const [],
  }) async {
    // 새 사진 업로드가 실패하면 여기서 예외가 올라가고, 기존 문서·사진은
    // 전혀 건드리지 않은 채로 끝난다(부분 저장 없음).
    final newPhotos = await _uploadPhotos(uid, diary.id, newPhotoFiles);
    final keptPhotos = diary.photos.where((p) => !removedPhotoPaths.contains(p.path)).toList();
    final toSave = diary.copyWith(photos: [...keptPhotos, ...newPhotos]);
    await _diaries(uid).doc(diary.id).update(toSave.toFirestoreUpdate());

    for (final path in removedPhotoPaths) {
      try {
        await _storage.refFromURL(path).delete();
      } catch (_) {
        // 이미 지워졌거나 일시적 오류 — 문서는 이미 갱신됐으니 무시하고
        // 계속 진행한다(펫 사진 삭제와 같은 관례).
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
