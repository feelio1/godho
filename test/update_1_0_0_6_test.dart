import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:petcliniccheck/ads/app_open_ad_suppression.dart';
import 'package:petcliniccheck/ads/tracking_consent.dart';
import 'package:petcliniccheck/config/admob_config.dart';
import 'package:petcliniccheck/data/auth_repository.dart';
import 'package:petcliniccheck/diary/diary_photo_local_store.dart';
import 'package:petcliniccheck/diary/diary_photo_upload_queue.dart';
import 'package:petcliniccheck/notifications/diary_reminder_schedule.dart';
import 'package:petcliniccheck/notifications/notification_service.dart';
import 'package:petcliniccheck/screens/info_screens.dart';

class _FakeTracking implements TrackingPlatform {
  _FakeTracking(this.current, {this.answer = TrackingStatus.denied, this.fail = false});
  TrackingStatus current;
  final TrackingStatus answer;
  final bool fail;
  AppOpenAdSuppression? suppression;
  int statusCalls = 0;
  int requestCalls = 0;
  int? suppressionCountDuringRequest;

  @override
  Future<TrackingStatus> status() async {
    statusCalls++;
    if (fail) throw PlatformException(code: 'no-channel');
    return current;
  }

  @override
  Future<TrackingStatus> request() async {
    requestCalls++;
    suppressionCountDuringRequest = suppression?.count;
    current = answer;
    return answer;
  }
}

TrackingConsent _consent(_FakeTracking fake, TargetPlatform platform) =>
    TrackingConsent(platform: fake, targetPlatform: () => platform, waitUntilActive: () async {});

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

  group('L-5 앱 추적 투명성(ATT)', () {
    test('iOS·아직 안 물음: 한 번만 묻고, 묻는 동안 앱 오프닝 광고 억제', () async {
      final suppression = AppOpenAdSuppression();
      final fake = _FakeTracking(TrackingStatus.notDetermined)..suppression = suppression;
      final consent = _consent(fake, TargetPlatform.iOS);
      await consent.requestIfNeeded(suppression);
      await consent.requestIfNeeded(suppression);
      expect(fake.requestCalls, 1);
      expect(fake.statusCalls, 1);
      expect(fake.suppressionCountDuringRequest, 1);
      expect(suppression.count, 0);
      expect(consent.status, TrackingStatus.denied);
      // 거부 → 비맞춤 광고.
      expect(consent.personalizedAdsAllowed, isFalse);
      expect(consent.adRequest().nonPersonalizedAds, isTrue);
    });

    test('iOS·허용하면 맞춤 광고', () async {
      final fake = _FakeTracking(TrackingStatus.notDetermined, answer: TrackingStatus.authorized);
      final consent = _consent(fake, TargetPlatform.iOS);
      await consent.requestIfNeeded(AppOpenAdSuppression());
      expect(consent.personalizedAdsAllowed, isTrue);
      expect(consent.adRequest().nonPersonalizedAds, isFalse);
    });

    test('iOS·이미 답했으면(거부·제한) 다시 묻지 않고 비맞춤', () async {
      for (final answered in [TrackingStatus.denied, TrackingStatus.restricted]) {
        final fake = _FakeTracking(answered);
        final consent = _consent(fake, TargetPlatform.iOS);
        await consent.requestIfNeeded(AppOpenAdSuppression());
        expect(fake.requestCalls, 0, reason: '$answered');
        expect(consent.adRequest().nonPersonalizedAds, isTrue, reason: '$answered');
      }
    });

    test('iOS 광고 로드는 답이 정해질 때까지 기다린다(첫 광고 요청 전에 묻기)', () async {
      final fake = _FakeTracking(TrackingStatus.notDetermined);
      final consent = _consent(fake, TargetPlatform.iOS);
      var ready = false;
      unawaited(consent.ready.then((_) => ready = true));
      await Future<void>.delayed(Duration.zero);
      expect(ready, isFalse);
      await consent.requestIfNeeded(AppOpenAdSuppression());
      await Future<void>.delayed(Duration.zero);
      expect(ready, isTrue);
    });

    test('iOS·통로 실패해도 예외 없이 광고는 비맞춤으로 진행', () async {
      final fake = _FakeTracking(TrackingStatus.notDetermined, fail: true);
      final consent = _consent(fake, TargetPlatform.iOS);
      await expectLater(consent.requestIfNeeded(AppOpenAdSuppression()), completes);
      expect(consent.status, TrackingStatus.unknown);
      await expectLater(consent.ready, completes);
      expect(consent.adRequest().nonPersonalizedAds, isTrue);
    });

    test('안드로이드: 아무것도 묻지 않고, 광고 요청은 지금과 같은 AdRequest()', () async {
      final fake = _FakeTracking(TrackingStatus.notDetermined);
      final consent = _consent(fake, TargetPlatform.android);
      await consent.requestIfNeeded(AppOpenAdSuppression());
      expect(fake.statusCalls, 0);
      expect(fake.requestCalls, 0);
      await expectLater(consent.ready, completes);
      expect(consent.personalizedAdsAllowed, isTrue);
      expect(consent.adRequest().nonPersonalizedAds, isNull);
    });

    test('연결: 메인 화면이 한 번 부르고, 두 광고 로더가 iOS에서 기다린다, 네이티브 통로', () {
      final shell = File('lib/screens/main_shell.dart').readAsStringSync();
      expect(shell, contains('TrackingConsent.instance.requestIfNeeded(ref.read(adSuppressionProvider))'));
      for (final path in ['lib/ads/app_open_ad_manager.dart', 'lib/ads/global_banner_ad.dart']) {
        final src = File(path).readAsStringSync();
        expect(src, contains('consent.ready.then'), reason: path);
        expect(src, contains('_load(const AdRequest())'), reason: '$path: 안드로이드 경로 그대로');
      }
      final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(delegate, contains('name: "petcli/tracking"'));
      expect(delegate, contains('ATTrackingManager.requestTrackingAuthorization'));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('app_tracking_transparency')));
    });
  });

  group('L-6 아이콘·런치 스크린', () {
    test('iOS 아이콘: 앱 아이콘 그대로, 알파 없음(App Store 규칙), 1024 포함', () {
      final dir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      final pngs = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList();
      expect(pngs, isNotEmpty);
      for (final f in pngs) {
        final image = img.decodePng(f.readAsBytesSync())!;
        expect(image.numChannels, 3, reason: '${f.path}: 알파 채널 없음');
      }
      final big = img.decodePng(File('${dir.path}/Icon-App-1024x1024@1x.png').readAsBytesSync())!;
      expect(big.width, 1024);
      // Flutter 기본(흰) 아이콘이 아니라 네이비 바탕 앱 아이콘.
      final corner = big.getPixel(10, 10);
      expect(corner.b, greaterThan(corner.r));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('\n  ios: true\n  remove_alpha_ios: true\n'));
    });

    test('런치 스크린 배경은 네이비 #1B4D8C, 아이콘 도구가 pbxproj를 망가뜨리지 않았다', () {
      final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
      final m = RegExp(r'<color key="backgroundColor" red="([0-9.]+)" green="([0-9.]+)" blue="([0-9.]+)"').firstMatch(storyboard)!;
      int channel(int i) => (double.parse(m.group(i)!) * 255).round();
      expect([channel(1), channel(2), channel(3)], [0x1B, 0x4D, 0x8C]);
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(pbx, isNot(contains('ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon')));
      expect(RegExp(r'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;').allMatches(pbx).length, 3);
    });
  });

  group('L-7 iOS에서 깨지는 곳', () {
    test('사진 대기열: iOS 앱 업데이트로 앱 폴더가 바뀌어도 같은 이름 파일로 찾아간다', () {
      const oldPath = '/var/mobile/Containers/Data/Application/AAAA/Documents/diary_photo_queue/p1_main.jpg';
      const newDir = '/var/mobile/Containers/Data/Application/BBBB/Documents/diary_photo_queue';
      final files = {'$newDir/p1_main.jpg'};
      expect(relocatedDiaryPhotoQueuePath(oldPath, newDir, exists: files.contains), '$newDir/p1_main.jpg');
      // 적힌 경로에 파일이 있으면(안드로이드·업데이트 전) 그대로.
      expect(relocatedDiaryPhotoQueuePath(oldPath, newDir, exists: (p) => p == oldPath), oldPath);
      // 어디에도 없으면 적힌 경로 그대로(업로드가 지금처럼 실패 처리).
      expect(relocatedDiaryPhotoQueuePath(oldPath, newDir, exists: (_) => false), oldPath);
    });

    test('사진 대기열: 경로만 바꾸고 나머지는 그대로', () {
      final item = DiaryPhotoQueueItem(
        id: 'p1',
        uid: 'u',
        diaryId: 'd',
        order: 2,
        mainFilePath: '/old/p1_main.jpg',
        thumbFilePath: '/old/p1_thumb.jpg',
        width: 2048,
        height: 1536,
        attempts: 3,
        nextAttemptAt: DateTime(2026, 11, 24, 10),
      );
      final moved = item.copyWithPaths(mainFilePath: '/new/p1_main.jpg', thumbFilePath: '/new/p1_thumb.jpg');
      expect(moved.toJson(), {
        ...item.toJson(),
        'mainFilePath': '/new/p1_main.jpg',
        'thumbFilePath': '/new/p1_thumb.jpg',
      });
    });

    test('카카오 지도: 키 없음·초기화 실패·지도 오류면 그 화면만 준비 중(초기화 순서 그대로)', () {
      final screen = File('lib/screens/nearby_map_screen.dart').readAsStringSync();
      expect(screen, contains('if (!isKakaoMapConfigured || !kakaoMapSdkInitialized || _mapFailed) {'));
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.indexOf('Firebase.initializeApp()'), lessThan(main.indexOf('KakaoMapSdk.instance.initialize')));
      expect(main.indexOf('KakaoMapSdk.instance.initialize'), lessThan(main.indexOf('MobileAds.instance.initialize()')));
    });

    test('네이버 지도 앱 appname은 iOS 번들 ID와 같다(앱 없으면 웹)', () {
      final links = File('lib/utils/external_links.dart').readAsStringSync();
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(links, contains("const String _naverMapAppName = 'com.petcheck.petcliniccheck';"));
      expect(pbx, contains('PRODUCT_BUNDLE_IDENTIFIER = com.petcheck.petcliniccheck;'));
      expect(links, contains('https://map.naver.com/p/search/'));
    });
  });

  group('L-8 Codemagic', () {
    final yaml = File('codemagic.yaml').readAsStringSync();

    test('워크플로 ios-testflight: Flutter 고정, 변수 그룹 petcli_ios, TestFlight에만', () {
      expect(yaml, contains('\n  ios-testflight:\n'));
      expect(yaml, contains('flutter: 3.47.8'));
      expect(yaml, contains('- petcli_ios'));
      expect(yaml, contains('distribution_type: app_store'));
      expect(yaml, contains('bundle_identifier: com.petcheck.petcliniccheck'));
      expect(yaml, contains('submit_to_testflight: true'));
      expect(yaml, contains('submit_to_app_store: false'));
      // 자동 시작(푸시마다 빌드) 없음.
      expect(yaml, isNot(contains('triggering:')));
    });

    test('비밀 파일은 환경 변수로 만들고, 빌드는 저장소 밖 임시 dart-define 파일로', () {
      for (final name in [
        'GOOGLE_SERVICE_INFO_PLIST',
        'ADMOB_APP_ID_IOS',
        'GOOGLE_IOS_CLIENT_ID',
        'GOOGLE_REVERSED_CLIENT_ID',
        'DART_DEFINES_JSON',
      ]) {
        expect(yaml, contains(name), reason: name);
      }
      expect(yaml, contains('> ios/Runner/GoogleService-Info.plist'));
      expect(yaml, contains('SECRETS=ios/Flutter/Secrets.xcconfig'));
      expect(yaml, contains(r'DART_DEFINES_FILE="$HOME/petcli_dart_defines.json"'));
      expect(yaml, contains(r'flutter build ipa --release'));
      expect(yaml, contains(r'--dart-define-from-file="$DART_DEFINES_FILE"'));
      // 빌드 번호는 pubspec에서 — 따로 넘기지 않는다.
      expect(yaml, isNot(contains('--build-number')));
    });

    test('저장소에 비밀값이 없고, 로그에 값을 찍지 않는다', () {
      expect(RegExp(r'^\s*set -[a-z]*x', multiLine: true).hasMatch(yaml), isFalse, reason: '명령 출력 금지');
      expect(yaml, isNot(contains(r'echo "$GOOGLE')));
      expect(yaml, isNot(contains(r'cat ios/Runner/GoogleService-Info.plist')));
      expect(yaml, isNot(matches(RegExp(r'ca-app-pub-\d{16}'))));
      expect(yaml, isNot(contains('googleusercontent.com')));
      expect(yaml, isNot(contains('BEGIN PRIVATE KEY')));
      final ignore = File('.gitignore').readAsLinesSync();
      for (final pattern in ['*.p8', '*.p12', '*.mobileprovision', 'ios/Flutter/Secrets.xcconfig']) {
        expect(ignore, contains(pattern), reason: pattern);
      }
      final readme = File('tool/ios/README.md').readAsStringSync();
      for (final name in [
        'petcli_ios',
        'GOOGLE_SERVICE_INFO_PLIST',
        'ADMOB_APP_ID_IOS',
        'GOOGLE_IOS_CLIENT_ID',
        'GOOGLE_REVERSED_CLIENT_ID',
        'DART_DEFINES_JSON',
        'ADMOB_BANNER_UNIT_ID_IOS',
        'ADMOB_APP_OPEN_UNIT_ID_IOS',
        'petcli_asc',
      ]) {
        expect(readme, contains(name), reason: name);
      }
    });
  });
}
