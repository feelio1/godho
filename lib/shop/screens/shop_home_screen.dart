import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ads/global_banner_ad.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/inline_error_message.dart';
import '../models/product.dart';
import '../providers/shop_providers.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

/// 스토어 홈 — 카테고리 칩, "우리 아이에게 맞는" 추천(조건 충족 시),
/// 전체 상품 그리드("쇼핑 기초" 지시서 5-1). [ShopScreen]이 런타임
/// 스위치가 켜졌을 때만 이 화면을 보여준다.
class ShopHomeScreen extends ConsumerWidget {
  const ShopHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final recommendedAsync = ref.watch(recommendedProductsProvider);
    final cartCount = ref.watch(cartItemCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('쇼핑'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: '장바구니',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(
                      cartCount > 99 ? '99+' : '$cartCount',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const _CategoryChips(),
          recommendedAsync.maybeWhen(
            data: (products) => products.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _RecommendedSection(products: products),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.section),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: productsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => InlineErrorMessage(
                error: error,
                onRetry: () => ref.invalidate(productsProvider),
              ),
              data: (page) => page.products.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('아직 등록된 상품이 없어요', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: page.products.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, index) => _ProductCard(product: page.products[index]),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          const GlobalBannerAd(inline: true),
        ],
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(shopCategoryFilterProvider);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: ProductCategory.values.length + 1,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = i == 0 ? null : ProductCategory.values[i - 1];
          return ChoiceChip(
            label: Text(category?.label ?? '전체'),
            selected: selected == category,
            onSelected: (_) => ref.read(shopCategoryFilterProvider.notifier).state = category,
          );
        },
      ),
    );
  }
}

class _RecommendedSection extends StatelessWidget {
  final List<Product> products;

  const _RecommendedSection({required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 10),
          child: Text('우리 아이에게 맞는', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            itemCount: products.length,
            separatorBuilder: (context, i) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(width: 150, child: _ProductCard(product: products[i])),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final soldOut = product.status == ProductStatus.soldout;
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
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ProductImage(url: product.images.isNotEmpty ? product.images.first : null),
                  if (soldOut)
                    Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.closedBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: const Text('품절', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.closedText)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  if (product.isOnSale) ...[
                    Text(
                      '${NumberFormat('#,###').format(product.price)}원',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textPlaceholder, decoration: TextDecoration.lineThrough),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    '${NumberFormat('#,###').format(product.displayPrice)}원',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? url;

  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        color: AppColors.surfaceMutedLight,
        alignment: Alignment.center,
        child: const Icon(Icons.pets, color: AppColors.textPlaceholder, size: 32),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.surfaceMutedLight,
        alignment: Alignment.center,
        child: const Icon(Icons.pets, color: AppColors.textPlaceholder, size: 32),
      ),
    );
  }
}
