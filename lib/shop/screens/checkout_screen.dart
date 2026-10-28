import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ads/app_open_ad_suppression.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../models/seller.dart';
import '../models/shop_order.dart';
import '../payment/payment_gateway.dart';
import '../pricing.dart';
import '../providers/shop_providers.dart';

/// 주문서(체크아웃, "쇼핑 기초" 지시서 5-4) — 배송지 입력 + 주문 요약 +
/// 필수 동의. [PaymentGateway] 구현체가 없는 지금은 결제 버튼이 항상
/// 비활성이고, 주문 문서도 만들지 않는다(지시서 0 — 가격·주문 확정은
/// 서버 몫, 결제 승인 전 단계까지만 클라이언트가 만든다).
class CheckoutScreen extends ConsumerStatefulWidget {
  final List<CartLine> lines;

  const CheckoutScreen({super.key, required this.lines});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _zipController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _memoController = TextEditingController();

  bool _agreeOrder = false;
  bool _agreeDataShare = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _memoController.dispose();
    super.dispose();
  }

  bool get _addressFilled =>
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _zipController.text.trim().isNotEmpty &&
      _address1Controller.text.trim().isNotEmpty;

  ShippingAddress get _shippingAddress => ShippingAddress(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        zip: _zipController.text.trim(),
        address1: _address1Controller.text.trim(),
        address2: _address2Controller.text.trim(),
        memo: _memoController.text.trim(),
      );

  Future<void> _submit(CartSummary summary) async {
    final gateway = ref.read(paymentGatewayProvider);
    final uid = ref.read(authStateProvider).value?.uid;
    if (gateway == null || uid == null) return;

    setState(() => _submitting = true);
    try {
      final items = summary.sellerGroups.expand((g) => g.lines).map((line) => OrderItem(
            productId: line.product.id,
            sellerId: line.product.sellerId,
            nameSnapshot: line.product.name,
            optionName: line.option?.name,
            unitPrice: line.unitPrice,
            quantity: line.quantity,
            lineTotal: line.lineTotal,
          ));
      final shippingFees = {for (final g in summary.sellerGroups) g.sellerId: g.shippingFee};

      final order = await ref.read(shopRepositoryProvider).createPendingOrder(
            uid: uid,
            items: items.toList(),
            shippingFees: shippingFees,
            shippingAddress: _shippingAddress,
          );
      final result = await gateway.pay(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.success ? '결제가 완료됐어요' : (result.errorMessage ?? '결제에 실패했어요'))),
      );
      if (result.success) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // 주문서 작성·결제 중에는 앱 오프닝 광고를 띄우지 않는다 — 화면이 사라지면
  // (어떤 경로든) 억제도 같이 풀린다.
  @override
  Widget build(BuildContext context) => AppOpenAdSuppressor(child: _buildScreen(context));

  Widget _buildScreen(BuildContext context) {
    final sellerIds = widget.lines.map((l) => l.product.sellerId).toSet().toList();
    final sellerAsyncs = [for (final id in sellerIds) ref.watch(sellerProvider(id))];
    final loading = sellerAsyncs.any((a) => a.isLoading);
    final hasError = sellerAsyncs.any((a) => a.hasError);

    return Scaffold(
      appBar: AppBar(title: const Text('주문서')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? const Center(child: Text('판매자 정보를 불러오지 못했어요', style: TextStyle(color: AppColors.textSecondary)))
              : _buildBody(context, sellerIds, sellerAsyncs),
    );
  }

  Widget _buildBody(BuildContext context, List<String> sellerIds, List<AsyncValue<Seller?>> sellerAsyncs) {
    final sellersById = <String, Seller>{};
    for (var i = 0; i < sellerIds.length; i++) {
      final seller = sellerAsyncs[i].value;
      if (seller != null) sellersById[sellerIds[i]] = seller;
    }
    final summary = summarizeCart(widget.lines, sellersById: sellersById);
    final gateway = ref.watch(paymentGatewayProvider);
    final canSubmit = !_submitting && gateway != null && _addressFilled && _agreeOrder && _agreeDataShare && summary.grandTotal > 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              const Text('배송지', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _AddressField(controller: _nameController, label: '받는 사람', onChanged: () => setState(() {})),
              _AddressField(controller: _phoneController, label: '연락처', keyboardType: TextInputType.phone, onChanged: () => setState(() {})),
              _AddressField(controller: _zipController, label: '우편번호', keyboardType: TextInputType.number, onChanged: () => setState(() {})),
              _AddressField(controller: _address1Controller, label: '주소', onChanged: () => setState(() {})),
              _AddressField(controller: _address2Controller, label: '상세주소(선택)', onChanged: () => setState(() {})),
              _AddressField(controller: _memoController, label: '배송 메모(선택)', onChanged: () => setState(() {})),
              const SizedBox(height: AppSpacing.section),
              const Text('주문 요약', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final group in summary.sellerGroups) _OrderSummaryGroup(group: group),
              const Divider(height: 24),
              _TotalsRow(label: '상품 합계', value: summary.itemsTotal),
              _TotalsRow(label: '배송비 합계', value: summary.shippingTotal),
              const SizedBox(height: 6),
              _TotalsRow(label: '총 결제금액', value: summary.grandTotal, emphasize: true),
              const SizedBox(height: AppSpacing.section),
              CheckboxListTile(
                value: _agreeOrder,
                onChanged: (v) => setState(() => _agreeOrder = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('주문 내용 확인 및 결제 진행 동의', style: TextStyle(fontSize: 13)),
              ),
              CheckboxListTile(
                value: _agreeDataShare,
                onChanged: (v) => setState(() => _agreeDataShare = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('개인정보 판매자 제공 동의', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, AppSpacing.page, 14),
            child: Column(
              children: [
                if (gateway == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('결제 준비 중이에요', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: canSubmit ? () => _submit(summary) : null,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('결제하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final VoidCallback onChanged;

  const _AddressField({required this.controller, required this.label, this.keyboardType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}

class _OrderSummaryGroup extends StatelessWidget {
  final SellerCartGroup group;

  const _OrderSummaryGroup({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in group.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.product.name}${line.option != null ? ' · ${line.option!.name}' : ''} × ${line.quantity}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${NumberFormat('#,###').format(line.lineTotal)}원', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final String label;
  final int value;
  final bool emphasize;

  const _TotalsRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: emphasize ? 15 : 13, fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500, color: emphasize ? AppColors.textPrimary : AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            '${NumberFormat('#,###').format(value)}원',
            style: TextStyle(
              fontSize: emphasize ? 17 : 13,
              fontWeight: FontWeight.w800,
              color: emphasize ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
