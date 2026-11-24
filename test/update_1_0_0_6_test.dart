import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/config/admob_config.dart';

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
}
