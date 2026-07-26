/// Naver Cloud Platform Maps Client ID.
///
/// Sprint 1 ships without a provisioned key. Once issued from the NCP
/// console, pass it at build/run time with
/// `--dart-define=NAVER_MAP_CLIENT_ID=xxx` (see 스프린트 1 지시서
/// 5. 주변 병원 셋업 주의 구간). Until then, the 주변 병원 tab falls back
/// to a "준비 중" stub so the rest of the app still builds and runs.
const String naverMapClientId =
    String.fromEnvironment('NAVER_MAP_CLIENT_ID', defaultValue: '');

bool get isNaverMapConfigured => naverMapClientId.isNotEmpty;
