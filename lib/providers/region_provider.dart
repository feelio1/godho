import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';
import '../models/region_filter.dart';

/// [isUserSelected] distinguishes a region the user picked from a region
/// merely auto-derived from GPS — a later GPS update must never override an
/// explicit user choice (see 스프린트 2 지시서 4: "사용자가 지역을 수동
/// 선택하면 그 선택이 GPS보다 우선").
class RegionState {
  final RegionFilter filter;
  final bool isUserSelected;

  const RegionState({required this.filter, required this.isUserSelected});
}

class RegionNotifier extends AsyncNotifier<RegionState> {
  final _store = const LocalStore();

  @override
  Future<RegionState> build() async {
    final saved = await _store.loadRegion();
    if (saved != null) {
      return RegionState(filter: saved, isUserSelected: true);
    }
    return const RegionState(filter: RegionFilter.all(), isUserSelected: false);
  }

  Future<void> selectRegion(RegionFilter filter) async {
    await _store.saveRegion(filter);
    state = AsyncValue.data(RegionState(filter: filter, isUserSelected: true));
  }

  /// Applies a GPS-derived region, but only while the user has not made an
  /// explicit choice yet — otherwise a no-op.
  void applyGpsRegionIfUnset(RegionFilter gpsFilter) {
    final current = state.value;
    if (current == null || current.isUserSelected) return;
    if (current.filter == gpsFilter) return;
    state = AsyncValue.data(RegionState(filter: gpsFilter, isUserSelected: false));
  }
}

final regionProvider = AsyncNotifierProvider<RegionNotifier, RegionState>(
  RegionNotifier.new,
);
