import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/utils/phone_format.dart';

void main() {
  test('02 서울', () {
    expect(formatPhoneNumber('027449098'), '02-744-9098');
    expect(formatPhoneNumber('0212345678'), '02-1234-5678');
  });

  test('0XX 지역번호·010·070', () {
    expect(formatPhoneNumber('0311234567'), '031-123-4567');
    expect(formatPhoneNumber('03112345678'), '031-1234-5678');
    expect(formatPhoneNumber('01012345678'), '010-1234-5678');
    expect(formatPhoneNumber('07012345678'), '070-1234-5678');
  });

  test('050X 평생번호', () {
    expect(formatPhoneNumber('05051234567'), '0505-123-4567');
    expect(formatPhoneNumber('050712345678'), '0507-1234-5678');
  });

  test('15XX·16XX·18XX 대표번호', () {
    expect(formatPhoneNumber('15881234'), '1588-1234');
    expect(formatPhoneNumber('16441234'), '1644-1234');
    expect(formatPhoneNumber('18991234'), '1899-1234');
  });

  test('지역번호 없는 7·8자리', () {
    expect(formatPhoneNumber('36728441'), '3672-8441');
    expect(formatPhoneNumber('7228441'), '722-8441');
  });

  test('이미 하이픈이 있으면 숫자만 보고 다시 맞춘다, 모르는 형식은 그대로', () {
    expect(formatPhoneNumber('02-744-9098'), '02-744-9098');
    expect(formatPhoneNumber('031 123 4567'), '031-123-4567');
    expect(formatPhoneNumber('12345'), '12345');
    expect(formatPhoneNumber('0311234'), '0311234');
    expect(formatPhoneNumber('알 수 없음'), '알 수 없음');
  });
}
