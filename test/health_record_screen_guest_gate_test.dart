import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/screens/health_record_screen.dart';
import 'package:petcliniccheck/screens/login_screen.dart';

/// 진료기록 탭도 캘린더와 같은 로그인 필요 기능이다("로그인 게이팅"
/// 지시서 1) — 게스트는 반려동물·기록 데이터를 전혀 건드리지 않고 바로
/// 안내 상태를 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpGuest(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        child: const MaterialApp(home: HealthRecordScreen()),
      ),
    );
  }

  group('HealthRecordScreen(게스트) — 탭 내용 대신 로그인 안내를 본다', () {
    testWidgets('로그인 안내 문구와 "로그인·가입" 버튼이 보인다', (tester) async {
      await pumpGuest(tester);

      expect(find.text('로그인하면 진료기록을 쓸 수 있어요'), findsOneWidget);
      expect(find.textContaining('기기가 바뀌어도 이어서 볼 수 있어요'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '로그인 · 가입'), findsOneWidget);
    });

    testWidgets('"로그인·가입"을 누르면 로그인 화면으로 이동한다', (tester) async {
      await pumpGuest(tester);

      await tester.tap(find.widgetWithText(FilledButton, '로그인 · 가입'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
