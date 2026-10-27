import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/diary_photo_display.dart';

/// 상세 화면에서 사진을 넘길 때 미리 받아 둘(precache) 인덱스("일기
/// 수정" 지시서 2-2) — 상세 진입 시(0번째)엔 첫 장·다음 장, 그 뒤엔
/// 앞뒤만, 범위 밖은 제외한다.
void main() {
  group('diaryPhotoPrecacheIndices', () {
    test('맨 처음(0번째)이면 첫 장·다음 장만 돌려준다', () {
      expect(diaryPhotoPrecacheIndices(index: 0, total: 5), [0, 1]);
    });

    test('중간이면 앞뒤를 모두 돌려준다', () {
      expect(diaryPhotoPrecacheIndices(index: 2, total: 5), [1, 2, 3]);
    });

    test('마지막이면 다음 장 없이 앞뒤만(뒤는 범위 밖이라 빠진다)', () {
      expect(diaryPhotoPrecacheIndices(index: 4, total: 5), [3, 4]);
    });

    test('사진이 한 장뿐이면 그 한 장만', () {
      expect(diaryPhotoPrecacheIndices(index: 0, total: 1), [0]);
    });
  });
}
