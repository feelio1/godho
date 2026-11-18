/// 한국어 줄바꿈을 낱말 단위로 — Flutter는 한글을 글자마다 끊을 수 있어
/// "한 줄만 남 / 겨 볼까요?"처럼 낱말 가운데서 줄이 바뀐다. 공백이 아닌
/// 글자 사이에 WORD JOINER(U+2060, 보이지 않음)를 넣어 공백에서만 끊기게
/// 한다. 제목·손글씨 한 줄처럼 짧은 문구에만 쓴다(긴 본문은 그대로).
String keepWords(String text) {
  final buffer = StringBuffer();
  final runes = text.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    buffer.writeCharCode(runes[i]);
    if (i + 1 < runes.length && !_isSpace(runes[i]) && !_isSpace(runes[i + 1])) {
      buffer.write('⁠');
    }
  }
  return buffer.toString();
}

bool _isSpace(int rune) => rune == 0x20 || rune == 0x0A || rune == 0x09;
