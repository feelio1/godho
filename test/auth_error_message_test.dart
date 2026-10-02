import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/utils/auth_error_message.dart';

void main() {
  group(
    'authErrorMessage — FirebaseAuth 에러 코드를 한국어 안내로 바꾼다'
    '("자체 회원가입·로그인·비밀번호 재설정" 지시서 4). 어떤 코드든 '
    '크래시 없이 문자열 하나로 수렴한다',
    () {
      test('이미 가입된 이메일', () {
        expect(
          authErrorMessage(FirebaseAuthException(code: 'email-already-in-use')),
          '이미 가입된 이메일이에요',
        );
      });

      test('이메일 형식 오류', () {
        expect(
          authErrorMessage(FirebaseAuthException(code: 'invalid-email')),
          '이메일 형식을 확인해주세요',
        );
      });

      test('약한 비밀번호', () {
        expect(
          authErrorMessage(FirebaseAuthException(code: 'weak-password')),
          '비밀번호는 6자 이상이어야 해요',
        );
      });

      test('비밀번호 불일치(wrong-password/invalid-credential 모두 같은 안내)', () {
        expect(
          authErrorMessage(FirebaseAuthException(code: 'wrong-password')),
          '이메일 또는 비밀번호가 올바르지 않아요',
        );
        expect(
          authErrorMessage(FirebaseAuthException(code: 'invalid-credential')),
          '이메일 또는 비밀번호가 올바르지 않아요',
        );
      });

      test('가입되지 않은 이메일', () {
        expect(
          authErrorMessage(FirebaseAuthException(code: 'user-not-found')),
          '가입되지 않은 이메일이에요',
        );
      });

      test('모르는 코드/네트워크 오류는 크래시 없이 담백한 일반 안내로 수렴한다', () {
        expect(
          authErrorMessage(FirebaseAuthException(code: 'network-request-failed')),
          isNotEmpty,
        );
        expect(
          authErrorMessage(FirebaseAuthException(code: 'completely-unknown-code')),
          isNotEmpty,
        );
      });
    },
  );
}
