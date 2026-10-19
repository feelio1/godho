import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/screens/shop_screen.dart';

/// 쇼핑 탭 "준비 중" 화면("탭 개편" 지시서 C) — 게스트·회원 게이팅 없이
/// 누구나 볼 수 있고, 가짜 상품·가격·사전 예약 같은 미끼 요소가 없는지
/// 확인한다. 입점 문의 탭은 메일 앱(url_launcher)을 실제로 여는
/// 플랫폼 호출이라 이 테스트 환경에서 탭까지는 하지 않는다 — 버튼이
/// 보이는지만 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('제목·본문·입점 문의 버튼이 보이고, 미끼 요소(가격·사전예약 등)는 없다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShopScreen()));
    await tester.pump();

    expect(find.text('쇼핑'), findsOneWidget);
    expect(find.text('펫클 쇼핑, 곧 열려요'), findsOneWidget);
    expect(find.text('펫클이 직접 고른 반려용품과 간식을 준비하고 있어요.'), findsOneWidget);
    expect(find.text('브랜드 입점 문의'), findsOneWidget);

    expect(find.textContaining('사전 예약'), findsNothing);
    expect(find.textContaining('원'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
