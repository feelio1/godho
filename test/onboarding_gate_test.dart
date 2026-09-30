import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/screens/onboarding_gate.dart';

void main() {
  testWidgets('처음 실행이면 온보딩이 뜨고, 건너뛰기를 누르면 바로 본편으로 넘어간다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: OnboardingGate(child: Text('메인 화면'))));
    await tester.pumpAndSettle();

    expect(find.text('건너뛰기'), findsOneWidget);
    expect(find.text('메인 화면'), findsNothing);

    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.text('메인 화면'), findsOneWidget);
    expect(find.text('건너뛰기'), findsNothing);
  });

  testWidgets('이미 온보딩을 본 기기(플래그 true)는 바로 본편을 보여준다', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});
    await tester.pumpWidget(const MaterialApp(home: OnboardingGate(child: Text('메인 화면'))));
    await tester.pumpAndSettle();

    expect(find.text('메인 화면'), findsOneWidget);
    expect(find.text('건너뛰기'), findsNothing);
  });

  testWidgets('건너뛰지 않고 3장을 끝까지 넘기면 "시작하기"로 본편에 들어간다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: OnboardingGate(child: Text('메인 화면'))));
    await tester.pumpAndSettle();

    // 1번째 장 → 2번째 장(중간값 예시 카드) → 3번째 장(지역 시세).
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('대표 가격은 평균이 아니라\n중간값이에요'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('시세는 특정 병원이 아니라\n지역(구) 시세예요'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('메인 화면'), findsOneWidget);
  });
}
