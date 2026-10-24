/// 입점 브랜드(판매자) 상태 — `paused`면 그 브랜드의 상품은 더 이상
/// 새로 노출하지 않는다("쇼핑 기초" 지시서 2 — 판매자는 `active`일 때만
/// 읽기 허용, `firestore.rules` 참고).
enum SellerStatus {
  active,
  paused;

  static SellerStatus fromFirestore(String? value) => SellerStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => SellerStatus.paused,
      );
}

/// 배송 정책 — `freeOver`는 그 금액(원) 이상 주문 시 무료배송 기준이다.
/// 브랜드가 무료배송 기준을 두지 않으면(필드 누락) `null` — "배송비 항상
/// 부과"를 뜻한다. `baseFee`/`extraJejuFee`는 원 단위.
class ShippingPolicy {
  final int baseFee;
  final int? freeOver;
  final int extraJejuFee;
  final String? carrier;
  final int dispatchDays;

  const ShippingPolicy({
    this.baseFee = 0,
    this.freeOver,
    this.extraJejuFee = 0,
    this.carrier,
    this.dispatchDays = 2,
  });

  factory ShippingPolicy.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const ShippingPolicy();
    return ShippingPolicy(
      baseFee: (data['baseFee'] as num?)?.toInt() ?? 0,
      freeOver: (data['freeOver'] as num?)?.toInt(),
      extraJejuFee: (data['extraJejuFee'] as num?)?.toInt() ?? 0,
      carrier: data['carrier'] as String?,
      dispatchDays: (data['dispatchDays'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'baseFee': baseFee,
        'freeOver': freeOver,
        'extraJejuFee': extraJejuFee,
        'carrier': carrier,
        'dispatchDays': dispatchDays,
      };
}

/// 반품/교환 정책 — 배송비와 별개로 편도 회수비를 브랜드가 각각 정한다.
class ReturnPolicy {
  final int returnFee;
  final int exchangeFee;
  final String returnAddress;
  final String note;

  const ReturnPolicy({
    this.returnFee = 0,
    this.exchangeFee = 0,
    this.returnAddress = '',
    this.note = '',
  });

  factory ReturnPolicy.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const ReturnPolicy();
    return ReturnPolicy(
      returnFee: (data['returnFee'] as num?)?.toInt() ?? 0,
      exchangeFee: (data['exchangeFee'] as num?)?.toInt() ?? 0,
      returnAddress: data['returnAddress'] as String? ?? '',
      note: data['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'returnFee': returnFee,
        'exchangeFee': exchangeFee,
        'returnAddress': returnAddress,
        'note': note,
      };
}

/// `sellers/{sellerId}` 문서 — 입점 브랜드("쇼핑 기초" 지시서 0: 펫클은
/// 통신판매중개자, 판매자가 거래 당사자). 정산·계좌 정보는 여기 두지
/// 않는다(나중에 관리자 전용 비공개 컬렉션에 — 지시서 2).
class Seller {
  final String id;
  final String name;
  final String brandName;
  final String ceoName;
  final String bizRegNo;
  final String mailOrderNo;
  final String address;
  final String csPhone;
  final String csEmail;
  final ShippingPolicy shipping;
  final ReturnPolicy returnPolicy;
  final SellerStatus status;

  const Seller({
    required this.id,
    required this.name,
    this.brandName = '',
    this.ceoName = '',
    this.bizRegNo = '',
    this.mailOrderNo = '',
    this.address = '',
    this.csPhone = '',
    this.csEmail = '',
    this.shipping = const ShippingPolicy(),
    this.returnPolicy = const ReturnPolicy(),
    this.status = SellerStatus.paused,
  });

  factory Seller.fromFirestore(String id, Map<String, dynamic> data) => Seller(
        id: id,
        name: data['name'] as String? ?? '',
        brandName: data['brandName'] as String? ?? '',
        ceoName: data['ceoName'] as String? ?? '',
        bizRegNo: data['bizRegNo'] as String? ?? '',
        mailOrderNo: data['mailOrderNo'] as String? ?? '',
        address: data['address'] as String? ?? '',
        csPhone: data['csPhone'] as String? ?? '',
        csEmail: data['csEmail'] as String? ?? '',
        shipping: ShippingPolicy.fromFirestore(data['shipping'] as Map<String, dynamic>?),
        returnPolicy: ReturnPolicy.fromFirestore(data['returnPolicy'] as Map<String, dynamic>?),
        status: SellerStatus.fromFirestore(data['status'] as String?),
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'brandName': brandName,
        'ceoName': ceoName,
        'bizRegNo': bizRegNo,
        'mailOrderNo': mailOrderNo,
        'address': address,
        'csPhone': csPhone,
        'csEmail': csEmail,
        'shipping': shipping.toFirestore(),
        'returnPolicy': returnPolicy.toFirestore(),
        'status': status.name,
      };
}
