/// 원고지 배치 — 한 칸에 한 글자. 규칙:
/// - 공백은 빈 칸 한 개. 단, 자동 줄바꿈 직후 줄 맨 앞에 오는 공백은 버린다
///   (줄 첫 칸이 비어 들여쓰기처럼 보이지 않게).
/// - 줄바꿈(\n)은 다음 줄로. 줄이 꽉 차서 막 넘어간 직후의 줄바꿈은 빈 줄을
///   하나 더 만들지 않는다.
/// - 영문·숫자가 이어지면 2글자까지 한 칸("20", "26").
/// - 첫 줄 들여쓰기는 하지 않고, 글 앞뒤 공백은 버린다.
library;

const int kManuscriptColumns = 12;

bool _isAsciiAlnum(int rune) =>
    (rune >= 0x30 && rune <= 0x39) || (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);

/// [text]를 원고지 줄 목록으로 나눈다 — 각 줄은 최대 [columns]칸(뒤쪽 빈
/// 칸은 채우지 않는다). 빈 글이면 빈 목록.
List<List<String>> layoutManuscriptLines(String text, {int columns = kManuscriptColumns}) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\t', ' ').trim();
  final runes = normalized.runes.toList();
  final lines = <List<String>>[];
  var current = <String>[];
  // 지금 줄이 앞줄이 꽉 차서 자동으로 넘어온 줄인가.
  var autoWrapped = false;

  for (var i = 0; i < runes.length; i++) {
    final rune = runes[i];
    final String cell;
    if (rune == 0x0A) {
      if (current.isEmpty && autoWrapped) {
        autoWrapped = false;
        continue;
      }
      lines.add(current);
      current = <String>[];
      autoWrapped = false;
      continue;
    } else if (rune == 0x20) {
      if (current.isEmpty && autoWrapped) continue;
      cell = '';
    } else if (_isAsciiAlnum(rune) && i + 1 < runes.length && _isAsciiAlnum(runes[i + 1])) {
      cell = String.fromCharCodes([rune, runes[i + 1]]);
      i++;
    } else {
      cell = String.fromCharCode(rune);
    }
    current.add(cell);
    if (current.length == columns) {
      lines.add(current);
      current = <String>[];
      autoWrapped = true;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

/// 줄 목록을 쪽별 칸 배열로 나눈다 — 첫 쪽은 [firstPageRows]줄, 이어지는
/// 쪽은 [continuationRows]줄. 각 쪽은 rows×columns로 빈 칸('')을 채운다.
/// 글이 없어도 첫 쪽(빈 원고지) 하나는 돌려준다.
List<List<List<String>>> paginateManuscript(
  List<List<String>> lines, {
  required int firstPageRows,
  required int continuationRows,
  int columns = kManuscriptColumns,
}) {
  assert(firstPageRows > 0 && continuationRows > 0);
  List<List<String>> pad(List<List<String>> chunk, int rows) => [
        for (var r = 0; r < rows; r++)
          [for (var c = 0; c < columns; c++) r < chunk.length && c < chunk[r].length ? chunk[r][c] : ''],
      ];

  final pages = <List<List<String>>>[pad(lines.take(firstPageRows).toList(), firstPageRows)];
  var index = firstPageRows;
  while (index < lines.length) {
    pages.add(pad(lines.skip(index).take(continuationRows).toList(), continuationRows));
    index += continuationRows;
  }
  return pages;
}
