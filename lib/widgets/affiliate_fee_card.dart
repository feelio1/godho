import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 펫보험 제휴(CPA) 카드("출시 전 마무리" 지시서 A-1) — 아직 실제 제휴
/// 파트너·링크가 없어 탭하면 "준비 중" 안내만 한다(다른 준비 중 기능과
/// 같은 관례 — 없는 걸 있는 것처럼 보이지 않게). "제휴 링크" 라벨과
/// 수수료 고지를 항상 함께 두어, 이 카드가 시세 데이터와는 무관한
/// 별도 수익 구조임을 분명히 한다(CLAUDE.md: 병원에게 과금하지 않되,
/// 이용자 대상 제휴는 투명하게 고지).
class AffiliateFeeCard extends StatelessWidget {
  const AffiliateFeeCard({super.key});

  void _onTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('펫보험 제휴는 준비 중입니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => _onTap(context),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.card),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.borderCard),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceMutedLight,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Text(
                '제휴 링크',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '반려동물 보험 알아보기',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '이 링크로 가입하면 펫클이 수수료를 받을 수 있어요. 시세 데이터에는 영향이 없어요.',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.textPlaceholder),
          ],
        ),
      ),
    );
  }
}
