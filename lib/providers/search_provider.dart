import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import 'bundle_provider.dart';
import 'location_provider.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.name);

/// Search results for [searchQueryProvider], sorted by [sortOptionProvider].
/// Requires [bundleProvider] to already be loaded.
final searchResultsProvider = Provider<List<Hospital>>((ref) {
  final repo = ref.watch(repositoryProvider);
  final query = ref.watch(searchQueryProvider);
  final sort = ref.watch(sortOptionProvider);
  final location = ref.watch(locationProvider).value;

  final results = repo.search(query);
  return repo.sortHospitals(
    results,
    sort,
    currentLat: location?.latitude,
    currentLng: location?.longitude,
  );
});
