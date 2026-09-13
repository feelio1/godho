import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/utils/external_links.dart';

void main() {
  group('ExternalLinks.sanitizedPhone', () {
    test('null이면 null(전화번호 없음)', () {
      expect(ExternalLinks.sanitizedPhone(null), isNull);
    });

    test('빈 문자열·공백만 있으면 null — 스프린트 12 지시서 2: 쉼터동물병원처럼 데이터에 전화번호가 없는 경우', () {
      expect(ExternalLinks.sanitizedPhone(''), isNull);
      expect(ExternalLinks.sanitizedPhone('   '), isNull);
    });

    test('숫자만 있으면 그대로 보존된다', () {
      expect(ExternalLinks.sanitizedPhone('0212345678'), '0212345678');
    });

    test('공백·하이픈·괄호가 섞여 있어도 숫자만 남긴다', () {
      expect(ExternalLinks.sanitizedPhone('02-1234-5678'), '0212345678');
      expect(ExternalLinks.sanitizedPhone('(02) 1234 5678'), '0212345678');
      expect(ExternalLinks.sanitizedPhone('070.1234.5678'), '07012345678');
    });

    test('맨 앞 +는 국가번호 표기로 보존하고 나머지 숫자만 남긴다', () {
      expect(ExternalLinks.sanitizedPhone('+82 10-1234-5678'), '+821012345678');
    });

    test('숫자가 하나도 없는 값(문자만)이면 null — 걸 수 없는 값은 없는 것과 동일하게 취급', () {
      expect(ExternalLinks.sanitizedPhone('문의불가'), isNull);
      expect(ExternalLinks.sanitizedPhone('-'), isNull);
    });
  });
}
