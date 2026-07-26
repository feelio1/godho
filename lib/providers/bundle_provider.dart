import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bundle_loader.dart';
import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import '../models/hospital_bundle.dart';

/// Loads assets/hospitals.json once and keeps it in memory for the app
/// session (see CLAUDE.md: 앱 시작 시 로드, 메모리에서 검색/필터).
final bundleProvider = FutureProvider<HospitalBundle>((ref) async {
  return const BundleLoader().load();
});

/// Only valid once [bundleProvider] has resolved; screens should gate on
/// bundleProvider's AsyncValue before reading this.
final repositoryProvider = Provider<HospitalRepository>((ref) {
  final bundle = ref.watch(bundleProvider).requireValue;
  return HospitalRepository(bundle);
});

final hospitalByIdProvider = Provider.family<Hospital?, String>((ref, id) {
  return ref.watch(repositoryProvider).byId(id);
});
