import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';

/// Saved (관심) hospital ids, persisted locally via SharedPreferences.
/// No account, no server, no alerts (알림은 v1.1 — see sprint doc).
class SavedHospitalsNotifier extends AsyncNotifier<List<String>> {
  final _store = const LocalStore();

  @override
  Future<List<String>> build() => _store.loadSavedIds();

  Future<void> toggle(String hospitalId) async {
    final updated = await _store.toggleSaved(hospitalId);
    state = AsyncValue.data(updated);
  }

  bool isSaved(String hospitalId) => state.value?.contains(hospitalId) ?? false;
}

final savedHospitalsProvider =
    AsyncNotifierProvider<SavedHospitalsNotifier, List<String>>(
  SavedHospitalsNotifier.new,
);
