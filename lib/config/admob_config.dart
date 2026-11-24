import 'package:flutter/foundation.dart';

/// AdMob unit IDs.
///
/// Defaults are Google's own public **test** ad unit IDs (documented at
/// https://developers.google.com/admob/android/test-ads and
/// https://developers.google.com/admob/ios/test-ads) — they are not
/// secrets and are safe to ship as fallbacks so the app always builds,
/// runs, and shows working (test) ads even with no configuration. Pass
/// real production IDs at build/run time before release:
/// - Android: `--dart-define=ADMOB_BANNER_UNIT_ID=xxx`,
///   `--dart-define=ADMOB_APP_OPEN_UNIT_ID=xxx` (스프린트 5 "로컬 설정 안내").
/// - iOS: `ADMOB_BANNER_UNIT_ID_IOS`, `ADMOB_APP_OPEN_UNIT_ID_IOS`
///   (iOS 출시 준비 L-2 — Codemagic의 `DART_DEFINES_JSON`으로 넣는다).
///
/// 플랫폼마다 광고 단위가 따로라서(AdMob 콘솔에서 앱이 둘) iOS에서는
/// iOS 값만, 안드로이드에서는 지금까지와 똑같이 안드로이드 값만 쓴다 —
/// 한쪽 값이 비어 있어도 다른 플랫폼의 실제 ID로 넘어가지 않고 그
/// 플랫폼의 테스트 ID로 떨어진다.
///
/// The AdMob **App ID** itself is a native value, not a Dart one — Android:
/// android/secrets.properties, iOS: `ADMOB_APP_ID_IOS` in
/// ios/Flutter/Secrets.xcconfig (없으면 구글 공개 iOS 테스트 앱 ID).
const String kTestBannerUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
const String kTestAppOpenUnitIdAndroid = 'ca-app-pub-3940256099942544/9257395921';
const String kTestBannerUnitIdIos = 'ca-app-pub-3940256099942544/2934735716';
const String kTestAppOpenUnitIdIos = 'ca-app-pub-3940256099942544/5575463023';

const String _bannerAndroid = String.fromEnvironment('ADMOB_BANNER_UNIT_ID');
const String _appOpenAndroid = String.fromEnvironment('ADMOB_APP_OPEN_UNIT_ID');
const String _bannerIos = String.fromEnvironment('ADMOB_BANNER_UNIT_ID_IOS');
const String _appOpenIos = String.fromEnvironment('ADMOB_APP_OPEN_UNIT_ID_IOS');

/// 플랫폼별 배너 광고 단위 — [configured]가 비어 있으면 그 플랫폼의
/// 구글 공개 테스트 ID. 테스트에서 값을 직접 넣어 확인할 수 있게
/// 설정값을 인자로 받는다.
@visibleForTesting
String bannerUnitIdFor(TargetPlatform platform, {String? configured}) {
  final isIos = platform == TargetPlatform.iOS;
  final value = configured ?? (isIos ? _bannerIos : _bannerAndroid);
  if (value.isNotEmpty) return value;
  return isIos ? kTestBannerUnitIdIos : kTestBannerUnitIdAndroid;
}

/// 플랫폼별 앱 오프닝 광고 단위 — [bannerUnitIdFor]와 같은 규칙.
@visibleForTesting
String appOpenUnitIdFor(TargetPlatform platform, {String? configured}) {
  final isIos = platform == TargetPlatform.iOS;
  final value = configured ?? (isIos ? _appOpenIos : _appOpenAndroid);
  if (value.isNotEmpty) return value;
  return isIos ? kTestAppOpenUnitIdIos : kTestAppOpenUnitIdAndroid;
}

String get admobBannerUnitId => bannerUnitIdFor(defaultTargetPlatform);

String get admobAppOpenUnitId => appOpenUnitIdFor(defaultTargetPlatform);
