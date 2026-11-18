import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fee.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'fee_format.dart';

final _won = NumberFormat('#,###');

/// 진료비 한 항목 — 이름·가운데 값(굵게) + 최저~최고 가로 막대 위의 가운데
/// 값 점 + 막대 양끝 금액("장구름의 수첩", 3차 업데이트 J-2). 높다·낮다에
/// 색 의미를 주지 않는다 — 막대·점 모두 중립 잉크/네이비 톤.
/// [FeeValue.sampleLow](최저 = 최고)면 막대 없이 "참고용"만 보인다.
class FeeRangeRow extends StatelessWidget {
  final String name;
  final FeeValue value;

  const FeeRangeRow({super.key, required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value.sampleLow ? '참고용' : feeWonLabel(value.mid),
                style: AppTextStyles.mono(
                  size: value.sampleLow ? 14 : 20,
                  weight: FontWeight.w700,
                  color: value.sampleLow ? AppColors.textSecondary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (!value.sampleLow) ...[
            const SizedBox(height: 10),
            FeeDotBar(min: value.min, mid: value.mid, max: value.max),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${_won.format(value.min)}원',
                  style: AppTextStyles.mono(size: 12.5, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${_won.format(value.max)}원',
                  style: AppTextStyles.mono(size: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 최저~최고 막대 + 가운데 값 점(잉크색, 흰 테두리) — 높다·낮다에 색
/// 의미를 주지 않는다.
class FeeDotBar extends StatelessWidget {
  final int min;
  final int mid;
  final int max;

  const FeeDotBar({super.key, required this.min, required this.mid, required this.max});

  @override
  Widget build(BuildContext context) {
    final span = max - min;
    final t = span <= 0 ? 0.5 : ((mid - min) / span).clamp(0.0, 1.0);
    const dot = 16.0;
    return Semantics(
      label: '가장 낮은 곳 ${_won.format(min)}원, 가운데 값 ${_won.format(mid)}원, 가장 높은 곳 ${_won.format(max)}원',
      child: SizedBox(
        height: dot,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: (dot - 8) / 2,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.feeRangeFill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Positioned(
                  left: (w - dot) * t,
                  top: 0,
                  child: Container(
                    width: dot,
                    height: dot,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 진료비 항목 카드용 — [FeeDotBar] + 아래 "범위 최저~최고원".
class FeeRangeBar extends StatelessWidget {
  final int min;
  final int mid;
  final int max;

  const FeeRangeBar({super.key, required this.min, required this.mid, required this.max});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeeDotBar(min: min, mid: mid, max: max),
        const SizedBox(height: 6),
        Text(
          '범위 ${feeWonRangeLabel(min, max)}',
          style: AppTextStyles.mono(size: 12.5, weight: FontWeight.w500, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
