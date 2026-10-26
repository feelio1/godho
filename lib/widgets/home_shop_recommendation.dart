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

/// 홈의 "쇼핑 추천" 섹션("방향 개편" 지시서 B-6) — 쇼핑이 꺼져 있거나
/// 판매 중(active) 상품이 하나도 없으면 아무것도 그리지 않는다(빈 칸·
/// 준비 중 문구도 없음 — CLAUDE.md처럼 "없는 기능을 있는 것처럼" 보여주지
/// 않는다). 로그인 + 반려동물이 있으면 기존 [filterRecommendedProducts]
/// (종·체중·생애주기만 — 진료기록 참조 금지)로 거른 결과를 먼저 쓰고,
/// 맞는 상품이 없으면 일반 판매 중 상품으로 채운다. 과장 배지는 쓰지
/// 않는다.
final homeShopPreviewProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final page = await ref.watch(productsProvider.future);
  final active = page.products.where((p) => p.status == ProductStatus.active).toList();
  if (active.isEmpty) return const [];

  final uid = ref.watch(authStateProvider).value?.uid;
  final pets = uid == null ? const <Pet>[] : await ref.watch(effectivePetsProvider.future);
  return selectHomeShopPreview(activeProducts: active, pets: pets);
});

class HomeShopRecommendation extends ConsumerWidget {
  const HomeShopRecommendation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopEnabled = ref.watch(shopEnabledProvider).value ?? false;
    if (!shopEnabled) return const SizedBox.shrink();

    final previewAsync = ref.watch(homeShopPreviewProvider);
    final products = previewAsync.value ?? const [];
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('펫클 쇼핑', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: () => ref.read(selectedTabProvider.notifier).state = AppTab.shop.index,
              child: const Text('전체 보기'),
            ),
          ],
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, i) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(width: 128, child: _HomeShopProductCard(product: products[i])),
          ),
        ),
      ],
    );
  }
}

class _HomeShopProductCard extends ConsumerWidget {
  final Product product;

  const _HomeShopProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(sellerProvider(product.sellerId)).value;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.borderCard),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              width: double.infinity,
              child: product.images.isEmpty
                  ? Container(
                      color: AppColors.surfaceMutedLight,
                      alignment: Alignment.center,
                      child: const Icon(Icons.pets, color: AppColors.textPlaceholder, size: 28),
                    )
                  : Image.network(
                      product.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.surfaceMutedLight,
                        alignment: Alignment.center,
                        child: const Icon(Icons.pets, color: AppColors.textPlaceholder, size: 28),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${NumberFormat('#,###').format(product.displayPrice)}원',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  if (seller != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '판매 ${seller.brandName.isNotEmpty ? seller.brandName : seller.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
