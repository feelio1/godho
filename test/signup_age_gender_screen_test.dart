import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/app_user.dart';
import 'package:petcliniccheck/providers/signup_flow_provider.dart';
import 'package:petcliniccheck/screens/signup_age_gender_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const age14Text = '만 14세 이상입니다 (필수)';

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> agreeAll(WidgetTester tester) async {
    await tapKey(tester, 'consent_age14');
    await tapKey(tester, 'consent_terms');
    await tapKey(tester, 'consent_privacy');
  }

  group(
    'SignupAgeGenderScreen — 성별·연령대는 선택 입력이다(2차 업데이트 결정 1). '
    '"건너뛰기" 버튼은 없다(고르지 않으면 그게 건너뛰기). 만 14세 이상·이용약관·'
    '개인정보 동의는 공통 필수다("v1 출시 준비" 지시서 2)',
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

      testWidgets('만 14세 이상·이용약관·개인정보 동의 문구가 모두 보인다', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SignupAgeGenderScreen()),
          ),
        );

        expect(find.text(age14Text), findsOneWidget);
        expect(find.text('이용약관 동의'), findsOneWidget);
        expect(find.text('개인정보 수집·이용 동의'), findsOneWidget);
        expect(find.text('이용 통계 활용 동의'), findsOneWidget);
      });

      testWidgets('성별·연령대를 고르지 않아도 필수 동의 3개만 하면 "다음"으로 갈 수 있다', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SignupAgeGenderScreen()),
          ),
        );

        final nextButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(nextButton.onPressed, isNull);
        // 두 항목 모두 "선택" 표시.
        expect(find.text('선택'), findsWidgets);
        expect(find.text('필수'), findsNWidgets(2), reason: '필수 배지는 이용약관·개인정보 동의 2개뿐');

        await tester.tap(find.text('20대'));
        await tester.tap(find.text('여'));
        await tester.pump();
        final afterAgeAndGender = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(afterAgeAndGender.onPressed, isNull, reason: '필수 동의 없이 성별·연령대만으로는 진행할 수 없다');

        // 고른 칩을 다시 누르면 풀린다.
        await tester.tap(find.text('20대'));
        await tester.tap(find.text('여'));
        await tester.pump();

        await tapKey(tester, 'consent_age14');
        final afterAge14Only = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(afterAge14Only.onPressed, isNull, reason: '이용약관·개인정보 동의도 필요하다');

        await tapKey(tester, 'consent_terms');
        await tapKey(tester, 'consent_privacy');
        final afterAll = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(afterAll.onPressed, isNotNull, reason: '성별·연령대 없이 필수 동의 3개면 진행할 수 있다');
      });

      testWidgets('성별·연령대 없이 "다음"을 누르면 두 값은 null로 넘어간다', (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SignupAgeGenderScreen()),
          ),
        );
        await agreeAll(tester);
        await tester.tap(find.widgetWithText(FilledButton, '다음'));
        await tester.pumpAndSettle();

        final state = container.read(signupFlowProvider);
        expect(state.ageGroup, isNull);
        expect(state.gender, isNull);
      });

      testWidgets('"전체 동의"를 누르면 필수·선택 동의가 한 번에 체크된다', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SignupAgeGenderScreen()),
          ),
        );

        await tester.tap(find.text('20대'));
        await tester.pump();
        await tester.tap(find.text('여'));
        await tester.pump();
        await tapKey(tester, 'consent_age14');

        // "전체 동의"는 법적 필수 동의(14세 확인)와는 별개로, 이용약관·
        // 개인정보·통계 3개를 함께 토글한다.
        await tapKey(tester, 'consent_all');

        final afterAll = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음'));
        expect(afterAll.onPressed, isNotNull);
      });

      testWidgets('나이대·성별·모든 필수 동의를 하고 "다음"을 누르면 상태에 반영되고 반려동물 등록 화면으로 넘어간다',
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
        await agreeAll(tester);

        final element = tester.element(find.byType(SignupAgeGenderScreen));
        final container = ProviderScope.containerOf(element);

        await tester.tap(find.widgetWithText(FilledButton, '다음'));
        await tester.pumpAndSettle();

        final state = container.read(signupFlowProvider);
        expect(state.ageGroup, AgeGroup.thirties);
        expect(state.gender, Gender.male);
        expect(find.text('나중에 등록할게요'), findsOneWidget);
      });
    },
  );
}
