import 'dart:math' as math;

import '../models/hospital.dart';
import '../models/hospital_bundle.dart';
import '../models/hospital_status.dart';
import '../models/region_filter.dart';

/// Search-result sort options.
///
/// Deliberately does NOT include anything like "신뢰도 순" — this app
/// never ranks hospitals by an inferred trust or quality score
/// (see CLAUDE.md 원칙 1).
enum SortOption {
  distance('가까운 순'),
  operatingLength('운영 긴 순'),
  recentOpen('최근 개원 순'),
  name('이름 순');

  final String label;

  const SortOption(this.label);
}

class HospitalRepository {
  final HospitalBundle bundle;

  HospitalRepository(this.bundle);

  List<Hospital> get all => bundle.hospitals;

  /// 시/도 -> 시군구 index, built once and reused (nationwide bundle is
  /// ~10,584 records, so this is computed lazily on first access rather
  /// than per screen build). Values come only from what's actually present
  /// in the data — never hardcoded.
  late final Map<String, List<String>> _sigunguBySido = _buildRegionIndex();

  late final List<String> sidoList = (_sigunguBySido.keys.toList()..sort());

  Map<String, List<String>> _buildRegionIndex() {
    final map = <String, Set<String>>{};
    for (final h in bundle.hospitals) {
      if (h.sido.isEmpty) continue;
      final set = map.putIfAbsent(h.sido, () => <String>{});
      if (h.sigungu.isNotEmpty) set.add(h.sigungu);
    }
    return map.map((sido, sigunguSet) {
      final list = sigunguSet.toList()..sort();
      return MapEntry(sido, list);
    });
  }

  List<String> sigunguListFor(String sido) => _sigunguBySido[sido] ?? const [];

  Hospital? byId(String id) {
    for (final h in bundle.hospitals) {
      if (h.id == id) return h;
    }
    return null;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  List<Hospital> search(String query) {
    final needle = _normalize(query);
    if (needle.isEmpty) return const [];
    return bundle.hospitals
        .where((h) =>
            _normalize(h.name).contains(needle) ||
            _normalize(h.roadAddr).contains(needle))
        .toList();
  }

  List<Hospital> filterByRegion(List<Hospital> hospitals, RegionFilter region) {
    if (region.isNationwide) return hospitals;
    return hospitals.where((h) => region.matches(h.sido, h.sigungu)).toList();
  }

  List<Hospital> filterByStatus(List<Hospital> hospitals, {required bool includeClosed}) {
    if (includeClosed) return hospitals;
    return hospitals.where((h) => h.status != HospitalStatus.closed).toList();
  }

  /// Best-effort "current region" from a GPS fix: the region of the
  /// nearest hospital with coordinates. Used only to pick a sensible
  /// default region filter — never shown to the user as a fact about a
  /// specific hospital.
  RegionFilter? nearestRegion(double lat, double lng) {
    Hospital? nearest;
    double? nearestDistance;
    for (final h in bundle.hospitals) {
      if (!h.hasCoordinates) continue;
      final d = distanceKm(lat, lng, h.lat, h.lng)!;
      if (nearestDistance == null || d < nearestDistance) {
        nearestDistance = d;
        nearest = h;
      }
    }
    if (nearest == null) return null;
    return RegionFilter(sido: nearest.sido, sigungu: nearest.sigungu);
  }

  /// Great-circle distance in kilometers, or null if either point is
  /// unavailable.
  static double? distanceKm(
    double? lat1,
    double? lng1,
    double? lat2,
    double? lng2,
  ) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return null;
    }
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Sorts a copy of [hospitals]. For [SortOption.distance], hospitals
  /// without coordinates or without a known [currentLat]/[currentLng]
  /// sort to the end rather than being dropped.
  List<Hospital> sortHospitals(
    List<Hospital> hospitals,
    SortOption option, {
    double? currentLat,
    double? currentLng,
  }) {
    final result = List<Hospital>.from(hospitals);
    switch (option) {
      case SortOption.distance:
        result.sort((a, b) {
          final da = distanceKm(currentLat, currentLng, a.lat, a.lng);
          final db = distanceKm(currentLat, currentLng, b.lat, b.lng);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
        break;
      case SortOption.operatingLength:
        result.sort((a, b) {
          final ya = a.operatingYears;
          final yb = b.operatingYears;
          if (ya == null && yb == null) return 0;
          if (ya == null) return 1;
          if (yb == null) return -1;
          return yb.compareTo(ya);
        });
        break;
      case SortOption.recentOpen:
        result.sort((a, b) {
          final oa = a.openDate;
          final ob = b.openDate;
          if (oa == null && ob == null) return 0;
          if (oa == null) return 1;
          if (ob == null) return -1;
          return ob.compareTo(oa);
        });
        break;
      case SortOption.name:
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return result;
  }

  int sameAddressRecordCount(Hospital hospital) =>
      bundle.sameAddressRecordCount(hospital);
}
