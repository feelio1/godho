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

  const FeeContextChip({super.key, required this.hospital});

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

    return Chip(
      label: Text(
        '이 지역 초진 시세 · 중간 ${feeWonLabel(value.mid)}',
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
