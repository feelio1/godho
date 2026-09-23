import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fee.dart';
import '../models/region_filter.dart';
import '../providers/fee_provider.dart';
import '../providers/region_provider.dart';
import '../screens/fee_overview_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'fee_context_chip.dart';
import 'fee_format.dart';

/// 홈 상단 진료비 시세 카드(화면 01) — 선택한 지역의 초진 진찰료 시세를
/// 한눈에 보여주고 탭하면 진료비 시세 전체 페이지(21)로 이동한다. 특정
/// 병원의 가격이 아니라 "이 지역" 시세임을 항상 명시한다(CLAUDE.md
/// 진료비 원칙 2).
class FeeSummaryCard extends ConsumerWidget {
  const FeeSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(regionProvider).value?.filter ?? const RegionFilter.all();
    final bundle = ref.watch(feeBundleProvider).value;
    final weight = ref.watch(feeWeightProvider).bucket;

    final value = bundle != null && region.sigungu != null
        ? bundle.lookup(
            sido: region.sido!,
            sigungu: region.sigungu!,
            itemId: representativeFeeItemId,
            weight: weight,
          )
        : null;
    final item = bundle?.itemById(representativeFeeItemId);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FeeOverviewScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.card),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: value != null && item != null
            ? _WithData(regionLabel: region.shortLabel, itemName: item.name, value: value, weight: weight)
            : const _WithoutData(),
      ),
    );
  }
}

class _WithData extends StatelessWidget {
  final String regionLabel;
  final String itemName;
  final FeeValue value;
  final FeeWeightBucket weight;

  const _WithData({
    required this.regionLabel,
    required this.itemName,
    required this.value,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$regionLabel · $itemName 시세',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    feeWonLabel(value.mid),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '중간값',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value.sampleLow
                    ? '참고용 · ${weight.label} 기준'
                    : '범위 ${feeWonRangeLabel(value.min, value.max)} · ${weight.label} 기준',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.primaryTextTone),
      ],
    );
  }
}

class _WithoutData extends StatelessWidget {
  const _WithoutData();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            '지역을 선택하면 우리 동네 진료비 시세를 볼 수 있어요',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
          ),
        ),
        Icon(Icons.chevron_right, color: AppColors.primaryTextTone),
      ],
    );
  }
}
