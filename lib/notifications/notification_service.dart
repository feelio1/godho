import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_settings.dart';
import '../models/appointment.dart';

/// 진료 예약 로컬 알림(스프린트 9 지시서 3, 스프린트 12에서 정확한 시각
/// 알림으로 보강, 스프린트 15에서 실기기 미작동 원인 규명·수정). 서버
/// 없이 기기 안에서만 예약·발송되며, 사용자가 예약마다 "며칠 전 + 몇 시"를
/// 직접 골라 여러 개 둘 수 있다.
///
/// 알림 안정성 원칙(지시서 "과거 크래시 교훈"): 초기화·권한 요청·예약 중
/// 어떤 단계가 실패해도(권한 거부, 플랫폼 채널 없음 등) 예외를 앱 밖으로
/// 던지지 않는다 — 전부 조용히 무시하고 앱은 정상 동작한다. 다만 "조용히"는
/// 예외를 앱 밖으로 던지지 않는다는 뜻이지 원인을 아예 안 남긴다는 뜻은
/// 아니다 — 각 단계 실패는 [debugPrint]로 남겨 실기기에서 `adb logcat`으로
/// 원인을 추적할 수 있게 한다(스프린트 15 지시서 1: "실패를 조용히 삼키지
/// 말고 원인을 로그로 남길 것"). 콜드 스타트 경로(`main.dart`)에서는 아예
/// 초기화하지 않고, 예약을 실제로 저장하는 시점에만 지연 초기화한다.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 한 예약(id)마다 이만큼의 알림 슬롯을 예약해 둔다. 취소 시 이 범위를
  /// 전부 지워, 이전에 몇 개를 설정했었는지 별도로 기억할 필요가 없게 한다.
  static const _maxRemindersPerAppointment = 8;

  /// 테스트 알림 1건이 쓰는 별도 id — 실제 예약 알림 id 범위와 겹치지 않게
  /// 아주 큰 값을 고정으로 쓴다.
  static const _testNotificationId = 999999;
  static const _immediateTestNotificationId = 999998;

  static void _log(String message) {
    debugPrint('[NotificationService] $message');
  }

  static const _reminderChannel = AndroidNotificationDetails(
    'appointment_reminders',
    '예약 알림',
    channelDescription: '등록한 진료 예약을 지정한 시각에 알려드립니다.',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// 일기 알림 전용 채널 — 예약 알림과 완전히 별개다("일기 활성화"
  /// 지시서 K: "기존 예약 알림 채널 변경 금지").
  static const _diaryReminderChannel = AndroidNotificationDetails(
    'diary_reminders',
    '일기 알림',
    channelDescription: '정한 시간에 하루를 일기로 남겨보도록 알려드립니다.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// 알림 하나뿐이라(매일 반복) 고정 id 하나만 쓴다 — 예약 알림 id 범위
  /// (해시 기반)·테스트 알림 id와 겹치지 않게 떨어뜨려 둔다.
  static const _diaryReminderId = 777777;

  /// 알림을 탭했을 때의 구분값 — 예약 알림은 payload를 쓰지 않으므로
  /// (영향 없음), 일기 알림만 이 값으로 식별한다.
  static const diaryReminderPayload = 'diary_reminder';

  /// 알림을 탭했을 때 실행할 동작 — 앱(위젯 트리 쪽)이 등록한다. 현재는
  /// 일기 알림 탭 시 우리 아이 탭 일기 작성으로 이동하는 데만 쓴다.
  void Function(String payload)? onNotificationTapped;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      // 이 앱은 국내 동물병원 데이터만 다루므로 한국 표준시로 고정한다
      // (기기 시간대 감지용 별도 패키지 없이 최소 구현).
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      final ok = await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      _initialized = true;
      _log('초기화 완료 (initialize() 반환값: $ok)');
    } catch (e, st) {
      // 초기화 실패 — 알림 기능만 조용히 비활성화하고 앱은 계속 정상 동작한다.
      _initialized = false;
      _log('초기화 실패: $e\n$st');
    }
  }

  /// 앱이 이미 떠 있는 상태(포그라운드·백그라운드)에서 알림을 탭하면
  /// 플러그인이 바로 이걸 부른다.
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    _log('알림 탭됨 (payload: $payload)');
    onNotificationTapped?.call(payload);
  }

  /// `main()`에서 앱을 시작할 때 한 번 불러 미리 초기화해 둔다 — 알림을
  /// 탭해 앱이 완전히 새로 켜진 경우까지 [consumeLaunchNotificationPayload]
  /// 로 알아낼 수 있으려면, 그 확인 전에 플러그인이 초기화돼 있어야
  /// 한다. 예약 알림 쪽은 계속 필요할 때만 지연 초기화하므로(바뀌는 것
  /// 없음), 이 호출이 그보다 먼저 끝나 있어도 동작은 같다 — 다른
  /// 네이티브 SDK(Firebase 등)처럼 실패해도 앱을 막지 않는다.
  Future<void> initializeForAppStart() => _ensureInitialized();

  /// 알림을 탭해 앱이 완전히 종료된 상태에서 새로 켜졌는지 확인한다.
  /// 일기 알림이었으면 그 payload를, 아니면 null을 돌려준다.
  Future<String?> consumeLaunchNotificationPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        return details?.notificationResponse?.payload;
      }
    } catch (e) {
      _log('알림으로 시작됐는지 확인 실패(무시): $e');
    }
    return null;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Android 13+ 알림 권한 + (가능하면) 정확한 시각 알람 권한을 함께
  /// 요청한다. 예약 알림을 처음 설정하는 시점에만 호출한다(CLAUDE.md 취지
  /// 연장 — 앱 시작 시 강제 요청 금지와 같은 원칙을 알림 권한에도 적용).
  ///
  /// 정확한 시각 권한(SCHEDULE_EXACT_ALARM)이 거부되거나 이 기기/버전에서
  /// 요청 자체가 불가능해도 실패로 취급하지 않는다 — 그런 경우
  /// [scheduleAppointmentReminders]가 자동으로 근사 시각 모드로 대체한다.
  /// 반환값은 "알림 권한"이 허용됐는지만 나타낸다(예약 저장 자체를 막을
  /// 이유는 아니므로 호출부에서는 결과를 참고용으로만 쓴다).
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    if (!_initialized) return false;
    var notificationsGranted = false;
    try {
      notificationsGranted = await _android?.requestNotificationsPermission() ?? false;
      _log('알림 권한 요청 결과: $notificationsGranted');
    } catch (e) {
      notificationsGranted = false;
      _log('알림 권한 요청 실패: $e');
    }
    try {
      // 이미 허용돼 있으면 시스템 설정 화면을 다시 띄우지 않는다.
      final alreadyExact = await _android?.canScheduleExactNotifications() ?? false;
      _log('정확한 시각 알람 권한 보유 여부: $alreadyExact');
      if (!alreadyExact) {
        final requested = await _android?.requestExactAlarmsPermission();
        _log('정확한 시각 알람 권한 요청 결과: $requested');
      }
    } catch (e) {
      // 이 기기/버전이 지원하지 않거나 거부됨 — 근사 시각 모드로 대체되므로
      // 무시하고 계속 진행한다.
      _log('정확한 시각 알람 권한 요청 중 예외(무시하고 근사 시각으로 대체): $e');
    }
    return notificationsGranted;
  }

  static int _notificationId(String appointmentId, int reminderIndex) =>
      (appointmentId.hashCode & 0x7fffffff) ^ (reminderIndex * 7919);

  /// [appointment]의 이전 알림을 모두 지우고, 각 알림 시각이 지금보다
  /// 미래일 때만 다시 예약한다. 알림 하나가 실패해도 나머지는 계속
  /// 진행한다.
  Future<void> scheduleAppointmentReminders(Appointment appointment) async {
    await cancelAppointmentReminders(appointment.id);
    if (appointment.reminders.isEmpty) return;

    if (!await const AppSettings().notificationsEnabled()) {
      _log('설정에서 예약 알림이 꺼져 있어 예약(${appointment.id})을 스케줄하지 않음');
      return;
    }

    await _ensureInitialized();
    if (!_initialized) {
      _log('초기화가 안 돼 있어 예약(${appointment.id})을 스케줄하지 않음');
      return;
    }

    final scheduleMode = await _bestAvailableScheduleMode();
    _log('예약(${appointment.id}) 알림 ${appointment.reminders.length}건 스케줄 시작 (모드: $scheduleMode)');

    for (var i = 0; i < appointment.reminders.length && i < _maxRemindersPerAppointment; i++) {
      final reminder = appointment.reminders[i];
      final fireAt = reminder.fireTimeFor(appointment.dateTime);
      if (fireAt.isBefore(DateTime.now())) {
        _log('알림 #$i 시각($fireAt)이 이미 지나 건너뜀');
        continue;
      }
      try {
        await _plugin.zonedSchedule(
          id: _notificationId(appointment.id, i),
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          title: '진료 예약 알림',
          body: _reminderBody(appointment),
          notificationDetails: const NotificationDetails(android: _reminderChannel),
          androidScheduleMode: scheduleMode,
        );
        _log('알림 #$i 스케줄 완료 — $fireAt');
      } catch (e, st) {
        // 이 알림 하나만 건너뛰고 나머지는 계속 예약한다.
        _log('알림 #$i 스케줄 실패: $e\n$st');
      }
    }
  }

  /// 정확한 시각 알람 권한이 있으면 [AndroidScheduleMode.exactAllowWhileIdle]
  /// (지정 시각에 정확히, Doze 상태에서도 울림)을, 없으면
  /// [AndroidScheduleMode.inexactAllowWhileIdle]로 조용히 대체한다 — 권한이
  /// 없다고 예약 자체를 막지 않는다(스프린트 12 지시서 1 핵심 수정).
  Future<AndroidScheduleMode> _bestAvailableScheduleMode() async {
    try {
      final canExact = await _android?.canScheduleExactNotifications() ?? false;
      if (canExact) return AndroidScheduleMode.exactAllowWhileIdle;
    } catch (e) {
      // 확인 자체가 안 되는 기기/버전 — 근사 시각으로 안전하게 대체.
      _log('정확한 시각 알람 가능 여부 확인 실패(근사 시각으로 대체): $e');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> cancelAppointmentReminders(String appointmentId) async {
    await _ensureInitialized();
    if (!_initialized) return;
    for (var i = 0; i < _maxRemindersPerAppointment; i++) {
      try {
        await _plugin.cancel(id: _notificationId(appointmentId, i));
      } catch (e) {
        // 이미 없는 알림을 지우는 경우 등 — 무시하고 계속 진행.
        _log('알림 취소 중 예외(무시): $e');
      }
    }
  }

  /// 설정 화면에서 "예약 알림"을 끌 때 호출 — 이미 예약된 알림을 모두
  /// 지운다. 각 예약이 몇 개의 알림을 걸어뒀는지 여기서는 알 수 없으므로,
  /// 쓰일 수 있는 id 전체 범위를 지운다(개별 예약 id를 따로 모아두지
  /// 않는 이 서비스의 기존 구조를 바꾸지 않기 위한 선택).
  Future<void> cancelAll() async {
    await _ensureInitialized();
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      _log('모든 알림 취소 완료');
    } catch (e) {
      _log('모든 알림 취소 중 예외(무시): $e');
    }
  }

  /// 매일 [hour]:[minute]에 일기 알림을 켠다 — 사용자 동의 시에만
  /// 호출된다("일기 활성화" 지시서 K). 예약 알림과 다른 채널이고, 매일
  /// 반복([DateTimeComponents.time])이라 한 번만 걸어두면 된다.
  ///
  /// 알려진 한계: 그날 이미 일기를 썼으면 그날 알림을 건너뛰는 것까지는
  /// 구현하지 못했다 — `flutter_local_notifications`의 반복 알람은 특정
  /// 날짜 하나만 건너뛸 수단이 없고(반복 자체를 취소/재예약해야 하는데,
  /// 그러면 다음 날짜까지 다시 계산해야 해 어떤 시점에 앱이 꺼져 있으면
  /// 깨진다), 안정적으로 구현하려면 네이티브 쪽 별도 작업이 필요해 이번
  /// 범위를 넘어선다.
  Future<void> scheduleDailyDiaryReminder({required int hour, required int minute}) async {
    await cancelDiaryReminder();
    await _ensureInitialized();
    if (!_initialized) {
      _log('초기화가 안 돼 있어 일기 알림을 스케줄하지 않음');
      return;
    }
    final scheduleMode = await _bestAvailableScheduleMode();
    final fireAt = _nextInstanceOfTime(hour, minute);
    try {
      await _plugin.zonedSchedule(
        id: _diaryReminderId,
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        title: '일기 알림',
        body: '오늘 하루를 일기로 남겨볼까요?',
        notificationDetails: const NotificationDetails(android: _diaryReminderChannel),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: diaryReminderPayload,
      );
      _log('일기 알림 매일 $hour:$minute 스케줄 완료');
    } catch (e, st) {
      _log('일기 알림 스케줄 실패: $e\n$st');
    }
  }

  Future<void> cancelDiaryReminder() async {
    await _ensureInitialized();
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _diaryReminderId);
    } catch (e) {
      _log('일기 알림 취소 중 예외(무시): $e');
    }
  }

  DateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _reminderBody(Appointment appointment) {
    final reason = appointment.reason.trim();
    final suffix = reason.isEmpty ? '' : ' ($reason)';
    return '${appointment.hospitalName} 예약이 있어요$suffix';
  }

  /// 지금 바로 뜨는 즉시 알림 — Android의 AlarmManager/예약 브로드캐스트
  /// 경로를 전혀 타지 않고 [FlutterLocalNotificationsPlugin.show]로 바로
  /// 띄운다. [sendTestNotification](1분 뒤 예약형)이 안 울릴 때, 문제가
  /// "초기화·채널·권한"에 있는지 "스케줄링(정확한 시각 알람·리시버)"에
  /// 있는지 이분 탐색하기 위한 디버그 경로다(스프린트 15 지시서 1) — 이게
  /// 뜨면 초기화·채널·권한은 정상이고, 그런데도 예약형이 안 울리면 스케줄
  /// 쪽(타임존/정확한 시각 모드/매니페스트 리시버)을 봐야 한다.
  Future<bool> showImmediateTestNotification() async {
    await requestPermission();
    await _ensureInitialized();
    if (!_initialized) {
      _log('즉시 테스트 알림: 초기화 실패로 표시 불가');
      return false;
    }
    try {
      await _plugin.show(
        id: _immediateTestNotificationId,
        title: '즉시 테스트 알림',
        body: '이 알림이 보이면 초기화·채널·권한은 정상입니다.',
        notificationDetails: const NotificationDetails(android: _reminderChannel),
      );
      _log('즉시 테스트 알림 표시 완료');
      return true;
    } catch (e, st) {
      _log('즉시 테스트 알림 표시 실패: $e\n$st');
      return false;
    }
  }

  /// 실기기에서 알림 설정이 실제로 동작하는지 확인하기 위한 테스트 알림 —
  /// 1분 뒤 울리도록 예약한다. 예약 알림과 완전히 같은 코드 경로(권한
  /// 확인 → 예약 모드 선택 → zonedSchedule)를 타므로, 이게 울리면 실제
  /// 예약 알림도 같은 조건에서 울린다고 볼 수 있다. 실패해도 예외를 밖으로
  /// 던지지 않고 성공 여부만 반환한다(설정 화면의 "테스트 알림 보내기"
  /// 버튼에서 사용 — 스프린트 12 지시서 "실기기 검증" 요구사항).
  Future<bool> sendTestNotification() async {
    await requestPermission();
    await _ensureInitialized();
    if (!_initialized) {
      _log('1분 뒤 테스트 알림: 초기화 실패로 예약 불가');
      return false;
    }
    final scheduleMode = await _bestAvailableScheduleMode();
    final fireAt = DateTime.now().add(const Duration(minutes: 1));
    try {
      await _plugin.zonedSchedule(
        id: _testNotificationId,
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        title: '테스트 알림',
        body: '이 알림이 보이면 예약 알림도 정상 동작합니다 '
            '(${scheduleMode == AndroidScheduleMode.exactAllowWhileIdle ? '정확한 시각' : '근사 시각'} 모드).',
        notificationDetails: const NotificationDetails(android: _reminderChannel),
        androidScheduleMode: scheduleMode,
      );
      _log('1분 뒤 테스트 알림 스케줄 완료 — $fireAt (모드: $scheduleMode)');
      return true;
    } catch (e, st) {
      _log('1분 뒤 테스트 알림 스케줄 실패: $e\n$st');
      return false;
    }
  }
}
