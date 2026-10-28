import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/diary_book/manuscript.dart';

void main() {
  group('layoutManuscriptLines', () {
    test('한 칸에 한 글자, 12칸이 차면 다음 줄로', () {
      final lines = layoutManuscriptLines('가나다라마바사아자차카타파하');
      expect(lines.length, 2);
      expect(lines[0], ['가', '나', '다', '라', '마', '바', '사', '아', '자', '차', '카', '타']);
      expect(lines[1], ['파', '하']);
    });

    test('공백은 빈 칸 한 개, 첫 줄 들여쓰기·글 앞뒤 공백 없음', () {
      expect(layoutManuscriptLines('  오늘 산책  '), [
        ['오', '늘', '', '산', '책'],
      ]);
    });

    test('줄바꿈은 다음 줄로, 연속 줄바꿈은 빈 줄', () {
      expect(layoutManuscriptLines('가\n나\n\n다'), [
        ['가'],
        ['나'],
        <String>[],
        ['다'],
      ]);
      expect(layoutManuscriptLines('가\r\n나'), [
        ['가'],
        ['나'],
      ]);
    });

    test('줄이 꽉 차 넘어간 직후의 줄바꿈·공백은 빈 줄·빈 칸을 더 만들지 않는다', () {
      final twelve = '가' * 12;
      expect(layoutManuscriptLines('$twelve\n나'), [
        List.filled(12, '가'),
        ['나'],
      ]);
      expect(layoutManuscriptLines('$twelve 나'), [
        List.filled(12, '가'),
        ['나'],
      ]);
    });

    test('영문·숫자가 이어지면 2글자까지 한 칸', () {
      expect(layoutManuscriptLines('2026년 abc'), [
        ['20', '26', '년', '', 'ab', 'c'],
      ]);
      expect(layoutManuscriptLines('a가b'), [
        ['a', '가', 'b'],
      ]);
    });

    test('빈 글은 빈 목록', () {
      expect(layoutManuscriptLines('   \n  '), isEmpty);
    });
  });

  group('paginateManuscript', () {
    test('첫 쪽은 rows×columns로 빈 칸을 채우고, 글이 없어도 한 쪽은 있다', () {
      final pages = paginateManuscript(const [], firstPageRows: 3, continuationRows: 5);
      expect(pages.length, 1);
      expect(pages.first.length, 3);
      expect(pages.first.every((row) => row.length == 12 && row.every((c) => c == '')), isTrue);
    });

    test('넘치면 이어지는 쪽으로 나눈다', () {
      final lines = layoutManuscriptLines('가' * (12 * 10));
      expect(lines.length, 10);
      final pages = paginateManuscript(lines, firstPageRows: 4, continuationRows: 6);
      expect(pages.length, 2);
      expect(pages[0].length, 4);
      expect(pages[1].length, 6);
      expect(pages[1][5].every((c) => c == '가'), isTrue);
      // 남은 글이 이어지는 쪽 일부만 채우면 나머지 줄은 빈 칸.
      final pages3 = paginateManuscript(lines, firstPageRows: 4, continuationRows: 4);
      expect(pages3.length, 3);
      expect(pages3[2][1].first, '가');
      expect(pages3[2][2].every((c) => c == ''), isTrue);
    });
  });
}
