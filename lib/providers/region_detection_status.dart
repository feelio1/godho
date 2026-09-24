import 'package:flutter_riverpod/legacy.dart';

/// 위치 기반 지역 자동 감지가 왜 실패했는지(또는 성공했는지) — 화면 26이
/// 이 값을 보고 사유별로 다른 안내 문구를 보여준다. "조용한 실패"가
/// 진단을 막았던 문제를 고치는 게 목적이라(위치 자동감지 디버깅
/// 지시서 A), 값 자체는 UI 문구 선택에만 쓰고 로직 분기에는 쓰지 않는다
/// — 실제 판단은 언제나 `regionProvider`의 실제 상태(구가 있는지)로 한다.
enum RegionDetectionReason {
  /// 아직 한 번도 시도하지 않음.
  idle,

  /// 진행 중 — 권한 확인부터 정규화까지 어느 단계든.
  detecting,

  /// 위치 서비스(GPS)가 꺼져 있음.
  locationServiceDisabled,

  /// 위치 권한이 거부됨(일시적 거부 또는 영구 거부 모두).
  permissionDenied,

  /// 권한·서비스는 정상인데 좌표를 못 얻음(타임아웃 등).
  positionUnavailable,

  /// 좌표는 얻었지만 카카오 REST·오프라인 폴백 모두 이 앱이 다루는
  /// 지역으로 매핑하지 못함(예: 국내 데이터 범위 밖의 좌표).
  regionNotFound,

  /// 감지 성공 — 지역이 설정됨.
  success,
}

final regionDetectionReasonProvider = StateProvider<RegionDetectionReason>(
  (ref) => RegionDetectionReason.idle,
);
