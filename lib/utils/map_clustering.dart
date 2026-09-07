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

/// Grid cell size in degrees for a given Kakao map zoom level. Larger cells
/// (more aggressive grouping) when zoomed out; 0 — meaning "no clustering,
/// one marker per hospital" — at or above [clusterDisabledZoom].
double cellSizeForZoom(int zoomLevel, {int clusterDisabledZoom = 17}) {
  if (zoomLevel >= clusterDisabledZoom) return 0;
  final steps = (clusterDisabledZoom - zoomLevel).clamp(0, 10);
  var size = 0.01;
  for (var i = 0; i < steps; i++) {
    size *= 2;
  }
  return size;
}

/// Buckets [hospitals] (all assumed to have coordinates) into a lat/lng
/// grid sized by [zoomLevel]. Every hospital appears in exactly one group.
List<MarkerGroup> clusterHospitals(
  List<Hospital> hospitals,
  int zoomLevel, {
  int clusterDisabledZoom = 17,
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
