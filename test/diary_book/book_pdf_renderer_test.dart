import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:petcliniccheck/diary_book/book_input.dart';
import 'package:petcliniccheck/diary_book/book_layout.dart';
import 'package:petcliniccheck/diary_book/book_layout_engine.dart';
import 'package:petcliniccheck/diary_book/book_spec.dart';
import 'package:petcliniccheck/diary_book/diary_book_pdf_service.dart';
import 'package:petcliniccheck/diary_book/render/book_pdf_renderer.dart';
import 'package:petcliniccheck/diary_book/screens/diary_book_preview_screen.dart'
    show kPreviewWatermarkCaption, kPreviewWatermarkDiagonal;

/// 렌더러 스모크 — 작은 BookLayout → 유효한 PDF 바이트, 쪽 수 일치.
BookRenderFonts _fonts() => BookRenderFonts(
      handwriting: File('assets/fonts/nanum_pen_script/NanumPenScript-Regular.ttf').readAsBytesSync(),
      label: File('assets/fonts/IBMPlexSansKR-Regular.ttf').readAsBytesSync(),
    );

Uint8List _jpeg(int w, int h) => img.encodeJpg(img.Image(width: w, height: h), quality: 70);

/// PDF 안의 쪽 객체 수(`/Type /Page`, `/Pages` 제외).
int _pdfPageCount(Uint8List bytes) =>
    RegExp(r'/Type\s*/Page(?!s)').allMatches(String.fromCharCodes(bytes)).length;

BookLayout _layout() {
  final result = layoutBook(BookInput(
    petName: '구름이',
    title: '',
    periodStart: DateTime(2026, 10, 1),
    periodEnd: DateTime(2026, 12, 31),
    entries: [
      BookDiaryEntry(
        id: 'a',
        date: DateTime(2026, 10, 28),
        weather: BookWeather.sunny,
        activities: const ['산책', '간식'],
        text: '오늘은 구름이랑 공원에 갔다. 2026년 abc',
        photos: const [
          BookPhoto(id: 'p1', widthPx: 400, heightPx: 300),
          BookPhoto(id: 'p2', widthPx: 300, heightPx: 400),
          BookPhoto(id: 'missing', widthPx: 300, heightPx: 300),
        ],
      ),
      BookDiaryEntry(id: 'b', date: DateTime(2026, 11, 2), text: '가' * 300),
    ],
  ));
  return (result as BookLayoutOk).layout;
}

void main() {
  test('작은 레이아웃 → 유효한 PDF, 쪽 수 일치, 진행 콜백, 없는 사진은 빈 칸', () async {
    final layout = _layout();
    final photos = {'p1': _jpeg(400, 300), 'p2': _jpeg(300, 400)};
    final progress = <int>[];
    final bytes = await renderBookPdf(
      layout,
      spec: BookSpec.a5,
      fonts: _fonts(),
      loadPhoto: (id) => photos[id],
      onProgress: (done, total) {
        expect(total, layout.pageCount);
        progress.add(done);
      },
    );
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(_pdfPageCount(bytes), layout.pageCount);
    expect(progress, [for (var i = 1; i <= layout.pageCount; i++) i]);
  });

  test('별도 isolate에서 그려 파일로 쓰고 쪽 진행을 알린다', () async {
    final layout = _layout();
    final dir = await Directory.systemTemp.createTemp('diary_book_test');
    addTearDown(() => dir.delete(recursive: true));
    final photo = File('${dir.path}/p1.jpg')..writeAsBytesSync(_jpeg(400, 300));
    final out = '${dir.path}/book.pdf';
    final pages = <int>[];
    await renderDiaryBookInIsolate(
      DiaryBookRenderJob(
        layout: layout,
        spec: BookSpec.a5,
        fonts: _fonts(),
        photoPaths: {'p1': photo.path},
        outPath: out,
      ),
      (p) => pages.add(p.done),
    );
    final bytes = File(out).readAsBytesSync();
    expect(_pdfPageCount(bytes), layout.pageCount);
    expect(pages.last, layout.pageCount);
    expect(File('$out.part').existsSync(), isFalse);
  });

  test('인쇄 파일(PDF)에는 미리보기 워터마크가 없다 — 워터마크는 화면 오버레이 전용', () async {
    final layout = _layout();
    final bytes = await renderBookPdf(
      layout,
      spec: BookSpec.a5,
      fonts: _fonts(),
      loadPhoto: (_) => null,
    );

    // 렌더러가 그리는 글은 전부 레이아웃에서 온다 — 그 어디에도 워터마크 문구가 없다.
    final drawnTexts = <String>[
      for (final page in layout.pages) ...switch (page) {
        CoverPage() => [page.title, page.periodLabel],
        DiaryEntryPage() => [page.dateLabel, page.activityText, ...page.grid.cells.expand((r) => r)],
        ContinuationPage() => [page.dateLabel, ...page.grid.cells.expand((r) => r)],
        SummaryPage() => [page.periodLabel, ...page.topActivities.map((a) => a.label)],
        MemoPage() => const <String>[],
      },
      for (final page in layout.pages) ?page.pageLabel,
    ];
    expect(drawnTexts.join('\n'), isNot(contains(kPreviewWatermarkDiagonal)));

    // PDF 바이트에도 그 문구가 어떤 인코딩으로도 없다. 같은 방법으로 문서 제목
    // ("구름이의 그림일기", PDF 정보 사전)은 찾아지는지 확인해 검사가 헛돌지 않게 한다.
    bool containsText(Uint8List pdf, String text) {
      final latin = String.fromCharCodes(pdf);
      final utf16 = [0xFE, 0xFF, for (final u in text.codeUnits) ...[u >> 8, u & 0xFF]];
      final hex = utf16.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return latin.contains(String.fromCharCodes(utf16)) ||
          latin.toLowerCase().contains(hex) ||
          latin.contains(String.fromCharCodes(utf8Encode(text)));
    }

    expect(containsText(bytes, '구름이의 그림일기'), isTrue, reason: '검사 방법 자체 확인(문서 제목)');
    expect(containsText(bytes, kPreviewWatermarkDiagonal), isFalse);
    expect(containsText(bytes, kPreviewWatermarkCaption), isFalse);
  });
}

List<int> utf8Encode(String text) => const Utf8Encoder().convert(text);
