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

    expect(find.text('Petcli'), findsOneWidget);
    expect(find.text('지도에서 보기'), findsOneWidget);

    // 스프린트 13 지시서 2 — 홈이 병원 리스트 섹션으로 세로로 채워지는지
    // (전국 데이터 기준으로는 항상 데이터가 있어야 하는 섹션들만 확인).
    // 아래쪽 섹션은 초기 뷰포트 밖이라 스크롤해서 실제로 빌드되게 한다.
    // (진료비 시세 카드가 위에 추가되며 이 섹션도 뷰포트 밖으로 밀려났다.)
    await tester.scrollUntilVisible(
      find.text('내 주변 가까운 병원'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('내 주변 가까운 병원'), findsOneWidget);
    expect(find.text('전체 병원 보기'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('운영 20년 이상 병원'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('운영 20년 이상 병원'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('최근 개원한 병원'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('최근 개원한 병원'), findsOneWidget);
  });
}
