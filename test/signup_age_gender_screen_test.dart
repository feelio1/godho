import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/app_user.dart';
import 'package:petcliniccheck/providers/signup_flow_provider.dart';
import 'package:petcliniccheck/screens/signup_age_gender_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const age14Text = '만 14세 이상입니다. (만 14세 미만은 가입할 수 없어요)';

  group(
    'SignupAgeGenderScreen — 성별·연령대는 모든 신규 가입(소셜 포함)에서 '
    '필수다("자체 회원가입·로그인·비밀번호 재설정" 지시서 3). "건너뛰기"는 '
    '더 이상 없다. 만 14세 이상 확인도 공통 필수다("v1 출시 준비" 지시서 2)',
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

      testWidgets('만 14세 이상 확인 문구가 보인다', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SignupAgeGenderScreen()),
          ),
        );

        expect(find.text(age14Text), findsOneWidget);
      });

      testWidgets('나이대·성별·14세 확인을 모두 하기 전에는 "다음"이 비활성화돼 진행할 수 없다', (tester) async {
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
        final afterAgeAndGender = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(
          afterAgeAndGender.onPressed,
          isNull,
          reason: '14세 확인을 체크하기 전에는 나이대·성별만으로는 진행할 수 없어야 한다',
        );

        await tester.tap(find.text(age14Text));
        await tester.pump();
        final afterAll = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(afterAll.onPressed, isNotNull, reason: '셋 다 하면 진행할 수 있어야 한다');
      });

      testWidgets('나이대·성별·14세 확인을 모두 하고 "다음"을 누르면 상태에 반영되고 반려동물 등록 화면으로 넘어간다',
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
        await tester.tap(find.text(age14Text));
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
