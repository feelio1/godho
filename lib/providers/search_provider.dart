import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import 'bundle_provider.dart';
import 'location_provider.dart';
import 'region_provider.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.name);

/// Tracks whether the user has ever picked a sort option themselves, so a
/// GPS fix arriving later can default to 가까운 순 without clobbering an
/// explicit choice (스프린트 2 지시서 4, mirroring [RegionState.isUserSelected]).
final sortManuallySetProvider = StateProvider<bool>((ref) => false);

/// "폐업 병원도 보기" — off by default, per 스프린트 2 지시서 1
/// (검색 결과는 기본적으로 영업중만 표시).
final includeClosedProvider = StateProvider<bool>((ref) => false);

/// Search results for [searchQueryProvider], region-filtered by
/// [regionProvider], status-filtered by [includeClosedProvider], and sorted
/// by [sortOptionProvider]. Requires [bundleProvider] to already be loaded.
///
/// With an empty query this returns the whole selected region (스프린트 4
/// 지시서 1: 검색 화면 진입 시 지역 기준 목록을 바로 표시) instead of an
/// empty list — typing narrows that same list by name/address.
///
/// This filtering is scoped to the search list only — the detail screen's
/// same-address timeline always shows every record regardless of these
/// filters (스프린트 2 지시서 1: 상세 타임라인은 절대 필터링하지 말 것).
final searchResultsProvider = Provider<List<Hospital>>((ref) {
  final repo = ref.watch(repositoryProvider);
  final query = ref.watch(searchQueryProvider);
  final sort = ref.watch(sortOptionProvider);
  final location = ref.watch(locationProvider).value;
  final region = ref.watch(regionProvider).value?.filter;
  final includeClosed = ref.watch(includeClosedProvider);

  var results = query.trim().isEmpty ? repo.all : repo.search(query);
  if (region != null) {
    results = repo.filterByRegion(results, region);
  }
  results = repo.filterByStatus(results, includeClosed: includeClosed);

  return repo.sortHospitals(
    results,
    sort,
    currentLat: location?.latitude,
    currentLng: location?.longitude,
  );
});
