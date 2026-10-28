import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/data/firestore_diary_repository.dart';
import 'package:petcliniccheck/diary/models/diary.dart';

/// [FirestoreDiaryRepository]의 Firestore-only 경로("일기 재수정"
/// 지시서 2) — 사진 업로드(Storage)는 이제 이 클래스가 하지 않으므로,
/// Storage 가짜 없이도 `createDiary`/`updateDiary`(사진 제거 없는 경우)
/// 를 `fake_cloud_firestore`로 직접 검증할 수 있다. 사진 제거가 있는
/// 경로(Storage 삭제)는 기존 제약대로 테스트하지 않는다.
void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreDiaryRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreDiaryRepository(firestore: firestore);
  });

  Diary diaryFixture({List<DiaryPhoto> photos = const []}) => Diary(
        id: '',
        date: DateTime(2026, 1, 1),
        petIds: const ['p1'],
        text: '오늘 일기',
        photos: photos,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  group('createDiary — 사진 업로드를 기다리지 않고 바로 만든다("일기 재수정" 지시서 2-1)', () {
    test('문서를 바로 만들고 photos는 항상 비어 있다(호출부가 사진을 줘도)', () async {
      final diaryWithPhotos = diaryFixture(photos: const [DiaryPhoto(path: 'should-be-ignored', width: 1, height: 1)]);
      final id = await repo.createDiary('u1', diaryWithPhotos, pendingPhotoCount: 2);

      final doc = await firestore.collection('users').doc('u1').collection('diaries').doc(id).get();
      final data = doc.data()!;
      expect(data['photos'], isEmpty);
      expect(data['pendingPhotoCount'], 2);
    });

    test('사진이 없으면(글만 작성) pendingPhotoCount도 0이다', () async {
      final id = await repo.createDiary('u1', diaryFixture());
      final doc = await firestore.collection('users').doc('u1').collection('diaries').doc(id).get();
      expect(doc.data()!['pendingPhotoCount'], 0);
    });
  });

  group('updateDiary — 새 사진은 올리지 않고 pendingPhotoCount만 늘린다("일기 재수정" 지시서 2-5)', () {
    test('새 사진이 없으면(글만 수정) 기존 pendingPhotoCount를 건드리지 않는다', () async {
      final docRef = firestore.collection('users').doc('u1').collection('diaries').doc();
      await docRef.set(diaryFixture().copyWith(pendingPhotoCount: 2).toFirestore());
      final existing = Diary.fromFirestore(docRef.id, (await docRef.get()).data()!);

      await repo.updateDiary('u1', existing.copyWith(text: '수정된 글'));

      final updated = await docRef.get();
      expect(updated.data()!['text'], '수정된 글');
      expect(updated.data()!['pendingPhotoCount'], 2);
    });

    test('새 사진을 추가하면(newPendingPhotoCount) 기존 값에 더해진다(덮어쓰지 않음)', () async {
      final docRef = firestore.collection('users').doc('u1').collection('diaries').doc();
      await docRef.set(diaryFixture().copyWith(pendingPhotoCount: 1).toFirestore());
      final existing = Diary.fromFirestore(docRef.id, (await docRef.get()).data()!);

      await repo.updateDiary('u1', existing, newPendingPhotoCount: 3);

      final updated = await docRef.get();
      expect(updated.data()!['pendingPhotoCount'], 4);
    });

    test('기존 사진(order 포함)을 준 그대로 저장한다 — 제거 없이', () async {
      final docRef = firestore.collection('users').doc('u1').collection('diaries').doc();
      await docRef.set(diaryFixture().toFirestore());
      final existing = Diary.fromFirestore(docRef.id, (await docRef.get()).data()!);
      final kept = [const DiaryPhoto(path: 'https://example.com/a.jpg', width: 1, height: 1, order: 0)];

      await repo.updateDiary('u1', existing.copyWith(photos: kept));

      final updated = await docRef.get();
      final photos = updated.data()!['photos'] as List;
      expect(photos, hasLength(1));
      expect(photos.single['path'], 'https://example.com/a.jpg');
    });
  });
}
