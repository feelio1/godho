import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/app_user.dart';
import 'package:petcliniccheck/providers/signup_flow_provider.dart';
import 'package:petcliniccheck/screens/signup_age_gender_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'SignupAgeGenderScreen — 성별·연령대는 모든 신규 가입(소셜 포함)에서 '
    '필수다("자체 회원가입·로그인·비밀번호 재설정" 지시서 3). "건너뛰기"는 '
    '더 이상 없다',
    () {
      testWidgets('"건너뛰기" 버튼이 없고, "선택 안 함"도 선택지로 노출되지 않는다', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SignupAgeGenderScreen()),
          ),
        );

        expect(find.text('건너뛰기'), findsNothing);
        expect(find.text('선택 안 함'), findsNothing);
      });

      testWidgets('나이대·성별을 모두 고르기 전에는 "다음"이 비활성화돼 진행할 수 없다', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SignupAgeGenderScreen()),
          ),
        );

        final nextButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(nextButton.onPressed, isNull);

        await tester.tap(find.text('20대'));
        await tester.pump();
        final afterAgeOnly = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(afterAgeOnly.onPressed, isNull, reason: '성별을 고르기 전에는 여전히 진행할 수 없어야 한다');

        await tester.tap(find.text('여'));
        await tester.pump();
        final afterBoth = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(afterBoth.onPressed, isNotNull, reason: '둘 다 고르면 진행할 수 있어야 한다');
      });

      testWidgets('나이대·성별을 모두 고르고 "다음"을 누르면 상태에 반영되고 반려동물 등록 화면으로 넘어간다',
          (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SignupAgeGenderScreen()),
          ),
        );

        await tester.tap(find.text('30대'));
        await tester.pump();
        await tester.tap(find.text('남'));
        await tester.pump();

        final element = tester.element(find.byType(SignupAgeGenderScreen));
        final container = ProviderScope.containerOf(element);

        await tester.tap(find.widgetWithText(FilledButton, '다음'));
        await tester.pumpAndSettle();

        final state = container.read(signupFlowProvider);
        expect(state.ageGroup, AgeGroup.thirties);
        expect(state.gender, Gender.male);
        expect(find.text('반려동물 등록'), findsOneWidget);
      });
    },
  );
}
