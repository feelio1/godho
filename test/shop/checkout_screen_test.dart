import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/shop/data/shop_repository.dart';
import 'package:petcliniccheck/shop/models/cart_item.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/models/seller.dart';
import 'package:petcliniccheck/shop/models/shop_order.dart';
import 'package:petcliniccheck/shop/pricing.dart';
import 'package:petcliniccheck/shop/providers/shop_providers.dart';
import 'package:petcliniccheck/shop/screens/checkout_screen.dart';

/// 결제 게이트웨이가 없는 지금("쇼핑 기초" 지시서 0·4·5-4) 결제 버튼은
/// 배송지·동의를 전부 채워도 비활성 상태이고, 주문 문서도 만들지 않는다
/// — [paymentGatewayProvider]가 null을 돌려주는 기본 동작 그대로 쓴다
/// (따로 오버라이드하지 않음).
class _FakeShopRepository implements ShopRepository {
  int createPendingOrderCallCount = 0;
  final Seller seller;

  _FakeShopRepository(this.seller);

  @override
  Future<Seller?> fetchSeller(String sellerId) async => seller;

  @override
  Future<ShopOrder> createPendingOrder({
    required String uid,
    required List<OrderItem> items,
    required Map<String, int> shippingFees,
    required ShippingAddress shippingAddress,
  }) async {
    createPendingOrderCallCount++;
    throw UnimplementedError('이 테스트에서는 호출되면 안 된다');
  }

  @override
  Future<void> addToCart(String uid, {required String productId, String? optionId, int quantity = 1}) =>
      throw UnimplementedError();

  @override
  Future<void> clearCart(String uid) => throw UnimplementedError();

  @override
  Future<ProductPage> fetchProducts({
    ProductCategory? category,
    PetTypeTag? petType,
    LifeStageTag? lifeStage,
    int limit = 20,
    Object? cursor,
  }) =>
      throw UnimplementedError();

  @override
  Future<Product?> fetchProduct(String productId) => throw UnimplementedError();

  @override
  Future<ShopOrder?> fetchOrder(String orderId) => throw UnimplementedError();

  @override
  Future<void> removeFromCart(String uid, String itemId) => throw UnimplementedError();

  @override
  Stream<List<CartItem>> streamCart(String uid) => throw UnimplementedError();

  @override
  Stream<List<ShopOrder>> streamMyOrders(String uid) => throw UnimplementedError();

  @override
  Future<void> updateCartQuantity(String uid, String itemId, int quantity) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Product sampleProduct() => Product(
        id: 'p1',
        sellerId: 's1',
        name: '강아지 사료 1kg',
        price: 20000,
        status: ProductStatus.active,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Seller sampleSeller() => const Seller(
        id: 's1',
        name: '아깽이상점',
        status: SellerStatus.active,
        shipping: ShippingPolicy(baseFee: 3000),
      );

  testWidgets('결제 게이트웨이가 없으면(기본 상태) 배송지·동의를 전부 채워도 결제 버튼은 비활성이고, 주문이 만들어지지 않는다', (tester) async {
    final fakeRepo = _FakeShopRepository(sampleSeller());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [shopRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(
          home: CheckoutScreen(lines: [CartLine(product: sampleProduct(), quantity: 1)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 결제 준비 중 안내가 보인다.
    expect(find.text('결제 준비 중이에요'), findsOneWidget);

    // 배송지를 전부 채운다.
    await tester.enterText(find.widgetWithText(TextField, '받는 사람'), '홍길동');
    await tester.enterText(find.widgetWithText(TextField, '연락처'), '01000000000');
    await tester.enterText(find.widgetWithText(TextField, '우편번호'), '12345');
    await tester.enterText(find.widgetWithText(TextField, '주소'), '서울시 어딘가');
    await tester.pumpAndSettle();

    // 필수 동의 2개를 모두 체크한다(ListView 아래쪽이라 스크롤부터).
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('주문 내용 확인 및 결제 진행 동의'), 300, scrollable: scrollable);
    await tester.pumpAndSettle();
    final agreements = find.byType(CheckboxListTile);
    expect(agreements, findsNWidgets(2));
    await tester.tap(agreements.at(0));
    await tester.pump();
    await tester.tap(agreements.at(1));
    await tester.pumpAndSettle();

    // 그래도 결제 버튼은 비활성이다(게이트웨이가 없어서).
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '결제하기'));
    expect(button.onPressed, isNull);

    expect(fakeRepo.createPendingOrderCallCount, 0);
  });
}
