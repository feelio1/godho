import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/diary/screens/diary_form_screen.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';

/// 일기 날짜는 미래를 고를 수 없다("방향 개편" 지시서 D). 날짜 선택
/// 시트 자체도 lastDate(오늘) 이후를 비활성화하지만, 저장 시점에도 한
/// 번 더 막는다(방어적 검증) — [DiaryFormScreen.initialDate]로 미래
/// 날짜를 직접 주입해 그 방어적 검증을 확인한다(바텀시트 애니메이션·
/// 스크롤에 의존하지 않는 안정적인 경로).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 날짜를 'ko_KR' 로케일로 표시하는 화면은 실제 앱 초기화와 같은 호출이
  // 테스트 환경에도 필요하다(없으면 LocaleDataException — followup_check_
  // sheet_test.dart와 같은 패턴).
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  testWidgets('초기 날짜가 미래면 저장을 눌러도 안내만 뜨고 화면이 닫히지 않는다', (tester) async {
    // 폼의 모든 필드가 스크롤 없이 한 화면에 들어오도록 테스트 화면을
    // 넉넉히 키운다 — 아래쪽 "저장" 버튼을 스크롤해 찾는 방식은 이
    // 화면(ReorderableListView 등 복합 위젯 포함)에서 불안정했다.
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final futureDate = DateTime.now().add(const Duration(days: 3));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        child: MaterialApp(
          home: DiaryFormScreen(defaultPetIds: const ['p1'], initialDate: futureDate),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pump();

    expect(find.text('미래 날짜는 선택할 수 없어요.'), findsOneWidget);
    expect(find.byType(DiaryFormScreen), findsOneWidget);
  });
}
