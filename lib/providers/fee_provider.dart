import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fee_bundle_loader.dart';
import '../models/fee.dart';
import '../models/fee_bundle.dart';

/// Loads assets/fees.json once and keeps it in memory for the app session
/// — same pattern as [bundleProvider] for hospitals.json.
final feeBundleProvider = FutureProvider<FeeBundle>((ref) async {
  return const FeeBundleLoader().load();
});

/// [isUserSelected]는 사용자가 직접 고른 체중 구간과, 반려동물 체중에서
/// 자동으로 유도한 구간을 구분한다 — 나중에 반려동물 체중이 바뀌어도
/// 사용자가 이미 손으로 고른 구간을 덮어쓰지 않는다([RegionState]의
/// isUserSelected와 같은 패턴).
class FeeWeightState {
  final FeeWeightBucket bucket;
  final bool isUserSelected;

  const FeeWeightState({required this.bucket, required this.isUserSelected});
}

/// 진료비 시세 조회에 쓰는 체중 기준 — 진료비 시세 화면·병원 카드·병원
/// 상세가 모두 같은 값을 공유한다("우리 아이 체중 기준"이 화면마다
/// 다르게 보이지 않게). 반려동물 미등록/미입력 시 기본값은 5kg 미만이다.
class FeeWeightNotifier extends Notifier<FeeWeightState> {
  @override
  FeeWeightState build() {
    return const FeeWeightState(bucket: FeeWeightBucket.u5, isUserSelected: false);
  }

  void select(FeeWeightBucket bucket) {
    state = FeeWeightState(bucket: bucket, isUserSelected: true);
  }

  /// 반려동물 체중이 확인되면(등록·입력) 그 구간을 기본값으로 반영한다 —
  /// 사용자가 이미 직접 고른 경우는 덮어쓰지 않는다.
  void applyPetWeightIfUnset(double weightKg) {
    if (state.isUserSelected) return;
    final derived = FeeWeightBucket.fromKg(weightKg);
    if (state.bucket == derived) return;
    state = FeeWeightState(bucket: derived, isUserSelected: false);
  }
}

final feeWeightProvider = NotifierProvider<FeeWeightNotifier, FeeWeightState>(
  FeeWeightNotifier.new,
);
