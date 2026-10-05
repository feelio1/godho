import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/screens/signup_email_screen.dart';

/// 입력값 검증(이메일 형식/비밀번호 길이/비밀번호 확인 일치/이름 공백)
/// 만 다룬다 — 검증을 통과하면 실제 FirebaseAuth(`signUpWithEmail`)를
/// 호출하므로, 이 테스트 환경(FirebaseAuth 미초기화)에서는 검증
/// 실패 경로만 확인한다("자체 회원가입·로그인·비밀번호 재설정" 지시서
/// 1-1, 6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SignupEmailScreen()),
      ),
    );
  }

  testWidgets('이메일 형식이 아니면 가입을 막고 안내한다', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, 'example@email.com'), '이메일아님');
    await tester.enterText(find.widgetWithText(TextField, '6자 이상'), '123456');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호를 한 번 더 입력해주세요'), '123456');
    await tester.enterText(find.widgetWithText(TextField, '닉네임으로 써도 괜찮아요'), '테스터');

    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await tester.pump();

    expect(find.text('이메일 형식을 확인해주세요'), findsOneWidget);
  });

  testWidgets('비밀번호가 6자 미만이면 막고 안내한다', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, 'example@email.com'), 'user@example.com');
    await tester.enterText(find.widgetWithText(TextField, '6자 이상'), '123');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호를 한 번 더 입력해주세요'), '123');
    await tester.enterText(find.widgetWithText(TextField, '닉네임으로 써도 괜찮아요'), '테스터');

    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await tester.pump();

    expect(find.text('비밀번호는 6자 이상이어야 해요'), findsOneWidget);
  });

  testWidgets('비밀번호 확인이 일치하지 않으면 막고 안내한다', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, 'example@email.com'), 'user@example.com');
    await tester.enterText(find.widgetWithText(TextField, '6자 이상'), '123456');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호를 한 번 더 입력해주세요'), '654321');
    await tester.enterText(find.widgetWithText(TextField, '닉네임으로 써도 괜찮아요'), '테스터');

    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await tester.pump();

    expect(find.text('비밀번호가 일치하지 않아요'), findsOneWidget);
  });

  testWidgets('이름이 비어 있으면 막고 안내한다', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, 'example@email.com'), 'user@example.com');
    await tester.enterText(find.widgetWithText(TextField, '6자 이상'), '123456');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호를 한 번 더 입력해주세요'), '123456');

    await tester.tap(find.widgetWithText(FilledButton, '다음'));
    await tester.pump();

    expect(find.text('이름을 입력해주세요'), findsOneWidget);
  });
}
