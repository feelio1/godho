import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';

/// 지정(단골) hospital ids, persisted locally via SharedPreferences. 홈
/// 상단에 항상 노출되는 병원 목록으로, "저장(관심)"과는 별개 개념이다
/// (스프린트 8 지시서 1).
class DesignatedHospitalsNotifier extends AsyncNotifier<List<String>> {
  final _store = const LocalStore();

  @override
  Future<List<String>> build() => _store.loadDesignatedIds();

  Future<void> toggle(String hospitalId) async {
    final updated = await _store.toggleDesignated(hospitalId);
    state = AsyncValue.data(updated);
  }

  bool isDesignated(String hospitalId) => state.value?.contains(hospitalId) ?? false;
}

final designatedHospitalsProvider =
    AsyncNotifierProvider<DesignatedHospitalsNotifier, List<String>>(
  DesignatedHospitalsNotifier.new,
);
