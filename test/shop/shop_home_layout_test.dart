import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/providers/effective_pets_provider.dart';
import 'package:petcliniccheck/shop/data/shop_repository.dart';
import 'package:petcliniccheck/shop/models/cart_item.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/models/seller.dart';
import 'package:petcliniccheck/shop/providers/shop_providers.dart';
import 'package:petcliniccheck/shop/screens/shop_home_screen.dart';
import 'package:petcliniccheck/theme/app_theme.dart';

class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeShopRepository implements ShopRepository {
  final List<Product> products;
  final List<CartItem> cart;

  _FakeShopRepository({required this.products, this.cart = const []});

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
  Future<Seller?> fetchSeller(String sellerId) async => null;

  @override
  Stream<List<CartItem>> streamCart(String uid) => Stream.value(cart);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

Product _product(String id, String name, {int price = 10300}) => Product(
      id: id,
      sellerId: 'aggaeng',
      name: name,
      category: ProductCategory.apparel,
      price: price,
      status: ProductStatus.active,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

/// 스토어 홈 카드 높이는 "카드 폭 + 실제 글꼴로 잰 글자 영역" — 폭이 바뀌어도
/// 상품명 2줄 + 가격이 넘치지 않아야 한다. 앱과 같은 IBM Plex Sans KR로 잰다.
void main() {
  setUpAll(() async {
    final plex = FontLoader('IBM Plex Sans KR');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      plex.addFont(Future.value(ByteData.sublistView(File('assets/fonts/IBMPlexSansKR-$weight.ttf').readAsBytesSync())));
    }
    await plex.load();
    // AdMob 배너는 테스트에 플랫폼 구현이 없다 — 빈 응답(배너 미표시).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'plugins.flutter.io/google_mobile_ads',
      (message) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
    );
  });

  final products = [
    _product('a', '강아지 비건 수제간식 5종 아주 긴 이름이 두 줄을 넘어가는 경우까지'),
    _product('b', '튼튼요정견 황태져키 200g'),
    _product('c', '강아지 후드티'),
    _product('d', '강아지 레이어드 맨투맨', price: 1234567),
  ];

  Future<void> pumpAt(WidgetTester tester, double width, {List<CartItem> cart = const []}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        shopRepositoryProvider.overrideWithValue(_FakeShopRepository(products: products, cart: cart)),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
        effectivePetsProvider.overrideWith((ref) async => const <Pet>[]),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const ShopHomeScreen()),
    ));
    await tester.pumpAndSettle();
  }

  for (final width in [360.0, 411.0, 600.0]) {
    testWidgets('폭 $width에서 상품 카드가 넘치지 않는다(상품명 2줄 + 가격)', (tester) async {
      await pumpAt(tester, width);
      expect(tester.takeException(), isNull);
      expect(find.text('강아지 레이어드 맨투맨'), findsOneWidget);
      expect(find.text('1,234,567원'), findsOneWidget);
    });
  }

  testWidgets('장바구니 배지는 수량 합계가 아니라 줄 수(상품·옵션 조합 수)', (tester) async {
    final now = DateTime(2026, 11, 9);
    await pumpAt(tester, 360, cart: [
      CartItem(id: 'c1', productId: 'c', optionId: 'o3', quantity: 2, addedAt: now),
      CartItem(id: 'c2', productId: 'kennel', optionId: 'o1', quantity: 1, addedAt: now),
      CartItem(id: 'c3', productId: 'bags', quantity: 10, addedAt: now),
    ]);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('13'), findsNothing);
  });
}
