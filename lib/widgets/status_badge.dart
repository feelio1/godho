import 'package:flutter/material.dart';

import '../models/hospital_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 상태 pill — 영업중은 그린 점+텍스트, 폐업·정보부족은 회색(빨강 금지,
/// CLAUDE.md 평가 금지 원칙). Petcli 시안 스펙의 정확한 bg/text/dot 색을
/// 그대로 쓴다(알파 블렌딩이 아니라 지정된 고정 색).
class StatusBadge extends StatelessWidget {
  final HospitalStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.forStatusText(status);
    final bgColor = AppColors.forStatusBg(status);
    final dotColor = AppColors.forStatusDot(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
