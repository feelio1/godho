import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:petcliniccheck/data/user_repository.dart';
import 'package:petcliniccheck/diary/data/diary_repository.dart';
import 'package:petcliniccheck/diary/models/diary.dart';
import 'package:petcliniccheck/diary/providers/diary_providers.dart';
import 'package:petcliniccheck/diary/screens/diary_list_body.dart';
import 'package:petcliniccheck/diary_book/book_layout.dart';
import 'package:petcliniccheck/diary_book/book_spec.dart';
import 'package:petcliniccheck/diary_book/diary_book_pdf_service.dart';
import 'package:petcliniccheck/diary_book/providers/diary_book_switch.dart';
import 'package:petcliniccheck/diary_book/screens/diary_book_preview_screen.dart';
import 'package:petcliniccheck/diary_book/screens/diary_book_setup_screen.dart';
import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/providers/effective_pets_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 실제 FirebaseAuth [User]는 만들 수 없어 uid만 돌려주는 가짜를 쓴다.
class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 일기 읽기만 하는 메모리 저장소 — 그림일기는 쓰기를 부르지 않는다.
class _FakeDiaryRepository implements DiaryRepository {
  final List<Diary> diaries;

  _FakeDiaryRepository(this.diaries);

  @override
  Future<DiaryPage> fetchDiaries(String uid, {int limit = 20, Object? cursor}) async =>
      DiaryPage(diaries: diaries.take(limit).toList());

  @override
  Future<List<Diary>> fetchDiariesForMonth(String uid, DateTime month) async =>
      diaries.where((d) => d.date.year == month.year && d.date.month == month.month).toList();

  @override
  Future<Diary?> fetchDiary(String uid, String diaryId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('write ${invocation.memberName}');
}

class _FakeGenerator implements DiaryBookPdfGenerator {
  int calls = 0;
  BookLayout? lastLayout;

  @override
  Future<DiaryBookPdf> generate(
    BookLayout layout, {
    required BookSpec spec,
    required String cacheKey,
    void Function(DiaryBookProgress progress)? onProgress,
  }) async {
    calls++;
    lastLayout = layout;
    onProgress?.call(DiaryBookProgress(DiaryBookPhase.pages, layout.pageCount, layout.pageCount));
    return DiaryBookPdf(path: 'fake.pdf', bytes: Uint8List.fromList('%PDF-fake'.codeUnits));
  }

  @override
  Future<void> clearCache() async {}
}

final _png = Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 3)));

const _pet = Pet(id: 'account:p1', name: '구름이', species: PetSpecies.dog);

Diary _diary(String id, DateTime date, {String text = '산책했다'}) => Diary(
      id: id,
      date: date,
      petIds: const ['account:p1'],
      weather: DiaryWeather.sunny,
      activities: const [DiaryActivity.walk],
      text: text,
      createdAt: date,
      updatedAt: date,
    );

DateTime _daysAgo(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days, 12);
}

List<Override> _overrides({
  required List<Diary> diaries,
  bool bookEnabled = true,
  Stream<bool>? bookEnabledStream,
  DiaryBookPdfGenerator? generator,
}) =>
    [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
      effectivePetsProvider.overrideWith((ref) async => const [_pet]),
      diaryRepositoryProvider.overrideWithValue(_FakeDiaryRepository(diaries)),
      userRepositoryProvider.overrideWithValue(UserRepository(firestore: FakeFirebaseFirestore())),
      diaryBookEnabledProvider.overrideWith((ref) => bookEnabledStream ?? Stream.value(bookEnabled)),
      diaryBookPdfGeneratorProvider.overrideWithValue(generator ?? _FakeGenerator()),
      diaryBookRasterizerProvider.overrideWithValue((pdf, page, dpi) async => _png),
    ];

void main() {
  setUpAll(() => initializeDateFormatting('ko'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('진입점(스위치)', () {
    Future<void> pumpList(WidgetTester tester, {required bool enabled}) async {
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(diaries: [_diary('d1', _daysAgo(1))], bookEnabled: enabled),
        child: const MaterialApp(
          home: Scaffold(body: DiaryListBody(selectedPet: _pet, allPets: [_pet])),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('스위치가 닫혀 있으면 일기 보기에 "그림일기 만들기"가 없다', (tester) async {
      await pumpList(tester, enabled: false);
      expect(find.text('일기 쓰기'), findsOneWidget);
      expect(find.text('그림일기 만들기'), findsNothing);
    });

    testWidgets('스위치가 열리면 "그림일기 만들기"가 보이고 설정 화면으로 간다', (tester) async {
      await pumpList(tester, enabled: true);
      await tester.tap(find.text('그림일기 만들기'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryBookSetupScreen), findsOneWidget);
    });

    testWidgets('스위치 상태를 아직 모르면(로딩) 닫힘으로 본다', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(diaries: const [], bookEnabledStream: const Stream<bool>.empty()),
        child: const MaterialApp(
          home: Scaffold(body: DiaryListBody(selectedPet: _pet, allPets: [_pet])),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('그림일기 만들기'), findsNothing);
    });
  });

  group('설정 → 미리보기', () {
    testWidgets('기간 안 일기 수·예상 쪽 수를 보여주고, 미리보기에서 PDF 쪽을 넘겨 본다(주문은 비활성)', (tester) async {
      final generator = _FakeGenerator();
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(
          diaries: [
            _diary('d1', _daysAgo(10)),
            _diary('d2', _daysAgo(3)),
            // 기본 기간(최근 3개월) 밖 — 빠진다.
            _diary('old', _daysAgo(200)),
          ],
          generator: generator,
        ),
        child: const MaterialApp(home: DiaryBookSetupScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('포함 일기 2편 · 예상 4쪽'), findsOneWidget);
      expect(find.text('구름이의 그림일기'), findsOneWidget);
      expect(find.text('기간 안에 사진이 없어요 — 표지는 사진 없이 만들어져요'), findsOneWidget);

      await tester.tap(find.text('미리보기 만들기'));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryBookPreviewScreen), findsOneWidget);
      expect(generator.calls, 1);
      expect(generator.lastLayout!.pageCount, 4);
      expect(find.text('4쪽'), findsOneWidget);
      final order = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '책으로 주문하기'));
      expect(order.onPressed, isNull);
      expect(find.text('곧 주문할 수 있어요'), findsOneWidget);
      // 가격·저장·공유는 없다.
      expect(find.textContaining('원'), findsNothing);
      expect(find.byIcon(Icons.share), findsNothing);

      // 펼침면 전환: 4쪽 → 표지 | 2–3 | 4 로 3장면.
      await tester.tap(find.text('펼침면'));
      await tester.pumpAndSettle();
      expect(diaryBookViews(4, spread: true), [
        [0],
        [1, 2],
        [3],
      ]);
    });

    testWidgets('기간 안에 일기가 없으면 미리보기 만들기 비활성 + 안내', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(diaries: [_diary('old', _daysAgo(200))]),
        child: const MaterialApp(home: DiaryBookSetupScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('기간 안에 일기가 없어요'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '미리보기 만들기'));
      expect(button.onPressed, isNull);
    });

    testWidgets('생성이 실패하면 다시 시도할 수 있다', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(diaries: [_diary('d1', _daysAgo(1))], generator: _FailingGenerator()),
        child: const MaterialApp(home: DiaryBookSetupScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('미리보기 만들기'));
      await tester.pumpAndSettle();
      expect(find.text('그림일기를 만들지 못했어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  });

  test('diaryBookViews: 한쪽 보기는 쪽마다, 펼침면은 표지·마지막 쪽을 홑으로', () {
    expect(diaryBookViews(3, spread: false), [
      [0],
      [1],
      [2],
    ]);
    expect(diaryBookViews(6, spread: true), [
      [0],
      [1, 2],
      [3, 4],
      [5],
    ]);
  });

  test('defaultDiaryBookPeriod: 오늘까지 최근 3개월', () {
    final p = defaultDiaryBookPeriod(DateTime(2026, 10, 28));
    expect(p.start, DateTime(2026, 7, 29));
    expect(p.end, DateTime(2026, 10, 28));
  });
}

class _FailingGenerator implements DiaryBookPdfGenerator {
  @override
  Future<DiaryBookPdf> generate(
    BookLayout layout, {
    required BookSpec spec,
    required String cacheKey,
    void Function(DiaryBookProgress progress)? onProgress,
  }) async =>
      throw StateError('boom');

  @override
  Future<void> clearCache() async {}
}
