import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/config/admob_config.dart';
import 'package:petcliniccheck/data/auth_repository.dart';
import 'package:petcliniccheck/notifications/diary_reminder_schedule.dart';
import 'package:petcliniccheck/notifications/notification_service.dart';
import 'package:petcliniccheck/screens/info_screens.dart';

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth({this.fail = false});
  final bool fail;
  final revoked = <String>[];

  @override
  Future<void> revokeTokenWithAuthorizationCode(String authorizationCode) async {
    if (fail) throw FirebaseAuthException(code: 'invalid-credential');
    revoked.add(authorizationCode);
  }
}

class _FakeInfo extends Fake implements UserInfo {
  _FakeInfo(this.providerId);
  @override
  final String providerId;
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.providerIds);
  final List<String> providerIds;
  @override
  List<UserInfo> get providerData => [for (final id in providerIds) _FakeInfo(id)];
}

void main() {
  group('L-1 버전·아이폰 전용', () {
    test('pubspec 1.0.0+6, intl 0.20.3 그대로', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('\nversion: 1.0.0+6\n'));
      expect(pubspec, contains('\n  intl: 0.20.3\n'));
    });

    test('Xcode 프로젝트: 아이폰 전용(1), 최소 iOS 15.0(Firebase 요구)', () {
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(RegExp(r'TARGETED_DEVICE_FAMILY = 1;').allMatches(pbx).length, 3);
      expect(pbx, isNot(contains('TARGETED_DEVICE_FAMILY = "1,2"')));
      expect(pbx, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0')));
      expect(RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15.0;').allMatches(pbx).length, 3);
    });
  });

  group('L-2 Info.plist·비밀값 주입', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    String valueAfter(String key) {
      final m = RegExp('<key>$key</key>\\s*<string>([^<]*)</string>').firstMatch(plist);
      return m?.group(1) ?? '';
    }

    test('권한 문구는 지시서 그대로', () {
      expect(valueAfter('NSLocationWhenInUseUsageDescription'), '주변 동물병원과 우리 동네 진료비를 보여 드리려고 현재 위치를 사용해요.');
      expect(valueAfter('NSPhotoLibraryUsageDescription'), '일기와 반려동물 사진을 고르려고 사진 보관함을 사용해요.');
      expect(valueAfter('NSCameraUsageDescription'), '일기와 반려동물 사진을 찍으려고 카메라를 사용해요.');
      expect(valueAfter('NSUserTrackingUsageDescription'), '광고를 관심사에 맞게 보여 드리는 데 쓰여요. 허용하지 않아도 모든 기능을 그대로 쓸 수 있어요.');
    });

    test('암호화 고지·네이버 지도 스킴·광고/구글 값은 빌드 변수로만', () {
      expect(plist, matches(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>')));
      expect(plist, contains('<string>nmap</string>'));
      // 카카오 로그인이 꺼져 있으니 카카오 스킴은 넣지 않는다.
      expect(plist, isNot(contains('<string>kakaokompassauth</string>')));
      expect(valueAfter('GADApplicationIdentifier'), r'$(ADMOB_APP_ID_IOS)');
      expect(valueAfter('GIDClientID'), r'$(GOOGLE_IOS_CLIENT_ID)');
      expect(plist, contains(r'<string>$(GOOGLE_REVERSED_CLIENT_ID)</string>'));
      expect(plist, contains('<string>cstr6suwn9.skadnetwork</string>'));
      // 실제 키 모양(ca-app-pub-…~…, *.apps.googleusercontent.com)이 저장소 plist에 없다.
      expect(plist, isNot(contains('ca-app-pub-')));
      expect(plist, isNot(contains('googleusercontent.com')));
    });

    test('Debug/Release.xcconfig는 Secrets.xcconfig를 선택적으로 읽고, 없으면 테스트 앱 ID', () {
      for (final name in ['Debug', 'Release']) {
        final xc = File('ios/Flutter/$name.xcconfig').readAsStringSync();
        expect(xc, contains('#include "Generated.xcconfig"'));
        expect(xc, contains('#include? "Secrets.xcconfig"'));
        expect(xc, contains('ADMOB_APP_ID_IOS = ca-app-pub-3940256099942544~1458002511'));
        // 기본값이 먼저, Secrets.xcconfig가 나중 — 나중 값이 덮어쓴다.
        expect(xc.indexOf('ADMOB_APP_ID_IOS ='), lessThan(xc.indexOf('#include? "Secrets.xcconfig"')));
      }
      final example = File('ios/Flutter/Secrets.xcconfig.example').readAsStringSync();
      for (final key in ['ADMOB_APP_ID_IOS', 'GOOGLE_IOS_CLIENT_ID', 'GOOGLE_REVERSED_CLIENT_ID']) {
        expect(example, contains('//$key ='));
      }
      final gitignore = File('.gitignore').readAsLinesSync();
      expect(gitignore, contains('ios/Flutter/Secrets.xcconfig'));
      expect(gitignore, contains('ios/Runner/GoogleService-Info.plist'));
    });

    test('GoogleService-Info.plist는 있을 때만 앱에 복사(없어도 빌드 계속)', () {
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(pbx, contains('/* Copy GoogleService-Info.plist */ = {'));
      expect(pbx, contains(r'if [ -f \"$PLIST\" ]; then'));
      expect(pbx, isNot(contains('GoogleService-Info.plist in Resources')));
    });
  });

  group('L-2 AdMob 광고 단위는 플랫폼별, 없으면 그 플랫폼의 테스트 ID', () {
    test('설정값이 없으면 플랫폼별 구글 공개 테스트 ID', () {
      expect(bannerUnitIdFor(TargetPlatform.android, configured: ''), 'ca-app-pub-3940256099942544/6300978111');
      expect(appOpenUnitIdFor(TargetPlatform.android, configured: ''), 'ca-app-pub-3940256099942544/9257395921');
      expect(bannerUnitIdFor(TargetPlatform.iOS, configured: ''), 'ca-app-pub-3940256099942544/2934735716');
      expect(appOpenUnitIdFor(TargetPlatform.iOS, configured: ''), 'ca-app-pub-3940256099942544/5575463023');
    });

    test('설정값이 있으면 그대로', () {
      expect(bannerUnitIdFor(TargetPlatform.iOS, configured: 'ios-banner'), 'ios-banner');
      expect(appOpenUnitIdFor(TargetPlatform.android, configured: 'and-open'), 'and-open');
    });

    test('dart-define 없이 돌리면(테스트 환경) 각 플랫폼이 자기 테스트 ID를 고른다', () {
      // 안드로이드 값은 iOS로, iOS 값은 안드로이드로 새지 않는다.
      expect(bannerUnitIdFor(TargetPlatform.android), kTestBannerUnitIdAndroid);
      expect(bannerUnitIdFor(TargetPlatform.iOS), kTestBannerUnitIdIos);
      expect(appOpenUnitIdFor(TargetPlatform.android), kTestAppOpenUnitIdAndroid);
      expect(appOpenUnitIdFor(TargetPlatform.iOS), kTestAppOpenUnitIdIos);
    });

    testWidgets('실제 getter는 defaultTargetPlatform을 따른다', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(admobBannerUnitId, kTestBannerUnitIdIos);
      expect(admobAppOpenUnitId, kTestAppOpenUnitIdIos);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(admobBannerUnitId, kTestBannerUnitIdAndroid);
      expect(admobAppOpenUnitId, kTestAppOpenUnitIdAndroid);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('L-3 애플 로그인·탈퇴 시 토큰 철회', () {
    test('애플이 준 이름: 한글은 "성이름", 그 밖은 "이름 성", 없으면 null', () {
      expect(AuthRepository.appleDisplayName(givenName: '구름', familyName: '장'), '장구름');
      expect(AuthRepository.appleDisplayName(givenName: 'Gureum', familyName: 'Jang'), 'Gureum Jang');
      expect(AuthRepository.appleDisplayName(givenName: ' 구름 ', familyName: null), '구름');
      expect(AuthRepository.appleDisplayName(givenName: '', familyName: '  '), isNull);
      expect(AuthRepository.appleDisplayName(), isNull);
    });

    test('토큰 철회: 받은 authorizationCode로 FirebaseAuth.revokeTokenWithAuthorizationCode', () async {
      final auth = _FakeAuth();
      await AuthRepository(auth: auth).revokeAppleToken('code-123');
      expect(auth.revoked, ['code-123']);
    });

    test('토큰 철회 실패·코드 없음은 예외 없이 지나간다(탈퇴는 계속)', () async {
      await expectLater(AuthRepository(auth: _FakeAuth(fail: true)).revokeAppleToken('code-123'), completes);
      final auth = _FakeAuth();
      await AuthRepository(auth: auth).revokeAppleToken(null);
      await AuthRepository(auth: auth).revokeAppleToken('');
      expect(auth.revoked, isEmpty);
    });

    test('애플 계정 판단은 Firebase 로그인 수단(apple.com)으로', () {
      expect(isAppleAccount(_FakeUser(['apple.com'])), isTrue);
      expect(isAppleAccount(_FakeUser(['google.com'])), isFalse);
      expect(isAppleAccount(_FakeUser(['password'])), isFalse);
      expect(isAppleAccount(null), isFalse);
    });

    test('entitlements: Sign in with Apple(Default)이 Runner 세 구성에 연결', () {
      final ent = File('ios/Runner/Runner.entitlements').readAsStringSync();
      expect(ent, matches(RegExp(r'<key>com.apple.developer.applesignin</key>\s*<array>\s*<string>Default</string>')));
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(RegExp(r'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;').allMatches(pbx).length, 3);
      expect(pbx, contains('/* Runner.entitlements */ = {isa = PBXFileReference;'));
    });
  });

  group('L-4 iOS 알림', () {
    test('초기화에 iOS 설정이 들어 있고, 시작 때 아무 권한도 묻지 않는다', () {
      const settings = NotificationService.initializationSettings;
      final ios = settings.iOS!;
      expect(ios.requestAlertPermission, isFalse);
      expect(ios.requestBadgePermission, isFalse);
      expect(ios.requestSoundPermission, isFalse);
      expect(ios.requestProvisionalPermission, isFalse);
      expect(ios.requestCriticalPermission, isFalse);
      expect(ios.notificationCategories.map((c) => c.identifier), ['appointment_reminders', 'diary_reminders']);
      // 안드로이드 초기화는 그대로.
      expect(settings.android!.defaultIcon, '@mipmap/ic_launcher');
    });

    test('예약 알림과 일기 알림은 iOS에서도 따로(카테고리·스레드), 안드로이드 채널은 그대로', () {
      const appointment = NotificationService.appointmentNotificationDetails;
      const diary = NotificationService.diaryNotificationDetails;
      expect(appointment.android!.channelId, 'appointment_reminders');
      expect(diary.android!.channelId, 'diary_reminders');
      expect(appointment.iOS!.categoryIdentifier, 'appointment_reminders');
      expect(appointment.iOS!.threadIdentifier, 'appointment_reminders');
      expect(diary.iOS!.categoryIdentifier, 'diary_reminders');
      expect(diary.iOS!.threadIdentifier, 'diary_reminders');
      expect(appointment.android!.importance, Importance.high);
      expect(diary.android!.importance, Importance.defaultImportance);
    });

    test('iOS 예약 알림 64개 한도: 일기 창 14 + 예약당 1 + 테스트 1', () {
      expect(NotificationService.iosPendingNotificationLimit, 64);
      expect(kDiaryReminderWindowDays, 14);
      // 앞으로의 예약이 49건까지는 상한 안 — 예약 화면은 알림을 1개만 저장한다.
      expect(kDiaryReminderWindowDays + 49 + 1, lessThanOrEqualTo(NotificationService.iosPendingNotificationLimit));
    });

    test('AppDelegate는 알림 센터 대리자만 두고 권한은 묻지 않는다', () {
      final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(delegate, contains('UNUserNotificationCenter.current().delegate = self'));
      expect(delegate, isNot(contains('requestAuthorization')));
    });
  });
}
