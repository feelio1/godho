import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/diary_calendar.dart';
import 'package:petcliniccheck/diary/models/diary.dart';

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
}
