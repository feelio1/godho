import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/inline_error_message.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../pricing.dart';
import '../providers/shop_providers.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart' show QuantityStepper;

/// 장바구니 줄 하나 + 그 줄의 Firestore 문서 id("쇼핑 기초" 지시서 5-3) —
/// 수량 변경·삭제가 어느 장바구니 문서를 가리키는지 알아야 해서 [CartLine]
/// 에 문서 id만 더한 것. [summarizeCart]는 [CartLine]만 보고 계산하므로
/// 그대로 넘겨도 동작은 같다.
class _CartLineEntry extends CartLine {
  final String cartItemId;

  const _CartLineEntry({required this.cartItemId, required super.product, super.option, required super.quantity});
}

/// 장바구니 항목을 상품/옵션/판매자 정보까지 채워 [summarizeCart]로 계산한
/// 결과. 장바구니 자체(실시간 스트림)가 바뀌면 다시 계산된다.
final _cartSummaryProvider = FutureProvider.autoDispose<CartSummary>((ref) async {
  final cartAsync = ref.watch(cartProvider);
  final items = cartAsync.value ?? const <CartItem>[];
  if (items.isEmpty) return CartSummary.empty;

  final repo = ref.watch(shopRepositoryProvider);
  final lines = <_CartLineEntry>[];
  for (final item in items) {
    final product = await repo.fetchProduct(item.productId);
    if (product == null) continue;
    ProductOption? option;
    if (item.optionId != null) {
      for (final o in product.options) {
        if (o.id == item.optionId) {
          option = o;
          break;
        }
      }
    }
    lines.add(_CartLineEntry(cartItemId: item.id, product: product, option: option, quantity: item.quantity));
  }

  final sellerIds = lines.map((l) => l.product.sellerId).toSet();
  final sellersById = <String, Seller>{};
  for (final sellerId in sellerIds) {
    final seller = await repo.fetchSeller(sellerId);
    if (seller != null) sellersById[sellerId] = seller;
  }

  return summarizeCart(lines, sellersById: sellersById);
});

/// 장바구니 화면("쇼핑 기초" 지시서 5-3) — 판매자별로 묶어 보여주고, 품절·
/// 비공개 상품은 표시는 하되 구매 대상에서 빠진다([summarizeCart]가 이미
/// 걸러낸 결과만 받으므로 이 화면은 그 결과를 그대로 그리기만 한다).
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_cartSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('장바구니')),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineErrorMessage(error: error, onRetry: () => ref.invalidate(_cartSummaryProvider)),
        data: (summary) {
          if (summary.sellerGroups.isEmpty) {
            return const Center(
              child: Text('장바구니가 비어 있어요', style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    for (final group in summary.sellerGroups) _SellerGroupCard(group: group),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                      child: Text(
                        '상품은 공급업체에서 직접 보내요.',
                        style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              _CartFooter(summary: summary),
            ],
          );
        },
      ),
    );
  }
}

/// 판매자 묶음 카드("장바구니", 3차 업데이트 J-6) — 가게 아이콘 + 판매자 이름,
/// 상품 행들, 배송비 + 무료배송까지 남은 정도(네이비 막대 + 회색 담담한 문구).
/// 재촉하는 문구·강조 색은 쓰지 않는다.
class _SellerGroupCard extends ConsumerWidget {
  final SellerCartGroup group;

  const _SellerGroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(sellerProvider(group.sellerId)).value;
    final freeOver = seller?.shipping.freeOver;
    // 무료배송 판정은 따로 배송 상품을 뺀 일반 상품 소계만으로(CLAUDE.md).
    final standardSubtotal = group.lines.where((l) => !l.product.isBulky).fold<int>(0, (sum, l) => sum + l.lineTotal);
    final remaining = freeOver != null && group.standardFee > 0 ? freeOver - standardSubtotal : null;
    // 판매자 상호(아깽이상점) — 직판 고지와 같은 이름.
    final sellerName = seller?.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(AppSpacing.cardLarge),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.borderCard),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sellerName != null) ...[
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(sellerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
          ],
          for (var i = 0; i < group.lines.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.borderMuted),
            _CartLineTile(line: group.lines[i] as _CartLineEntry),
          ],
          const Divider(height: 24, color: AppColors.borderMuted),
          Row(
            children: [
              const Text('배송비', style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary)),
              const Spacer(),
              Text(
                group.shippingFee > 0 ? '${NumberFormat('#,###').format(group.shippingFee)}원' : '무료',
                style: AppTextStyles.mono(size: 15, weight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          if (remaining != null && remaining > 0 && freeOver! > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (standardSubtotal / freeOver).clamp(0.0, 1.0),
                minHeight: 6,
                color: AppColors.primary,
                backgroundColor: AppColors.primarySoft,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${NumberFormat('#,###').format(remaining)}원 더 담으면 배송비가 무료예요',
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ],
          if (group.bulkyFee > 0) ...[
            const SizedBox(height: 6),
            Text(
              '따로 배송 상품 ${group.bulkyKinds}종 배송비 ${NumberFormat('#,###').format(group.bulkyFee)}원 포함',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          if (seller != null && seller.shipping.extraJejuFee > 0) ...[
            const SizedBox(height: 6),
            Text(
              '제주·도서산간은 추가 배송비 ${NumberFormat('#,###').format(seller.shipping.extraJejuFee)}원이 있어요.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  final _CartLineEntry line;

  const _CartLineTile({required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final repo = ref.watch(shopRepositoryProvider);
    final image = line.product.images.isNotEmpty ? line.product.images.first : null;
    Widget placeholder() => Container(
      color: AppColors.surfaceMutedLight,
      alignment: Alignment.center,
      child: const Icon(Icons.pets, color: AppColors.textPlaceholder),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 76,
              height: 76,
              child: image == null
                  ? placeholder()
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => placeholder(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          line.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        tooltip: '빼기',
                        onPressed: uid == null ? null : () => repo.removeFromCart(uid, line.cartItemId),
                        icon: const Icon(Icons.close, size: 22, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (line.option != null)
                  Text(
                    line.option!.name.replaceAll(' / ', ' · '),
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    QuantityStepper(
                      quantity: line.quantity,
                      // 최소 주문 수량 아래로는 줄이지 않는다(빼려면 × 버튼).
                      onDecrease: uid == null || line.quantity <= line.product.minQty
                          ? null
                          : () => repo.updateCartQuantity(uid, line.cartItemId, line.quantity - 1),
                      onIncrease: uid == null
                          ? null
                          : () => repo.updateCartQuantity(uid, line.cartItemId, line.quantity + 1),
                    ),
                    const Spacer(),
                    Text(
                      '${NumberFormat('#,###').format(line.lineTotal)}원',
                      style: AppTextStyles.mono(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                if (line.quantity < line.product.minQty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${line.product.minQty}개부터 주문할 수 있어요',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  final CartSummary summary;

  const _CartFooter({required this.summary});

  @override
  Widget build(BuildContext context) {
    final lines = summary.sellerGroups.expand((g) => g.lines).toList();
    Widget row(String label, int won) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            '${NumberFormat('#,###').format(won)}원',
            style: AppTextStyles.mono(size: 14.5, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 14),
        decoration: const BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border(top: BorderSide(color: AppColors.borderCard)),
        ),
        child: Column(
          children: [
            row('상품 합계', summary.itemsTotal),
            row('배송비', summary.shippingTotal),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('총 결제금액', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${NumberFormat('#,###').format(summary.grandTotal)}원',
                  style: AppTextStyles.mono(size: 22, weight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckoutScreen(lines: lines))),
                child: const Text('주문하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
