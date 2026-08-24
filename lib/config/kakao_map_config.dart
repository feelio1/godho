/// Kakao Maps native app key.
///
/// Pass it at build/run time with `--dart-define=KAKAO_NATIVE_KEY=xxx`
/// once issued from the Kakao Developers console (see
/// 스프린트 5 지시서 1). No key is hardcoded here or anywhere else — until
/// one is provided, the 주변 병원 tab falls back to a "준비 중" stub so the
/// rest of the app still builds and runs.
const String kakaoNativeKey =
    String.fromEnvironment('KAKAO_NATIVE_KEY', defaultValue: '');

bool get isKakaoMapConfigured => kakaoNativeKey.isNotEmpty;
