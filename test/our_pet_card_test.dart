import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/widgets/our_pet_card.dart';

/// 게스트 분기만 다룬다("우리 아이" 카드는 로그인+계정 반려동물이 있을
/// 때만 보인다 — "출시 전 마무리" 지시서 C). 로그인 상태는 실제
/// FirebaseAuth [User] 인스턴스를 이 테스트 환경에서 만들 수 없다
/// (my_info_screen_test.dart와 같은 지속된 제약).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('게스트에게는 아무것도 보이지 않는다(SizedBox.shrink)', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        child: const MaterialApp(home: Scaffold(body: OurPetCard())),
      ),
    );
    await tester.pump();

    final shrink = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(shrink.width, 0);
    expect(shrink.height, 0);
    expect(find.byType(InkWell), findsNothing);
  });
}
