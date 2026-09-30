import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/utils/appointment_calendar.dart';

Appointment _appointment(String id, DateTime dateTime, {String petId = 'p1'}) => Appointment(
      id: id,
      petId: petId,
      dateTime: dateTime,
      hospitalName: '병원',
    );

void main() {
  group('dateOnly', () {
    test('시·분·초를 버리고 그 날 자정만 남긴다', () {
      final result = dateOnly(DateTime(2026, 9, 28, 15, 30, 45));
      expect(result, DateTime(2026, 9, 28));
    });

    test('시각이 달라도 같은 날이면 같은 값이 된다(Map 키·날짜 비교에 안전)', () {
      final morning = dateOnly(DateTime(2026, 9, 28, 0, 1));
      final night = dateOnly(DateTime(2026, 9, 28, 23, 59));
      expect(morning, night);
    });
  });

  group('groupAppointmentsByDate — 캘린더 월 뷰 마커·날짜별 목록의 기반', () {
    test('같은 날 여러 건은 한 키에 원래 순서 그대로 모인다', () {
      final morning = _appointment('a1', DateTime(2026, 9, 28, 9, 0));
      final afternoon = _appointment('a2', DateTime(2026, 9, 28, 15, 0));
      final grouped = groupAppointmentsByDate([morning, afternoon]);

      expect(grouped[DateTime(2026, 9, 28)]?.map((a) => a.id).toList(), ['a1', 'a2']);
    });

    test('날짜가 다르면 각각 다른 키로 나뉜다', () {
      final today = _appointment('a1', DateTime(2026, 9, 28, 9, 0));
      final tomorrow = _appointment('a2', DateTime(2026, 9, 29, 9, 0));
      final grouped = groupAppointmentsByDate([today, tomorrow]);

      expect(grouped.keys, hasLength(2));
      expect(grouped[DateTime(2026, 9, 28)]?.single.id, 'a1');
      expect(grouped[DateTime(2026, 9, 29)]?.single.id, 'a2');
    });

    test('빈 목록이면 빈 맵을 돌려준다(예약 없는 반려동물의 캘린더가 마커 없이 안전하게 뜸)', () {
      expect(groupAppointmentsByDate(const []), isEmpty);
    });

    test('예약이 없는 날짜로 조회하면 null(호출부는 ?? const []로 안전하게 처리)', () {
      final grouped = groupAppointmentsByDate([_appointment('a1', DateTime(2026, 9, 28))]);
      expect(grouped[DateTime(2026, 9, 29)], isNull);
    });
  });

  group('isPastDay — 캘린더에서 과거 날짜(진료기록 추가) vs 오늘·미래(예약 추가) 판단', () {
    test('어제는 과거다', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(isPastDay(yesterday), isTrue);
    });

    test('오늘은 과거로 치지 않는다', () {
      expect(isPastDay(DateTime.now()), isFalse);
    });

    test('내일은 과거가 아니다', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(isPastDay(tomorrow), isFalse);
    });

    test('시각과 무관하게 날짜만 본다(오늘 자정 직전이어도 과거가 아님)', () {
      final now = DateTime.now();
      final lateToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      expect(isPastDay(lateToday), isFalse);
    });
  });
}
