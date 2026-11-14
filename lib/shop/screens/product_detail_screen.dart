import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/guest_gate.dart';
import '../../widgets/inline_error_message.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../pricing.dart';
import '../providers/shop_providers.dart';
import 'checkout_screen.dart';

const String _directSaleNotice =
    '이 상품의 판매자는 아깽이상점입니다. 상품은 공급업체에서 직접 발송되며, 주문·교환·반품 문의는 아깽이상점 고객센터로 접수해 주세요.';

/// 상품 상세("쇼핑 기초" 지시서 5-2) — 이미지·가격·옵션·수량, 설명/상품정보
/// 제공고시/배송·반품 안내/판매자 정보를 접이식으로, 하단에 직판 고지(판매자
/// = 아깽이상점, 공급업체가 직접 발송)를 고정 표시한다. 상품 보기는 게스트도 할 수 있고, 장바구니/바로구매부터
/// 로그인이 필요하다(CLAUDE.md 게이팅 — 보기는 열어두고 쓰기만 막는다).
class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productProvider(productId));
    return Scaffold(
      appBar: AppBar(title: const Text('상품')),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineErrorMessage(
          error: error,
          onRetry: () => ref.invalidate(productProvider(productId)),
        ),
        data: (product) =>
            product == null ? const Center(child: Text('상품을 찾을 수 없어요')) : _ProductDetailBody(product: product),
      ),
    );
  }
}

class _ProductDetailBody extends ConsumerStatefulWidget {
  final Product product;

  const _ProductDetailBody({required this.product});

  @override
  ConsumerState<_ProductDetailBody> createState() => _ProductDetailBodyState();
}

class _ProductDetailBodyState extends ConsumerState<_ProductDetailBody> {
  ProductOption? _selectedOption;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    // 최소 주문 수량부터 시작하고, 그 아래로는 줄일 수 없다.
    _quantity = widget.product.minQty;
    final options = widget.product.options;
    if (options.isNotEmpty) {
      _selectedOption = options.firstWhere((o) => !o.soldOut, orElse: () => options.first);
    }
  }

  int get _unitPrice => widget.product.displayPrice + (_selectedOption?.extraPrice ?? 0);

  bool get _canBuy =>
      widget.product.isPurchasable && (widget.product.options.isEmpty || (_selectedOption != null && !_selectedOption!.soldOut));

  Future<void> _addToCart() async {
    final uid = await _ensureLoggedIn('로그인하면 장바구니에 담을 수 있어요');
    if (uid == null || !mounted) return;
    await ref.read(shopRepositoryProvider).addToCart(
          uid,
          productId: widget.product.id,
          optionId: _selectedOption?.id,
          quantity: _quantity,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('장바구니에 담았어요')));
  }

  Future<void> _buyNow() async {
    final uid = await _ensureLoggedIn('로그인하면 바로 구매할 수 있어요');
    if (uid == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          lines: [CartLine(product: widget.product, option: _selectedOption, quantity: _quantity)],
        ),
      ),
    );
  }

  Future<String?> _ensureLoggedIn(String message) async {
    final ok = await requireLogin(context, ref, message: message);
    if (!ok || !mounted) return null;
    return ref.read(authStateProvider).value?.uid;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final sellerAsync = ref.watch(sellerProvider(product.sellerId));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _ImageCarousel(images: product.images),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (product.isOnSale)
                      Text(
                        '${NumberFormat('#,###').format(product.price)}원',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPlaceholder, decoration: TextDecoration.lineThrough),
                      ),
                    Text(
                      '${NumberFormat('#,###').format(product.displayPrice)}원',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    ..._purchaseNotes(product, sellerAsync.value),
                    if (product.status == ProductStatus.soldout) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.closedBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: const Text('품절', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.closedText)),
                      ),
                    ],
                    if (product.options.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text('옵션', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: product.options
                            .map((o) => ChoiceChip(
                                  label: Text(o.soldOut ? '${o.name} (품절)' : (o.extraPrice > 0 ? '${o.name} (+${NumberFormat('#,###').format(o.extraPrice)}원)' : o.name)),
                                  selected: _selectedOption?.id == o.id,
                                  onSelected: o.soldOut ? null : (_) => setState(() => _selectedOption = o),
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text('수량', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > product.minQty ? () => setState(() => _quantity--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_quantity', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        IconButton(
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        const Spacer(),
                        Text(
                          '${NumberFormat('#,###').format(_unitPrice * _quantity)}원',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ExpansionTile(
                title: const Text('상품 설명'),
                initiallyExpanded: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 16),
                    child: Text(
                      product.description.isEmpty ? '등록된 설명이 없어요' : product.description,
                      style: const TextStyle(height: 1.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              if (product.notice.isNotEmpty)
                ExpansionTile(
                  title: const Text('상품정보제공고시'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 16),
                      child: _NoticeTable(entries: product.orderedNotice),
                    ),
                  ],
                ),
              sellerAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, _) => const SizedBox.shrink(),
                data: (seller) => seller == null
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          ExpansionTile(
                            title: const Text('배송·교환·반품 안내'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 16),
                                child: _ShippingReturnInfo(seller: seller),
                              ),
                            ],
                          ),
                          ExpansionTile(
                            title: const Text('판매자 정보'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 16),
                                child: _SellerInfo(seller: seller),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.all(AppSpacing.page),
                child: Text(_directSaleNotice, style: TextStyle(fontSize: 11.5, color: AppColors.textPlaceholder, height: 1.5)),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _canBuy ? _addToCart : null,
                    child: const Text('장바구니'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _canBuy ? _buyNow : null,
                    child: const Text('바로 구매'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 가격 아래 회색 정보 — 따로 배송·최소 수량·판매 종료 예정(해당할 때만).
  /// 압박 문구·빨강/주황은 쓰지 않는다.
  List<Widget> _purchaseNotes(Product product, Seller? seller) {
    final notes = <String>[
      if (product.isBulky)
        seller != null && seller.shipping.bulkyFee > 0
            ? '다른 상품과 따로 배송돼요 · 배송비 ${NumberFormat('#,###').format(seller.shipping.bulkyFee)}원'
            : '다른 상품과 따로 배송돼요',
      if (product.minQty > 1) '${product.minQty}개부터 주문할 수 있어요',
    ];
    return [
      for (final note in notes) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(child: Text(note, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
          ],
        ),
      ],
      if (product.isDiscontinuing) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: const Text('재고 소진 시 판매 종료', style: TextStyle(fontSize: 12, color: AppColors.neutral)),
        ),
      ],
    ];
  }
}

/// 상품정보제공고시 — 키가 길어("법에 의한 인증·허가 사항" 등) 좁은 폭에서
/// 라벨이 세로로 쪼개지지 않도록, 넓을 때만 라벨·값 2칸, 좁으면 라벨 위·값
/// 아래 2줄로 놓는다. 값이 "확인 필요"여도 숨기지 않는다.
class _NoticeTable extends StatelessWidget {
  /// 표시 순서대로 정렬된 고시 항목([Product.orderedNotice]).
  final List<MapEntry<String, String>> entries;

  const _NoticeTable({required this.entries});

  static const _labelStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5);
  static const _valueStyle = TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 420;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 150, child: Text(e.key, style: _labelStyle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.value, style: _valueStyle)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key, style: _labelStyle),
                          const SizedBox(height: 2),
                          Text(e.value, style: _valueStyle),
                        ],
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _ImageCarousel extends StatelessWidget {
  final List<String> images;

  const _ImageCarousel({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        height: 280,
        color: AppColors.surfaceMutedLight,
        alignment: Alignment.center,
        child: const Icon(Icons.pets, size: 48, color: AppColors.textPlaceholder),
      );
    }
    return SizedBox(
      height: 280,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, i) => Image.network(
          images[i],
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.surfaceMutedLight,
            alignment: Alignment.center,
            child: const Icon(Icons.pets, size: 48, color: AppColors.textPlaceholder),
          ),
        ),
      ),
    );
  }
}

class _ShippingReturnInfo extends StatelessWidget {
  final Seller seller;

  const _ShippingReturnInfo({required this.seller});

  @override
  Widget build(BuildContext context) {
    final shipping = seller.shipping;
    final returnPolicy = seller.returnPolicy;
    final rows = <String>[
      '배송비: ${NumberFormat('#,###').format(shipping.baseFee)}원'
          '${shipping.freeOver != null ? ' (${NumberFormat('#,###').format(shipping.freeOver)}원 이상 무료)' : ''}',
      if (shipping.bulkyFee > 0)
        '따로 배송 상품(배변판·켄넬 등) 배송비: 상품 1종마다 ${NumberFormat('#,###').format(shipping.bulkyFee)}원 (무료배송과 별도)',
      if (shipping.extraJejuFee > 0) '제주/도서 추가 배송비: ${NumberFormat('#,###').format(shipping.extraJejuFee)}원',
      if (shipping.carrier != null && shipping.carrier!.isNotEmpty) '택배사: ${shipping.carrier}',
      '발송 소요: ${shipping.dispatchDays}일 이내',
      '교환/반품 배송비: 교환 ${NumberFormat('#,###').format(returnPolicy.exchangeFee)}원 · 반품 ${NumberFormat('#,###').format(returnPolicy.returnFee)}원',
      if (returnPolicy.returnAddress.isNotEmpty) '반품 주소: ${returnPolicy.returnAddress}',
      if (returnPolicy.note.isNotEmpty) returnPolicy.note,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(r, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
              ))
          .toList(),
    );
  }
}

class _SellerInfo extends StatelessWidget {
  final Seller seller;

  const _SellerInfo({required this.seller});

  @override
  Widget build(BuildContext context) {
    final rows = <String>[
      if (seller.brandName.isNotEmpty) '브랜드: ${seller.brandName}',
      '상호: ${seller.name}',
      if (seller.ceoName.isNotEmpty) '대표자: ${seller.ceoName}',
      if (seller.bizRegNo.isNotEmpty) '사업자등록번호: ${seller.bizRegNo}',
      if (seller.mailOrderNo.isNotEmpty) '통신판매업 신고번호: ${seller.mailOrderNo}',
      if (seller.address.isNotEmpty) '주소: ${seller.address}',
      if (seller.csPhone.isNotEmpty) '고객센터: ${seller.csPhone}',
      if (seller.csEmail.isNotEmpty) '이메일: ${seller.csEmail}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(r, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
              ))
          .toList(),
    );
  }
}
