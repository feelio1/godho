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
  ///
  /// 위치 자동감지 디버깅 지시서 E: 이전엔 `state.value`를 바로 읽어서,
  /// [build]가 아직 끝나지 않았으면(SharedPreferences 읽는 중) `current`가
  /// null이라 조용히 아무 것도 안 하고 끝났다 — 그리고 다시는 재시도되지
  /// 않았다(이 메서드는 locationProvider가 바뀔 때만 호출되므로). 앱 시작
  /// 직후 위치가 지역보다 먼저 도착하면 정확히 이 경쟁조건에 걸려 감지된
  /// 지역이 버려졌다. `future`를 먼저 기다려 build가 끝난 뒤의 실제 상태를
  /// 보고 판단한다.
  Future<void> applyGpsRegionIfUnset(RegionFilter gpsFilter) async {
    final current = await future;
    if (current.isUserSelected) return;
    if (current.filter == gpsFilter) return;
    state = AsyncValue.data(RegionState(filter: gpsFilter, isUserSelected: false));
  }
}

final regionProvider = AsyncNotifierProvider<RegionNotifier, RegionState>(
  RegionNotifier.new,
);
