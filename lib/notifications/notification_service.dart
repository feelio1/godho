import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/appointment.dart';

/// 진료 예약 로컬 알림(스프린트 9 지시서 3). 서버 없이 기기 안에서만
/// 예약·발송되며, 사용자가 예약마다 "며칠 전 + 몇 시"를 직접 골라 여러 개
/// 둘 수 있다.
///
/// 알림 안정성 원칙(지시서 "과거 크래시 교훈"): 초기화·권한 요청·예약 중
/// 어떤 단계가 실패해도(권한 거부, 플랫폼 채널 없음 등) 예외를 앱 밖으로
/// 던지지 않는다 — 전부 조용히 무시하고 앱은 정상 동작한다. 콜드 스타트
/// 경로(`main.dart`)에서는 아예 초기화하지 않고, 예약을 실제로 저장하는
/// 시점에만 지연 초기화한다.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 한 예약(id)마다 이만큼의 알림 슬롯을 예약해 둔다. 취소 시 이 범위를
  /// 전부 지워, 이전에 몇 개를 설정했었는지 별도로 기억할 필요가 없게 한다.
  static const _maxRemindersPerAppointment = 8;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      // 이 앱은 국내 동물병원 데이터만 다루므로 한국 표준시로 고정한다
      // (기기 시간대 감지용 별도 패키지 없이 최소 구현).
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (_) {
      // 초기화 실패 — 알림 기능만 조용히 비활성화하고 앱은 계속 정상 동작한다.
      _initialized = false;
    }
  }

  /// Android 13+ 알림 권한을 요청한다. 예약 알림을 처음 설정하는 시점에만
  /// 호출한다(CLAUDE.md 취지 연장 — 앱 시작 시 강제 요청 금지와 같은 원칙을
  /// 알림 권한에도 적용).
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    if (!_initialized) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static int _notificationId(String appointmentId, int reminderIndex) =>
      (appointmentId.hashCode & 0x7fffffff) ^ (reminderIndex * 7919);

  /// [appointment]의 이전 알림을 모두 지우고, 각 알림 시각이 지금보다
  /// 미래일 때만 다시 예약한다. 알림 하나가 실패해도 나머지는 계속
  /// 진행한다.
  Future<void> scheduleAppointmentReminders(Appointment appointment) async {
    await cancelAppointmentReminders(appointment.id);
    if (appointment.reminders.isEmpty) return;

    await _ensureInitialized();
    if (!_initialized) return;

    // 정확한 시각(exact alarm) 대신 근사 시각(inexact)을 쓴다 — 별도 권한
    // 없이도 동작하고, 거부/미지원 기기에서도 앱이 정상 동작한다는 지시서
    // 원칙을 그대로 따른 것이다.
    for (var i = 0; i < appointment.reminders.length && i < _maxRemindersPerAppointment; i++) {
      final reminder = appointment.reminders[i];
      final fireAt = reminder.fireTimeFor(appointment.dateTime);
      if (fireAt.isBefore(DateTime.now())) continue;
      try {
        await _plugin.zonedSchedule(
          id: _notificationId(appointment.id, i),
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          title: '진료 예약 알림',
          body: _reminderBody(appointment),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'appointment_reminders',
              '예약 알림',
              channelDescription: '등록한 진료 예약을 지정한 시각에 알려드립니다.',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {
        // 이 알림 하나만 건너뛰고 나머지는 계속 예약한다.
      }
    }
  }

  Future<void> cancelAppointmentReminders(String appointmentId) async {
    await _ensureInitialized();
    if (!_initialized) return;
    for (var i = 0; i < _maxRemindersPerAppointment; i++) {
      try {
        await _plugin.cancel(id: _notificationId(appointmentId, i));
      } catch (_) {
        // 이미 없는 알림을 지우는 경우 등 — 무시하고 계속 진행.
      }
    }
  }

  static String _reminderBody(Appointment appointment) {
    final reason = appointment.reason.trim();
    final suffix = reason.isEmpty ? '' : ' ($reason)';
    return '${appointment.hospitalName} 예약이 있어요$suffix';
  }
}
