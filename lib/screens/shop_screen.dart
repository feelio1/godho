import 'package:flutter/material.dart';

import '../ads/global_banner_ad.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/external_links.dart';
import '../widgets/mascot_image.dart';

const _shopInquiryEmail = 'miyaongshop@gmail.com';

/// "쇼핑" 탭("탭 개편" 지시서 C) — 지금은 준비 중 화면만 보여준다. 게스트·
/// 회원 모두 게이팅 없이 볼 수 있고, 가짜 상품·가격·사전 예약 같은 미끼
/// 요소나 오픈 알림 신청 같은 데이터 수집은 넣지 않는다. 나중에 실제
/// 스토어 화면으로 바꿀 때 이 파일 하나만 교체하면 되게 분리해뒀다.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('쇼핑')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.warmBackground,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MascotImage(size: 72),
                const SizedBox(height: 20),
                const Text(
                  '펫클 쇼핑, 곧 열려요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  '펫클이 직접 고른 반려용품과 간식을 준비하고 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () => ExternalLinks.emailContact(
                    context,
                    _shopInquiryEmail,
                    subject: '[펫클 쇼핑] 입점 문의',
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      '브랜드 입점 문의',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          const GlobalBannerAd(inline: true),
        ],
      ),
    );
  }
}
