import 'dart:math' as math;

import '../models/hospital.dart';
import '../models/hospital_status.dart';

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
/// 지도 마커 후보를 고를 때 쓰는 "카메라 중심에서 몇 km 안을 보여줄지"
/// 근사값 — 줌 레벨이 낮을수록(더 멀리 보일수록) 반경을 넓힌다. 카카오
/// 지도 SDK가 실제 화면 경계(bounds)를 안정적으로 주지 않아, 위치 기반
/// 지도 표시 지시서가 허용한 대안("지도 중심/사용자 위치 반경 R km")을
/// 쓴다 — 목적은 정밀한 화면 경계가 아니라 "구 경계를 넘어 인접 병원도
/// 거리순으로 보이게" 하는 것이라 대략적인 값으로 충분하다.
double markerSearchRadiusKmForZoom(int zoomLevel) {
  if (zoomLevel >= 17) return 1.5;
  if (zoomLevel == 16) return 2.5;
  if (zoomLevel == 15) return 4;
  if (zoomLevel == 14) return 6;
  if (zoomLevel == 13) return 10;
  if (zoomLevel == 12) return 16;
  if (zoomLevel == 11) return 25;
  return 40;
}

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

/// 지도에 보이는 영역(위도·경도 사각형) — 마커 후보를 이 안에서 고른다
/// (실기기 2차 보정: 중심 반경만 보던 방식은 지도를 옮긴 곳에 마커가 없었다).
class MapViewport {
  final double south;
  final double west;
  final double north;
  final double east;

  const MapViewport({required this.south, required this.west, required this.north, required this.east});

  /// 화면 두 모서리의 좌표로 만든다 — 값이 비정상이면(무한대·넓이 0·한
  /// 변이 [maxSpanDegrees]보다 큼) null. 카카오 SDK의 화면→좌표 변환이
  /// 늘 믿을 만하지는 않아, 이상하면 호출부가 줌 기준 반경으로 대신한다.
  static MapViewport? fromCorners(double lat1, double lng1, double lat2, double lng2, {double maxSpanDegrees = 20}) {
    if (![lat1, lng1, lat2, lng2].every((v) => v.isFinite)) return null;
    final south = math.min(lat1, lat2);
    final north = math.max(lat1, lat2);
    final west = math.min(lng1, lng2);
    final east = math.max(lng1, lng2);
    if (north - south <= 0 || east - west <= 0) return null;
    if (north - south > maxSpanDegrees || east - west > maxSpanDegrees) return null;
    return MapViewport(south: south, west: west, north: north, east: east);
  }

  /// [lat],[lng] 중심 [radiusKm] 정사각형(근사) — 화면 좌표 변환을 못 쓸 때.
  factory MapViewport.around(double lat, double lng, double radiusKm) {
    final dLat = radiusKm / 111.0;
    final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.01, 1.0);
    final dLng = radiusKm / (111.0 * cosLat);
    return MapViewport(south: lat - dLat, west: lng - dLng, north: lat + dLat, east: lng + dLng);
  }

  bool contains(double lat, double lng) => lat >= south && lat <= north && lng >= west && lng <= east;

  /// 가장자리에 걸친 병원이 패닝 중 갑자기 생기지 않게 사방으로 [ratio]만큼 넓힌다.
  MapViewport expanded(double ratio) {
    final dLat = (north - south) * ratio;
    final dLng = (east - west) * ratio;
    return MapViewport(south: south - dLat, west: west - dLng, north: north + dLat, east: east + dLng);
  }
}

/// 지도 마커 후보 — [viewport] 안의 좌표 있는 영업중 병원. 클러스터로 묶이는
/// 줌(< [clusterDisabledZoom])에서는 모두 넘겨 클러스터 개수가 실제와 맞게
/// 하고, 개별 마커로 그리는 줌에서만 [individualCap]개까지 [centerLat]/
/// [centerLng]에 가까운 순으로 자른다(지도 렌더링 안전장치 — 검색·목록은
/// 그대로).
List<Hospital> selectMarkerCandidates(
  Iterable<Hospital> hospitals, {
  required MapViewport viewport,
  required double centerLat,
  required double centerLng,
  required int zoomLevel,
  int clusterDisabledZoom = 14,
  int individualCap = 300,
}) {
  var candidates = [
    for (final h in hospitals)
      if (h.hasCoordinates && h.status != HospitalStatus.closed && viewport.contains(h.lat!, h.lng!)) h,
  ];
  if (zoomLevel >= clusterDisabledZoom && candidates.length > individualCap) {
    double d(Hospital h) {
      final dLat = h.lat! - centerLat;
      final dLng = h.lng! - centerLng;
      return dLat * dLat + dLng * dLng;
    }
    candidates.sort((a, b) => d(a).compareTo(d(b)));
    candidates = candidates.take(individualCap).toList();
  }
  return candidates;
}
