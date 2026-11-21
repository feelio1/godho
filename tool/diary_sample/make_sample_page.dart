// 빈 일기 화면의 견본 그림일기 장(assets/diary/sample_page.png, 1x·2x)을 만든다
// (4차 업데이트 K-6). 앱 실행 중에는 그리지 않고, 이 스크립트로 만든 PNG를
// 에셋으로 넣는다 — 실제 엔진(layoutSingleDiary)·렌더러(renderBookPdf)를 그대로
// 쓰고, PDF → PNG 변환은 poppler의 pdftoppm을 쓴다.
//
//   dart run tool/diary_sample/make_sample_page.dart
//
// 견본이라 사진 자리에 구름이 그림을 쓴다(사용자 일기 장·책에는 마스코트를
// 넣지 않는다).
import 'dart:io';

import 'package:petcliniccheck/diary_book/book_input.dart';
import 'package:petcliniccheck/diary_book/book_layout.dart';
import 'package:petcliniccheck/diary_book/book_layout_engine.dart';
import 'package:petcliniccheck/diary_book/book_spec.dart';
import 'package:petcliniccheck/diary_book/render/book_pdf_renderer.dart';

const _mascot = 'assets/mascot/janggureum.png';

Future<void> main() async {
  final entry = BookDiaryEntry(
    id: 'sample',
    date: DateTime(2026, 11, 14),
    weather: BookWeather.sunny,
    activities: const ['산책', '간식'],
    text: '오늘은 공원에서 낙엽을 밟았다. 바스락 소리가 좋아서 계속 뛰었다. 집에 와서 간식을 먹고 금방 잠들었다.',
    photos: const [BookPhoto(id: _mascot, widthPx: 0, heightPx: 0)],
  );
  final pages = layoutSingleDiary(entry);
  final pdf = await renderBookPdf(
    BookLayout([pages.first]),
    spec: BookSpec.a5,
    fonts: BookRenderFonts(
      handwriting: File('assets/fonts/nanum_pen_script/NanumPenScript-Regular.ttf').readAsBytesSync(),
      label: File('assets/fonts/IBMPlexSansKR-Regular.ttf').readAsBytesSync(),
    ),
    loadPhoto: (id) => File(id).readAsBytesSync(),
    pageNumbers: false,
  );
  final tmp = await Directory.systemTemp.createTemp('sample_page');
  final pdfFile = File('${tmp.path}/sample.pdf')..writeAsBytesSync(pdf);
  for (final (width, out) in [(320, 'assets/diary/sample_page'), (640, 'assets/diary/2.0x/sample_page')]) {
    final result = await Process.run('pdftoppm', [
      '-png',
      '-singlefile',
      '-scale-to-x',
      '$width',
      '-scale-to-y',
      '-1',
      pdfFile.path,
      out,
    ]);
    if (result.exitCode != 0) throw StateError('pdftoppm 실패: ${result.stderr}');
    stdout.writeln('wrote $out.png');
  }
  await tmp.delete(recursive: true);
}
