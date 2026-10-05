import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/screens/login_screen.dart';
import 'package:petcliniccheck/screens/my_info_screen.dart';
import 'package:petcliniccheck/screens/saved_screen.dart';

/// 게스트 분기만 다룬다 — 로그인 상태는 실제 FirebaseAuth [User] 인스턴스를
/// 이 테스트 환경에서 만들 수 없어(firebase_auth_mocks가 kakao SDK와
/// 충돌하는 이 프로젝트의 지속된 제약) 직접 구동할 수 없다. 반려동물
/// 추가/수정이 재사용하는 [AccountPetActions]와 로그인 수단 배지에 쓰는
/// [LoginType.badgeLabel]은 각각 user_repository_test.dart/
/// app_user_signup_pet_model_test.dart가 다룬다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpGuest(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        child: const MaterialApp(home: MyInfoScreen()),
      ),
    );
  }

  group(
    'MyInfoScreen(게스트) — 로그인 유도 카드 + 안내 메뉴("디자인 1단계" 지시서 2-B). '
    '게이팅이 아니라 상태 표시일 뿐이라 앱은 그대로 쓸 수 있다는 안내를 보여준다',
    () {
      testWidgets('로그인 유도 카드와 "로그인·가입" 버튼이 보인다', (tester) async {
        await pumpGuest(tester);

        expect(find.text('로그인하지 않았어요'), findsOneWidget);
        expect(find.textContaining('검색과 시세는 지금처럼 로그인 없이'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, '로그인 · 가입'), findsOneWidget);
      });

      testWidgets('"로그인·가입"을 누르면 로그인 화면으로 이동한다', (tester) async {
        await pumpGuest(tester);

        await tester.tap(find.widgetWithText(FilledButton, '로그인 · 가입'));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('안내 메뉴(설정·이용안내·데이터 출처·개인정보처리방침·이용약관·문의하기)와 버전이 보이고, '
          '로그인 전용 항목(반려동물·저장한 병원·로그아웃)은 보이지 않는다', (tester) async {
        await pumpGuest(tester);

        expect(find.text('설정'), findsOneWidget);
        expect(find.text('이용안내'), findsOneWidget);
        expect(find.text('데이터 출처'), findsOneWidget);
        expect(find.text('개인정보처리방침'), findsOneWidget);
        expect(find.text('이용약관'), findsOneWidget);
        expect(find.text('문의하기'), findsOneWidget);
        expect(find.text('miyaongshop@gmail.com'), findsOneWidget);
        expect(find.text('버전 1.0.0'), findsOneWidget);

        expect(find.text('반려동물'), findsNothing);
        expect(find.text('저장한 병원'), findsNothing);
        expect(find.text('로그아웃'), findsNothing);
      });

      testWidgets('개인정보처리방침·이용약관 화면은 본문 없이도 크래시 없이 열린다'
          '("디자인 1단계" 지시서 3 — 틀+라우팅만)', (tester) async {
        await pumpGuest(tester);

        await tester.tap(find.text('개인정보처리방침'));
        await tester.pumpAndSettle();
        expect(find.text('개인정보처리방침'), findsWidgets);
        expect(tester.takeException(), isNull);

        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.text('이용약관'));
        await tester.pumpAndSettle();
        expect(find.text('이용약관'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('"데이터 출처"를 누르면 저장 화면이 아니라 출처 화면으로 이동한다(회귀 확인)', (tester) async {
        await pumpGuest(tester);

        await tester.tap(find.text('데이터 출처'));
        await tester.pumpAndSettle();

        expect(find.byType(SavedScreen), findsNothing);
      });
    },
  );
}
