import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/diary_book/book_input.dart';
import 'package:petcliniccheck/diary_book/book_layout.dart';
import 'package:petcliniccheck/diary_book/book_layout_engine.dart';
import 'package:petcliniccheck/diary_book/book_spec.dart';
import 'package:petcliniccheck/diary_book/book_text.dart';
import 'package:petcliniccheck/diary_book/photo_slots.dart';

BookPhoto _photo(String id, {int w = 2048, int h = 1536}) => BookPhoto(id: id, widthPx: w, heightPx: h);

BookDiaryEntry _entry(
  String id,
  DateTime date, {
  BookWeather? weather,
  List<String> activities = const [],
  String text = '',
  int photos = 0,
}) =>
    BookDiaryEntry(
      id: id,
      date: date,
      weather: weather,
      activities: activities,
      text: text,
      photos: [for (var i = 0; i < photos; i++) _photo('$id-$i')],
    );

BookInput _input(List<BookDiaryEntry> entries, {String? coverPhotoId}) => BookInput(
      petName: '구름이',
      title: '',
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 12, 31),
      entries: entries,
      coverPhotoId: coverPhotoId,
    );

BookLayout _ok(BookLayoutResult result) {
  expect(result, isA<BookLayoutOk>());
  return (result as BookLayoutOk).layout;
}

bool _close(double a, double b) => (a - b).abs() < 1e-6;

void main() {
  group('photoSlotRects', () {
    const box = MmRect(0, 0, 100, 60);

    test('사진 수별 배치', () {
      expect(photoSlotRects(box, 0), isEmpty);
      expect(photoSlotRects(box, 1), [box]);

      final two = photoSlotRects(box, 2, gap: 2);
      expect(two.map((r) => r.width), [49, 49]);
      expect(two[1].x, 51);

      // 3장: 왼쪽 큰 1 + 오른쪽 위아래 2(시안).
      final three = photoSlotRects(box, 3, gap: 2);
      expect(three[0].height, 60);
      expect(three[0].width, greaterThan(three[1].width));
      expect(three[1].x, three[2].x);
      expect(three[1].height, 29);
      expect(three[2].y, 31);

      final four = photoSlotRects(box, 4, gap: 2);
      expect(four.every((r) => r.width == 49 && r.height == 29), isTrue);

      // 5장: 큰 1 + 작은 4.
      final five = photoSlotRects(box, 5, gap: 2);
      expect(five.length, 5);
      expect(five[0].height, 60);
      expect(five.skip(1).every((r) => r.height == 29 && _close(r.width, 23.5)), isTrue);
      // 모든 칸은 상자 안에 있다.
      expect(five.every((r) => r.right <= 100 + 1e-9 && r.bottom <= 60 + 1e-9), isTrue);
    });

    test('5장 넘게 와도 5칸까지만', () {
      expect(photoSlotRects(box, 7).length, 5);
    });
  });

  group('coverCrop / photoDpi', () {
    test('가로로 긴 사진은 좌우를 가운데 기준으로 잘라낸다', () {
      final crop = coverCrop(photoWidthPx: 2000, photoHeightPx: 1000, slot: const MmRect(0, 0, 50, 50));
      expect(crop.width, 0.5);
      expect(crop.left, 0.25);
      expect(crop.height, 1);
    });

    test('세로로 긴 사진은 위아래를 잘라낸다', () {
      final crop = coverCrop(photoWidthPx: 1000, photoHeightPx: 2000, slot: const MmRect(0, 0, 100, 50));
      expect(crop.width, 1);
      expect(crop.height, 0.25);
      expect(crop.top, 0.375);
    });

    test('크기를 모르면 자르지 않고 dpi도 판단하지 않는다', () {
      final slot = buildPhotoSlot(const BookPhoto(id: 'x', widthPx: 0, heightPx: 0), const MmRect(0, 0, 50, 50),
          minDpi: 150);
      expect(slot.crop.width, 1);
      expect(slot.dpi, isNull);
      expect(slot.lowResolution, isFalse);
    });

    test('dpi = 쓰이는 픽셀 ÷ (칸 mm / 25.4), 150 미만이면 경고', () {
      // 254mm 칸에 1500px → 150dpi(경계값은 경고 아님).
      final ok = buildPhotoSlot(_photo('a', w: 1500, h: 1500), const MmRect(0, 0, 254, 254), minDpi: 150);
      expect(ok.dpi, closeTo(150, 1e-9));
      expect(ok.lowResolution, isFalse);
      final low = buildPhotoSlot(_photo('b', w: 1400, h: 1400), const MmRect(0, 0, 254, 254), minDpi: 150);
      expect(low.lowResolution, isTrue);
      // 잘라낸 만큼만 센다: 2000px 중 절반만 쓰이면 1000px.
      final cropped = buildPhotoSlot(_photo('c', w: 2000, h: 1000), const MmRect(0, 0, 25.4, 25.4), minDpi: 150);
      expect(cropped.dpi, closeTo(1000, 1e-9));
    });
  });

  group('layoutBook', () {
    test('일기가 없으면 Empty', () {
      expect(layoutBook(_input(const [])), isA<BookLayoutEmpty>());
    });

    test('표지 · 일기 · 메모 · 함께한 날들 — 최소 4쪽, 짝수', () {
      final layout = _ok(layoutBook(_input([_entry('d1', DateTime(2026, 10, 28), photos: 1)])));
      expect(layout.pageCount, 4);
      expect(layout.pages[0], isA<CoverPage>());
      expect(layout.pages[1], isA<DiaryEntryPage>());
      expect(layout.pages[2], isA<MemoPage>());
      expect(layout.pages[3], isA<SummaryPage>());
      expect([for (final p in layout.pages) p.pageNumber], [1, 2, 3, 4]);
    });

    test('쪽 번호: 표지는 없음, 첫 일기 쪽이 1 — 이어지는 쪽·메모·함께한 날들까지 연속', () {
      // 표지 + 일기(1) + 이어서(2) + 일기(3) + 메모(4) + 함께한 날들(5) = 6쪽.
      final layout = _ok(layoutBook(_input([
        _entry('long', DateTime(2026, 10, 1), photos: 1, text: '가' * 200),
        _entry('next', DateTime(2026, 10, 2)),
      ])));
      expect(layout.pages.map((p) => p.runtimeType).toList(),
          [CoverPage, DiaryEntryPage, ContinuationPage, DiaryEntryPage, MemoPage, SummaryPage]);
      expect([for (final p in layout.pages) p.displayNumber], [null, 1, 2, 3, 4, 5]);
      expect([for (final p in layout.pages) p.pageLabel], [null, '— 1 —', '— 2 —', '— 3 —', '— 4 —', '— 5 —']);
      expect(layout.pages.first.displayName, '표지');
      expect(layout.pages[2].displayName, '2쪽');
    });

    test('함께한 날들의 작은 하단 문구는 쪽 번호 자리와 겹치지 않는다', () {
      const spec = BookSpec.a5;
      final layout = _ok(layoutBook(_input([_entry('d1', DateTime(2026, 10, 1))])));
      final summary = layout.pages.last as SummaryPage;
      final pageNumberTop = spec.heightMm - spec.safeMm - BookLayoutMetrics.footerHeight;
      expect(summary.footerRect.bottom, lessThanOrEqualTo(pageNumberTop + 1e-9));
      expect(summary.footerRect.y, greaterThan(summary.bodyRect.bottom));
    });

    test('총 쪽수가 홀수면 메모 쪽 하나로 짝수를 맞춘다', () {
      // 표지 1 + 일기 3 + 함께한 날들 1 = 5 → 6.
      final layout = _ok(layoutBook(_input([
        for (var i = 1; i <= 3; i++) _entry('d$i', DateTime(2026, 10, i)),
      ])));
      expect(layout.pageCount, 6);
      expect(layout.pages.whereType<MemoPage>().length, 1);
      expect(layout.pages.last, isA<SummaryPage>());
      // 짝수면 메모 없음: 1 + 4 + 1 = 6.
      final even = _ok(layoutBook(_input([
        for (var i = 1; i <= 4; i++) _entry('d$i', DateTime(2026, 10, i)),
      ])));
      expect(even.pageCount, 6);
      expect(even.pages.whereType<MemoPage>(), isEmpty);
    });

    test('최대 쪽수를 넘으면 자르지 않고 오류', () {
      final spec = const BookSpec(widthMm: 148, heightMm: 210, bleedMm: 3, safeMm: 10, maxPages: 6);
      final result = layoutBook(
        _input([for (var i = 1; i <= 5; i++) _entry('d$i', DateTime(2026, 10, i))]),
        spec: spec,
      );
      expect(result, isA<BookLayoutTooManyPages>());
      expect((result as BookLayoutTooManyPages).pageCount, 8);
      expect(result.maxPages, 6);
    });

    test('일기는 날짜순, 머리 칸 날짜 문구', () {
      final layout = _ok(layoutBook(_input([
        _entry('late', DateTime(2026, 11, 2)),
        _entry('early', DateTime(2026, 10, 28)),
      ])));
      final diaries = layout.pages.whereType<DiaryEntryPage>().toList();
      expect(diaries.map((d) => d.diaryId), ['early', 'late']);
      expect(diaries.first.dateLabel, '2026년 10월 28일 수요일');
    });

    test('날씨 동그라미는 기록된 날씨 아이콘 위, 없으면 없음', () {
      final layout = _ok(layoutBook(_input([
        _entry('rain', DateTime(2026, 10, 1), weather: BookWeather.rainy),
        _entry('none', DateTime(2026, 10, 2)),
      ])));
      final diaries = layout.pages.whereType<DiaryEntryPage>().toList();
      final rain = diaries[0];
      expect(rain.weatherIcons.map((w) => w.weather), BookWeather.values);
      final rainIcon = rain.weatherIcons[BookWeather.rainy.index];
      expect(rain.weatherMark, isNotNull);
      expect(rain.weatherMark!.centerX, rainIcon.centerX);
      expect(rain.weatherMark!.centerY, rainIcon.centerY);
      // 아이콘은 왼쪽→오른쪽, 머리 칸 오른쪽(날씨) 영역 안.
      final xs = rain.weatherIcons.map((w) => w.centerX).toList();
      expect(xs, [...xs]..sort());
      expect(xs.first, greaterThan(rain.headerDividerX));
      expect(xs.last, lessThan(rain.headerRect.right));
      expect(diaries[1].weatherMark, isNull);
    });

    test('오늘 한 일 문구, 태그 없으면 빈 문구', () {
      final layout = _ok(layoutBook(_input([
        _entry('a', DateTime(2026, 10, 1), activities: ['산책', '간식', '놀이']),
        _entry('b', DateTime(2026, 10, 2)),
      ])));
      final diaries = layout.pages.whereType<DiaryEntryPage>().toList();
      expect(diaries[0].activityText, '산책 · 간식 · 놀이');
      expect(diaries[1].activityText, '');
    });

    test('사진이 없으면 그림 칸 대신 원고지 줄이 늘어난다', () {
      final layout = _ok(layoutBook(_input([
        _entry('photo', DateTime(2026, 10, 1), photos: 3),
        _entry('nophoto', DateTime(2026, 10, 2)),
      ])));
      final diaries = layout.pages.whereType<DiaryEntryPage>().toList();
      expect(diaries[0].pictureBox, isNotNull);
      expect(diaries[0].photos.length, 3);
      expect(diaries[1].pictureBox, isNull);
      expect(diaries[1].photos, isEmpty);
      expect(diaries[1].grid.rows, greaterThan(diaries[0].grid.rows));
      // A5 기본값: 사진 있으면 8줄, 없으면 14줄, 12칸 정사각.
      expect(diaries[0].grid.rows, 8);
      expect(diaries[1].grid.rows, 14);
      expect(diaries[0].grid.columns, 12);
      expect(diaries[0].grid.rect.width, closeTo(BookSpec.a5.contentWidthMm, 1e-9));
    });

    test('모든 요소는 안전 여백 안에 있다', () {
      const spec = BookSpec.a5;
      final layout = _ok(layoutBook(_input([
        _entry('a', DateTime(2026, 10, 1), photos: 5, text: '가' * 400, weather: BookWeather.sunny),
      ])));
      bool inside(MmRect r) =>
          r.x >= spec.safeMm - 1e-9 &&
          r.y >= spec.safeMm - 1e-9 &&
          r.right <= spec.widthMm - spec.safeMm + 1e-9 &&
          r.bottom <= spec.heightMm - spec.safeMm + 1e-9;
      for (final page in layout.pages) {
        switch (page) {
          case DiaryEntryPage():
            expect(inside(page.headerRect), isTrue);
            expect(inside(page.grid.rect), isTrue);
            expect(inside(page.pictureBox!), isTrue);
            expect(page.photos.every((p) => inside(p.rect)), isTrue);
          case ContinuationPage():
            expect(inside(page.grid.rect), isTrue);
          case CoverPage():
            expect(inside(page.frameRect), isTrue);
            expect(inside(page.titleRect), isTrue);
          case SummaryPage():
            expect(inside(page.footerRect), isTrue);
          case MemoPage():
            break;
        }
      }
    });

    test('긴 글은 이어지는 쪽에 원고지만 이어서', () {
      // 사진 있는 첫 쪽 8줄×12칸 = 96자, 이어지는 쪽 15줄×12칸 = 180자.
      final layout = _ok(layoutBook(_input([
        _entry('long', DateTime(2026, 10, 1), photos: 1, text: '가' * 200),
        _entry('next', DateTime(2026, 10, 2)),
      ])));
      final kinds = layout.pages.map((p) => p.runtimeType).toList();
      expect(kinds.sublist(0, 4), [CoverPage, DiaryEntryPage, ContinuationPage, DiaryEntryPage]);
      final cont = layout.pages[2] as ContinuationPage;
      expect(cont.diaryId, 'long');
      expect(cont.dateLabel, '2026년 10월 1일 목요일');
      expect(cont.grid.rows, 15);
      expect(cont.grid.cells.expand((r) => r).where((c) => c == '가').length, 200 - 96);
    });

    test('표지 사진: 고른 사진, 없으면 기간 안 첫 사진', () {
      final entries = [
        _entry('b', DateTime(2026, 10, 5), photos: 2),
        _entry('a', DateTime(2026, 10, 1), photos: 1),
      ];
      final byDefault = _ok(layoutBook(_input(entries))).pages.first as CoverPage;
      expect(byDefault.photo!.photo.id, 'a-0');
      expect(byDefault.title, '구름이의 그림일기');
      expect(byDefault.periodLabel, '2026. 10 — 2026. 12');
      final chosen = _ok(layoutBook(_input(entries, coverPhotoId: 'b-1'))).pages.first as CoverPage;
      expect(chosen.photo!.photo.id, 'b-1');
      final noPhotos = _ok(layoutBook(_input([_entry('x', DateTime(2026, 10, 1))]))).pages.first as CoverPage;
      expect(noPhotos.photo, isNull);
    });

    test('해상도 경고가 있는 쪽 번호를 알려준다', () {
      final layout = _ok(layoutBook(_input([
        BookDiaryEntry(id: 'low', date: DateTime(2026, 10, 2), photos: const [BookPhoto(id: 'tiny', widthPx: 200, heightPx: 150)]),
        BookDiaryEntry(id: 'ok', date: DateTime(2026, 10, 3), photos: [_photo('big')]),
      ], coverPhotoId: 'big')));
      expect(layout.lowResolutionPageNumbers, [2]);
      expect(layout.lowResolutionPageNames, ['1쪽']);
      // 표지 사진이 낮으면 "표지".
      final cover = _ok(layoutBook(_input([
        BookDiaryEntry(id: 'low', date: DateTime(2026, 10, 2), photos: const [BookPhoto(id: 'tiny', widthPx: 200, heightPx: 150)]),
      ])));
      expect(cover.lowResolutionPageNames, ['표지', '1쪽']);
    });

    test('함께한 날들: 기간·일기 수·많이 한 활동 3개(같으면 먼저 기록된 순)', () {
      final layout = _ok(layoutBook(_input([
        _entry('1', DateTime(2026, 10, 1), activities: ['산책', '간식']),
        _entry('2', DateTime(2026, 10, 2), activities: ['놀이', '산책']),
        _entry('3', DateTime(2026, 10, 3), activities: ['목욕', '간식', '산책']),
        _entry('4', DateTime(2026, 10, 4), activities: ['놀이']),
      ])));
      final summary = layout.pages.last as SummaryPage;
      expect(summary.diaryCount, 4);
      expect(summary.periodLabel, '2026. 10 — 2026. 12');
      expect(summary.topActivities, const [
        ActivityCount('산책', 3),
        ActivityCount('간식', 2),
        ActivityCount('놀이', 2),
      ]);
    });
  });

  test('bookPeriodLabel: 같은 달이면 하나만', () {
    expect(bookPeriodLabel(DateTime(2026, 3, 1), DateTime(2026, 3, 20)), '2026. 03');
    expect(bookPeriodLabel(DateTime(2026, 10, 1), DateTime(2027, 1, 2)), '2026. 10 — 2027. 01');
  });
}
