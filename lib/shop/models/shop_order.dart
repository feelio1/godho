import 'package:cloud_firestore/cloud_firestore.dart';

/// 주문 상태("쇼핑 기초" 지시서 2) — 정상 경로는 `pendingPayment → paid →
/// preparing → shipped → delivered`, 분기로 취소(`cancelRequested →
/// cancelled`)·반품(`returnRequested → returned → refunded`)이 있다.
/// 클라이언트는 `pendingPayment`만 만들 수 있고, 그다음 상태 전이는 전부
/// 서버/관리자 몫이다(`firestore.rules`: orders는 update/delete 불가).
enum OrderStatus {
  pendingPayment,
  paid,
  preparing,
  shipped,
  delivered,
  cancelRequested,
  cancelled,
  returnRequested,
  returned,
  refunded;

  static OrderStatus fromFirestore(String? value) => OrderStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => OrderStatus.pendingPayment,
      );
}

/// 주문 시점 스냅샷 한 줄 — 상품 가격이 나중에 바뀌어도 이미 낸 주문의
/// 금액은 바뀌지 않는다.
class OrderItem {
  final String productId;
  final String sellerId;
  final String nameSnapshot;
  final String? optionName;
  final int unitPrice;
  final int quantity;
  final int lineTotal;

  const OrderItem({
    required this.productId,
    required this.sellerId,
    required this.nameSnapshot,
    this.optionName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  factory OrderItem.fromFirestore(Map<String, dynamic> data) => OrderItem(
        productId: data['productId'] as String? ?? '',
        sellerId: data['sellerId'] as String? ?? '',
        nameSnapshot: data['nameSnapshot'] as String? ?? '',
        optionName: data['optionName'] as String?,
        unitPrice: (data['unitPrice'] as num?)?.toInt() ?? 0,
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        lineTotal: (data['lineTotal'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toFirestore() => {
        'productId': productId,
        'sellerId': sellerId,
        'nameSnapshot': nameSnapshot,
        'optionName': optionName,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'lineTotal': lineTotal,
      };
}

/// 배송지 — 우편번호 검색 없이 직접 입력(지시서 5-4, 나중에 교체 가능).
class ShippingAddress {
  final String name;
  final String phone;
  final String zip;
  final String address1;
  final String address2;
  final String memo;

  const ShippingAddress({
    required this.name,
    required this.phone,
    required this.zip,
    required this.address1,
    this.address2 = '',
    this.memo = '',
  });

  /// 제주 배송비 추가 판정("쇼핑 기초" 지시서 4 pricing) — 주소 문자열
  /// 기준의 아주 단순한 판정이다. 정밀한 우편번호 기반 판정은 실제
  /// 주소 검색 연동 때 교체한다.
  bool get isJeju => address1.contains('제주') || zip.startsWith('63');

  factory ShippingAddress.fromFirestore(Map<String, dynamic> data) => ShippingAddress(
        name: data['name'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        zip: data['zip'] as String? ?? '',
        address1: data['address1'] as String? ?? '',
        address2: data['address2'] as String? ?? '',
        memo: data['memo'] as String? ?? '',
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'phone': phone,
        'zip': zip,
        'address1': address1,
        'address2': address2,
        'memo': memo,
      };
}

/// 결제 정보 — PG 연동 전이라 전부 비어 있다("쇼핑 기초" 지시서 0 결제
/// 미정). 서버가 결제 승인 후 이 필드들을 채운다.
class PaymentInfo {
  final String? provider;
  final String? txId;
  final String? method;
  final DateTime? paidAt;

  const PaymentInfo({this.provider, this.txId, this.method, this.paidAt});

  bool get isEmpty => provider == null && txId == null && method == null && paidAt == null;

  factory PaymentInfo.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const PaymentInfo();
    return PaymentInfo(
      provider: data['provider'] as String?,
      txId: data['txId'] as String?,
      method: data['method'] as String?,
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'provider': provider,
        'txId': txId,
        'method': method,
        'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      };
}

/// 브랜드별 송장 — 한 주문에 여러 브랜드가 섞일 수 있어 `sellerId`별로
/// 따로 둔다.
class ShipmentInfo {
  final String? carrier;
  final String? trackingNo;
  final DateTime? shippedAt;

  const ShipmentInfo({this.carrier, this.trackingNo, this.shippedAt});

  factory ShipmentInfo.fromFirestore(Map<String, dynamic> data) => ShipmentInfo(
        carrier: data['carrier'] as String?,
        trackingNo: data['trackingNo'] as String?,
        shippedAt: (data['shippedAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toFirestore() => {
        'carrier': carrier,
        'trackingNo': trackingNo,
        'shippedAt': shippedAt != null ? Timestamp.fromDate(shippedAt!) : null,
      };
}

/// `orders/{orderId}` 문서. 클라이언트는 `status: pendingPayment`로만
/// 생성할 수 있다("쇼핑 기초" 지시서 0·3) — 결제 승인·상태 변경·배송
/// 등록은 전부 나중에 Cloud Functions/관리자 몫이다.
class ShopOrder {
  final String id;
  final String uid;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  /// 판매자별 배송비 — key는 sellerId.
  final Map<String, int> shippingFees;
  final int itemsTotal;
  final int shippingTotal;
  final int grandTotal;
  final ShippingAddress shippingAddress;
  final PaymentInfo payment;

  /// 판매자별 송장 — key는 sellerId.
  final Map<String, ShipmentInfo> shipments;

  const ShopOrder({
    required this.id,
    required this.uid,
    this.status = OrderStatus.pendingPayment,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.shippingFees = const {},
    required this.itemsTotal,
    required this.shippingTotal,
    required this.grandTotal,
    required this.shippingAddress,
    this.payment = const PaymentInfo(),
    this.shipments = const {},
  });

  factory ShopOrder.fromFirestore(String id, Map<String, dynamic> data) => ShopOrder(
        id: id,
        uid: data['uid'] as String? ?? '',
        status: OrderStatus.fromFirestore(data['status'] as String?),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        items: (data['items'] as List<dynamic>? ?? const [])
            .map((e) => OrderItem.fromFirestore(e as Map<String, dynamic>))
            .toList(),
        shippingFees: (data['shippingFees'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        itemsTotal: (data['itemsTotal'] as num?)?.toInt() ?? 0,
        shippingTotal: (data['shippingTotal'] as num?)?.toInt() ?? 0,
        grandTotal: (data['grandTotal'] as num?)?.toInt() ?? 0,
        shippingAddress:
            ShippingAddress.fromFirestore(data['shippingAddress'] as Map<String, dynamic>? ?? const {}),
        payment: PaymentInfo.fromFirestore(data['payment'] as Map<String, dynamic>?),
        shipments: (data['shipments'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, ShipmentInfo.fromFirestore(v as Map<String, dynamic>))),
      );

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'items': items.map((e) => e.toFirestore()).toList(),
        'shippingFees': shippingFees,
        'itemsTotal': itemsTotal,
        'shippingTotal': shippingTotal,
        'grandTotal': grandTotal,
        'shippingAddress': shippingAddress.toFirestore(),
        'payment': payment.toFirestore(),
        'shipments': shipments.map((k, v) => MapEntry(k, v.toFirestore())),
      };
}
