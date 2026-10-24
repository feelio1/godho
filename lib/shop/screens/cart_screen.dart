import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/inline_error_message.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../pricing.dart';
import '../providers/shop_providers.dart';
import 'checkout_screen.dart';

/// 장바구니 줄 하나 + 그 줄의 Firestore 문서 id("쇼핑 기초" 지시서 5-3) —
/// 수량 변경·삭제가 어느 장바구니 문서를 가리키는지 알아야 해서 [CartLine]
/// 에 문서 id만 더한 것. [summarizeCart]는 [CartLine]만 보고 계산하므로
/// 그대로 넘겨도 동작은 같다.
class _CartLineEntry extends CartLine {
  final String cartItemId;

  const _CartLineEntry({
    required this.cartItemId,
    required super.product,
    super.option,
    required super.quantity,
  });
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
        error: (error, _) => InlineErrorMessage(
          error: error,
          onRetry: () => ref.invalidate(_cartSummaryProvider),
        ),
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

class _SellerGroupCard extends ConsumerWidget {
  final SellerCartGroup group;

  const _SellerGroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.borderCard),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in group.lines) _CartLineTile(line: line as _CartLineEntry),
          const Divider(height: 20),
          Row(
            children: [
              const Text('배송비', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const Spacer(),
              Text(
                group.shippingFee > 0 ? '${NumberFormat('#,###').format(group.shippingFee)}원' : '무료',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                if (line.option != null) ...[
                  const SizedBox(height: 2),
                  Text(line.option!.name, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: uid == null ? null : () => repo.updateCartQuantity(uid, line.cartItemId, line.quantity - 1),
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                    ),
                    Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: uid == null ? null : () => repo.updateCartQuantity(uid, line.cartItemId, line.quantity + 1),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${NumberFormat('#,###').format(line.lineTotal)}원', style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: uid == null ? null : () => repo.removeFromCart(uid, line.cartItemId),
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textSecondary),
              ),
            ],
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
            Row(
              children: [
                const Text('총 결제금액', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${NumberFormat('#,###').format(summary.grandTotal)}원',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CheckoutScreen(lines: lines)),
                ),
                child: const Text('주문하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
