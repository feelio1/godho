import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fee.dart';
import '../models/fee_bundle.dart';
import '../models/region_filter.dart';
import '../providers/fee_provider.dart';
import '../providers/region_provider.dart';
import '../screens/fee_overview_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/fee_no_data_message.dart';
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
        child: _content(region, bundle, weight),
      ),
    );
  }

  /// 위치 자동 감지 성공 시 홈 카드가 자동으로 그 지역 상태를 반영해야
  /// 한다(홈 자동 시세 표시 지시서 변경 1) — 지역이 아직 없을 때만
  /// "지역을 선택하면..."을 보여주고, 지역은 있지만 그 구가 fees 조사
  /// 범위 밖(신설 구 등)이면 대체값 없이 이유를 보여준다(변경 2).
  Widget _content(RegionFilter region, FeeBundle? bundle, FeeWeightBucket weight) {
    if (region.sigungu == null) {
      return const _WithoutRegion();
    }
    final sido = region.sido!;
    final sigungu = region.sigungu!;

    if (bundle == null) {
      // fees.json 로딩 중 — 지역은 이미 있으니 "선택하면" 문구는 부적절
      // 하고, 그렇다고 아직 없는 데이터를 있다고 말할 수도 없다. 잠깐의
      // 과도 상태라 빈 자리로 둔다(다음 프레임에 바로 갱신됨).
      return const SizedBox.shrink();
    }

    if (!bundle.hasAnyDataFor(sido, sigungu)) {
      return _NoFeeData(regionLabel: region.shortLabel, sigungu: sigungu);
    }

    final value = bundle.lookup(
      sido: sido,
      sigungu: sigungu,
      itemId: representativeFeeItemId,
      weight: weight,
    );
    final item = bundle.itemById(representativeFeeItemId);
    if (value == null || item == null) {
      // 이 구에 다른 항목 데이터는 있지만 대표 항목(초진 진찰료)만
      // 없는 드문 경우 — 같은 "자료가 아직 없다" 안내로 충분하다.
      return _NoFeeData(regionLabel: region.shortLabel, sigungu: sigungu);
    }

    return _WithData(regionLabel: region.shortLabel, itemName: item.name, value: value, weight: weight);
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

class _WithoutRegion extends StatelessWidget {
  const _WithoutRegion();

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

/// 지역은 있지만(자동 감지·수동 선택 모두) 그 구가 fees 조사 범위 밖일
/// 때 — 다른 구 값으로 대체하지 않고 이유를 보여준다(홈 자동 시세 표시
/// 지시서 변경 2). "지역을 선택하면..."과 달리 이미 지역은 정해졌다는
/// 점을 문구로 분명히 한다.
class _NoFeeData extends StatelessWidget {
  final String regionLabel;
  final String sigungu;

  const _NoFeeData({required this.regionLabel, required this.sigungu});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$regionLabel 진료비 시세',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
              ),
              const SizedBox(height: 4),
              Text(
                feeNoRegionDataSubtitle(regionLabel, sigungu),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, color: AppColors.primaryTextTone),
      ],
    );
  }
}
