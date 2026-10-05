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
}
