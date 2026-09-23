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

/// Kakao Local REST API key — 좌표→행정구역 변환(coord2regioncode)에만
/// 쓴다. 지도 SDK 키(네이티브 앱 키)와는 다른 키다.
///
/// `--dart-define=KAKAO_REST_KEY=xxx`로 주입한다. 키가 없으면(또는 호출이
/// 실패하면) 위치 기반 지역 자동 감지는 hospitals.json 최단거리 병원
/// 기준의 오프라인 폴백으로 조용히 넘어간다 — 지도 탭과 달리 이 키가
/// 없다고 기능 전체를 막지 않는다.
const String kakaoRestKey =
    String.fromEnvironment('KAKAO_REST_KEY', defaultValue: '');

bool get isKakaoRestConfigured => kakaoRestKey.isNotEmpty;
