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
}
