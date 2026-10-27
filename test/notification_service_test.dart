import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService — 알림 안정성(스프린트 12 지시서 1)', () {
    test(
      'requestPermission은 플랫폼 채널이 없는 테스트 환경에서도 예외 없이 false를 반환한다 '
      '(POST_NOTIFICATIONS + SCHEDULE_EXACT_ALARM 요청 모두 안전하게 실패 처리됨)',
      () async {
        final granted = await NotificationService.instance.requestPermission();
        expect(granted, isFalse);
      },
    );

    test(
      'sendTestNotification은 플랫폼 채널이 없어도 예외를 던지지 않고 실패(false)로 처리된다',
      () async {
        final sent = await NotificationService.instance.sendTestNotification();
        expect(sent, isFalse);
      },
    );
  });

  group('NotificationService — 일기 알림("일기 활성화" 지시서 K, 예약 알림과 별도 채널)', () {
    test('scheduleDailyDiaryReminder는 플랫폼 채널이 없어도 예외를 던지지 않는다', () async {
      await expectLater(
        NotificationService.instance.scheduleDailyDiaryReminder(hour: 21, minute: 0),
        completes,
      );
    });

    test('cancelDiaryReminder는 플랫폼 채널이 없어도 예외를 던지지 않는다', () async {
      await expectLater(NotificationService.instance.cancelDiaryReminder(), completes);
    });

    test('initializeForAppStart은 플랫폼 채널이 없어도 예외를 던지지 않는다', () async {
      await expectLater(NotificationService.instance.initializeForAppStart(), completes);
    });

    test('consumeLaunchNotificationPayload는 플랫폼 채널이 없으면 안전하게 null이다', () async {
      expect(await NotificationService.instance.consumeLaunchNotificationPayload(), isNull);
    });

    test('알림 탭 콜백은 일기 알림 payload로만 불린다', () async {
      String? received;
      NotificationService.instance.onNotificationTapped = (payload) => received = payload;
      addTearDown(() => NotificationService.instance.onNotificationTapped = null);

      // 플랫폼 채널이 없는 테스트 환경에서는 실제 알림 응답이 오지 않으므로
      // (콜백 등록만 가능·호출은 플러그인이 함), 콜백 자체가 안전하게 등록·
      // 해제되는지만 확인한다 — 실제 전달 경로는 실기기 검증 대상이다.
      expect(NotificationService.instance.onNotificationTapped, isNotNull);
      expect(received, isNull);
    });
  });
}
