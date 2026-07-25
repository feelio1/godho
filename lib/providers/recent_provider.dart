import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';

/// Recently viewed hospital ids, most recent first, persisted locally.
class RecentHospitalsNotifier extends AsyncNotifier<List<String>> {
  final _store = const LocalStore();

  @override
  Future<List<String>> build() => _store.loadRecentIds();

  Future<void> recordVisit(String hospitalId) async {
    final updated = await _store.recordVisit(hospitalId);
    state = AsyncValue.data(updated);
  }
}

final recentHospitalsProvider =
    AsyncNotifierProvider<RecentHospitalsNotifier, List<String>>(
  RecentHospitalsNotifier.new,
);
