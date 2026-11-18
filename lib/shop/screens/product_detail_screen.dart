import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/guest_gate.dart';
import '../../widgets/inline_error_message.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../option_split.dart';
import '../pricing.dart';
import '../providers/shop_providers.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';

const String _directSaleNotice = '이 상품의 판매자는 아깽이상점입니다. 상품은 공급업체에서 직접 발송되며, 주문·교환·반품 문의는 아깽이상점 고객센터로 접수해 주세요.';

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
    // "장구름의 수첩"(3차 업데이트 J-6): 정사각 큰 사진 위에 뒤로·장바구니 흰
    // 동그라미 버튼을 겹친다.
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _CircleButton(
                  icon: Icons.arrow_back,
                  tooltip: '뒤로',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CircleButton(
              icon: Icons.shopping_cart_outlined,
              tooltip: '장바구니',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
            ),
          ),
        ],
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            InlineErrorMessage(error: error, onRetry: () => ref.invalidate(productProvider(productId))),
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
      widget.product.isPurchasable &&
      (widget.product.options.isEmpty || (_selectedOption != null && !_selectedOption!.soldOut));

  Future<void> _addToCart() async {
    final uid = await _ensureLoggedIn('로그인하면 장바구니에 담을 수 있어요');
    if (uid == null || !mounted) return;
    await ref
        .read(shopRepositoryProvider)
        .addToCart(uid, productId: widget.product.id, optionId: _selectedOption?.id, quantity: _quantity);
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
                    Text(
                      product.name,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${NumberFormat('#,###').format(product.displayPrice)}원',
                      style: AppTextStyles.mono(size: 30, weight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (sellerAsync.value != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _shippingLine(sellerAsync.value!),
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                    ..._purchaseNotes(product, sellerAsync.value),
                    if (product.status == ProductStatus.soldout) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.closedBg,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          '품절',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.closedText),
                        ),
                      ),
                    ],
                    if (product.options.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _OptionPicker(
                        product: product,
                        selected: _selectedOption,
                        onSelect: (o) => setState(() => _selectedOption = o),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('수량', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        QuantityStepper(
                          quantity: _quantity,
                          onDecrease: _quantity > product.minQty ? () => setState(() => _quantity--) : null,
                          onIncrease: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '합계 ${NumberFormat('#,###').format(_unitPrice * _quantity)}원',
                        style: AppTextStyles.mono(size: 15, weight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Column(
                      children: [
                        ExpansionTile(
                          title: const Text('상품 설명', style: _tileTitle),
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
                        if (product.notice.isNotEmpty) ...[
                          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderMuted),
                          ExpansionTile(
                            title: const Text('상품정보제공고시', style: _tileTitle),
                            subtitle: const Text(
                              '소재·제조국·치수 등',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 16),
                                child: _NoticeTable(entries: product.orderedNotice),
                              ),
                            ],
                          ),
                        ],
                        ...switch (sellerAsync.value) {
                          null => const <Widget>[],
                          final seller => [
                            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderMuted),
                            ExpansionTile(
                              title: const Text('배송·교환·반품 안내', style: _tileTitle),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 16),
                                  child: _ShippingReturnInfo(seller: seller),
                                ),
                              ],
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderMuted),
                            ExpansionTile(
                              title: const Text('판매자 정보', style: _tileTitle),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 16),
                                  child: _SellerInfo(seller: seller),
                                ),
                              ],
                            ),
                          ],
                        },
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(AppSpacing.page),
                child: Text(
                  _directSaleNotice,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
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
                  child: OutlinedButton(onPressed: _canBuy ? _addToCart : null, child: const Text('장바구니')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(onPressed: _canBuy ? _buyNow : null, child: const Text('바로 구매')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const _tileTitle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

  static String _shippingLine(Seller seller) {
    final policy = seller.shipping;
    final fee = '배송비 ${NumberFormat('#,###').format(policy.baseFee)}원';
    final freeOver = policy.freeOver;
    if (freeOver == null) return fee;
    final over = freeOver % 10000 == 0 ? '${freeOver ~/ 10000}만 원' : '${NumberFormat('#,###').format(freeOver)}원';
    return '$fee, $over 이상 사면 무료';
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
            Expanded(
              child: Text(note, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
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

class _ImageCarousel extends StatefulWidget {
  final List<String> images;

  const _ImageCarousel({required this.images});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _page = 0;

  Widget _placeholder() => Container(
    color: AppColors.surfaceMutedLight,
    alignment: Alignment.center,
    child: const Icon(Icons.pets, size: 48, color: AppColors.textPlaceholder),
  );

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return AspectRatio(
      aspectRatio: 1,
      child: images.isEmpty
          ? _placeholder()
          : Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => Image.network(
                    images[i],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _placeholder(),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${_page + 1} / ${images.length}',
                        style: AppTextStyles.mono(size: 13, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 사진 위 흰 동그라미 버튼(뒤로·장바구니).
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CircleButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 1,
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: AppColors.textPrimary),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// 옵션 고르기 — 옵션 이름이 "색 / 사이즈" 꼴이면 색상 줄(2열) → 사이즈 줄(한
/// 줄)로 나눠 고르고, 그 색에 없는(또는 품절인) 사이즈는 회색 + "품절"로 막는다
/// (빨강 금지). 고른 사이즈의 치수는 상품정보제공고시 '치수'에서 한 줄로.
/// 나눌 수 없으면 지금처럼 한 줄 칩.
class _OptionPicker extends StatelessWidget {
  final Product product;
  final ProductOption? selected;
  final ValueChanged<ProductOption> onSelect;

  const _OptionPicker({required this.product, required this.selected, required this.onSelect});

  static const _label = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

  @override
  Widget build(BuildContext context) {
    final options = product.options;
    final axes = OptionAxes.of(options);
    if (axes == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('옵션', style: _label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(
                    o.soldOut
                        ? '${o.name} (품절)'
                        : (o.extraPrice > 0 ? '${o.name} (+${NumberFormat('#,###').format(o.extraPrice)}원)' : o.name),
                  ),
                  selected: selected?.id == o.id,
                  onSelected: o.soldOut ? null : (_) => onSelect(o),
                ),
            ],
          ),
        ],
      );
    }

    final current = selected != null ? OptionAxes.splitName(selected!.name) : null;
    final color = current?.$1 ?? axes.colors.first;
    final size = current?.$2;
    final measure = size == null ? null : sizeMeasureLine(product.notice['치수'], size);

    void pickColor(String c) {
      // 같은 사이즈가 그 색에 있으면 유지, 없으면 그 색의 첫 구매 가능 사이즈.
      final keep = size != null ? OptionAxes.find(options, c, size) : null;
      if (keep != null && !keep.soldOut) return onSelect(keep);
      for (final s in axes.sizes) {
        final o = OptionAxes.find(options, c, s);
        if (o != null && !o.soldOut) return onSelect(o);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('색상', style: _label),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in axes.colors)
                  SizedBox(
                    width: width,
                    child: _OptionButton(
                      label: c,
                      selected: c == color,
                      enabled: axes.sizes.any((s) {
                        final o = OptionAxes.find(options, c, s);
                        return o != null && !o.soldOut;
                      }),
                      onTap: () => pickColor(c),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('사이즈', style: _label),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < axes.sizes.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final o = OptionAxes.find(options, color, axes.sizes[i]);
                    final available = o != null && !o.soldOut;
                    return _OptionButton(
                      label: axes.sizes[i],
                      caption: available ? null : '품절',
                      showCheck: false,
                      selected: o != null && selected?.id == o.id,
                      enabled: available,
                      onTap: () => onSelect(o!),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        if (selected != null && selected!.extraPrice > 0) ...[
          const SizedBox(height: 8),
          Text(
            '이 옵션은 ${NumberFormat('#,###').format(selected!.extraPrice)}원이 더해져요',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
        ],
        if (measure != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.softPanel, borderRadius: BorderRadius.circular(12)),
            child: Text(measure, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary)),
          ),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final String? caption;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  /// 좁은 사이즈 버튼은 체크 표시 없이 테두리·바탕으로만 선택을 보인다.
  final bool showCheck;

  const _OptionButton({
    required this.label,
    this.caption,
    this.showCheck = true,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = !enabled ? AppColors.textPlaceholder : (selected ? AppColors.primary : AppColors.textPrimary);
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Material(
        color: !enabled ? AppColors.closedBg : (selected ? AppColors.primarySoft : AppColors.surfaceLight),
        shape: StadiumBorder(
          side: selected
              ? const BorderSide(color: AppColors.primary, width: 2)
              : BorderSide(color: enabled ? AppColors.borderInput : AppColors.borderCard),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected && showCheck) ...[
                    const Icon(Icons.check, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: fg,
                          ),
                        ),
                        if (caption != null)
                          Text(caption!, style: const TextStyle(fontSize: 11, color: AppColors.textPlaceholder)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 수량 스테퍼 — 알약 안에 [−] 숫자 [+], 버튼 44dp.
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const QuantityStepper({super.key, required this.quantity, this.onDecrease, this.onIncrease});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surfaceLight,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.borderInput)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '하나 빼기',
            onPressed: onDecrease,
            icon: const Icon(Icons.remove),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.mono(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          IconButton(
            tooltip: '하나 더하기',
            onPressed: onIncrease,
            icon: const Icon(Icons.add),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
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
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(r, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
            ),
          )
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
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(r, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
            ),
          )
          .toList(),
    );
  }
}
