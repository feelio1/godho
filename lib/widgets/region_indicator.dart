import 'package:flutter/material.dart';

import '../models/region_filter.dart';
import '../theme/app_colors.dart';

/// "인천 남동구 ▾" style button shown on home/search to display the
/// currently selected region and let the user change it.
class RegionIndicator extends StatelessWidget {
  final RegionFilter region;
  final VoidCallback onTap;

  const RegionIndicator({super.key, required this.region, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // "장구름의 수첩"(3차 업데이트 J-2): 흰 바탕 알약, 높이 44dp.
    return Material(
      color: AppColors.surfaceLight,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.borderCard)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                region.label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
