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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // 카드 높이 = 카드 폭(정사각 이미지) + 글자 영역 — 비율로
                        // 정하면 좁은 폭에서 글자 영역이 모자라 넘친다.
                        const spacing = 14.0;
                        final cardWidth = (constraints.maxWidth - spacing) / 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: page.products.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: spacing,
                            crossAxisSpacing: spacing,
                            mainAxisExtent: cardWidth +
                                _ProductCard.textAreaHeight(
                                  context,
                                  withStrikePrice: page.products.any((p) => p.isOnSale),
                                ),
                          ),
                          itemBuilder: (context, index) => _ProductCard(product: page.products[index]),
                        );
                      },
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
    // 상품이 있는 카테고리만(불러오는 중·실패 땐 "전체"만). 지금 고른
    // 카테고리는 상품이 사라져도 칩을 남겨 선택을 풀 수 있게 한다.
    final available = ref.watch(availableShopCategoriesProvider).value ?? const <ProductCategory>{};
    final categories = visibleShopCategories({...available, ?selected});
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: categories.length + 1,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = i == 0 ? null : categories[i - 1];
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
          height: 150 + _ProductCard.textAreaHeight(context, withStrikePrice: products.any((p) => p.isOnSale)),
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

  static const _textPadding = 10.0;
  static const _nameGap = 6.0;
  static const _strikeGap = 2.0;
  static const _nameStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const _priceStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
  static const _strikeStyle =
      TextStyle(fontSize: 11.5, color: AppColors.textPlaceholder, decoration: TextDecoration.lineThrough);

  /// 이미지 아래 글자 영역 높이 — 상품명 2줄 + 가격 1줄(+ 할인 전 가격 줄) +
  /// 여백을 실제 글꼴·글자 크기 설정으로 재서 정한다(카드 높이를 이 값으로
  /// 고정하므로 어떤 폭·글꼴에서도 넘치지 않는다).
  static double textAreaHeight(BuildContext context, {bool withStrikePrice = false}) {
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double lines(TextStyle style, int count) {
      final painter = TextPainter(
        text: TextSpan(text: List.filled(count, '가g').join('\n'), style: base.merge(style)),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    return _textPadding * 2 +
        lines(_nameStyle, 2) +
        _nameGap +
        (withStrikePrice ? lines(_strikeStyle, 1) + _strikeGap : 0) +
        lines(_priceStyle, 1) +
        // 테두리(위·아래 1px)와 반올림 여유.
        4;
  }

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
              padding: const EdgeInsets.all(_textPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _nameStyle,
                  ),
                  const SizedBox(height: _nameGap),
                  if (product.isOnSale) ...[
                    Text(
                      '${NumberFormat('#,###').format(product.price)}원',
                      style: _strikeStyle,
                    ),
                    const SizedBox(height: _strikeGap),
                  ],
                  Text(
                    '${NumberFormat('#,###').format(product.displayPrice)}원',
                    style: _priceStyle,
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
