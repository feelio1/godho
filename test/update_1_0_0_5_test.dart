import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

import 'package:petcliniccheck/ads/app_open_ad_suppression.dart';
import 'package:petcliniccheck/data/user_repository.dart';
import 'package:petcliniccheck/diary/diary_saved_event.dart';
import 'package:petcliniccheck/diary/data/diary_repository.dart';
import 'package:petcliniccheck/diary/models/diary.dart';
import 'package:petcliniccheck/diary/providers/diary_providers.dart';
import 'package:petcliniccheck/diary/screens/diary_detail_screen.dart';
import 'package:petcliniccheck/diary/screens/diary_list_body.dart';
import 'package:petcliniccheck/diary/screens/today_diary_row.dart';
import 'package:petcliniccheck/diary_book/book_input.dart';
import 'package:petcliniccheck/diary_book/book_layout.dart';
import 'package:petcliniccheck/diary_book/book_layout_engine.dart';
import 'package:petcliniccheck/diary_book/book_spec.dart';
import 'package:petcliniccheck/diary_book/diary_page_image_service.dart';
import 'package:petcliniccheck/diary_book/providers/diary_book_switch.dart';
import 'package:petcliniccheck/diary_book/render/book_pdf_renderer.dart';
import 'package:petcliniccheck/diary_book/screens/diary_book_preview_screen.dart' show BookOrderInterestToggle;
import 'package:petcliniccheck/diary_book/screens/diary_page_screen.dart';
import 'package:petcliniccheck/screens/onboarding_screen.dart';
import 'package:petcliniccheck/diary_book/screens/first_diary_page_sheet.dart';
import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/providers/effective_pets_provider.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';

class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 일기 읽기 전용 메모리 저장소.
class _FakeDiaryRepository implements DiaryRepository {
  final List<Diary> diaries;

  _FakeDiaryRepository(this.diaries);

  @override
  Future<Diary?> fetchDiary(String uid, String diaryId) async => diaries.where((d) => d.id == diaryId).firstOrNull;

  @override
  Future<DiaryPage> fetchDiaries(String uid, {int limit = 20, Object? cursor}) async =>
      DiaryPage(diaries: diaries.take(limit).toList());

  @override
  Future<List<Diary>> fetchDiariesForMonth(String uid, DateTime month) async =>
      diaries.where((d) => d.date.year == month.year && d.date.month == month.month).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

/// 그림일기 장 이미지를 그리지 않고 작은 PNG 파일만 돌려주는 가짜 서비스.
class _FakePageService extends DiaryPageImageService {
  final Directory dir;
  final calls = <bool>[];

  _FakePageService(this.dir);

  @override
  Future<List<File>> generate(BookDiaryEntry entry, {required bool share, BookSpec spec = BookSpec.a5}) async {
    calls.add(share);
    final f = File('${dir.path}/${entry.id}_${share ? 'share' : 'view'}_0.png');
    f.writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 6)));
    return [f];
  }
}

Diary _diary({String id = 'd1'}) => Diary(
  id: id,
  date: DateTime(2026, 11, 14),
  petIds: const ['account:p1'],
  weather: DiaryWeather.sunny,
  activities: const [DiaryActivity.walk],
  text: '오늘은 공원에서 낙엽을 밟았다.',
  createdAt: DateTime(2026, 11, 14, 20),
  updatedAt: DateTime(2026, 11, 14, 20),
);

BookRenderFonts _fonts() => BookRenderFonts(
  handwriting: File('assets/fonts/nanum_pen_script/NanumPenScript-Regular.ttf').readAsBytesSync(),
  label: File('assets/fonts/IBMPlexSansKR-Regular.ttf').readAsBytesSync(),
);

BookPhoto _photo(String id) => BookPhoto(id: id, widthPx: 1600, heightPx: 1200);

BookDiaryEntry _entry({int photos = 0, String text = '오늘은 공원에서 낙엽을 밟았다.', String id = 'd1'}) => BookDiaryEntry(
  id: id,
  date: DateTime(2026, 11, 14),
  weather: BookWeather.sunny,
  activities: const ['산책', '간식'],
  text: text,
  photos: [for (var i = 0; i < photos; i++) _photo('p$i')],
);

/// 같은 일기를 책에 넣었을 때의 일기 쪽들(표지·메모·함께한 날들 제외).
List<BookPage> _bookPagesFor(BookDiaryEntry entry) {
  final result = layoutBook(
    BookInput(
      petName: '구름이',
      title: '',
      periodStart: DateTime(2026, 11, 1),
      periodEnd: DateTime(2026, 11, 30),
      entries: [entry],
    ),
  );
  return [
    for (final p in (result as BookLayoutOk).layout.pages)
      if (p is DiaryEntryPage || p is ContinuationPage) p,
  ];
}

String _rect(MmRect r) =>
    '${r.x.toStringAsFixed(4)},${r.y.toStringAsFixed(4)},'
    '${r.width.toStringAsFixed(4)},${r.height.toStringAsFixed(4)}';

/// 쪽 하나의 배치 지문 — 사진 칸·원고지 칸 좌표와 원고지 글자.
String _fingerprint(BookPage page) => switch (page) {
  DiaryEntryPage() => [
    'diary',
    _rect(page.headerRect),
    page.pictureBox == null ? '-' : _rect(page.pictureBox!),
    for (final s in page.photos) '${s.photo.id}@${_rect(s.rect)}',
    _rect(page.grid.rect),
    '${page.grid.rows}x${page.grid.columns}',
    page.grid.cells.map((r) => r.join()).join('|'),
  ].join(';'),
  ContinuationPage() => ['cont', _rect(page.grid.rect), page.grid.cells.map((r) => r.join()).join('|')].join(';'),
  _ => 'other',
};

/// PDF의 첫 쪽 MediaBox 높이(pt).
double _mediaBoxHeight(Uint8List pdf) {
  final m = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]').firstMatch(String.fromCharCodes(pdf))!;
  return double.parse(m.group(2)!);
}

void main() {
  group('K-1 일기 한 장 = 그림일기 한 장(엔진)', () {
    for (final (label, entry) in [
      ('사진 0장', _entry()),
      ('사진 3장', _entry(photos: 3)),
      ('사진 6장(앞 5장만)', _entry(photos: 6)),
      ('긴 글("이어서" 쪽)', _entry(photos: 2, text: '바스락 소리가 좋아서 계속 뛰었다. ' * 40)),
    ]) {
      test('$label: 책 속 일기 쪽과 사진 칸·원고지 칸이 같다', () {
        final single = layoutSingleDiary(entry);
        final book = _bookPagesFor(entry);
        expect(single.length, book.length);
        expect([for (final p in single) _fingerprint(p)], [for (final p in book) _fingerprint(p)]);
        // 표지·메모·함께한 날들은 없다.
        expect(single.whereType<CoverPage>(), isEmpty);
        expect(single.whereType<MemoPage>(), isEmpty);
        expect(single.whereType<SummaryPage>(), isEmpty);
      });
    }

    test('사진 수: 0장이면 그림 칸 없음, 6장이면 앞 5장만', () {
      expect((layoutSingleDiary(_entry()).first as DiaryEntryPage).pictureBox, isNull);
      final six = layoutSingleDiary(_entry(photos: 6)).first as DiaryEntryPage;
      expect([for (final s in six.photos) s.photo.id], ['p0', 'p1', 'p2', 'p3', 'p4']);
    });

    test('긴 글은 "(이어서)" 쪽까지 이어진다', () {
      final pages = layoutSingleDiary(_entry(text: '가' * 600));
      expect(pages.first, isA<DiaryEntryPage>());
      expect(pages.skip(1), everyElement(isA<ContinuationPage>()));
      expect(pages.length, greaterThan(1));
    });
  });

  group('K-1/K-4 렌더 — 쪽 번호·공유 하단 표시', () {
    test('공유 이미지만 쪽 아래 바깥 여백(하단 표시)이 붙고, 화면 보기·책 PDF는 판형 그대로', () async {
      final pages = layoutSingleDiary(_entry());
      final view = await renderBookPdf(
        BookLayout(pages),
        spec: BookSpec.a5,
        fonts: _fonts(),
        loadPhoto: (_) => null,
        pageNumbers: false,
      );
      final share = await renderBookPdf(
        BookLayout(pages),
        spec: BookSpec.a5,
        fonts: _fonts(),
        loadPhoto: (_) => null,
        pageNumbers: false,
        shareFooter: kShareFooterText,
      );
      const mm = 72 / 25.4;
      expect(_mediaBoxHeight(view), closeTo(BookSpec.a5.heightMm * mm, 0.5));
      expect(_mediaBoxHeight(share), closeTo((BookSpec.a5.heightMm + kShareFooterMm) * mm, 0.5));
      expect(kShareFooterText, '펫클로 만든 그림일기');
      // 하단 글자 크기는 이미지 높이의 약 2%.
      final ratio = (kShareFooterFontPt / mm) / (BookSpec.a5.heightMm + kShareFooterMm);
      expect(ratio, inInclusiveRange(0.015, 0.025));

      final book =
          (layoutBook(
                    BookInput(
                      petName: '구름이',
                      title: '',
                      periodStart: DateTime(2026, 11, 1),
                      periodEnd: DateTime(2026, 11, 30),
                      entries: [_entry()],
                    ),
                  )
                  as BookLayoutOk)
              .layout;
      final bookPdf = await renderBookPdf(book, spec: BookSpec.a5, fonts: _fonts(), loadPhoto: (_) => null);
      expect(_mediaBoxHeight(bookPdf), closeTo(BookSpec.a5.heightMm * mm, 0.5));
    });
  });

  group('K-1 이미지 서비스', () {
    late Directory dir;
    late Directory photoDir;
    final rasterCalls = <double>[];

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('diary_page_preview');
      photoDir = await Directory.systemTemp.createTemp('photos');
      rasterCalls.clear();
    });
    tearDown(() async {
      await dir.delete(recursive: true);
      await photoDir.delete(recursive: true);
    });

    DiaryPageImageService service() => DiaryPageImageService(
      cacheDirectory: () async => dir,
      loadFonts: () async => _fonts(),
      resolvePhotos: (ids) async => {for (final id in ids) id: '${photoDir.path}/$id.jpg'},
      render: (job) async {
        final bytes = await renderBookPdf(
          job.layout,
          spec: job.spec,
          fonts: job.fonts,
          loadPhoto: (id) {
            final path = job.photoPaths[id];
            return path == null ? null : File(path).readAsBytesSync();
          },
          pageNumbers: job.pageNumbers,
          shareFooter: job.shareFooter,
        );
        await File(job.outPath).writeAsBytes(bytes);
      },
      rasterize: (pdf, page, dpi) async {
        rasterCalls.add(dpi);
        return Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 6)));
      },
    );

    test('공유 파일은 원본 사진 파일이 아니라 새로 그린 PNG(캐시 폴더), 가로 1080px 기준 dpi', () async {
      final original = img.encodeJpg(img.Image(width: 1600, height: 1200), quality: 80);
      for (var i = 0; i < 2; i++) {
        await File('${photoDir.path}/p$i.jpg').writeAsBytes(original);
      }
      final files = await service().generate(_entry(photos: 2), share: true);
      expect(files, hasLength(1));
      for (final f in files) {
        expect(f.path, startsWith(dir.path));
        expect(f.path, isNot(startsWith(photoDir.path)));
        final bytes = await f.readAsBytes();
        expect(isPngBytes(bytes), isTrue);
        expect(bytes, isNot(original));
      }
      expect(rasterCalls.single, closeTo(1080 / (148 / 25.4), 0.01));
    });

    test('화면 보기는 110dpi, 같은 내용이면 다시 그리지 않는다, 글이 바뀌면 새로', () async {
      final s = service();
      final first = await s.generate(_entry(), share: false);
      expect(rasterCalls, [kDiaryPageViewDpi]);
      final again = await s.generate(_entry(), share: false);
      expect(again.map((f) => f.path), first.map((f) => f.path));
      expect(rasterCalls, hasLength(1), reason: '같은 내용 해시면 재사용');
      final edited = await s.generate(_entry(text: '고친 글'), share: false);
      expect(rasterCalls, hasLength(2));
      expect(first.single.existsSync(), isFalse, reason: '같은 일기의 이전 이미지는 지운다');
      expect(edited.single.existsSync(), isTrue);
    });
  });

  group('K-2 일기 상세 "그림일기 장으로 보기" + K-4 공유', () {
    late Directory dir;
    late _FakePageService service;
    late AppOpenAdSuppression suppression;

    setUpAll(() => initializeDateFormatting('ko_KR'));
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('page_widget');
      service = _FakePageService(dir);
      suppression = AppOpenAdSuppression();
    });
    tearDown(() => dir.delete(recursive: true));

    List<Override> overrides({required bool bookOn, DiaryPageSharer? sharer}) => [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
      diaryRepositoryProvider.overrideWithValue(_FakeDiaryRepository([_diary()])),
      diaryBookEnabledProvider.overrideWith((ref) => Stream.value(bookOn)),
      diaryPageImageServiceProvider.overrideWithValue(service),
      adSuppressionProvider.overrideWithValue(suppression),
      if (sharer != null) diaryPageSharerProvider.overrideWithValue(sharer),
    ];

    testWidgets('스위치가 닫히면 버튼이 없다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(bookOn: false),
          child: const MaterialApp(home: DiaryDetailScreen(diaryId: 'd1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('오늘은 공원에서 낙엽을 밟았다.'), findsOneWidget);
      expect(find.byKey(const ValueKey('diary_page_view')), findsNothing);
    });

    testWidgets('열리면 [그림일기 장으로 보기] → 장 보기 화면(워터마크 없음) → [공유하기]는 공유 이미지·광고 억제', (tester) async {
      List<XFile>? shared;
      var suppressedDuringShare = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(
            bookOn: true,
            sharer: (files) async {
              shared = files;
              suppressedDuringShare = suppression.isSuppressed;
            },
          ),
          child: const MaterialApp(home: DiaryDetailScreen(diaryId: 'd1')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('diary_page_view')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryPageScreen), findsOneWidget);
      expect(find.text('그림일기 전체 보기'), findsOneWidget);
      expect(find.textContaining('미리보기'), findsNothing, reason: '내 일기 한 장 보기에는 워터마크 없음');
      expect(service.calls, [false]);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('diary_page_share')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(service.calls, [false, true]);
      expect(shared, hasLength(1));
      expect(shared!.single.path, endsWith('_share_0.png'));
      expect(shared!.single.mimeType, 'image/png');
      expect(suppressedDuringShare, isTrue);
      expect(suppression.isSuppressed, isFalse, reason: '공유가 끝나면 억제를 푼다');
    });
  });

  group('K-3 첫 일기를 저장하면 "첫 장이 생겼어요"', () {
    test('판정: 새 일기·스위치 열림·1편·처음일 때만 시트, 그 밖엔 스낵바, 수정·스위치 닫힘은 없음', () {
      DiarySavedFollowUp d({bool isNew = true, bool on = true, int count = 1, bool shown = false}) =>
          decideDiarySavedFollowUp(isNew: isNew, bookVisible: on, diaryCount: count, firstPageAlreadyShown: shown);
      expect(d(), DiarySavedFollowUp.firstPageSheet);
      expect(d(count: 2), DiarySavedFollowUp.viewSnackbar);
      expect(d(shown: true), DiarySavedFollowUp.viewSnackbar);
      expect(d(isNew: false), DiarySavedFollowUp.none);
      expect(d(on: false), DiarySavedFollowUp.none);
    });

    late Directory dir;
    setUpAll(() => initializeDateFormatting('ko_KR'));
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('first_page');
    });
    tearDown(() => dir.delete(recursive: true));

    Future<FakeFirebaseFirestore> pumpSaved(
      WidgetTester tester, {
      required List<Diary> diaries,
      bool bookOn = true,
      bool alreadyShown = false,
    }) async {
      final firestore = FakeFirebaseFirestore();
      if (alreadyShown) {
        await firestore.collection('users').doc('u1').set({'firstDiaryPageShownAt': DateTime(2026, 11, 1)});
      }
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
          diaryRepositoryProvider.overrideWithValue(_FakeDiaryRepository(diaries)),
          diaryBookEnabledProvider.overrideWith((ref) => Stream.value(bookOn)),
          diaryPageImageServiceProvider.overrideWithValue(_FakePageService(dir)),
          userRepositoryProvider.overrideWithValue(UserRepository(firestore: firestore)),
          effectivePetsProvider.overrideWith(
            (ref) async => const [Pet(id: 'account:p1', name: '구름이', species: PetSpecies.dog)],
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(diaryBookEnabledProvider, (_, _) {});
      container.listen(authStateProvider, (_, _) {});
      container.listen(effectivePetsProvider, (_, _) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiarySavedListener(
              settleDelay: Duration.zero,
              child: Scaffold(body: Text('메인')),
            ),
          ),
        ),
      );
      await tester.pump();
      container.read(diarySavedEventProvider.notifier).state = DiarySavedEvent(
        diaryId: diaries.first.id,
        isNew: true,
        serial: 1,
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      return firestore;
    }

    testWidgets('첫 일기: 시트(손글씨 제목·안내·버튼)가 뜨고 firstDiaryPageShownAt을 기록, 알림 권유는 같이 안 뜸', (tester) async {
      final firestore = await pumpSaved(tester, diaries: [_diary()]);
      expect(find.byKey(const ValueKey('first_diary_page_sheet')), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data?.replaceAll('\u2060', '') == '구름이의 그림일기 첫 장이 생겼어요'),
        findsOneWidget,
      );
      expect(find.text('일기를 쓸 때마다 한 장씩 늘어나요'), findsOneWidget);
      expect(find.text('크게 보기'), findsOneWidget);
      expect(find.text('공유하기'), findsOneWidget);
      expect(find.text('닫기'), findsOneWidget);
      expect(find.textContaining('알림'), findsNothing);
      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()?['firstDiaryPageShownAt'], isNotNull);
    });

    testWidgets('이미 보여 줬으면(다른 기기 포함) 시트 대신 스낵바', (tester) async {
      await pumpSaved(tester, diaries: [_diary()], alreadyShown: true);
      expect(find.byKey(const ValueKey('first_diary_page_sheet')), findsNothing);
      expect(find.text('그림일기 장으로 볼 수 있어요'), findsOneWidget);
      expect(find.text('보기'), findsOneWidget);
    });

    testWidgets('두 번째 일기부터는 스낵바만', (tester) async {
      await pumpSaved(
        tester,
        diaries: [
          _diary(),
          _diary(id: 'd0'),
        ],
      );
      expect(find.byKey(const ValueKey('first_diary_page_sheet')), findsNothing);
      expect(find.text('그림일기 장으로 볼 수 있어요'), findsOneWidget);
    });

    testWidgets('스위치가 닫히면 시트·스낵바 모두 없음', (tester) async {
      await pumpSaved(tester, diaries: [_diary()], bookOn: false);
      expect(find.byKey(const ValueKey('first_diary_page_sheet')), findsNothing);
      expect(find.text('그림일기 장으로 볼 수 있어요'), findsNothing);
    });
  });

  group('K-5 홈 일기 띠 캡션 · K-6 견본 그림일기 장', () {
    late Directory dir;
    setUpAll(() => initializeDateFormatting('ko_KR'));
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('k5');
    });
    tearDown(() => dir.delete(recursive: true));

    const pet = Pet(id: 'account:p1', name: '구름이', species: PetSpecies.dog);

    List<Override> overrides({required bool bookOn, required List<Diary> diaries}) => [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
      diaryRepositoryProvider.overrideWithValue(_FakeDiaryRepository(diaries)),
      diaryBookEnabledProvider.overrideWith((ref) => Stream.value(bookOn)),
      effectivePetsProvider.overrideWith((ref) async => const [pet]),
      userRepositoryProvider.overrideWithValue(UserRepository(firestore: FakeFirebaseFirestore())),
      diaryPageImageServiceProvider.overrideWithValue(_FakePageService(dir)),
    ];

    test('장 수는 목록이 끝까지 들어왔을 때만, 그 반려동물 일기만 센다', () {
      final page = DiaryPage(
        diaries: [
          _diary(),
          _diary(id: 'd2'),
        ],
      );
      expect(homeDiaryPageCount(page, 'account:p1'), 2);
      expect(homeDiaryPageCount(page, 'account:other'), isNull);
      expect(homeDiaryPageCount(DiaryPage(diaries: [_diary()], hasMore: true), 'account:p1'), isNull);
      expect(homeDiaryPageCount(null, 'account:p1'), isNull);
    });

    Future<void> pumpRow(WidgetTester tester, {required bool bookOn}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(
            bookOn: bookOn,
            diaries: [
              _diary(),
              _diary(id: 'd2'),
              _diary(id: 'd3'),
            ],
          ),
          child: const MaterialApp(home: Scaffold(body: TodayDiaryRow())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('스위치가 열리면 "그림일기 3장이 모였어요 · 나만 볼 수 있어요"(압박 낱말 없음)', (tester) async {
      await pumpRow(tester, bookOn: true);
      expect(find.text('그림일기 3장이 모였어요'), findsOneWidget);
      expect(find.text(' · 나만 볼 수 있어요'), findsOneWidget);
      expect(find.text('일기는 나만 볼 수 있어요'), findsNothing);
      for (final word in ['연속', '더 쓰면', '놓치지', '남았', '목표']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
      await tester.tap(find.byKey(const ValueKey('home_diary_page_count')));
      await tester.pumpAndSettle();
      expect(find.text('그림일기 만들기'), findsWidgets, reason: '그림일기 만들기 흐름으로');
    });

    testWidgets('스위치가 닫히면 기존 캡션', (tester) async {
      await pumpRow(tester, bookOn: false);
      expect(find.text('일기는 나만 볼 수 있어요'), findsOneWidget);
      expect(find.textContaining('장이 모였어요'), findsNothing);
    });

    Future<void> pumpEmptyList(WidgetTester tester, {required bool bookOn}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(bookOn: bookOn, diaries: const []),
          child: const MaterialApp(
            home: Scaffold(
              body: DiaryListBody(selectedPet: pet, allPets: [pet]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('일기 0편 + 스위치 열림: 견본 그림일기 장 + "견본" 칩 + 손글씨 한 줄 + [첫 일기 쓰기]', (tester) async {
      await pumpEmptyList(tester, bookOn: true);
      expect(find.byKey(const ValueKey('diary_sample_page')), findsOneWidget);
      expect(find.text('견본'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data?.replaceAll('\u2060', '') == '일기를 쓰면 이렇게 그림일기 장이 돼요'),
        findsOneWidget,
      );
      expect(find.text('첫 일기 쓰기'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image).first);
      expect((image.image as AssetImage).assetName, 'assets/diary/sample_page.png');
    });

    testWidgets('일기 0편 + 스위치 닫힘: 견본 없이 지금 화면 그대로', (tester) async {
      await pumpEmptyList(tester, bookOn: false);
      expect(find.byKey(const ValueKey('diary_sample_page')), findsNothing);
      expect(find.text('견본'), findsNothing);
      expect(find.text('첫 일기 쓰기'), findsOneWidget);
    });

    test('견본 에셋 1x·2x가 있다', () {
      expect(File('assets/diary/sample_page.png').existsSync(), isTrue);
      expect(File('assets/diary/2.0x/sample_page.png').existsSync(), isTrue);
    });
  });

  group('K-7 주문 오픈 알림 신청', () {
    testWidgets('켜면 bookOrderInterest.on = true, 취소하면 false(updatedAt 함께), 미끼 문구 없음', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
            userRepositoryProvider.overrideWithValue(UserRepository(firestore: firestore)),
          ],
          child: const MaterialApp(home: Scaffold(body: BookOrderInterestToggle())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('주문이 열리면 알려 주세요'), findsOneWidget);
      for (final word in ['할인', '한정', '원', '선착순']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }

      await tester.tap(find.byKey(const ValueKey('book_order_interest_off')));
      await tester.pumpAndSettle();
      expect(find.text('알림을 신청했어요'), findsOneWidget);
      var data = (await firestore.collection('users').doc('u1').get()).data()!;
      expect(data['bookOrderInterest']['on'], isTrue);
      expect(data['bookOrderInterest']['updatedAt'], isNotNull);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('주문이 열리면 알려 주세요'), findsOneWidget);
      data = (await firestore.collection('users').doc('u1').get()).data()!;
      expect(data['bookOrderInterest']['on'], isFalse);
    });
  });

  group('K-8 온보딩 한 줄', () {
    Future<void> pumpOnboarding(WidgetTester tester, Stream<bool> book) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [diaryBookEnabledProvider.overrideWith((ref) => book)],
          child: MaterialApp(home: OnboardingScreen(onDone: () {})),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('스위치가 열리면 "우리 아이 일기 · 그림일기", 진료기록은 세 번째 줄 설명에', (tester) async {
      await pumpOnboarding(tester, Stream.value(true));
      expect(find.text('우리 아이 일기 · 그림일기'), findsOneWidget);
      expect(find.text('쓴 일기가 그림일기 공책이 돼요'), findsOneWidget);
      expect(find.text('진료기록 · 예약 일정을 한곳에서'), findsOneWidget);
      expect(find.text('우리 아이 일기 · 진료기록'), findsNothing);
    });

    testWidgets('닫혔거나 아직 모르면(로딩) 지금 문구', (tester) async {
      for (final book in [Stream.value(false), const Stream<bool>.empty()]) {
        await pumpOnboarding(tester, book);
        expect(find.text('우리 아이 일기 · 진료기록'), findsOneWidget);
        expect(find.text('로그인하면 계정에 저장돼요'), findsOneWidget);
        expect(find.text('다니는 병원 일정을 한곳에서'), findsOneWidget);
        expect(find.textContaining('그림일기'), findsNothing);
      }
    });
  });
}
