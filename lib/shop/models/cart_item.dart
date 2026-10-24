import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/cart/{itemId}` 문서 — 가격은 저장하지 않는다("쇼핑 기초"
/// 지시서 2). 담을 때 가격이 바뀌어도 장바구니·주문서는 항상 상품 문서의
/// 지금 가격을 다시 계산해 보여준다(가격 스냅샷은 주문 생성 시점의
/// [OrderItem]에만 남는다).
class CartItem {
  final String id;
  final String productId;
  final String? optionId;
  final int quantity;
  final DateTime addedAt;

  const CartItem({
    required this.id,
    required this.productId,
    this.optionId,
    this.quantity = 1,
    required this.addedAt,
  });

  CartItem copyWith({int? quantity}) => CartItem(
        id: id,
        productId: productId,
        optionId: optionId,
        quantity: quantity ?? this.quantity,
        addedAt: addedAt,
      );

  factory CartItem.fromFirestore(String id, Map<String, dynamic> data) => CartItem(
        id: id,
        productId: data['productId'] as String? ?? '',
        optionId: data['optionId'] as String?,
        quantity: (data['quantity'] as num?)?.toInt() ?? 1,
        addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
        'productId': productId,
        'optionId': optionId,
        'quantity': quantity,
        'addedAt': Timestamp.fromDate(addedAt),
      };
}
