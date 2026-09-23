import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'fee_format.dart';

/// 최저–중간–최고 값의 위치를 보여주는 막대(화면 21 항목 카드). 트랙 위에
/// 중간값 위치를 점으로 찍는다 — 평가가 아니라 그저 숫자 세 개를 시각화한
/// 것뿐이라 색은 브랜드 블루 하나만 쓴다.
class FeeRangeBar extends StatelessWidget {
  final int min;
  final int mid;
  final int max;

  const FeeRangeBar({super.key, required this.min, required this.mid, required this.max});

  @override
  Widget build(BuildContext context) {
    final span = max - min;
    final fraction = span > 0 ? ((mid - min) / span).clamp(0.0, 1.0) : 0.5;
    const dotSize = 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: dotSize,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dotLeft = (constraints.maxWidth - dotSize) * fraction;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.borderMuted,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Positioned(
                    left: dotLeft.clamp(0.0, double.infinity),
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceLight, width: 2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '범위 ${feeWonRangeLabel(min, max)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
