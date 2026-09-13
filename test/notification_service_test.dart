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
}
