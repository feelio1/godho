import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/utils/region_display.dart';

void main() {
  group(
    'sidoDisplayLabel — 데이터 키(assets/hospitals.json·fees.json 조인 키)는 '
    '그대로 두고 화면에 보여줄 라벨만 축약한다("지역 표시 라벨 축약" 지시서)',
    () {
      test('충청북/충청남/경상북/경상남은 두 글자로 축약된다', () {
        expect(sidoDisplayLabel('충청북'), '충북');
        expect(sidoDisplayLabel('충청남'), '충남');
        expect(sidoDisplayLabel('경상북'), '경북');
        expect(sidoDisplayLabel('경상남'), '경남');
      });

      test('전남광주통합은 광주·전남으로 표기된다', () {
        expect(sidoDisplayLabel('전남광주통합'), '광주·전남');
      });

      test('매핑에 없는 키는 그대로 돌려준다(값 보존)', () {
        for (final sido in [
          '서울',
          '부산',
          '대구',
          '인천',
          '대전',
          '울산',
          '세종',
          '경기',
          '강원',
          '전북',
          '제주',
        ]) {
          expect(sidoDisplayLabel(sido), sido);
        }
      });
    },
  );
}
