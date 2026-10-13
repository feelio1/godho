import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/widgets/home_greeting_banner.dart';

/// 게스트 분기만 다룬다 — 로그인 상태는 실제 FirebaseAuth [User] 인스턴스를
/// 이 테스트 환경에서 만들 수 없다(my_info_screen_test.dart와 같은
/// 지속된 제약).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('게스트는 평가 금지 원칙을 담은 담백한 인사를 본다'
      '("출시 전 마무리" 지시서 B)', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        child: const MaterialApp(home: Scaffold(body: HomeGreetingBanner())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('평가하지 않아요'), findsOneWidget);
  });
}
