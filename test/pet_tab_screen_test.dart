import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/providers/pet_tab_provider.dart';
import 'package:petcliniccheck/screens/login_screen.dart';
import 'package:petcliniccheck/screens/pet_tab_screen.dart';

/// "우리 아이" 탭은 캘린더·진료기록이 각자 탭이던 시절의 게스트 게이팅을
/// 하나로 합쳤다("탭 개편" 지시서 B) — 예전엔 calendar_screen_guest_gate_
/// test.dart/health_record_screen_guest_gate_test.dart가 각 화면마다 다른
/// 안내 문구를 따로 검증했지만, 이제는 이 화면 하나가 세그먼트와 무관하게
/// 안내를 1번만 보여주므로 이 파일로 합쳤다. 로그인 상태 분기는 실제
/// FirebaseAuth [User] 인스턴스를 이 테스트 환경에서 만들 수 없어(다른
/// 화면들과 같은 제약) 다루지 않는다 — 게스트 분기만 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpGuest(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        child: const MaterialApp(home: PetTabScreen()),
      ),
    );
  }

  group('PetTabScreen(게스트) — 세그먼트와 무관하게 안내를 1번만 보여준다', () {
    testWidgets('로그인 안내 문구와 "로그인·가입" 버튼이 보인다 (진료기록/캘린더/일기 세그먼트 라벨은 뜨지 않는다)', (tester) async {
      await pumpGuest(tester);

      expect(find.text('로그인하면 우리 아이 기록을 쓸 수 있어요'), findsOneWidget);
      expect(find.textContaining('기기가 바뀌어도 이어서 볼 수 있어요'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '로그인 · 가입'), findsOneWidget);
      expect(find.text('진료기록'), findsNothing);
      expect(find.text('캘린더'), findsNothing);
      expect(find.text('일기'), findsNothing);
    });

    testWidgets('"로그인·가입"을 누르면 로그인 화면으로 이동한다', (tester) async {
      await pumpGuest(tester);

      await tester.tap(find.widgetWithText(FilledButton, '로그인 · 가입'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('petTabViewProvider — 세그먼트 선택은 앱 실행 중 유지된다("탭 개편" 지시서 B)', () {
    test('기본값은 진료기록이다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(petTabViewProvider), PetTabView.records);
    });

    test('캘린더로 바꾸면 다시 읽어도(=탭을 벗어났다 돌아와도) 캘린더로 유지된다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(petTabViewProvider.notifier).state = PetTabView.calendar;
      expect(container.read(petTabViewProvider), PetTabView.calendar);
    });

    test('일기로 바꾸면 다시 읽어도 일기로 유지된다("방향 개편" 지시서 D)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(petTabViewProvider.notifier).state = PetTabView.diary;
      expect(container.read(petTabViewProvider), PetTabView.diary);
    });
  });
}
