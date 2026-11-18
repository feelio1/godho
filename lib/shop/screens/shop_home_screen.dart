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
        toolbarHeight: 68,
        title: const Text('쇼핑', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: '장바구니',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.backgroundLight, width: 1.5),
                    ),
                    child: Text(
                      cartCount > 99 ? '99+' : '$cartCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        children: [
          const _ShippingStrip(),
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
              error: (error, _) => InlineErrorMessage(error: error, onRetry: () => ref.invalidate(productsProvider)),
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
                        const spacing = 16.0;
                        final cardWidth = (constraints.maxWidth - spacing) / 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: page.products.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: spacing,
                            crossAxisSpacing: spacing,
                            mainAxisExtent:
                                cardWidth +
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
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.section, AppSpacing.page, 0),
            child: Text(
              '판매자는 아깽이상점이고, 상품은 공급업체에서 직접 보내요.',
              style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
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
    // 카테고리 알약 탭 — 선택 = 네이비 채움(흰 글자), 안 선택 = 흰 바탕.
    return SizedBox(
      key: const ValueKey('shop_category_chips'),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: categories.length + 1,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = i == 0 ? null : categories[i - 1];
          final isSelected = selected == category;
          return Semantics(
            selected: isSelected,
            button: true,
            child: Material(
              color: isSelected ? AppColors.primary : AppColors.surfaceLight,
              shape: StadiumBorder(side: BorderSide(color: isSelected ? AppColors.primary : AppColors.borderCard)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => ref.read(shopCategoryFilterProvider.notifier).state = category,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Center(
                    child: Text(
                      category?.label ?? '전체',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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

/// 상품 카드("장구름의 수첩", 3차 업데이트 J-6) — 테두리 없이 정사각 사진
/// (반지름 20) + 이름 14sp + 가격 17sp 굵게 + 옵션 수(회색). 정가 취소선·
/// 할인율 연출은 하지 않는다(price만, CLAUDE.md).
class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  static const _nameGap = 4.0;
  static const _priceGap = 2.0;
  static const _nameStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary);
  static const _priceStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const _optionStyle = TextStyle(fontSize: 13, color: AppColors.textSecondary);

  /// 옵션 수 안내 — 옵션 이름이 "색 / 사이즈" 꼴이면 "색상·사이즈 N가지".
  static String? optionLabel(Product product) {
    final count = product.options.length;
    if (count < 2) return null;
    final paired = product.options.every((o) => o.name.contains('/'));
    return paired ? '색상·사이즈 $count가지' : '옵션 $count가지';
  }

  /// 이미지 아래 글자 영역 높이 — 상품명 2줄 + 가격 1줄 + 옵션 1줄 + 여백을
  /// 실제 글꼴·글자 크기 설정으로 재서 정한다(카드 높이를 이 값으로 고정하므로
  /// 어떤 폭·글꼴에서도 넘치지 않는다).
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

    return 10 + lines(_nameStyle, 2) + _nameGap + lines(_priceStyle, 1) + _priceGap + lines(_optionStyle, 1) + 4;
  }

  @override
  Widget build(BuildContext context) {
    final soldOut = product.status == ProductStatus.soldout;
    final options = optionLabel(product);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
                        decoration: BoxDecoration(
                          color: AppColors.closedBg,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          '품절',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.closedText),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _nameStyle),
          const SizedBox(height: _nameGap),
          Text('${NumberFormat('#,###').format(product.displayPrice)}원', style: _priceStyle),
          if (options != null) ...[
            const SizedBox(height: _priceGap),
            Text(options, maxLines: 1, overflow: TextOverflow.ellipsis, style: _optionStyle),
          ],
        ],
      ),
    );
  }
}

/// 배송 안내 띠 — 판매자 배송 정책 그대로("3만 원 이상 무료배송, 그 아래는
/// 3,000원"). 판매자 정보를 못 읽으면 그리지 않는다.
class _ShippingStrip extends ConsumerWidget {
  const _ShippingStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 직판형이라 판매자는 한 곳 — 목록의 상품이 가리키는 판매자의 정책을 쓴다.
    final sellerId = ref.watch(productsProvider).value?.products.firstOrNull?.sellerId;
    if (sellerId == null) return const SizedBox.shrink();
    final seller = ref.watch(sellerProvider(sellerId)).value;
    if (seller == null) return const SizedBox.shrink();
    final policy = seller.shipping;
    final fee = '${NumberFormat('#,###').format(policy.baseFee)}원';
    final freeOver = policy.freeOver;
    final text = freeOver == null ? '배송비 $fee' : '${_wonShort(freeOver)} 이상 무료배송, 그 아래는 $fee';
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.panel)),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _wonShort(int won) => won % 10000 == 0 ? '${won ~/ 10000}만 원' : '${NumberFormat('#,###').format(won)}원';
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
