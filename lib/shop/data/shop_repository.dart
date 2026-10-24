import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../models/shop_order.dart';

/// 상품 목록 한 페이지("쇼핑 기초" 지시서 4 — 페이지네이션 20개). [cursor]는
/// 호출부가 내용을 들여다보지 않고 그대로 다음 호출에 돌려주기만 하는
/// 불투명 값이다(Firestore 구현은 내부적으로 [DocumentSnapshot]을 담아
/// 두지만, 인터페이스 자체는 Firestore를 모른다).
class ProductPage {
  final List<Product> products;
  final Object? cursor;
  final bool hasMore;

  const ProductPage({required this.products, this.cursor, this.hasMore = false});

  static const empty = ProductPage(products: []);
}

/// 쇼핑 데이터 접근 인터페이스 — 화면은 이 인터페이스만 보고, 실제 구현은
/// [FirestoreShopRepository]다(테스트는 가짜 구현이나 `fake_cloud_firestore`
/// 로 바꿔 끼운다). 가격·주문 확정은 서버 몫이라는 원칙에 따라, 이 쪽에
/// 있는 쓰기 메서드는 장바구니(개인 소유 데이터)와 "결제대기 주문
/// 생성"뿐이다 — 주문 상태 변경 메서드는 의도적으로 없다.
abstract class ShopRepository {
  Future<ProductPage> fetchProducts({
    ProductCategory? category,
    PetTypeTag? petType,
    LifeStageTag? lifeStage,
    int limit = 20,
    Object? cursor,
  });

  Future<Product?> fetchProduct(String productId);

  Future<Seller?> fetchSeller(String sellerId);

  Stream<List<CartItem>> streamCart(String uid);

  Future<void> addToCart(String uid, {required String productId, String? optionId, int quantity = 1});

  Future<void> updateCartQuantity(String uid, String itemId, int quantity);

  Future<void> removeFromCart(String uid, String itemId);

  Future<void> clearCart(String uid);

  /// 결제대기(`pendingPayment`) 주문을 만든다 — 그 외 상태로는 만들 수
  /// 없다(`firestore.rules`가 서버/관리자 외 상태 변경을 막는다).
  Future<ShopOrder> createPendingOrder({
    required String uid,
    required List<OrderItem> items,
    required Map<String, int> shippingFees,
    required ShippingAddress shippingAddress,
  });

  Stream<List<ShopOrder>> streamMyOrders(String uid);

  Future<ShopOrder?> fetchOrder(String orderId);
}
