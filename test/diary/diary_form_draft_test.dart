import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/diary/screens/diary_form_screen.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';

/// 작성 중 자동 임시저장("일기 활성화" 지시서 G) — 새 작성 화면을 다시
/// 열면 임시본이 있는지 먼저 묻고, "이어쓰기"를 고르면 그 내용을 그대로
/// 되살린다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        child: const MaterialApp(home: DiaryFormScreen(defaultPetIds: ['p1'])),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('임시본이 없으면 이어쓰기 안내 없이 바로 빈 작성 화면이다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpForm(tester);

    expect(find.text('작성 중이던 일기가 있어요'), findsNothing);
  });

  testWidgets('임시본이 있으면 이어쓰기/새로 쓰기를 먼저 묻는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'diary_draft_v1': jsonEncode({
        'date': DateTime(2026, 4, 3).toIso8601String(),
        'petIds': ['p1'],
        'weather': null,
        'activities': <String>[],
        'text': '임시로 적어둔 내용',
        'photoPaths': <String>[],
      }),
    });
    await pumpForm(tester);

    expect(find.text('작성 중이던 일기가 있어요'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '새로 쓰기'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '이어쓰기'), findsOneWidget);
  });

  testWidgets('이어쓰기를 고르면 임시본 내용이 그대로 들어온다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'diary_draft_v1': jsonEncode({
        'date': DateTime(2026, 4, 3).toIso8601String(),
        'petIds': ['p1'],
        'weather': null,
        'activities': <String>[],
        'text': '임시로 적어둔 내용',
        'photoPaths': <String>[],
      }),
    });
    await pumpForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, '이어쓰기'));
    await tester.pumpAndSettle();

    expect(find.text('작성 중이던 일기가 있어요'), findsNothing);
    expect(find.text('임시로 적어둔 내용'), findsOneWidget);
    expect(find.textContaining('2026.04.03'), findsOneWidget);
  });

  testWidgets('새로 쓰기를 고르면 임시본을 지우고 빈 화면으로 시작한다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'diary_draft_v1': jsonEncode({
        'date': DateTime(2026, 4, 3).toIso8601String(),
        'petIds': ['p1'],
        'weather': null,
        'activities': <String>[],
        'text': '임시로 적어둔 내용',
        'photoPaths': <String>[],
      }),
    });
    await pumpForm(tester);

    await tester.tap(find.widgetWithText(TextButton, '새로 쓰기'));
    await tester.pumpAndSettle();

    expect(find.text('임시로 적어둔 내용'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('diary_draft_v1'), isNull);
  });
}
