import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/config/feature_flags.dart';

/// v1 출시 범위는 구글 + 이메일 + 게스트다("v1 출시 준비" 지시서 1) —
/// 카카오는 코드를 지우지 않고 이 플래그로만 숨긴다. 애플 로그인은 iOS
/// 출시 준비(L-3)에서 켰다 — iOS에서만 보이는지는 로그인 화면 테스트
/// (update_1_0_0_6_test.dart)가 확인한다.
void main() {
  test('카카오 로그인은 숨김, 애플 로그인은 켬(iOS 전용)', () {
    expect(kEnableKakaoLogin, isFalse);
    expect(kEnableAppleLogin, isTrue);
  });
}
