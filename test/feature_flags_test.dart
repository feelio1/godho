import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/config/feature_flags.dart';

/// v1 출시 범위는 구글 + 이메일 + 게스트다("v1 출시 준비" 지시서 1) —
/// 카카오·애플은 코드를 지우지 않고 이 플래그로만 숨긴다. 이 테스트는
/// v1 기본값이 "숨김"인지만 고정한다; 플래그를 true로 바꾸면 코드
/// 변경 없이 버튼이 다시 보이는지는 값을 바꿔보는 실기기 확인 대상이다.
void main() {
  test('v1 기본값은 카카오·애플 로그인 버튼이 숨겨진 상태다', () {
    expect(kEnableKakaoLogin, isFalse);
    expect(kEnableAppleLogin, isFalse);
  });
}
