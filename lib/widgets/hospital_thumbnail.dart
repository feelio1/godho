import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 병원 사진 자리. 실제 병원 사진 데이터는 없으므로(CLAUDE.md·스프린트 10
/// 지시서 — 크롤링 금지) 검색 결과 카드·상세 화면 상단에서 항상 같은
/// 장구름 placeholder(hospital_placeholder.png)를 보여준다. 어떤 병원이
/// 더 낫다는 인상을 주지 않도록 모든 병원이 동일한 이미지를 쓴다.
class HospitalThumbnail extends StatelessWidget {
  static const _assetPath = 'assets/mascot/hospital_placeholder.png';

  final double width;
  final double height;
  final double borderRadius;

  const HospitalThumbnail({
    super.key,
    this.width = 64,
    this.height = 64,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: AppColors.primarySoft,
        child: Image.asset(
          _assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.pets,
            size: width * 0.4,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}
