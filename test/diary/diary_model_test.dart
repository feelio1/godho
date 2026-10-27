import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/models/diary.dart';

/// "방향 개편" 지시서 C — Diary 모델이 Firestore 왕복에서 값을 그대로
/// 보존하는지, 필드가 누락된(예전/다른 서비스가 쓴) 문서를 읽어도 안전한
/// 기본값으로 떨어지는지 확인한다. fake_cloud_firestore로 실제 Timestamp
/// 변환까지 거쳐 fromFirestore/toFirestore 쌍을 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('Diary', () {
    test('toFirestore/fromFirestore 왕복에서 값이 보존된다', () async {
      final diary = Diary(
        id: 'ignored',
        date: DateTime(2026, 3, 5),
        petIds: const ['account:p1', 'account:p2'],
        weather: DiaryWeather.sunny,
        activities: const [DiaryActivity.walk, DiaryActivity.treat],
        text: '공원에서 신나게 뛰어놀았다.',
        photos: const [
          DiaryPhoto(path: 'https://example.com/a.jpg', width: 1200, height: 900),
        ],
        createdAt: DateTime(2026, 3, 5, 20),
        updatedAt: DateTime(2026, 3, 5, 20),
      );

      final ref = await firestore.collection('users').doc('u1').collection('diaries').add(diary.toFirestore());
      final doc = await ref.get();
      final restored = Diary.fromFirestore(doc.id, doc.data()!);

      expect(restored.date, DateTime(2026, 3, 5));
      expect(restored.petIds, ['account:p1', 'account:p2']);
      expect(restored.weather, DiaryWeather.sunny);
      expect(restored.activities, [DiaryActivity.walk, DiaryActivity.treat]);
      expect(restored.text, '공원에서 신나게 뛰어놀았다.');
      expect(restored.photos, hasLength(1));
      expect(restored.photos.single.path, 'https://example.com/a.jpg');
      expect(restored.photos.single.width, 1200);
      expect(restored.photos.single.height, 900);
    });

    test('필드가 누락된 문서는 안전한 기본값으로 떨어진다(하위호환)', () async {
      final ref = await firestore.collection('users').doc('u1').collection('diaries').add({});
      final doc = await ref.get();
      final restored = Diary.fromFirestore(doc.id, doc.data()!);

      expect(restored.petIds, isEmpty);
      expect(restored.weather, isNull);
      expect(restored.activities, isEmpty);
      expect(restored.text, '');
      expect(restored.photos, isEmpty);
    });

    test('썸네일 경로를 저장·복원한다("일기 활성화" 지시서 A)', () async {
      final diary = Diary(
        id: 'ignored',
        date: DateTime(2026, 3, 5),
        petIds: const ['p1'],
        photos: const [
          DiaryPhoto(path: 'https://example.com/a.jpg', thumbPath: 'https://example.com/a_t.jpg', width: 1200, height: 900),
        ],
        createdAt: DateTime(2026, 3, 5),
        updatedAt: DateTime(2026, 3, 5),
      );

      final ref = await firestore.collection('users').doc('u1').collection('diaries').add(diary.toFirestore());
      final doc = await ref.get();
      final restored = Diary.fromFirestore(doc.id, doc.data()!);

      expect(restored.photos.single.thumbPath, 'https://example.com/a_t.jpg');
      expect(restored.photos.single.displayThumbPath, 'https://example.com/a_t.jpg');
    });

    test('썸네일 없는 예전 사진은 원본으로 대체 표시한다(하위호환)', () {
      const photo = DiaryPhoto(path: 'https://example.com/a.jpg', width: 1200, height: 900);
      expect(photo.thumbPath, isNull);
      expect(photo.displayThumbPath, 'https://example.com/a.jpg');
    });

    test('알 수 없는 날씨/활동 값은 조용히 걸러진다(단정하지 않음)', () async {
      final ref = await firestore.collection('users').doc('u1').collection('diaries').add({
        'weather': 'tornado',
        'activities': ['walk', 'skydiving'],
      });
      final doc = await ref.get();
      final restored = Diary.fromFirestore(doc.id, doc.data()!);

      expect(restored.weather, isNull);
      expect(restored.activities, [DiaryActivity.walk]);
    });

    test('toFirestoreUpdate는 createdAt을 빼고 나머지는 그대로다', () {
      final diary = Diary(
        id: 'd1',
        date: DateTime(2026, 1, 1),
        petIds: const ['p1'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
      final update = diary.toFirestoreUpdate();
      expect(update.containsKey('createdAt'), isFalse);
      expect(update.containsKey('updatedAt'), isTrue);
    });

    test('copyWith로 날씨를 지울 수 있다(clearWeather)', () {
      final diary = Diary(
        id: 'd1',
        date: DateTime(2026, 1, 1),
        petIds: const ['p1'],
        weather: DiaryWeather.rainy,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final updated = diary.copyWith(clearWeather: true);
      expect(updated.weather, isNull);
    });
  });

  group('sortActivitiesByRecentUsage — 자주 쓴 태그부터("일기 활성화" 지시서 E)', () {
    Diary withActivities(List<DiaryActivity> activities) => Diary(
          id: 'd',
          date: DateTime(2026, 1, 1),
          petIds: const ['p1'],
          activities: activities,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

    test('기록이 없으면 원래(선언) 순서 그대로다', () {
      expect(sortActivitiesByRecentUsage(const []), DiaryActivity.values);
    });

    test('많이 쓴 태그가 앞으로 온다', () {
      final recent = [
        withActivities([DiaryActivity.bath]),
        withActivities([DiaryActivity.bath, DiaryActivity.walk]),
        withActivities([DiaryActivity.bath]),
      ];
      final sorted = sortActivitiesByRecentUsage(recent);

      expect(sorted.first, DiaryActivity.bath);
      expect(sorted.indexOf(DiaryActivity.walk), lessThan(sorted.indexOf(DiaryActivity.hospital)));
    });

    test('쓴 횟수가 같으면 원래 순서를 유지한다(동률 안정성)', () {
      final recent = [
        withActivities([DiaryActivity.hospital, DiaryActivity.outing]),
      ];
      final sorted = sortActivitiesByRecentUsage(recent);
      // hospital·outing 둘 다 1회로 동률 — 선언 순서(hospital이 outing보다 먼저)가 유지된다.
      expect(sorted.indexOf(DiaryActivity.hospital), lessThan(sorted.indexOf(DiaryActivity.outing)));
    });
  });

  group('capPhotoAdditions — "방향 개편" 지시서 C(사진 최대 $kDiaryMaxPhotos장)', () {
    test('아직 여유가 있으면 더할 목록을 그대로 돌려준다', () {
      final result = capPhotoAdditions(2, ['a', 'b', 'c']);
      expect(result, ['a', 'b', 'c']);
    });

    test('남은 자리보다 많이 더하려 하면 앞에서부터만 받아준다', () {
      final result = capPhotoAdditions(kDiaryMaxPhotos - 2, ['a', 'b', 'c', 'd']);
      expect(result, ['a', 'b']);
    });

    test('이미 가득 찼으면(또는 넘었으면) 아무것도 더하지 않는다', () {
      expect(capPhotoAdditions(kDiaryMaxPhotos, ['a']), isEmpty);
      expect(capPhotoAdditions(kDiaryMaxPhotos + 1, ['a']), isEmpty);
    });
  });
}
