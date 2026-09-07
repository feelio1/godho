import 'dart:math' as math;

import '../models/hospital.dart';

/// Same-cell hospitals for the 주변 병원 map — 1 hospital renders as an
/// individual marker, 2+ renders as a single cluster badge showing the
/// count (스프린트 6 지시서 3). Pure data, no SDK/platform dependency, so
/// the grouping logic can be unit-tested without a real map view.
class MarkerGroup {
  final List<Hospital> hospitals;

  const MarkerGroup(this.hospitals);

  bool get isCluster => hospitals.length > 1;

  /// The single hospital's own coordinates when not a cluster, otherwise
  /// the centroid (plain average) of the group — used only to place the
  /// cluster badge, never shown to the user as a fact about any hospital.
  ({double lat, double lng}) get position {
    if (hospitals.length == 1) {
      final h = hospitals.first;
      return (lat: h.lat!, lng: h.lng!);
    }
    var latSum = 0.0;
    var lngSum = 0.0;
    for (final h in hospitals) {
      latSum += h.lat!;
      lngSum += h.lng!;
    }
    return (lat: latSum / hospitals.length, lng: lngSum / hospitals.length);
  }
}

/// 클러스터 격자의 최소 칸 크기(도 단위, [clusterDisabledZoom] 바로 아래
/// 줌에서 적용) — 개별 마커가 막 뭉치기 시작하는 시점이라 같은 건물/블록
/// 수준으로 가까운 병원만 묶이도록 작게 잡는다.
const double _baseCellSize = 0.004;

/// 줌 레벨이 한 단계 낮아질(더 멀어질) 때마다 격자 칸 크기를 이 배율만큼
/// 키운다. 2배보다 완만하게 잡아 줌 단계 사이 전환이 덜 급격하도록 한다.
const double _cellGrowthFactor = 1.7;

/// [_cellGrowthFactor] 누적 계산의 안전 상한. 실제로 도달하는 줌 범위
/// (극단적으로 축소해도 전 세계 크기를 넘지 않음)보다 넉넉히 잡아, 이
/// 상한 자체가 "칸이 더는 커지지 않는" 원인이 되지 않게 한다.
const int _maxCellGrowthSteps = 24;

/// Grid cell size in degrees for a given Kakao map zoom level. Larger cells
/// (more aggressive grouping) when zoomed out; 0 — meaning "no clustering,
/// one marker per hospital" — at or above [clusterDisabledZoom].
///
/// 줌 레벨이 아무리 낮아져도(멀리 축소해도) 이 함수는 항상 0보다 큰 값을
/// 반환한다(스프린트 7 지시서 문제 2 — "아무것도 안 보이는 구간" 방지).
/// 칸이 아무리 커져도 [clusterHospitals]는 모든 병원을 반드시 어떤 그룹에
/// 포함시키므로, 화면에 병원이 있는 한 클러스터(N) 또는 개별 마커 중
/// 하나는 항상 그려진다.
double cellSizeForZoom(int zoomLevel, {int clusterDisabledZoom = 14}) {
  if (zoomLevel >= clusterDisabledZoom) return 0;
  final steps = (clusterDisabledZoom - zoomLevel).clamp(0, _maxCellGrowthSteps);
  return _baseCellSize * math.pow(_cellGrowthFactor, steps);
}

/// Buckets [hospitals] (all assumed to have coordinates) into a lat/lng
/// grid sized by [zoomLevel]. Every hospital appears in exactly one group,
/// regardless of zoom — there is no zoom level at which a non-empty input
/// produces an empty result.
List<MarkerGroup> clusterHospitals(
  List<Hospital> hospitals,
  int zoomLevel, {
  int clusterDisabledZoom = 14,
}) {
  final cellSize = cellSizeForZoom(zoomLevel, clusterDisabledZoom: clusterDisabledZoom);
  if (cellSize <= 0) {
    return hospitals.map((h) => MarkerGroup([h])).toList();
  }
  final buckets = <String, List<Hospital>>{};
  for (final h in hospitals) {
    final cellLat = (h.lat! / cellSize).floor();
    final cellLng = (h.lng! / cellSize).floor();
    buckets.putIfAbsent('$cellLat:$cellLng', () => []).add(h);
  }
  return buckets.values.map((list) => MarkerGroup(list)).toList();
}
