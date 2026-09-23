import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hospital.dart';
import '../providers/fee_provider.dart';
import '../theme/app_colors.dart';
import 'fee_format.dart';

/// 병원 카드 어디서나 대표로 보여주는 항목 — 초진 진찰료. 값이 없으면
/// 칩 자체를 숨긴다(호출부).
const representativeFeeItemId = 'consult_first';

/// 병원 카드 하단에 다는 "이 지역 초진 시세" 칩(스프린트 진료비 지시서
/// 2번 위치들 공통). 병원 자체 가격이 아니라 그 병원이 속한 시/군/구의
/// 시세임을 항상 "이 지역"으로 명시한다(CLAUDE.md 진료비 원칙 2). 이
/// 병원의 지역에 데이터가 없으면 조용히 숨는다 — 추정하지 않는다.
///
/// 폐업 병원엔 아예 달지 않는다 — 호출부가 그 경우 이 위젯 자체를 Wrap에
/// 넣지 않는다.
class FeeContextChip extends ConsumerWidget {
  final Hospital hospital;

  /// 지도처럼 서로 다른 구의 병원이 한 화면에 함께 보이는 곳에서는
  /// "이 지역" 대신 실제 구 이름을 밝힌다 — 인접 구 병원이 나란히 뜨는
  /// 지도에서 "이 지역"이라고만 하면 어느 구를 가리키는지 모호해
  /// 병원별 가격으로 오해될 수 있다(위치 기반 지도 표시 지시서 2-2).
  /// 검색결과·저장 목록처럼 한 지역으로만 좁혀진 화면은 기본값(false,
  /// "이 지역")을 그대로 쓴다.
  final bool showRegionLabel;

  const FeeContextChip({super.key, required this.hospital, this.showRegionLabel = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(feeBundleProvider).value;
    if (bundle == null) return const SizedBox.shrink();
    final weight = ref.watch(feeWeightProvider).bucket;
    final value = bundle.lookup(
      sido: hospital.sido,
      sigungu: hospital.sigungu,
      itemId: representativeFeeItemId,
      weight: weight,
    );
    if (value == null) return const SizedBox.shrink();

    final regionLabel = showRegionLabel ? '${hospital.sigungu} 시세' : '이 지역 초진 시세';

    return Chip(
      label: Text(
        '$regionLabel · 중간 ${feeWonLabel(value.mid)}',
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: AppColors.inputFill,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
