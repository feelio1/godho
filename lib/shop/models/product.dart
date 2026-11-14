import 'package:cloud_firestore/cloud_firestore.dart';

/// 상품 대분류 — 자유 입력이 아니라 콘솔에서 고정된 값만 고르게 한다.
enum ProductCategory {
  food,
  treat,
  apparel,
  supplement,
  hygiene,
  toy,
  living,
  etc;

  static ProductCategory fromFirestore(String? value) => ProductCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ProductCategory.etc,
      );

  /// 스토어 홈 카테고리 칩에 쓰는 화면 표시용 라벨.
  String get label => switch (this) {
        ProductCategory.food => '사료',
        ProductCategory.treat => '간식',
        ProductCategory.apparel => '옷',
        ProductCategory.supplement => '영양제',
        ProductCategory.hygiene => '위생용품',
        ProductCategory.toy => '장난감',
        ProductCategory.living => '생활용품',
        ProductCategory.etc => '기타',
      };
}

/// 추천 필터용 태그("쇼핑 기초" 지시서 4 — 진료기록이 아니라 반려동물
/// 프로필(종·체중·생애주기)만 본다). 종·토끼 등 그 외 종은 추천 대상에서
/// 빠진다(Pet.species의 `other`는 매칭되지 않음) — 상품 노출 자체는 막지
/// 않는다.
enum PetTypeTag {
  dog,
  cat;

  static PetTypeTag? fromFirestore(String? value) {
    for (final e in PetTypeTag.values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

enum LifeStageTag {
  puppy,
  adult,
  senior;

  static LifeStageTag? fromFirestore(String? value) {
    for (final e in LifeStageTag.values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

/// `draft`(작성 중)·`hidden`(비공개)은 앱에 노출하지 않는다. `soldout`은
/// 보여주되 구매는 막는다. 앱이 읽을 수 있는 상태는 `active`/`soldout`뿐
/// 이다(`firestore.rules`가 그렇게 강제한다).
enum ProductStatus {
  draft,
  active,
  soldout,
  hidden;

  static ProductStatus fromFirestore(String? value) => ProductStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ProductStatus.draft,
      );
}

/// 배송 구분 — `bulky`(배변판·켄넬 등 부피 큰 상품)는 공급사가 다른 상품과
/// 따로 발송해 별도 배송비([ShippingPolicy.bulkyFee])가 붙는다. 값이 없거나
/// 모르는 값이면 `standard`.
enum ShippingClass {
  standard,
  bulky;

  static ShippingClass fromFirestore(String? value) => ShippingClass.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ShippingClass.standard,
      );
}

/// 상품 태그 — 지금은 재고 소진 후 판매 종료 예정 표시 하나만 쓴다.
const String kProductTagDiscontinuing = 'discontinuing';

/// 단일 옵션 축(색상/용량 등 — 처음엔 단순하게 하나의 목록으로만 둔다).
class ProductOption {
  final String id;
  final String name;
  final int extraPrice;
  final bool soldOut;

  const ProductOption({
    required this.id,
    required this.name,
    this.extraPrice = 0,
    this.soldOut = false,
  });

  factory ProductOption.fromFirestore(Map<String, dynamic> data) => ProductOption(
        id: data['id'] as String? ?? '',
        name: data['name'] as String? ?? '',
        extraPrice: (data['extraPrice'] as num?)?.toInt() ?? 0,
        soldOut: data['soldOut'] as bool? ?? false,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'extraPrice': extraPrice,
        'soldOut': soldOut,
      };
}

/// `products/{productId}` 문서. 가격·주문 확정은 서버 몫이라는 원칙
/// ("쇼핑 기초" 지시서 0)에 따라, 이 모델은 어디까지나 "지금 콘솔에 등록된
/// 값을 읽어 보여주는" 용도다 — 클라이언트가 이 값을 믿고 주문을
/// 확정하지 않는다(주문 생성은 결제대기 상태까지만, 승인은 나중에 서버).
class Product {
  final String id;
  final String sellerId;
  final String name;
  final ProductCategory category;
  final List<PetTypeTag> petTypes;
  final List<LifeStageTag> lifeStages;
  final double? weightMinKg;
  final double? weightMaxKg;
  final int price;
  final int? salePrice;
  final List<String> images;
  final String description;
  final List<ProductOption> options;
  final Map<String, String> notice;

  /// [notice]를 보여줄 순서 — Firestore 맵은 키 순서를 보존하지 않아 따로
  /// 저장한다. 비어 있으면 [notice] 키 순서 그대로. [orderedNotice] 참고.
  final List<String> noticeKeys;
  final ProductStatus status;
  final int sortOrder;
  final ShippingClass shippingClass;

  /// 최소 주문 수량(1 미만 값은 1로 보정).
  final int minQty;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.sellerId,
    required this.name,
    this.category = ProductCategory.etc,
    this.petTypes = const [],
    this.lifeStages = const [],
    this.weightMinKg,
    this.weightMaxKg,
    required this.price,
    this.salePrice,
    this.images = const [],
    this.description = '',
    this.options = const [],
    this.notice = const {},
    this.noticeKeys = const [],
    this.status = ProductStatus.draft,
    this.sortOrder = 0,
    this.shippingClass = ShippingClass.standard,
    this.minQty = 1,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// 화면에 보여줄 "실제 가격" — 할인가가 있으면 할인가, 없으면 정가.
  int get displayPrice => salePrice ?? price;

  bool get isOnSale => salePrice != null && salePrice! < price;

  bool get isPurchasable => status == ProductStatus.active;

  bool get isBulky => shippingClass == ShippingClass.bulky;

  /// 상품정보제공고시를 표시 순서대로 — [noticeKeys] 순서를 따르고(값이
  /// 없는 키는 건너뜀), [noticeKeys]에 없고 [notice]에만 있는 키는 뒤에 붙인다.
  List<MapEntry<String, String>> get orderedNotice {
    final seen = <String>{};
    return [
      for (final key in noticeKeys)
        if (notice.containsKey(key) && seen.add(key)) MapEntry(key, notice[key]!),
      for (final entry in notice.entries)
        if (seen.add(entry.key)) entry,
    ];
  }

  /// 재고 소진 후 판매 종료 예정 — 상세에서만 회색 칩으로 알린다.
  bool get isDiscontinuing => tags.contains(kProductTagDiscontinuing);

  factory Product.fromFirestore(String id, Map<String, dynamic> data) => Product(
        id: id,
        sellerId: data['sellerId'] as String? ?? '',
        name: data['name'] as String? ?? '',
        category: ProductCategory.fromFirestore(data['category'] as String?),
        petTypes: (data['petTypes'] as List<dynamic>? ?? const [])
            .map((e) => PetTypeTag.fromFirestore(e as String?))
            .whereType<PetTypeTag>()
            .toList(),
        lifeStages: (data['lifeStages'] as List<dynamic>? ?? const [])
            .map((e) => LifeStageTag.fromFirestore(e as String?))
            .whereType<LifeStageTag>()
            .toList(),
        weightMinKg: (data['weightMinKg'] as num?)?.toDouble(),
        weightMaxKg: (data['weightMaxKg'] as num?)?.toDouble(),
        price: (data['price'] as num?)?.toInt() ?? 0,
        salePrice: (data['salePrice'] as num?)?.toInt(),
        images: (data['images'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
        description: data['description'] as String? ?? '',
        options: (data['options'] as List<dynamic>? ?? const [])
            .map((e) => ProductOption.fromFirestore(e as Map<String, dynamic>))
            .toList(),
        notice: (data['notice'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, v as String)),
        noticeKeys: (data['noticeKeys'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        status: ProductStatus.fromFirestore(data['status'] as String?),
        sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
        shippingClass: ShippingClass.fromFirestore(data['shippingClass'] as String?),
        minQty: _atLeastOne((data['minQty'] as num?)?.toInt()),
        tags: (data['tags'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
        'sellerId': sellerId,
        'name': name,
        'category': category.name,
        'petTypes': petTypes.map((e) => e.name).toList(),
        'lifeStages': lifeStages.map((e) => e.name).toList(),
        'weightMinKg': weightMinKg,
        'weightMaxKg': weightMaxKg,
        'price': price,
        'salePrice': salePrice,
        'images': images,
        'description': description,
        'options': options.map((e) => e.toFirestore()).toList(),
        'notice': notice,
        'noticeKeys': noticeKeys,
        'status': status.name,
        'sortOrder': sortOrder,
        'shippingClass': shippingClass.name,
        'minQty': minQty,
        'tags': tags,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

int _atLeastOne(int? value) => value == null || value < 1 ? 1 : value;
