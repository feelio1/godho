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
import 'fee_format.dart';

/// 홈 상단 진료비 시세 카드(화면 01) — 선택한 지역의 대표 항목 3~4개
/// 시세를 한눈에 보여주고 탭하면 진료비 시세 전체 페이지(21)로 이동한다
/// ("출시 전 마무리" 지시서 A-2 — 초진 하나만 보여주던 것을 확장).
/// 특정 병원의 가격이 아니라 "이 지역" 시세임을 항상 명시한다(CLAUDE.md
/// 진료비 원칙 2).
class FeeSummaryCard extends ConsumerWidget {
  const FeeSummaryCard({super.key});

  /// 대표로 시도해볼 항목 우선순위 — 초진 진찰료 → 종합백신(개) →
  /// 광견병백신 → 재진 진찰료 → 혈액검사(CBC). 그 구에 데이터가 없는
  /// 항목은 건너뛰고(대체·추정 금지), 있는 것만 최대 4개까지 보여준다.
  /// 항목명 자체는 여기서 새로 짓지 않고 항상 fees.json의 [FeeItem.name]을
  /// 그대로 쓴다.
  static const _candidateItemIds = [
    'consult_first',
    'vaccine_combo_dog',
    'vaccine_rabies',
    'consult_revisit',
    'test_cbc',
  ];
  static const _maxItems = 4;

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

    final items = _representativeItems(bundle, sido, sigungu, weight);
    if (items.isEmpty) {
      // 이 구에 다른 항목 데이터는 있지만 대표 후보 항목은 전부 없는
      // 드문 경우 — 같은 "자료가 아직 없다" 안내로 충분하다.
      return _NoFeeData(regionLabel: region.shortLabel, sigungu: sigungu);
    }

    return _WithItems(regionLabel: region.shortLabel, weight: weight, items: items);
  }

  List<(FeeItem, FeeValue)> _representativeItems(
    FeeBundle bundle,
    String sido,
    String sigungu,
    FeeWeightBucket weight,
  ) {
    final result = <(FeeItem, FeeValue)>[];
    for (final id in _candidateItemIds) {
      final item = bundle.itemById(id);
      if (item == null) continue;
      final value = bundle.lookup(sido: sido, sigungu: sigungu, itemId: id, weight: weight);
      if (value == null) continue;
      result.add((item, value));
      if (result.length >= _maxItems) break;
    }
    return result;
  }
}

class _WithItems extends StatelessWidget {
  final String regionLabel;
  final FeeWeightBucket weight;
  final List<(FeeItem, FeeValue)> items;

  const _WithItems({required this.regionLabel, required this.weight, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$regionLabel 진료비 시세 · ${weight.label} 기준',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primaryTextTone),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.borderCard),
          _FeeSummaryRow(item: items[i].$1, value: items[i].$2),
        ],
      ],
    );
  }
}

class _FeeSummaryRow extends StatelessWidget {
  final FeeItem item;
  final FeeValue value;

  const _FeeSummaryRow({required this.item, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.sampleLow ? '참고용' : feeWonLabel(value.mid),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: value.sampleLow ? AppColors.textPlaceholder : AppColors.textPrimary,
            ),
          ),
          if (!value.sampleLow) ...[
            const SizedBox(width: 6),
            Text(
              feeWonRangeLabel(value.min, value.max),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
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
