import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/notifications/diary_reminder_schedule.dart';

/// 일기 알림 — "매일 반복" 대신 14일치 1회성 알림으로("일기 보완"
/// 지시서 2). 순수 날짜 계산만 검증한다(실제 예약/취소는
/// NotificationService가 플랫폼 플러그인을 통해 한다).
void main() {
  group('diaryReminderNotificationId — 날짜별 고유 id', () {
    test('같은 날짜는 항상 같은 id다', () {
      final a = diaryReminderNotificationId(DateTime(2026, 5, 1, 9));
      final b = diaryReminderNotificationId(DateTime(2026, 5, 1, 21));
      expect(a, b);
    });

    test('다른 날짜는 다른 id다', () {
      final a = diaryReminderNotificationId(DateTime(2026, 5, 1));
      final b = diaryReminderNotificationId(DateTime(2026, 5, 2));
      expect(a, isNot(b));
    });

    test('예약 알림 id 범위(31비트 해시)·테스트 알림 id(999999, 999998)와 떨어져 있다', () {
      final id = diaryReminderNotificationId(DateTime(2026, 5, 1));
      expect(id, greaterThan(1000000));
      expect(id, lessThan(1 << 31));
    });
  });

  group('diaryReminderWindowDates — 오늘부터 14일(오늘 포함)', () {
    test('기본 14일을 오늘부터 하루씩 돌려준다', () {
      final dates = diaryReminderWindowDates(today: DateTime(2026, 5, 1));
      expect(dates, hasLength(kDiaryReminderWindowDays));
      expect(dates.first, DateTime(2026, 5, 1));
      expect(dates.last, DateTime(2026, 5, 14));
    });

    test('월을 넘어가도 하루씩 이어진다', () {
      final dates = diaryReminderWindowDates(today: DateTime(2026, 1, 25), windowDays: 10);
      expect(dates, [
        for (var d = 25; d <= 31; d++) DateTime(2026, 1, d),
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 2),
        DateTime(2026, 2, 3),
      ]);
    });
  });

  group('diaryReminderStaleDates — 지난 건 정리', () {
    test('오늘보다 이전인 날짜만 골라낸다', () {
      final stale = diaryReminderStaleDates(
        [DateTime(2026, 4, 28), DateTime(2026, 4, 30), DateTime(2026, 5, 1), DateTime(2026, 5, 2)],
        today: DateTime(2026, 5, 1),
      );
      expect(stale, [DateTime(2026, 4, 28), DateTime(2026, 4, 30)]);
    });

    test('전부 오늘 이후면 빈 목록이다', () {
      final stale = diaryReminderStaleDates(
        [DateTime(2026, 5, 1), DateTime(2026, 5, 2)],
        today: DateTime(2026, 5, 1),
      );
      expect(stale, isEmpty);
    });
  });

  group('diaryReminderDatesToSchedule — 재채움 시 새로 예약할 날짜만', () {
    final windowDates = diaryReminderWindowDates(today: DateTime(2026, 5, 1), windowDays: 5);
    // [2026-05-01, 05-02, 05-03, 05-04, 05-05]

    test('이미 예약된 날짜는 다시 포함하지 않는다', () {
      final toSchedule = diaryReminderDatesToSchedule(
        windowDates: windowDates,
        alreadyScheduledDates: {DateTime(2026, 5, 1), DateTime(2026, 5, 2)},
      );
      expect(toSchedule, [DateTime(2026, 5, 3), DateTime(2026, 5, 4), DateTime(2026, 5, 5)]);
    });

    test('오늘 일기를 써서 막 취소한 날은 되살리지 않는다', () {
      final toSchedule = diaryReminderDatesToSchedule(
        windowDates: windowDates,
        alreadyScheduledDates: {DateTime(2026, 5, 2), DateTime(2026, 5, 3), DateTime(2026, 5, 4), DateTime(2026, 5, 5)},
        skippedDate: DateTime(2026, 5, 1),
      );
      expect(toSchedule, isEmpty);
    });

    test('아무것도 예약돼 있지 않으면 창 전체를 새로 예약한다', () {
      final toSchedule = diaryReminderDatesToSchedule(windowDates: windowDates, alreadyScheduledDates: const {});
      expect(toSchedule, windowDates);
    });

    test('skippedDate가 창 밖(과거)이면 영향이 없다', () {
      final toSchedule = diaryReminderDatesToSchedule(
        windowDates: windowDates,
        alreadyScheduledDates: const {},
        skippedDate: DateTime(2026, 4, 20),
      );
      expect(toSchedule, windowDates);
    });
  });
}
