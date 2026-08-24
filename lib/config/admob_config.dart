/// AdMob unit IDs.
///
/// Defaults are Google's own public **test** ad unit IDs (documented at
/// https://developers.google.com/admob/android/test-ads) — they are not
/// secrets and are safe to ship as fallbacks so the app always builds,
/// runs, and shows working (test) ads even with no configuration. Pass
/// real production IDs at build/run time with
/// `--dart-define=ADMOB_BANNER_UNIT_ID=xxx` and
/// `--dart-define=ADMOB_APP_OPEN_UNIT_ID=xxx` before release (see
/// 스프린트 5 지시서 "로컬 설정 안내"). The AdMob **App ID** itself is a
/// native-manifest value, not a Dart one — see android/secrets.properties.
const String _testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
const String _testAppOpenUnitId = 'ca-app-pub-3940256099942544/9257395921';

const String admobBannerUnitId = String.fromEnvironment(
  'ADMOB_BANNER_UNIT_ID',
  defaultValue: _testBannerUnitId,
);

const String admobAppOpenUnitId = String.fromEnvironment(
  'ADMOB_APP_OPEN_UNIT_ID',
  defaultValue: _testAppOpenUnitId,
);
