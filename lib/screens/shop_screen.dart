import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/global_banner_ad.dart';
import '../config/feature_flags.dart';
import '../shop/providers/shop_providers.dart';
import '../shop/screens/shop_home_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/external_links.dart';
import '../widgets/mascot_image.dart';

const _shopInquiryEmail = 'miyaongshop@gmail.com';

/// "쇼핑" 탭 — 이중 스위치로 연다("쇼핑 기초" 지시서 1). 컴파일 플래그
/// [kEnableShopCode]가 꺼져 있거나, 켜져 있어도 Firestore `config/shop`
/// 문서의 `enabled`가 true가 아니면("탭 개편" 지시서 C에서 만든) 준비 중
/// 화면 그대로를 보여준다 — 둘 다 켜져야만 실제 스토어 홈([ShopHomeScreen])
/// 으로 넘어간다. 기본값은 항상 닫힘이라, 지금처럼 `config/shop` 문서가
/// 없는 상태에선 사용자가 보는 화면에 아무 변화가 없다.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kEnableShopCode) return const _ShopComingSoon();

    final enabled = ref.watch(shopEnabledProvider).value ?? false;
    return enabled ? const ShopHomeScreen() : const _ShopComingSoon();
  }
}

/// 기존 "준비 중" 화면("탭 개편" 지시서 C) — 문구·구성 변경 없음.
class _ShopComingSoon extends StatelessWidget {
  const _ShopComingSoon();

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
