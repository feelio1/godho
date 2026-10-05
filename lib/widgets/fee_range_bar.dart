import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'fee_format.dart';

/// 최저–중간–최고 값의 위치를 보여주는 막대("펫클 앱 디자인" 캔버스
/// 시안의 `.bar`/`.rng`/`.med`) — 이 항목의 최소~최대 범위를 옅은 파란
/// 막대로, 중간값 위치를 그 안의 세로 틱으로 표시한다. 평가가 아니라
/// 그저 숫자 세 개를 시각화한 것뿐이라 색은 브랜드 블루 하나만 쓴다.
class FeeRangeBar extends StatelessWidget {
  final int min;
  final int mid;
  final int max;

  const FeeRangeBar({super.key, required this.min, required this.mid, required this.max});

  @override
  Widget build(BuildContext context) {
    final span = max - min;
    final fraction = span > 0 ? ((mid - min) / span).clamp(0.0, 1.0) : 0.5;
    const tickWidth = 3.0;
    const trackHeight = 6.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 14,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tickLeft = (constraints.maxWidth - tickWidth) * fraction;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: AppColors.feeRangeFill,
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                  Positioned(
                    left: tickLeft.clamp(0.0, double.infinity),
                    child: Container(
                      width: tickWidth,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(1.5),
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
