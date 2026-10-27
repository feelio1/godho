import '../utils/appointment_calendar.dart' show dateOnly;

/// 일기 알림 — "매일 반복" 알람 1개 대신, 앞으로 [kDiaryReminderWindowDays]
/// 일치를 날짜마다 1회성 알림으로 예약한다("일기 보완" 지시서 2) — 반복
/// 알람은 특정 날짜 하나만 건너뛸 수단이 없어서(오늘 썼으면 오늘만
/// 취소) 이 방식으로 바꿨다. 이 파일은 순수 날짜 계산만 맡아 플러그인
/// 없이도 테스트할 수 있다 — 실제 예약/취소는 `NotificationService`가
/// 이 계산 결과를 가지고 한다.
const int kDiaryReminderWindowDays = 14;

/// 예약 알림 id 범위(해시 기반, appointmentId.hashCode 전체 31비트를
/// 씀)·테스트 알림 id(999999, 999998)와 떨어뜨려 둔 전용 구간.
const int kDiaryReminderNotificationIdBase = 710000000;

final DateTime _diaryReminderIdEpoch = DateTime(2020, 1, 1);

/// [date](시각 무시)에 대응하는 고유 알림 id — 같은 날짜는 항상 같은
/// id이므로, 다시 계산해 다시 예약해도 중복되지 않고 덮어쓴다.
int diaryReminderNotificationId(DateTime date) {
  final days = dateOnly(date).difference(_diaryReminderIdEpoch).inDays;
  return kDiaryReminderNotificationIdBase + days;
}

/// 오늘부터 [windowDays]일(오늘 포함) 동안 커버해야 할 날짜.
List<DateTime> diaryReminderWindowDates({DateTime? today, int windowDays = kDiaryReminderWindowDays}) {
  final start = dateOnly(today ?? DateTime.now());
  return [for (var i = 0; i < windowDays; i++) start.add(Duration(days: i))];
}

/// 창을 다시 채울 때 "지난 건 정리" 대상 — [scheduledDates] 중 오늘보다
/// 이전인 것들. 보통 알림이 울리면 자동으로 없어지지만, 기기가 한동안
/// 꺼져 있었다면 안 울린 채 남아 있을 수 있어 방어적으로 지운다.
List<DateTime> diaryReminderStaleDates(Iterable<DateTime> scheduledDates, {DateTime? today}) {
  final todayOnly = dateOnly(today ?? DateTime.now());
  return scheduledDates.where((d) => d.isBefore(todayOnly)).toList();
}

/// 창을 다시 채울 때 새로 예약해야 할 날짜만 고른다 — 이미 예약돼
/// 있으면([alreadyScheduledDates]) 그대로 두고, 오늘 쓴 일기 때문에
/// 막 취소한 날이면([skippedDate]) 되살리지 않는다. 그 외 창 안의
/// 날짜만 새로 추가한다.
List<DateTime> diaryReminderDatesToSchedule({
  required List<DateTime> windowDates,
  required Set<DateTime> alreadyScheduledDates,
  DateTime? skippedDate,
}) {
  return [
    for (final date in windowDates)
      if (!alreadyScheduledDates.contains(date) && date != skippedDate) date,
  ];
}
