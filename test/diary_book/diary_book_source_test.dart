import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/diary/diary_photo_upload_queue.dart';
import 'package:petcliniccheck/diary/models/diary.dart';
import 'package:petcliniccheck/diary_book/diary_book_source.dart';

final _query = DiaryBookQuery(
  uid: 'u1',
  petId: 'account:p1',
  petName: '구름이',
  start: DateTime(2026, 10, 1),
  end: DateTime(2026, 12, 31),
);

Diary _diary(String id, {List<DiaryPhoto> photos = const [], int pending = 0}) => Diary(
      id: id,
      date: DateTime(2026, 10, 5),
      petIds: const ['account:p1'],
      photos: photos,
      pendingPhotoCount: pending,
      createdAt: DateTime(2026, 10, 5),
      updatedAt: DateTime(2026, 10, 5),
    );

DiaryPhotoQueueItem _queued(String diaryId, int order) => DiaryPhotoQueueItem(
      id: '$diaryId-q$order',
      uid: 'u1',
      diaryId: diaryId,
      order: order,
      mainFilePath: '/local/$diaryId-$order.jpg',
      thumbFilePath: '/local/$diaryId-${order}_t.jpg',
      width: 2048,
      height: 1536,
    );

void main() {
  test('올라간 사진 + 이 기기 대기 중 사진을 order 순서로 합친다', () {
    final source = buildDiaryBookSource(
      query: _query,
      diaries: [
        _diary('d1', photos: const [
          DiaryPhoto(path: 'https://x/2.jpg', thumbPath: 'https://x/2_t.jpg', width: 10, height: 10, order: 2),
          DiaryPhoto(path: 'https://x/0.jpg', width: 10, height: 10, order: 0),
        ], pending: 1),
      ],
      pendingByDiary: {
        'd1': [_queued('d1', 1)],
      },
    );
    expect(source.input.entries.single.photos.map((p) => p.id), [
      'https://x/0.jpg',
      '$kBookLocalPhotoPrefix/local/d1-1.jpg',
      'https://x/2.jpg',
    ]);
    expect(source.thumbnails['https://x/2.jpg'], 'https://x/2_t.jpg');
    expect(source.missingPhotoCount, 0);
  });

  test('다른 기기에서 아직 올라가는 중인 사진은 빼고 그 수를 센다', () {
    final source = buildDiaryBookSource(
      query: _query,
      diaries: [
        // 올라가는 중 3장 중 이 기기 대기열에 1장 → 2장은 다른 기기.
        _diary('d1', pending: 3),
        // 다른 기기에서만 올리는 중 2장.
        _diary('d2', pending: 2),
        _diary('d3'),
      ],
      pendingByDiary: {
        'd1': [_queued('d1', 0)],
      },
    );
    expect(source.missingPhotoCount, 4);
    expect(source.input.entries[0].photos.length, 1);
    expect(source.input.entries[1].photos, isEmpty);
  });
}
