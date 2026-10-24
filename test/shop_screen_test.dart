import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/screens/shop_screen.dart';
import 'package:petcliniccheck/shop/providers/shop_providers.dart';
import 'package:petcliniccheck/shop/screens/shop_home_screen.dart';

/// 쇼핑 탭의 이중 스위치("쇼핑 기초" 지시서 1) — `config/shop` 문서가
/// 없거나 `enabled`가 false면 기존 "준비 중" 화면 그대로(가짜 상품·가격·
/// 사전 예약 같은 미끼 요소 없음), `enabled`가 true일 때만 실제 스토어
/// 홈([ShopHomeScreen])으로 넘어간다. 컴파일 플래그 [kEnableShopCode]는
/// 상수(지금 빌드는 true)라 이 테스트에서 꺼볼 수는 없다 — Firestore
/// 쪽 분기만 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWith(WidgetTester tester, FakeFirebaseFirestore firestore) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [shopFirestoreProvider.overrideWithValue(firestore)],
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await tester.pump();
  }

  group('config/shop 문서가 없거나 꺼져 있으면(닫힘) 기존 준비 중 화면 그대로다', () {
    testWidgets('문서가 없을 때: 제목·본문·입점 문의 버튼이 보이고, 미끼 요소(가격·사전예약 등)는 없다', (tester) async {
      await pumpWith(tester, FakeFirebaseFirestore());

      expect(find.text('쇼핑'), findsOneWidget);
      expect(find.text('펫클 쇼핑, 곧 열려요'), findsOneWidget);
      expect(find.text('펫클이 직접 고른 반려용품과 간식을 준비하고 있어요.'), findsOneWidget);
      expect(find.text('브랜드 입점 문의'), findsOneWidget);
      expect(find.byType(ShopHomeScreen), findsNothing);

      expect(find.textContaining('사전 예약'), findsNothing);
      expect(find.textContaining('원'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('enabled: false일 때도 준비 중 화면 그대로다', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('config').doc('shop').set({'enabled': false});
      await pumpWith(tester, firestore);

      expect(find.text('펫클 쇼핑, 곧 열려요'), findsOneWidget);
      expect(find.byType(ShopHomeScreen), findsNothing);
    });
  });

  testWidgets('enabled: true면 스토어 홈으로 넘어간다', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('config').doc('shop').set({'enabled': true});
    await pumpWith(tester, firestore);

    expect(find.byType(ShopHomeScreen), findsOneWidget);
    expect(find.text('펫클 쇼핑, 곧 열려요'), findsNothing);
  });
}
