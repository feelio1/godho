import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/shop/data/shop_repository.dart';
import 'package:petcliniccheck/shop/models/cart_item.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/models/seller.dart';
import 'package:petcliniccheck/shop/pricing.dart';
import 'package:petcliniccheck/shop/providers/shop_providers.dart';
import 'package:petcliniccheck/shop/screens/checkout_screen.dart';
import 'package:petcliniccheck/shop/screens/product_detail_screen.dart';
import 'package:petcliniccheck/shop/screens/shop_home_screen.dart';

/// 직판형 전환 — 판매자 = 아깽이상점, 공급사 위탁배송. 읽기만 하는 가짜 저장소.
class _FakeShopRepository implements ShopRepository {
  final List<Product> products;
  final Seller seller;

  _FakeShopRepository({required this.products, required this.seller});

  @override
  Future<ProductPage> fetchProducts({
    ProductCategory? category,
    PetTypeTag? petType,
    LifeStageTag? lifeStage,
    int limit = 20,
    Object? cursor,
  }) async =>
      ProductPage(products: [for (final p in products) if (category == null || p.category == category) p]);

  @override
  Future<Product?> fetchProduct(String productId) async => products.where((p) => p.id == productId).firstOrNull;

  @override
  Future<Seller?> fetchSeller(String sellerId) async => seller;

  @override
  Stream<List<CartItem>> streamCart(String uid) => Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

const _aggaeng = Seller(
  id: 'aggaeng',
  name: '아깽이상점',
  status: SellerStatus.active,
  shipping: ShippingPolicy(baseFee: 3000, freeOver: 30000, extraJejuFee: 3000, bulkyFee: 4000),
);

Product _product(
  String id, {
  String name = '상품',
  ProductCategory category = ProductCategory.living,
  int price = 10000,
  ShippingClass shippingClass = ShippingClass.standard,
  int minQty = 1,
  List<String> tags = const [],
  Map<String, String> notice = const {},
}) =>
    Product(
      id: id,
      sellerId: 'aggaeng',
      name: name,
      category: category,
      price: price,
      status: ProductStatus.active,
      shippingClass: shippingClass,
      minQty: minQty,
      tags: tags,
      notice: notice,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

Widget _app(List<Product> products, Widget home) => ProviderScope(
      overrides: [
        shopRepositoryProvider.overrideWithValue(_FakeShopRepository(products: products, seller: _aggaeng)),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      ],
      child: MaterialApp(home: home),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('상품 상세', () {
    testWidgets('따로 배송·최소 수량·판매 종료 예정 안내, 수량은 최소 수량부터', (tester) async {
      final product = _product(
        'kennel',
        name: '켄넬',
        shippingClass: ShippingClass.bulky,
        minQty: 10,
        tags: const [kProductTagDiscontinuing],
      );
      await tester.pumpWidget(_app([product], const ProductDetailScreen(productId: 'kennel')));
      await tester.pumpAndSettle();

      expect(find.text('다른 상품과 따로 배송돼요 · 배송비 4,000원'), findsOneWidget);
      expect(find.text('10개부터 주문할 수 있어요'), findsOneWidget);
      expect(find.text('재고 소진 시 판매 종료'), findsOneWidget);
      // 압박 문구 없음.
      expect(find.textContaining('마감'), findsNothing);
      expect(find.textContaining('서두르'), findsNothing);

      // 수량은 10에서 시작하고, 10에서는 줄일 수 없다.
      expect(find.text('10'), findsOneWidget);
      IconButton minus() => tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove_circle_outline));
      expect(minus().onPressed, isNull);
      await tester.ensureVisible(find.widgetWithIcon(IconButton, Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline));
      await tester.pump();
      expect(find.text('11'), findsOneWidget);
      expect(minus().onPressed, isNotNull);
    });

    testWidgets('일반 상품은 안내 없음, 이미지가 없으면 중립 플레이스홀더, 하단은 직판 고지', (tester) async {
      await tester.pumpWidget(_app([_product('p1', name: '배변봉투')], const ProductDetailScreen(productId: 'p1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('따로 배송'), findsNothing);
      expect(find.textContaining('개부터 주문'), findsNothing);
      expect(find.text('재고 소진 시 판매 종료'), findsNothing);
      expect(find.byIcon(Icons.pets), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.textContaining('이 상품의 판매자는 아깽이상점입니다'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('공급업체에서 직접 발송되며'), findsOneWidget);
      expect(find.textContaining('통신판매중개자'), findsNothing);
    });

    testWidgets('좁은 폭에서 긴 고시 라벨은 라벨 위·값 아래 2줄로, "확인 필요"도 그대로 보인다', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final product = _product('p1', notice: const {
        '법에 의한 인증·허가 사항': '확인 필요',
        '사료의 종류·형태·용도': '단미사료 · 펠릿사료 · 애완동물용',
      });
      await tester.pumpWidget(_app([product], const ProductDetailScreen(productId: 'p1')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('상품정보제공고시'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('상품정보제공고시'));
      await tester.pumpAndSettle();

      final label = find.text('법에 의한 인증·허가 사항');
      final value = find.text('확인 필요');
      expect(label, findsOneWidget);
      expect(value, findsOneWidget);
      // 라벨이 한 줄로 놓이고(세로로 쪼개지지 않음), 값은 라벨 아래에 온다.
      expect(tester.getSize(label).height, lessThan(24));
      expect(tester.getTopLeft(value).dy, greaterThan(tester.getBottomLeft(label).dy - 1));
    });
  });

  group('주문서', () {
    testWidgets('따로 배송 상품이 있으면 배송비 합계 아래에 내역을, 동의 문구는 공급업체 제공', (tester) async {
      final lines = [
        CartLine(product: _product('a', price: 30000), quantity: 1),
        CartLine(product: _product('kennel', shippingClass: ShippingClass.bulky), quantity: 2),
      ];
      await tester.pumpWidget(_app(const [], CheckoutScreen(lines: lines)));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('배송비 합계'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('· 따로 배송 상품 1종 4,000원'), findsOneWidget);
      expect(find.text('4,000원'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('배송을 위한 개인정보 제3자 제공 동의 (상품 공급업체)'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('개인정보 판매자 제공 동의'), findsNothing);
    });

    testWidgets('따로 배송 상품이 없으면 내역 줄을 그리지 않는다', (tester) async {
      await tester.pumpWidget(_app(const [], CheckoutScreen(lines: [CartLine(product: _product('a'), quantity: 1)])));
      await tester.pumpAndSettle();
      expect(find.textContaining('따로 배송 상품'), findsNothing);
    });
  });

  group('스토어 홈 카테고리 칩', () {
    test('상품이 있는 카테고리만, 선언 순서(옷은 간식 다음)', () {
      expect(
        visibleShopCategories({ProductCategory.living, ProductCategory.apparel, ProductCategory.treat}),
        [ProductCategory.treat, ProductCategory.apparel, ProductCategory.living],
      );
      expect(visibleShopCategories(const {}), isEmpty);
    });

    testWidgets('사료·영양제처럼 상품이 없는 칩은 보이지 않는다', (tester) async {
      await tester.pumpWidget(_app([
        _product('t', category: ProductCategory.treat),
        _product('c', category: ProductCategory.apparel),
      ], const ShopHomeScreen()));
      await tester.pumpAndSettle();

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).map((c) => (c.label as Text).data).toList();
      expect(chips, ['전체', '간식', '옷']);
      expect(find.text('사료'), findsNothing);
      expect(find.text('영양제'), findsNothing);
    });
  });
}
