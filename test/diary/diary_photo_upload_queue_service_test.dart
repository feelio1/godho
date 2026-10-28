import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/diary_photo_upload_queue_service.dart';
import 'package:petcliniccheck/diary/models/diary.dart';

/// 업로드 완료 뒤 Firestore 문서 갱신("일기 재수정" 지시서 2-2) —
/// Storage 의존이 없는 [appendUploadedDiaryPhoto]만 `fake_cloud_firestore`
/// 로 직접 검증한다(이 프로젝트에 Storage 가짜가 없는 기존 제약과 같은
/// 이유로, 실제 업로드(`DiaryPhotoUploadQueueService.enqueue`/
/// `processPending`)는 여기서 테스트하지 않는다).
void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<void> seedDiary(String uid, String diaryId, {int pendingPhotoCount = 1, List<Map<String, dynamic>> photos = const []}) async {
    await firestore.collection('users').doc(uid).collection('diaries').doc(diaryId).set({
      'date': DateTime(2026, 1, 1),
      'petIds': ['p1'],
      'weather': null,
      'activities': <String>[],
      'text': '',
      'photos': photos,
      'createdAt': DateTime(2026, 1, 1),
      'updatedAt': DateTime(2026, 1, 1),
      'pendingPhotoCount': pendingPhotoCount,
    });
  }

  test('photos 배열에 더하고 pendingPhotoCount를 하나 줄인다', () async {
    await seedDiary('u1', 'd1', pendingPhotoCount: 2);
    const photo = DiaryPhoto(path: 'https://example.com/a.jpg', thumbPath: 'https://example.com/a_t.jpg', width: 2048, height: 1536, order: 0);

    await appendUploadedDiaryPhoto(firestore, 'u1', 'd1', photo);

    final doc = await firestore.collection('users').doc('u1').collection('diaries').doc('d1').get();
    final data = doc.data()!;
    expect((data['photos'] as List).length, 1);
    expect((data['photos'] as List).first['path'], 'https://example.com/a.jpg');
    expect(data['pendingPhotoCount'], 1);
  });

  test('이미 사진이 있던 문서에 추가해도 기존 사진은 그대로 남는다', () async {
    await seedDiary('u1', 'd1', pendingPhotoCount: 1, photos: [
      {'path': 'https://example.com/old.jpg', 'width': 100, 'height': 100, 'order': 0},
    ]);
    const photo = DiaryPhoto(path: 'https://example.com/new.jpg', width: 2048, height: 1536, order: 1);

    await appendUploadedDiaryPhoto(firestore, 'u1', 'd1', photo);

    final doc = await firestore.collection('users').doc('u1').collection('diaries').doc('d1').get();
    final photos = doc.data()!['photos'] as List;
    expect(photos, hasLength(2));
    expect(photos.map((p) => p['path']), containsAll(['https://example.com/old.jpg', 'https://example.com/new.jpg']));
  });

  test('여러 장이 끝나는 순서와 무관하게(순차로 불러도) pendingPhotoCount는 정확히 줄어든다', () async {
    await seedDiary('u1', 'd1', pendingPhotoCount: 3);
    const a = DiaryPhoto(path: 'https://example.com/a.jpg', width: 1, height: 1, order: 0);
    const b = DiaryPhoto(path: 'https://example.com/b.jpg', width: 1, height: 1, order: 1);
    const c = DiaryPhoto(path: 'https://example.com/c.jpg', width: 1, height: 1, order: 2);

    // 동시 업로드가 끝나는 순서는 보장되지 않으므로(b가 먼저 끝날 수도
    // 있음) 호출 순서를 일부러 섞는다.
    await appendUploadedDiaryPhoto(firestore, 'u1', 'd1', b);
    await appendUploadedDiaryPhoto(firestore, 'u1', 'd1', a);
    await appendUploadedDiaryPhoto(firestore, 'u1', 'd1', c);

    final doc = await firestore.collection('users').doc('u1').collection('diaries').doc('d1').get();
    final data = doc.data()!;
    expect((data['photos'] as List).length, 3);
    expect(data['pendingPhotoCount'], 0);
  });
}
