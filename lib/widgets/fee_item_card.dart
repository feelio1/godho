import 'package:flutter/material.dart';

import '../models/fee.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'fee_format.dart';
import 'fee_range_bar.dart';

/// 진료비 시세 항목 카드(화면 21) — 항목명 + "중간값" 배지, 대표값(중간값)
/// 큰 글씨, 최저~최고 범위 슬라이더. 표본이 적어 최저==최고인 지역은
/// 슬라이더 대신 중립 안내를 보여준다(CLAUDE.md 진료비 원칙 4) — 구체적인
/// 병원 수는 원자료에 없으므로 표기하지 않는다.
class FeeItemCard extends StatelessWidget {
  final FeeItem item;
  final FeeValue value;

  const FeeItemCard({super.key, required this.item, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appCardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.cardLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Text(
                  '중간값',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            feeWonLabel(value.mid),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          if (value.sampleLow)
            const Text(
              '범위 데이터 없음',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPlaceholder),
            )
          else
            FeeRangeBar(min: value.min, mid: value.mid, max: value.max),
          if (value.sampleLow) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: const Text(
                '이 지역은 조사된 병원이 적어 참고용이에요',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
