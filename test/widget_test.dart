import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/main.dart';

void main() {
  testWidgets('App boots and shows the home tab', (WidgetTester tester) async {
    // 이미 온보딩을 본 기존 사용자 시나리오 — 앱을 열면 바로 홈이 뜬다
    // (온보딩 자체의 최초 1회 동작은 onboarding_gate_test.dart가 따로 본다).
    SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});
    await tester.pumpWidget(
      const ProviderScope(child: PetClinicCheckApp()),
    );
    // OnboardingGate가 SharedPreferences를 비동기로 읽고 나서야 그 아래
    // 본편(AppOpenAdGate→MainShell)을 마운트한다 — 그 한 프레임을 먼저
    // 흘려보내야 아래 bundle 로딩이 실제로 시작된다.
    await tester.pump();

    // The bundle load is real asset I/O, which FakeAsync's pump() doesn't
    // drive — hop out to the real zone so it can actually complete.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump();

    // "펫클 앱 디자인" 캔버스 시안(Main.dc.html) — 브랜드 마크 + 검색
    // 진입 + 3개 바로가기만 있고, 예전의 세로 리스트 섹션들은 없다
    // ("디자인 2단계" 지시서, 사용자 확인하에 제거).
    expect(find.text('펫클'), findsOneWidget);
    expect(find.text('병원 이름 또는 지역 검색'), findsOneWidget);
    expect(find.text('주변 병원'), findsOneWidget);
    expect(find.text('진료비 시세'), findsOneWidget);
    expect(find.text('저장한 병원'), findsOneWidget);

    expect(find.text('내 주변 가까운 병원'), findsNothing);
    expect(find.text('운영 20년 이상 병원'), findsNothing);
    expect(find.text('최근 개원한 병원'), findsNothing);
  });
}
