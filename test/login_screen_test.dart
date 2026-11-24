import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/screens/login_screen.dart';

/// v1 출시 범위는 구글 + 이메일 + 게스트다("v1 출시 준비" 지시서 1) —
/// 카카오 버튼은 기본 플래그(false)에서 보이지 않아야 하고, 관련 코드
/// 삭제가 아니라 "숨김"이므로 버튼 탭 핸들러(`_handleKakao`)는 여전히
/// 코드에 남아 있다. 애플 버튼은 iOS 출시 준비(L-3)에서 켰고 iOS에서만
/// 보인다 — 테스트 기본 플랫폼(안드로이드)에서는 보이지 않는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('안드로이드: 카카오·애플 버튼은 보이지 않고, 구글·이메일만 노출된다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('카카오로 계속하기'), findsNothing);
    expect(find.text('Apple로 계속하기'), findsNothing);

    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '회원가입'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '비밀번호 찾기'), findsOneWidget);
  });

  testWidgets('구글 버튼: 공식 G 로고(assets/brand) + 흰 바탕·#747775 1px 테두리·알약 모양·높이 54', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    final button = find.byKey(const ValueKey('login_google'));
    expect(tester.getSize(button).height, 54);
    final image = tester.widget<Image>(find.descendant(of: button, matching: find.byType(Image)));
    expect((image.image as AssetImage).assetName, 'assets/brand/google_g.png');
    expect(image.width, 20);
    final style = tester.widget<OutlinedButton>(find.descendant(of: button, matching: find.byType(OutlinedButton))).style!;
    expect(style.backgroundColor!.resolve({}), Colors.white);
    expect(style.side!.resolve({}), const BorderSide(color: Color(0xFF747775)));
    expect(style.shape!.resolve({}), isA<StadiumBorder>());
  });

  testWidgets('iOS: 애플 버튼이 구글 버튼 위에, 같은 높이·너비·알약 모양으로 보인다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    final apple = find.byKey(const ValueKey('login_apple'));
    final google = find.byKey(const ValueKey('login_google'));
    expect(apple, findsOneWidget);
    expect(find.text('Apple로 계속하기'), findsOneWidget);
    expect(tester.getSize(apple), tester.getSize(google));
    expect(tester.getTopLeft(apple).dy, lessThan(tester.getTopLeft(google).dy));
    final style = tester.widget<FilledButton>(find.descendant(of: apple, matching: find.byType(FilledButton))).style!;
    expect(style.backgroundColor!.resolve({}), Colors.black);
    expect(style.shape!.resolve({}), isA<StadiumBorder>());
    // 카카오는 iOS에서도 그대로 숨김.
    expect(find.text('카카오로 계속하기'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  test('애플 버튼은 iOS에서만', () {
    for (final platform in TargetPlatform.values) {
      expect(showAppleSignIn(platform), platform == TargetPlatform.iOS, reason: '$platform');
    }
  });
}
