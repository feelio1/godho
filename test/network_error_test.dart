import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/utils/network_error.dart';

void main() {
  group('isNetworkError', () {
    test('SocketException은 항상 네트워크 오류다', () {
      expect(isNetworkError(const SocketException('failed')), isTrue);
    });

    test('network-request-failed 코드의 FirebaseAuthException은 네트워크 오류다', () {
      expect(
        isNetworkError(FirebaseAuthException(code: 'network-request-failed')),
        isTrue,
      );
    });

    test('wrong-password 코드의 FirebaseAuthException은 네트워크 오류가 아니다', () {
      expect(
        isNetworkError(FirebaseAuthException(code: 'wrong-password')),
        isFalse,
      );
    });

    test('메시지에 network 관련 신호가 있는 알 수 없는 예외는 네트워크 오류로 본다', () {
      expect(isNetworkError(Exception('Failed host lookup: foo')), isTrue);
    });

    test('신호가 없는 알 수 없는 예외는 네트워크 오류가 아니다', () {
      expect(isNetworkError(Exception('뭔가 다른 문제')), isFalse);
    });
  });

  group('actionFailureMessage', () {
    test('네트워크 오류면 동작 이름과 무관하게 연결 확인 안내를 준다', () {
      expect(
        actionFailureMessage(const SocketException('failed'), '저장'),
        '인터넷 연결을 확인해주세요. 연결되면 다시 시도해주세요.',
      );
    });

    test('네트워크 오류가 아니면 동작 이름을 담은 일반 안내를 준다', () {
      expect(
        actionFailureMessage(Exception('뭔가 다른 문제'), '삭제'),
        '삭제에 실패했어요. 잠시 후 다시 시도해주세요.',
      );
    });
  });
}
