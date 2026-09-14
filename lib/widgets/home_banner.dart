import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 홈 상단 배너 — 장구름·나비(고양이) 캐릭터(home_banner.png) + 안내 문구
/// (스프린트 10 지시서 2). 실제 이미지가 없을 때는 조용히 문구만 남는다
/// (MascotImage와 같은 graceful fallback 패턴). 스프린트 13에서 아래에
/// 병원 리스트 섹션이 많이 늘어난 만큼, 배너 자체는 덜 차지하도록 줄였다.
class HomeBanner extends StatelessWidget {
  static const _assetPath = 'assets/mascot/home_banner.png';

  const HomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 60,
            child: Image.asset(
              _assetPath,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '동물병원 방문 전, 공개된 정보를 확인해보세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
