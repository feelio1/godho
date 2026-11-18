import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ads/app_open_ad_suppression.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/unsaved_changes_guard.dart';
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

  /// 우편번호 검색이 아직 없어 [주소 검색]을 누르면 우편번호·기본 주소 칸을
  /// 직접 입력하게 연다(실제 검색 연동은 쇼핑 오픈 전 별도 작업).
  bool _manualAddress = false;
  final _zipFocus = FocusNode();
  String? _memoPreset;
  bool _agreeDataShare = false;
  bool _submitting = false;

  /// 뒤로가기 확인용 — 배송지·요청사항을 하나라도 적었거나 동의를
  /// 체크했으면 "작성 중"으로 본다(2차 업데이트 H). 결제 성공 후 닫기는
  /// 막지 않는다.
  bool get _isDirty =>
      [
        _nameController,
        _phoneController,
        _zipController,
        _address1Controller,
        _address2Controller,
        _memoController,
      ].any((c) => c.text.trim().isNotEmpty) ||
      _agreeOrder ||
      _agreeDataShare;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _memoController.dispose();
    _zipFocus.dispose();
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
      final items = summary.sellerGroups
          .expand((g) => g.lines)
          .map(
            (line) => OrderItem(
              productId: line.product.id,
              sellerId: line.product.sellerId,
              nameSnapshot: line.product.name,
              optionName: line.option?.name,
              unitPrice: line.unitPrice,
              quantity: line.quantity,
              lineTotal: line.lineTotal,
            ),
          );
      final shippingFees = {for (final g in summary.sellerGroups) g.sellerId: g.shippingFee};

      final order = await ref
          .read(shopRepositoryProvider)
          .createPendingOrder(
            uid: uid,
            items: items.toList(),
            shippingFees: shippingFees,
            shippingAddress: _shippingAddress,
          );
      final result = await gateway.pay(order);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.success ? '결제가 완료됐어요' : (result.errorMessage ?? '결제에 실패했어요'))));
      if (result.success) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // 주문서 작성·결제 중에는 앱 오프닝 광고를 띄우지 않는다 — 화면이 사라지면
  // (어떤 경로든) 억제도 같이 풀린다.
  @override
  Widget build(BuildContext context) => AppOpenAdSuppressor(
    child: UnsavedChangesGuard(isDirty: () => _isDirty, child: _buildScreen(context)),
  );

  void _openAddressSearch() {
    setState(() => _manualAddress = true);
    _zipFocus.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주소 검색은 준비 중이에요. 우편번호와 주소를 직접 입력해 주세요.')));
  }

  Future<void> _showAgreement(String title, String body) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(height: 1.5)),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('확인'))],
    ),
  );

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
          ? const Center(
              child: Text('판매자 정보를 불러오지 못했어요', style: TextStyle(color: AppColors.textSecondary)),
            )
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
    final canSubmit =
        !_submitting && gateway != null && _addressFilled && _agreeOrder && _agreeDataShare && summary.grandTotal > 0;

    final itemCount = summary.sellerGroups.fold<int>(0, (sum, g) => sum + g.lines.length);
    void changed() => setState(() {});

    // "장구름의 수첩"(3차 업데이트 J-6): 받는 곳 카드(라벨 있는 입력칸) → 주문 상품
    // 카드 → 동의 카드 → 결제대행 안내 → 하단 고정 "{금액}원 결제하기".
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              _CheckoutCard(
                title: '받는 곳',
                children: [
                  const _FieldLabel('받는 사람'),
                  _AddressField(controller: _nameController, hint: '이름', onChanged: changed),
                  const _FieldLabel('연락처'),
                  _AddressField(
                    controller: _phoneController,
                    hint: '010-0000-0000',
                    keyboardType: TextInputType.phone,
                    onChanged: changed,
                  ),
                  const _FieldLabel('주소'),
                  Row(
                    children: [
                      Expanded(
                        child: _AddressField(
                          controller: _zipController,
                          hint: '우편번호',
                          keyboardType: TextInputType.number,
                          readOnly: !_manualAddress,
                          focusNode: _zipFocus,
                          onChanged: changed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
                          ),
                          onPressed: _openAddressSearch,
                          child: const Text('주소 검색'),
                        ),
                      ),
                    ],
                  ),
                  _AddressField(
                    controller: _address1Controller,
                    hint: _manualAddress ? '기본 주소' : '주소 검색으로 채워져요',
                    readOnly: !_manualAddress,
                    onChanged: changed,
                  ),
                  _AddressField(controller: _address2Controller, hint: '상세주소 (동·호수, 선택)', onChanged: changed),
                  const _FieldLabel('배송 메모', optional: true),
                  DropdownButtonFormField<String>(
                    initialValue: _memoPreset,
                    isExpanded: true,
                    hint: const Text('선택 안 함'),
                    items: [for (final preset in _memoPresets) DropdownMenuItem(value: preset, child: Text(preset))],
                    onChanged: (value) => setState(() {
                      _memoPreset = value;
                      if (value != _memoDirect) _memoController.text = value == _memoNone ? '' : (value ?? '');
                      if (value == _memoDirect) _memoController.clear();
                    }),
                  ),
                  if (_memoPreset == _memoDirect) ...[
                    const SizedBox(height: 10),
                    _AddressField(controller: _memoController, hint: '배송 메모를 적어 주세요', onChanged: changed),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _CheckoutCard(
                title: '주문 상품 $itemCount개',
                children: [
                  for (final group in summary.sellerGroups) _OrderSummaryGroup(group: group),
                  const Divider(height: 24, color: AppColors.borderMuted),
                  _TotalsRow(label: '상품 합계', value: summary.itemsTotal),
                  _TotalsRow(label: '배송비 합계', value: summary.shippingTotal),
                  ..._bulkyFeeNote(summary),
                  const SizedBox(height: 6),
                  _TotalsRow(label: '총 결제금액', value: summary.grandTotal, emphasize: true),
                ],
              ),
              const SizedBox(height: 14),
              _CheckoutCard(
                children: [
                  CheckboxListTile(
                    value: _agreeOrder,
                    onChanged: (v) => setState(() => _agreeOrder = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('주문 내용 확인 및 결제 진행 동의', style: TextStyle(fontSize: 14.5)),
                    subtitle: const Text('필수', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    secondary: TextButton(
                      onPressed: () => _showAgreement(
                        '주문 내용 확인 및 결제 진행 동의',
                        '주문할 상품·옵션·수량·결제금액(배송비 포함)을 확인했고, 이 내용으로 결제를 진행하는 데 동의합니다.',
                      ),
                      child: const Text('보기'),
                    ),
                  ),
                  CheckboxListTile(
                    value: _agreeDataShare,
                    onChanged: (v) => setState(() => _agreeDataShare = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    // TODO(법률): 최종 문구·제공받는 자 목록은 개인정보처리방침 개정과 함께 교체
                    title: const Text('배송을 위한 개인정보 제3자 제공 동의 (상품 공급업체)', style: TextStyle(fontSize: 14.5)),
                    subtitle: const Text('필수', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    secondary: TextButton(
                      onPressed: () => _showAgreement(
                        '개인정보 제3자 제공',
                        '제공받는 자: 주문 상품의 공급업체\n제공 항목: 받는 사람 이름·연락처·주소·배송 메모\n'
                            '목적: 상품 발송\n보유 기간: 배송 완료 후 관계 법령에 따른 기간',
                      ),
                      child: const Text('보기'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                '판매자 아깽이상점 · 상품은 공급업체에서 직접 발송해요. 카드 정보는 결제대행사가 처리하고 펫클에는 저장되지 않아요.',
                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 14),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(top: BorderSide(color: AppColors.borderCard)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gateway == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('결제 준비 중이에요', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('checkout_pay'),
                    onPressed: canSubmit ? () => _submit(summary) : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('${NumberFormat('#,###').format(summary.grandTotal)}원 결제하기'),
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

const _memoNone = '선택 안 함';
const _memoDirect = '직접 입력';
const _memoPresets = [_memoNone, '문 앞에 놓아 주세요', '경비실에 맡겨 주세요', '배송 전에 연락 주세요', _memoDirect];

class _CheckoutCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _CheckoutCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool optional;

  const _FieldLabel(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (optional)
              const TextSpan(
                text: ' (선택)',
                style: TextStyle(fontWeight: FontWeight.w400, color: AppColors.textSecondary),
              ),
          ],
        ),
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final VoidCallback onChanged;
  final bool readOnly;
  final FocusNode? focusNode;

  const _AddressField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    required this.onChanged,
    this.readOnly = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        focusNode: focusNode,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: hint,
          // 읽기 전용(주소 검색으로 채워지는 칸)은 옅은 회색 바탕.
          fillColor: readOnly ? AppColors.softPanel : null,
        ),
      ),
    );
  }
}

/// 배송비 합계 아래 회색 작은 글씨 — 따로 배송(bulky) 상품 몫을 보여줘 합계가
/// 어떻게 나왔는지 알 수 있게 한다. 없으면 아무것도 그리지 않는다.
List<Widget> _bulkyFeeNote(CartSummary summary) {
  final kinds = summary.sellerGroups.fold<int>(0, (sum, g) => sum + g.bulkyKinds);
  final fee = summary.sellerGroups.fold<int>(0, (sum, g) => sum + g.bulkyFee);
  if (kinds == 0) return const [];
  return [
    Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 3),
      child: Text(
        '· 따로 배송 상품 $kinds종 ${NumberFormat('#,###').format(fee)}원',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ),
  ];
}

class _OrderSummaryGroup extends StatelessWidget {
  final SellerCartGroup group;

  const _OrderSummaryGroup({required this.group});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      color: AppColors.surfaceMutedLight,
      alignment: Alignment.center,
      child: const Icon(Icons.pets, size: 20, color: AppColors.textPlaceholder),
    );
    return Column(
      children: [
        for (final line in group.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: line.product.images.isEmpty
                        ? placeholder()
                        : Image.network(
                            line.product.images.first,
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
                      Text(
                        line.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        [
                          if (line.option != null) line.option!.name.replaceAll(' / ', ' · '),
                          '${line.quantity}개',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${NumberFormat('#,###').format(line.lineTotal)}원',
                  style: AppTextStyles.mono(size: 15, weight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
      ],
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
            style: TextStyle(
              fontSize: emphasize ? 16 : 14.5,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
              color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '${NumberFormat('#,###').format(value)}원',
            style: AppTextStyles.mono(
              size: emphasize ? 22 : 14.5,
              weight: emphasize ? FontWeight.w700 : FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
