import 'package:firebase_auth/firebase_auth.dart';

/// FirebaseAuth 에러 코드 → 한국어 안내 문구("자체 회원가입·로그인·
/// 비밀번호 재설정" 지시서 4). 어떤 코드든 반드시 문자열을 돌려줘
/// 크래시로 이어지지 않는다 — 모르는 코드/네트워크 오류는 담백한
/// 일반 안내로 수렴한다(시스템 오류만 빨강, 입력 안내는 중립 — 이
/// 함수는 문구만 돌려주고 색은 호출부가 정한다).
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return '이미 가입된 이메일이에요';
    case 'invalid-email':
      return '이메일 형식을 확인해주세요';
    case 'weak-password':
      return '비밀번호는 6자 이상이어야 해요';
    case 'wrong-password':
    case 'invalid-credential':
      return '이메일 또는 비밀번호가 올바르지 않아요';
    case 'user-not-found':
      return '가입되지 않은 이메일이에요';
    case 'user-disabled':
      return '사용이 제한된 계정이에요';
    case 'too-many-requests':
      return '시도가 너무 많았어요. 잠시 후 다시 시도해주세요';
    case 'network-request-failed':
      return '네트워크 연결을 확인해주세요';
    default:
      return '잠시 후 다시 시도해주세요';
  }
}
