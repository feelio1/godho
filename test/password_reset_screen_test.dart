import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/screens/password_reset_screen.dart';

/// 이메일 형식 검증만 다룬다 — 통과하면 실제 FirebaseAuth
/// (`sendPasswordResetEmail`)를 호출하므로, 이 테스트 환경에서는
/// 검증 실패 경로만 확인한다("자체 회원가입·로그인·비밀번호 재설정"
/// 지시서 2, 6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('이메일 형식이 아니면 재설정 메일을 보내지 않고 안내한다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PasswordResetScreen()),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'example@email.com'), '이메일아님');
    await tester.tap(find.widgetWithText(FilledButton, '재설정 메일 보내기'));
    await tester.pump();

    expect(find.text('이메일 형식을 확인해주세요'), findsOneWidget);
  });
}
