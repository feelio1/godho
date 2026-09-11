import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 홈 상단 배너 — 장구름·나비(고양이) 캐릭터(home_banner.png) + 안내 문구
/// (스프린트 10 지시서 2). 실제 이미지가 없을 때는 조용히 문구만 남는다
/// (MascotImage와 같은 graceful fallback 패턴).
class HomeBanner extends StatelessWidget {
  static const _assetPath = 'assets/mascot/home_banner.png';

  const HomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            height: 80,
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
              '동물병원 방문 전,\n공개된 정보를 확인해보세요.',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
