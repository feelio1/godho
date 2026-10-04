import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/screens/login_screen.dart';

/// v1 출시 범위는 구글 + 이메일 + 게스트다("v1 출시 준비" 지시서 1) —
/// 카카오·애플 버튼은 기본 플래그(false)에서 보이지 않아야 하고, 관련
/// 코드 삭제가 아니라 "숨김"이므로 버튼 탭 핸들러(`_handleKakao`/
/// `_handleApple`)는 여전히 코드에 남아 있다(이 테스트는 화면에
/// 노출되지 않는지만 확인한다).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('카카오·애플 버튼은 보이지 않고, 구글·이메일만 노출된다', (tester) async {
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
}
