import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:petcliniccheck/diary_book/book_input.dart';
import 'package:petcliniccheck/diary_book/book_layout.dart';
import 'package:petcliniccheck/diary_book/book_layout_engine.dart';
import 'package:petcliniccheck/diary_book/book_spec.dart';
import 'package:petcliniccheck/diary_book/diary_page_image_service.dart';
import 'package:petcliniccheck/diary_book/render/book_pdf_renderer.dart';

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
}
