// 쇼핑 화면 미리보기 스크린샷 — 실기기 없이 화면을 이미지로 확인하려고 둔
// 골든 테스트. 폰트·플랫폼에 따라 픽셀이 달라지므로 기본 `flutter test`에서는
// 제외하고(`dart_test.yaml`의 screenshots 태그), 찍을 때만 실행한다:
//
//   flutter test --run-skipped --tags screenshots --update-goldens test/shop/screenshots
//
// 결과 PNG는 docs/screenshots/shop/ 에 저장된다.
@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/providers/effective_pets_provider.dart';
import 'package:petcliniccheck/screens/shop_screen.dart';
import 'package:petcliniccheck/shop/data/firestore_shop_repository.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/models/seller.dart';
import 'package:petcliniccheck/shop/pricing.dart';
import 'package:petcliniccheck/shop/providers/shop_providers.dart';
import 'package:petcliniccheck/shop/screens/cart_screen.dart';
import 'package:petcliniccheck/shop/screens/checkout_screen.dart';
import 'package:petcliniccheck/shop/screens/product_detail_screen.dart';
import 'package:petcliniccheck/theme/app_theme.dart';

/// 다른 테스트와 같은 가짜 로그인 — 실제 FirebaseAuth [User]는 만들 수 없어
/// uid만 돌려준다.
class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _hoodie = 'nr-pftcbb58mpvf';
const _hoodieM = 'o3'; // 그레이 / M
const _kennel = 'nr-6yrw26savsn6';
const _kennelSmall = 'o1'; // 켄넬(소)
const _pooBag1p = 'nr-f5shengfqtva';
const _jerky = 'nr-ubzzsbzu6n5g'; // 튼튼요정견 황태져키 200g

const _out = '../../../docs/screenshots/shop';

List<Map<String, dynamic>> _readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();

/// 앱과 같은 글꼴로 그린다 — 기본 테스트 글꼴(Ahem)이면 글자가 네모로 나온다.
Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async => ByteData.sublistView(await File(path).readAsBytes());

  final plex = FontLoader('IBM Plex Sans KR');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    plex.addFont(bytes('assets/fonts/IBMPlexSansKR-$weight.ttf'));
  }
  await plex.load();

  final mono = FontLoader('IBM Plex Mono')
    ..addFont(bytes('assets/fonts/IBMPlexMono-Regular.ttf'))
    ..addFont(bytes('assets/fonts/IBMPlexMono-Medium.ttf'));
  await mono.load();

  // 아이콘(플레이스홀더·수량 버튼 등)도 네모가 되지 않게 Flutter SDK의 아이콘 글꼴.
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, dynamic>;
  final flutterRoot = Uri.parse(
    (config['packages'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == 'flutter')['rootUri']
        as String,
  ).toFilePath();
  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('$flutterRoot/../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

/// 앱 테마 그대로 — 단, 칩 라벨(`chipTheme.labelStyle`)은 글꼴이 지정돼 있지
/// 않아 기기에선 시스템 한글 글꼴로 대체돼 그려지는데, 테스트에는 대체 글꼴이
/// 없어 네모가 된다. 스크린샷에서만 그 자리를 IBM Plex로 채운다(기기의 칩
/// 글자 모양과는 조금 다를 수 있다). 앱 코드는 바꾸지 않는다.
ThemeData _screenshotTheme() {
  final theme = AppTheme.light();
  return theme.copyWith(
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: (theme.chipTheme.labelStyle ?? const TextStyle()).copyWith(fontFamily: 'IBM Plex Sans KR'),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late Map<String, Product> products;
  late Seller seller;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    // AdMob 배너는 테스트에 플랫폼 구현이 없다 — 모든 호출에 빈 성공으로 답해
    // 광고가 로드되지 않은 상태(배너 자리 없음)로 찍는다. 앱 코드는 그대로.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'plugins.flutter.io/google_mobile_ads',
      (message) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
    );
  });

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final productDocs = _readJson('tool/shop_import/out/products.json');
    for (final p in productDocs) {
      await firestore.collection('products').doc(p['id'] as String).set(p);
    }
    final sellerDoc = _readJson('tool/shop_import/out/sellers.json').single;
    await firestore.collection('sellers').doc(sellerDoc['id'] as String).set(sellerDoc);
    await firestore.collection('config').doc('shop').set({'enabled': true});
    // 07·08: 후드티 M 2개 + 켄넬 1개 + 배변봉투 1P 10개.
    final cart = firestore.collection('users').doc('u1').collection('cart');
    final addedAt = Timestamp.fromDate(DateTime(2026, 11, 9, 10));
    await cart.doc('c1').set({'productId': _hoodie, 'optionId': _hoodieM, 'quantity': 2, 'addedAt': addedAt});
    await cart.doc('c2').set({'productId': _kennel, 'optionId': _kennelSmall, 'quantity': 1, 'addedAt': addedAt});
    await cart.doc('c3').set({'productId': _pooBag1p, 'optionId': null, 'quantity': 10, 'addedAt': addedAt});

    products = {for (final p in productDocs) p['id'] as String: Product.fromFirestore(p['id'] as String, p)};
    seller = Seller.fromFirestore(sellerDoc['id'] as String, sellerDoc);
  });

  List<Override> overrides() => [
        shopFirestoreProvider.overrideWithValue(firestore),
        shopRepositoryProvider.overrideWithValue(FirestoreShopRepository(firestore: firestore)),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
        effectivePetsProvider.overrideWith((ref) async => const <Pet>[]),
      ];

  /// 레이아웃 넘침(RenderFlex overflowed)은 테스트를 깨지 않고 그대로 찍는다 —
  /// 스크린샷의 목적이 "지금 화면이 어떻게 보이는지"라서, 넘침 줄무늬가 찍힌
  /// 채로 남기고 콘솔에 알린다. 다른 오류는 그대로 실패시킨다.
  Future<void> recordingOverflows(String name, Future<void> Function() body) async {
    final original = FlutterError.onError;
    final overflows = <String>{};
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('overflowed')) {
        overflows.add(message.split('\n').first);
      } else {
        original?.call(details);
      }
    };
    try {
      await body();
    } finally {
      FlutterError.onError = original;
      for (final o in overflows) {
        debugPrint('[screenshots] $name: $o');
      }
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(720, 1600); // 360×800, devicePixelRatio 2
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: _screenshotTheme(), home: home),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/$name.png'));

  Future<void> scrollBy(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(Scrollable).first, Offset(0, -dy));
    await tester.pumpAndSettle();
  }

  testWidgets('01 스토어 홈(전체)', (tester) async {
    await recordingOverflows('01 스토어 홈(전체)', () async {
      await pump(tester, const ShopScreen());
      await shot('01_home_all_a');
      await scrollBy(tester, 640);
      await shot('01_home_all_b');
    });
  });

  testWidgets('02 스토어 홈(옷 칩 선택)', (tester) async {
    await recordingOverflows('02 스토어 홈(옷 칩 선택)', () async {
      await pump(tester, const ShopScreen());
      await tester.tap(find.widgetWithText(ChoiceChip, '옷'));
      await tester.pumpAndSettle();
      await shot('02_home_apparel');
    });
  });

  testWidgets('03 후드티 상세(옵션)', (tester) async {
    await recordingOverflows('03 후드티 상세(옵션)', () async {
      await pump(tester, const ProductDetailScreen(productId: _hoodie));
      await tester.tap(find.widgetWithText(ChoiceChip, '그레이 / M'));
      await tester.pumpAndSettle();
      await shot('03_detail_hoodie');
    });
  });

  testWidgets('04 켄넬 상세(따로 배송 안내)', (tester) async {
    await recordingOverflows('04 켄넬 상세(따로 배송 안내)', () async {
      await pump(tester, const ProductDetailScreen(productId: _kennel));
      await shot('04_detail_kennel');
    });
  });

  testWidgets('05 배변봉투 1P 상세(10개부터)', (tester) async {
    await recordingOverflows('05 배변봉투 1P 상세(10개부터)', () async {
      await pump(tester, const ProductDetailScreen(productId: _pooBag1p));
      await shot('05_detail_pooBag1p');
    });
  });

  testWidgets('06 황태져키 상세(판매 종료 칩, 상품정보제공고시 펼침)', (tester) async {
    await recordingOverflows('06 황태져키 상세(판매 종료 칩, 상품정보제공고시 펼침)', () async {
      await pump(tester, const ProductDetailScreen(productId: _jerky));
      await shot('06_detail_jerky_notice_a');
      final notice = find.text('상품정보제공고시');
      await tester.scrollUntilVisible(notice, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(notice);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(notice, -50, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, Offset(0, tester.getTopLeft(notice).dy - 120));
      await tester.pumpAndSettle();
      await shot('06_detail_jerky_notice_b');
    });
  });

  testWidgets('07 장바구니', (tester) async {
    await recordingOverflows('07 장바구니', () async {
      await pump(tester, const CartScreen());
      await shot('07_cart');
    });
  });

  testWidgets('08 주문서(위 장바구니 그대로)', (tester) async {
    await recordingOverflows('08 주문서(위 장바구니 그대로)', () async {
      final hoodie = products[_hoodie]!;
      final kennel = products[_kennel]!;
      final lines = [
        CartLine(product: hoodie, option: hoodie.options.firstWhere((o) => o.id == _hoodieM), quantity: 2),
        CartLine(product: kennel, option: kennel.options.firstWhere((o) => o.id == _kennelSmall), quantity: 1),
        CartLine(product: products[_pooBag1p]!, quantity: 10),
      ];
      expect(seller.shipping.bulkyFee, 4000);
      await pump(tester, CheckoutScreen(lines: lines));
      await shot('08_checkout_a');
      await tester.scrollUntilVisible(find.text('총 결제금액'), 300, scrollable: find.byType(Scrollable).first);
      await scrollBy(tester, 160);
      await shot('08_checkout_b');
    });
  });
}
