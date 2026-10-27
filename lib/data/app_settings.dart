import 'package:shared_preferences/shared_preferences.dart';

/// 설정 화면(Settings.dc.html)의 기기 로컬 토글 — 서버·계정과 무관하게
/// 이 기기에만 저장된다. 값이 하나뿐이라 매번 `SharedPreferences`를 새로
/// 읽어오는 가벼운 정적 헬퍼로 둔다("디자인 2단계" 지시서).
class AppSettings {
  const AppSettings();

  static const _notificationsEnabledKey = 'settings_notifications_enabled_v1';

  /// 예약 알림을 울릴지 — 기본값은 켜짐. 꺼두면 새 알림을 스케줄하지
  /// 않고([NotificationService.scheduleAppointmentReminders]), 이미
  /// 예약된 알림도 모두 취소한다.
  Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, value);
  }

  // --- 일기 알림("일기 활성화" 지시서 K) ---
  // 예약 알림과 별개 설정이다 — 기본은 꺼짐(사용자 동의 전에는 절대
  // 울리지 않음), 켜질 때까지는 묻지 않는다.

  static const _diaryReminderEnabledKey = 'settings_diary_reminder_enabled_v1';
  static const _diaryReminderHourKey = 'settings_diary_reminder_hour_v1';
  static const _diaryReminderMinuteKey = 'settings_diary_reminder_minute_v1';
  static const _diaryReminderAskedKey = 'settings_diary_reminder_asked_v1';
  static const _diarySaveCountKey = 'settings_diary_save_count_v1';

  static const diaryReminderDefaultHour = 21;
  static const diaryReminderDefaultMinute = 0;

  Future<bool> diaryReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_diaryReminderEnabledKey) ?? false;
  }

  Future<void> setDiaryReminderEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_diaryReminderEnabledKey, value);
  }

  Future<({int hour, int minute})> diaryReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_diaryReminderHourKey) ?? diaryReminderDefaultHour,
      minute: prefs.getInt(_diaryReminderMinuteKey) ?? diaryReminderDefaultMinute,
    );
  }

  Future<void> setDiaryReminderTime({required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_diaryReminderHourKey, hour);
    await prefs.setInt(_diaryReminderMinuteKey, minute);
  }

  /// 3번째 저장 직후 알림 동의를 이미 물었는지 — 수락·거절과 상관없이
  /// 한 번 묻고 나면 다시 묻지 않는다.
  Future<bool> diaryReminderPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_diaryReminderAskedKey) ?? false;
  }

  Future<void> setDiaryReminderPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_diaryReminderAskedKey, true);
  }

  /// 새 일기를 저장할 때마다 불러 누적 횟수를 늘리고 그 값을 돌려준다 —
  /// "3번째 저장 직후"를 판단하는 데 쓴다.
  Future<int> incrementDiarySaveCount() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_diarySaveCountKey) ?? 0) + 1;
    await prefs.setInt(_diarySaveCountKey, next);
    return next;
  }

  // --- 일기 알림 — 14일 창("일기 보완" 지시서 2) ---
  // "매일 반복" 알람 하나가 아니라 날짜별 1회성 알림을 여러 개 두므로,
  // 지금 실제로 예약돼 있는 날짜들을 기기에 따로 기억해 둬야 재채움·
  // 취소 로직이 플러그인의 pending 목록을 뒤지지 않고도 동작한다.

  static const _diaryReminderScheduledDatesKey = 'settings_diary_reminder_scheduled_dates_v1';
  static const _diaryReminderSkippedDateKey = 'settings_diary_reminder_skipped_date_v1';

  /// 지금 예약돼 있다고 기억해 둔 날짜들(시각 제외) — 순서는 의미 없다.
  Future<List<DateTime>> diaryReminderScheduledDates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_diaryReminderScheduledDatesKey) ?? const [];
    return raw.map(DateTime.tryParse).whereType<DateTime>().toList();
  }

  Future<void> setDiaryReminderScheduledDates(List<DateTime> dates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _diaryReminderScheduledDatesKey,
      dates.map((d) => d.toIso8601String()).toList(),
    );
  }

  /// 오늘 일기를 써서 막 취소한 날짜(보통 오늘) — 같은 날 창을 다시
  /// 채워도 되살리지 않는 데 쓴다. 날이 지나 창 밖으로 벗어나면 그냥
  /// 무시되므로 따로 지울 필요는 없지만, [clear]로 지울 수도 있다.
  Future<DateTime?> diaryReminderSkippedDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_diaryReminderSkippedDateKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setDiaryReminderSkippedDate(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove(_diaryReminderSkippedDateKey);
    } else {
      await prefs.setString(_diaryReminderSkippedDateKey, date.toIso8601String());
    }
  }
}
