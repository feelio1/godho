import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/inline_error_message.dart';
import '../models/shop_order.dart';
import '../providers/shop_providers.dart';

String _statusLabel(OrderStatus status) => switch (status) {
      OrderStatus.pendingPayment => '결제 대기',
      OrderStatus.paid => '결제 완료',
      OrderStatus.preparing => '상품 준비 중',
      OrderStatus.shipped => '배송 중',
      OrderStatus.delivered => '배송 완료',
      OrderStatus.cancelRequested => '취소 요청',
      OrderStatus.cancelled => '취소 완료',
      OrderStatus.returnRequested => '반품 요청',
      OrderStatus.returned => '반품 완료',
      OrderStatus.refunded => '환불 완료',
    };

/// 주문내역("쇼핑 기초" 지시서 5-5) — 내 정보 탭에서 쇼핑이 켜져 있을 때만
/// 보이는 메뉴. 상태는 전부 중립 색(브랜드 톤 pill)로만 구분한다 —
/// CLAUDE.md 색상 규칙(평가처럼 보이는 색 금지)과 같은 원칙을 주문 상태
/// 표시에도 그대로 적용.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('주문내역')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineErrorMessage(
          error: error,
          onRetry: () => ref.invalidate(myOrdersProvider),
        ),
        data: (orders) => orders.isEmpty
            ? const Center(child: Text('아직 주문 내역이 없어요', style: TextStyle(color: AppColors.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.page),
                itemCount: orders.length,
                separatorBuilder: (context, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _OrderTile(order: orders[i]),
              ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final ShopOrder order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.card),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.borderCard),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('yyyy.MM.dd').format(order.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    order.items.isEmpty ? '상품 정보 없음' : '${order.items.first.nameSnapshot}${order.items.length > 1 ? ' 외 ${order.items.length - 1}건' : ''}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('${NumberFormat('#,###').format(order.grandTotal)}원', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text(_statusLabel(order.status), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 주문 상세 — 상품 목록·배송지·브랜드별 배송비/송장 조회 자리.
class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('주문 상세')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineErrorMessage(
          error: error,
          onRetry: () => ref.invalidate(orderProvider(orderId)),
        ),
        data: (order) => order == null
            ? const Center(child: Text('주문을 찾을 수 없어요'))
            : _OrderDetailBody(order: order),
      ),
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  final ShopOrder order;

  const _OrderDetailBody({required this.order});

  @override
  Widget build(BuildContext context) {
    final sellerIds = order.shippingFees.keys.toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Text(_statusLabel(order.status), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone)),
        ),
        const SizedBox(height: AppSpacing.section),
        const Text('상품', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.nameSnapshot}${item.optionName != null ? ' · ${item.optionName}' : ''} × ${item.quantity}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text('${NumberFormat('#,###').format(item.lineTotal)}원', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        const Divider(height: 24),
        const Text('배송지', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('${order.shippingAddress.name} · ${order.shippingAddress.phone}', style: const TextStyle(fontSize: 13)),
        Text(
          '(${order.shippingAddress.zip}) ${order.shippingAddress.address1} ${order.shippingAddress.address2}'.trim(),
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const Divider(height: 24),
        const Text('배송 조회', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final sellerId in sellerIds) _ShipmentRow(sellerId: sellerId, shipment: order.shipments[sellerId]),
        const SizedBox(height: AppSpacing.section),
        Row(
          children: [
            const Text('총 결제금액', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${NumberFormat('#,###').format(order.grandTotal)}원', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ],
        ),
      ],
    );
  }
}

class _ShipmentRow extends StatelessWidget {
  final String sellerId;
  final ShipmentInfo? shipment;

  const _ShipmentRow({required this.sellerId, required this.shipment});

  @override
  Widget build(BuildContext context) {
    final trackingNo = shipment?.trackingNo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              trackingNo != null ? '${shipment?.carrier ?? ''} $trackingNo'.trim() : '송장 등록 전이에요',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
