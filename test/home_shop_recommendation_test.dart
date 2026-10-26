import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/shop/data/shop_repository.dart';
import 'package:petcliniccheck/shop/models/cart_item.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/models/seller.dart';
import 'package:petcliniccheck/shop/models/shop_order.dart';
import 'package:petcliniccheck/shop/providers/shop_providers.dart';
import 'package:petcliniccheck/widgets/home_shop_recommendation.dart';

class _FakeShopRepository implements ShopRepository {
  final List<Product> products;

  _FakeShopRepository(this.products);

  @override
  Future<ProductPage> fetchProducts({
    ProductCategory? category,
    PetTypeTag? petType,
    LifeStageTag? lifeStage,
    int limit = 20,
    Object? cursor,
  }) async =>
      ProductPage(products: products);

  @override
  Future<Seller?> fetchSeller(String sellerId) async => const Seller(id: 's1', name: '아깽이상점', status: SellerStatus.active);

  @override
  Future<Product?> fetchProduct(String productId) => throw UnimplementedError();

  @override
  Future<void> addToCart(String uid, {required String productId, String? optionId, int quantity = 1}) =>
      throw UnimplementedError();

  @override
  Future<void> clearCart(String uid) => throw UnimplementedError();

  @override
  Future<ShopOrder> createPendingOrder({
    required String uid,
    required List<OrderItem> items,
    required Map<String, int> shippingFees,
    required ShippingAddress shippingAddress,
  }) =>
      throw UnimplementedError();

  @override
  Future<ShopOrder?> fetchOrder(String orderId) => throw UnimplementedError();

  @override
  Future<void> removeFromCart(String uid, String itemId) => throw UnimplementedError();

  @override
  Stream<List<CartItem>> streamCart(String uid) => Stream.value(const []);

  @override
  Stream<List<ShopOrder>> streamMyOrders(String uid) => throw UnimplementedError();

  @override
  Future<void> updateCartQuantity(String uid, String itemId, int quantity) => throw UnimplementedError();
}

Product _activeProduct(String id) => Product(
      id: id,
      sellerId: 's1',
      name: '상품 $id',
      price: 15000,
      status: ProductStatus.active,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// 홈 "쇼핑 추천" 섹션("방향 개편" 지시서 B-6) — 쇼핑이 꺼져 있거나 판매
/// 중 상품이 없으면 아무것도 그리지 않는다(빈 칸·준비 중 문구도 없음).
/// 로그인 상태 분기(개인화 추천)는 실제 FirebaseAuth [User] 인스턴스를
/// 이 테스트 환경에서 만들 수 없어(다른 화면들과 같은 제약) 다루지
/// 않는다 — 순수 선택 로직은 select_home_shop_preview_test.dart가 덮는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWith(WidgetTester tester, {required bool shopEnabled, required List<Product> products}) async {
    final firestore = FakeFirebaseFirestore();
    if (shopEnabled) {
      await firestore.collection('config').doc('shop').set({'enabled': true});
    }
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopFirestoreProvider.overrideWithValue(firestore),
          shopRepositoryProvider.overrideWithValue(_FakeShopRepository(products)),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeShopRecommendation())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('쇼핑이 꺼져 있으면 판매 중 상품이 있어도 아무것도 그리지 않는다', (tester) async {
    await pumpWith(tester, shopEnabled: false, products: [_activeProduct('p1')]);

    expect(find.text('펫클 쇼핑'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('쇼핑이 켜져 있어도 판매 중 상품이 없으면 아무것도 그리지 않는다', (tester) async {
    await pumpWith(tester, shopEnabled: true, products: const []);

    expect(find.text('펫클 쇼핑', skipOffstage: false), findsNothing);
  });

  testWidgets('쇼핑이 켜져 있고 판매 중 상품이 있으면(게스트) 상품 미리보기를 보여준다', (tester) async {
    await pumpWith(tester, shopEnabled: true, products: [_activeProduct('p1'), _activeProduct('p2')]);

    expect(find.text('펫클 쇼핑'), findsOneWidget);
    expect(find.text('전체 보기'), findsOneWidget);
    expect(find.text('상품 p1'), findsOneWidget);
    expect(find.text('상품 p2'), findsOneWidget);
  });
}
