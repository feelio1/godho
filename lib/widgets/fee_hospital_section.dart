import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fee.dart';
import '../models/fee_bundle.dart';
import '../models/hospital.dart';
import '../models/region_filter.dart';
import '../providers/fee_provider.dart';
import '../providers/region_provider.dart';
import '../screens/fee_overview_screen.dart';
import '../theme/app_colors.dart';
import '../utils/fee_no_data_message.dart';
import 'fee_context_chip.dart';
import 'fee_format.dart';
import 'fee_item_picker_sheet.dart';

/// 병원 상세의 "이 지역 진료비 시세" 섹션 — 대표 2~3개 항목만 요약해
/// 보여주고 전체 35개는 나열하지 않는다("다른 항목 보기"로 화면 22를
/// 연다). 이 병원 하나의 가격이 아니라 이 병원이 속한 시/군/구의 시세라는
/// 점을 제목·부제에서 항상 밝힌다(CLAUDE.md 진료비 원칙 2).
class FeeHospitalSection extends ConsumerWidget {
  final Hospital hospital;

  const FeeHospitalSection({super.key, required this.hospital});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(feeBundleProvider).value;
    if (bundle == null) return const SizedBox.shrink();
    final weight = ref.watch(feeWeightProvider).bucket;
    // 이 구가 fees 조사 범위 밖(신설 구 등)인지부터 먼저 본다 — 개별
    // 항목 표본 유무와는 다른 지역 단위 판정으로, 홈 카드·화면21과 같은
    // 기준·문구를 쓴다(펫클 홈 자동 시세 표시 지시서와 동일한
    // hasAnyDataFor/feeNoRegionDataSubtitle 재사용 — 3단계 지시서 3).
    final hasRegionData = bundle.hasAnyDataFor(hospital.sido, hospital.sigungu);
    final representative = hasRegionData ? _representativeItems(bundle, weight) : const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '이 지역 진료비 시세',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${hospital.sigungu} · ${weight.label}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasRegionData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  feeNoRegionDataSubtitle(hospital.sigungu, hospital.sigungu),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPlaceholder),
                ),
              )
            else if (representative.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '이 지역은 이 항목들의 조사 자료가 아직 없어요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPlaceholder),
                ),
              )
            else
              for (var i = 0; i < representative.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _FeeCompactRow(item: representative[i].$1, value: representative[i].$2),
              ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _openOtherItems(context, ref, bundle),
                child: const Text('다른 항목 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOtherItems(BuildContext context, WidgetRef ref, FeeBundle bundle) async {
    final picked = await showFeeItemPickerSheet(context, bundle: bundle);
    if (picked == null || !context.mounted) return;
    // 이 화면은 병원 자체 주소의 시/군/구 기준이므로, 21로 넘어갈 때도
    // 전역 지역을 이 병원의 지역으로 맞춰 값이 어긋나 보이지 않게 한다.
    await ref
        .read(regionProvider.notifier)
        .selectRegion(RegionFilter(sido: hospital.sido, sigungu: hospital.sigungu));
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FeeOverviewScreen(initialItemId: picked.id)),
    );
  }

  List<(FeeItem, FeeValue)> _representativeItems(FeeBundle bundle, FeeWeightBucket weight) {
    final candidateIds = <String>{representativeFeeItemId, ...bundle.items.map((item) => item.id)};
    final result = <(FeeItem, FeeValue)>[];
    for (final id in candidateIds) {
      final item = bundle.itemById(id);
      if (item == null) continue;
      final value = bundle.lookup(
        sido: hospital.sido,
        sigungu: hospital.sigungu,
        itemId: id,
        weight: weight,
      );
      if (value == null) continue;
      result.add((item, value));
      if (result.length >= 3) break;
    }
    return result;
  }
}

/// 대표값은 항상 중간값(median) — 평균 아님(CLAUDE.md 진료비 원칙).
/// 범위(최저~최고)를 중간값 바로 옆에 함께 보여줘 "이 한 값이 절대적"
/// 이라는 오해를 줄인다(펫클 3단계 지시서 3).
class _FeeCompactRow extends StatelessWidget {
  final FeeItem item;
  final FeeValue value;

  const _FeeCompactRow({required this.item, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(item.name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.sampleLow ? '참고용' : '중간 ${feeWonLabel(value.mid)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: value.sampleLow ? AppColors.textPlaceholder : AppColors.primaryTextTone,
                ),
              ),
              if (!value.sampleLow) ...[
                const SizedBox(height: 2),
                Text(
                  '범위 ${feeWonRangeLabel(value.min, value.max)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
