import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/screens/onboarding_gate.dart';

void main() {
  testWidgets('처음 실행이면 온보딩이 뜨고, "시작하기"를 누르면 바로 본편으로 넘어간다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: OnboardingGate(child: Text('메인 화면'))));
    await tester.pumpAndSettle();

    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('메인 화면'), findsNothing);

    // 작은 테스트 뷰포트에서는 버튼이 스크롤 영역 아래쪽에 있어 바로
    // 탭할 수 없을 수 있다 — 먼저 보이는 위치로 스크롤한다.
    await tester.ensureVisible(find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('메인 화면'), findsOneWidget);
    expect(find.text('시작하기'), findsNothing);
  });

  testWidgets('이미 온보딩을 본 기기(플래그 true)는 바로 본편을 보여준다', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});
    await tester.pumpWidget(const MaterialApp(home: OnboardingGate(child: Text('메인 화면'))));
    await tester.pumpAndSettle();

    expect(find.text('메인 화면'), findsOneWidget);
    expect(find.text('시작하기'), findsNothing);
  });

  testWidgets('온보딩 화면에 3단계 안내가 모두 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: OnboardingGate(child: Text('메인 화면'))));
    await tester.pumpAndSettle();

    expect(find.text('병원 행정 기록 · 지역 시세 확인'), findsOneWidget);
    expect(find.text('우리 아이 진료기록 · 예약 알림'), findsOneWidget);
    expect(find.text('병원 저장 · 캘린더'), findsOneWidget);
    expect(find.text('이미 계정이 있어요 · 로그인'), findsOneWidget);
  });
}
