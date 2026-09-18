import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 병원 카드 아바타 — 건물 아이콘 + 틴트 배경(스프린트 14, Petcli 시안).
/// 실제 병원 사진 데이터는 없으므로(크롤링 금지, CLAUDE.md·스프린트 10
/// 지시서) 모든 병원이 항상 같은 아이콘을 쓴다 — 어떤 병원이 더 낫다는
/// 인상을 주지 않는다. 스프린트 10~13의 사진 placeholder(hospital_
/// placeholder.png) 자리를 대체한다.
class HospitalAvatar extends StatelessWidget {
  final double size;
  final double radius;

  const HospitalAvatar({super.key, this.size = 56, this.radius = AppRadius.avatar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.apartment_outlined,
        size: size * 0.48,
        color: AppColors.primary,
      ),
    );
  }
}
