import 'package:cloud_firestore/cloud_firestore.dart';

/// 상품 대분류 — 자유 입력이 아니라 콘솔에서 고정된 값만 고르게 한다.
enum ProductCategory {
  food,
  treat,
  supplement,
  hygiene,
  toy,
  living,
  etc;

  static ProductCategory fromFirestore(String? value) => ProductCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ProductCategory.etc,
      );
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
  final ProductStatus status;
  final int sortOrder;
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
    this.status = ProductStatus.draft,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 화면에 보여줄 "실제 가격" — 할인가가 있으면 할인가, 없으면 정가.
  int get displayPrice => salePrice ?? price;

  bool get isOnSale => salePrice != null && salePrice! < price;

  bool get isPurchasable => status == ProductStatus.active;

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
        status: ProductStatus.fromFirestore(data['status'] as String?),
        sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
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
        'status': status.name,
        'sortOrder': sortOrder,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
