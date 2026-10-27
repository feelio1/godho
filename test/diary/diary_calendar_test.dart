import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/diary_calendar.dart';
import 'package:petcliniccheck/diary/models/diary.dart';
import 'package:petcliniccheck/utils/appointment_calendar.dart' show dateOnly;

Diary _diary(String id, DateTime date) => Diary(
      id: id,
      date: date,
      petIds: const ['p1'],
      createdAt: date,
      updatedAt: date,
    );

/// "방향 개편" 지시서 E — 캘린더가 일기 마커·날짜별 목록에 쓰는 그룹화.
/// `groupRecordsByDate`/`groupAppointmentsByDate`와 같은 계약(시각은
/// 버리고 날짜만 키로 쓴다, 하루에 여러 건 허용)을 그대로 따르는지 확인.
void main() {
  group('groupDiariesByDate', () {
    test('같은 날 여러 편은 한 키에 함께 묶인다(순서 유지)', () {
      final morning = _diary('d1', DateTime(2026, 5, 1, 8));
      final evening = _diary('d2', DateTime(2026, 5, 1, 21));
      final grouped = groupDiariesByDate([morning, evening]);

      expect(grouped[DateTime(2026, 5, 1)]?.map((d) => d.id), ['d1', 'd2']);
    });

    test('시각이 달라도 날짜만 같으면 같은 키다', () {
      final a = _diary('d1', DateTime(2026, 5, 1, 23, 59));
      final grouped = groupDiariesByDate([a]);

      expect(grouped.containsKey(DateTime(2026, 5, 1)), isTrue);
      expect(grouped.containsKey(DateTime(2026, 5, 1, 23, 59)), isFalse);
    });

    test('날짜가 다르면 다른 키로 나뉜다', () {
      final a = _diary('d1', DateTime(2026, 5, 1));
      final b = _diary('d2', DateTime(2026, 5, 2));
      final grouped = groupDiariesByDate([a, b]);

      expect(grouped.keys, hasLength(2));
    });

    test('빈 목록은 빈 맵이다', () {
      expect(groupDiariesByDate(const []), isEmpty);
    });
  });

  group('onThisDayCandidates — "그날의 기록" 카드가 찾아볼 날짜("일기 활성화" 지시서 I)', () {
    test('1년 전 오늘이 먼저, 한 달 전 오늘이 그다음이다', () {
      final candidates = onThisDayCandidates(DateTime(2026, 5, 15));
      expect(candidates, [DateTime(2025, 5, 15), DateTime(2026, 4, 15)]);
    });

    test('1월이면 한 달 전은 전년도 12월로 넘어간다', () {
      final candidates = onThisDayCandidates(DateTime(2026, 1, 10));
      expect(candidates[1], DateTime(2025, 12, 10));
    });
  });

  group('diaryRecordedDays — "이달의 기록" 집계("일기 활성화" 지시서 J)', () {
    test('같은 날 여러 편이어도 하루로 센다', () {
      final a = _diary('d1', DateTime(2026, 5, 1, 8));
      final b = _diary('d2', DateTime(2026, 5, 1, 21));
      final c = _diary('d3', DateTime(2026, 5, 3));

      final days = diaryRecordedDays([a, b, c]);

      expect(days, {dateOnly(DateTime(2026, 5, 1)), dateOnly(DateTime(2026, 5, 3))});
    });

    test('빈 목록은 빈 집합이다', () {
      expect(diaryRecordedDays(const []), isEmpty);
    });
  });
}
