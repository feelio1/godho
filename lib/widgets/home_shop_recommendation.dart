import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/pet.dart';
import '../providers/auth_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../providers/nav_provider.dart';
import '../shop/models/product.dart';
import '../shop/providers/shop_providers.dart';
import '../shop/recommend.dart';
import '../shop/screens/product_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// 홈의 "쇼핑 추천" 섹션("방향 개편" 지시서 B-6) — 쇼핑이 꺼져 있거나
/// 판매 중(active) 상품이 하나도 없으면 아무것도 그리지 않는다(빈 칸·
/// 준비 중 문구도 없음 — CLAUDE.md처럼 "없는 기능을 있는 것처럼" 보여주지
/// 않는다). 로그인 + 반려동물이 있으면 기존 [filterRecommendedProducts]
/// (종·체중·생애주기만 — 진료기록 참조 금지)로 거른 결과를 먼저 쓰고,
/// 맞는 상품이 없으면 일반 판매 중 상품으로 채운다. 과장 배지는 쓰지
/// 않는다.
final homeShopPreviewProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  return (await ref.watch(homeShopPreviewWithBasisProvider.future)).products;
});

/// 홈 추천 상품 + (실제로 프로필로 골랐을 때만) 그 근거 프로필 문구와
/// 반려동물 이름.
final homeShopPreviewWithBasisProvider =
    FutureProvider.autoDispose<({List<Product> products, String? basis, String? petName})>((ref) async {
      final page = await ref.watch(productsProvider.future);
      final active = page.products.where((p) => p.status == ProductStatus.active).toList();
      if (active.isEmpty) return (products: const <Product>[], basis: null, petName: null);

      final uid = ref.watch(authStateProvider).value?.uid;
      final pets = uid == null ? const <Pet>[] : await ref.watch(effectivePetsProvider.future);
      final basis = recommendationBasisLabel(active, pets);
      return (
        products: selectHomeShopPreview(activeProducts: active, pets: pets),
        basis: basis,
        petName: basis != null && pets.length == 1 ? pets.first.name : null,
      );
    });

/// "장구름의 수첩"(3차 업데이트 J-2): 제목 옆 회색 "판매" 표시, 3열 정사각
/// 사진(반지름 16) + 이름 + 굵은 가격, 아래 추천 근거 한 줄(실제로 프로필로
/// 골랐을 때만) + 판매자 안내.
class HomeShopRecommendation extends ConsumerWidget {
  const HomeShopRecommendation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopEnabled = ref.watch(shopEnabledProvider).value ?? false;
    if (!shopEnabled) return const SizedBox.shrink();

    final preview = ref.watch(homeShopPreviewWithBasisProvider).value;
    final products = (preview?.products ?? const <Product>[]).take(3).toList();
    if (products.isEmpty) return const SizedBox.shrink();
    final basis = preview?.basis;
    final title = preview?.petName != null ? '${preview!.petName}에게 맞는 용품' : '펫클 쇼핑';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.closedBg, borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      '판매',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => ref.read(selectedTabProvider.notifier).state = AppTab.shop.index,
              child: const Text('전체 보기'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: i < products.length ? _HomeShopProductCard(product: products[i]) : const SizedBox()),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          basis != null ? '$basis 프로필만 보고 골랐어요. 판매자는 아깽이상점이에요.' : '판매자는 아깽이상점이에요.',
          style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _HomeShopProductCard extends StatelessWidget {
  final Product product;

  const _HomeShopProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      color: AppColors.surfaceMutedLight,
      alignment: Alignment.center,
      child: const Icon(Icons.pets, color: AppColors.textPlaceholder, size: 28),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.panel),
              child: product.images.isEmpty
                  ? placeholder()
                  : Image.network(
                      product.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => placeholder(),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat('#,###').format(product.displayPrice)}원',
            style: AppTextStyles.mono(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
