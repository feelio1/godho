import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/diary/diary_photo_upload_queue.dart';

DiaryPhotoQueueItem _item(
  String id, {
  String uid = 'uid-1',
  String diaryId = 'diary-1',
  int order = 0,
  int attempts = 0,
  DateTime? nextAttemptAt,
}) =>
    DiaryPhotoQueueItem(
      id: id,
      uid: uid,
      diaryId: diaryId,
      order: order,
      mainFilePath: '/tmp/${id}_main.jpg',
      thumbFilePath: '/tmp/${id}_thumb.jpg',
      width: 2048,
      height: 1536,
      attempts: attempts,
      nextAttemptAt: nextAttemptAt,
    );

void main() {
  group('DiaryPhotoQueueItem JSON 왕복', () {
    test('모든 필드가 그대로 보존된다(nextAttemptAt 있음)', () {
      final item = _item('a', order: 2, attempts: 3, nextAttemptAt: DateTime(2026, 1, 1, 9));
      final restored = DiaryPhotoQueueItem.fromJson(item.toJson());

      expect(restored.id, item.id);
      expect(restored.uid, item.uid);
      expect(restored.diaryId, item.diaryId);
      expect(restored.order, item.order);
      expect(restored.mainFilePath, item.mainFilePath);
      expect(restored.thumbFilePath, item.thumbFilePath);
      expect(restored.width, item.width);
      expect(restored.height, item.height);
      expect(restored.attempts, item.attempts);
      expect(restored.nextAttemptAt, item.nextAttemptAt);
    });

    test('nextAttemptAt이 없으면 null로 보존된다', () {
      final item = _item('b');
      final restored = DiaryPhotoQueueItem.fromJson(item.toJson());
      expect(restored.nextAttemptAt, isNull);
    });
  });

  group('DiaryPhotoUploadQueueStore — SharedPreferences 영속("일기 재수정" 지시서 2-4)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('빈 상태에서 load()는 빈 목록이다', () async {
      expect(await const DiaryPhotoUploadQueueStore().load(), isEmpty);
    });

    test('addAll로 넣은 항목을 그대로 load()로 돌려받는다', () async {
      const store = DiaryPhotoUploadQueueStore();
      await store.addAll([_item('a'), _item('b')]);
      final items = await store.load();
      expect(items.map((e) => e.id), ['a', 'b']);
    });

    test('update는 id가 일치하는 항목만 바꾼다', () async {
      const store = DiaryPhotoUploadQueueStore();
      await store.addAll([_item('a'), _item('b')]);
      await store.update(_item('a', attempts: 5));
      final items = await store.load();
      expect(items.firstWhere((e) => e.id == 'a').attempts, 5);
      expect(items.firstWhere((e) => e.id == 'b').attempts, 0);
    });

    test('remove는 그 id만 지운다', () async {
      const store = DiaryPhotoUploadQueueStore();
      await store.addAll([_item('a'), _item('b')]);
      await store.remove('a');
      final items = await store.load();
      expect(items.map((e) => e.id), ['b']);
    });

    test('removeForDiary는 그 일기의 항목만 지운다', () async {
      const store = DiaryPhotoUploadQueueStore();
      await store.addAll([
        _item('a', diaryId: 'd1'),
        _item('b', diaryId: 'd2'),
        _item('c', diaryId: 'd1'),
      ]);
      await store.removeForDiary('d1');
      final items = await store.load();
      expect(items.map((e) => e.id), ['b']);
    });

    test('removeForUid는 그 계정의 항목만 지운다', () async {
      const store = DiaryPhotoUploadQueueStore();
      await store.addAll([
        _item('a', uid: 'u1'),
        _item('b', uid: 'u2'),
      ]);
      await store.removeForUid('u1');
      final items = await store.load();
      expect(items.map((e) => e.id), ['b']);
    });

    test('loadForDiary는 그 일기의 항목만 돌려준다', () async {
      const store = DiaryPhotoUploadQueueStore();
      await store.addAll([
        _item('a', diaryId: 'd1'),
        _item('b', diaryId: 'd2'),
      ]);
      final items = await store.loadForDiary('d1');
      expect(items.map((e) => e.id), ['a']);
    });

    test('앱이 꺼졌다 켜져도(새 저장소 인스턴스) 이어서 보인다 — 같은 SharedPreferences를 그대로 읽는다', () async {
      await const DiaryPhotoUploadQueueStore().addAll([_item('a')]);
      // "재시작"을 흉내 — 새 인스턴스를 만들어도 영속 저장소(SharedPreferences)는 그대로다.
      final restarted = const DiaryPhotoUploadQueueStore();
      final items = await restarted.load();
      expect(items.map((e) => e.id), ['a']);
    });
  });

  group('백오프·재시도 판단("일기 재수정" 지시서 2-4)', () {
    test('실패 횟수가 늘수록 대기 시간이 두 배씩 늘고 5분을 넘지 않는다', () {
      expect(diaryPhotoUploadBackoff(1), const Duration(seconds: 5));
      expect(diaryPhotoUploadBackoff(2), const Duration(seconds: 10));
      expect(diaryPhotoUploadBackoff(3), const Duration(seconds: 20));
      expect(diaryPhotoUploadBackoff(4), const Duration(seconds: 40));
      expect(diaryPhotoUploadBackoff(10).inSeconds, lessThanOrEqualTo(300));
      expect(diaryPhotoUploadBackoff(20).inSeconds, 300);
    });

    test('최대 횟수를 채우면 포기 상태다', () {
      expect(diaryPhotoUploadGivenUp(kDiaryPhotoUploadMaxAttempts - 1), isFalse);
      expect(diaryPhotoUploadGivenUp(kDiaryPhotoUploadMaxAttempts), isTrue);
      expect(diaryPhotoUploadGivenUp(kDiaryPhotoUploadMaxAttempts + 1), isTrue);
    });

    test('포기한 항목은 지금 바로 보내도 되는지에서 항상 false다', () {
      final item = _item('a', attempts: kDiaryPhotoUploadMaxAttempts);
      expect(diaryPhotoUploadReadyToAttempt(item, DateTime.now()), isFalse);
    });

    test('nextAttemptAt이 없으면(처음 실패 전) 바로 보내도 된다', () {
      final item = _item('a');
      expect(diaryPhotoUploadReadyToAttempt(item, DateTime.now()), isTrue);
    });

    test('백오프 시각이 아직 안 지났으면 보내지 않는다', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final item = _item('a', attempts: 1, nextAttemptAt: now.add(const Duration(seconds: 10)));
      expect(diaryPhotoUploadReadyToAttempt(item, now), isFalse);
    });

    test('백오프 시각이 지났으면 다시 보내도 된다', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final item = _item('a', attempts: 1, nextAttemptAt: now.subtract(const Duration(seconds: 1)));
      expect(diaryPhotoUploadReadyToAttempt(item, now), isTrue);
    });
  });
}
