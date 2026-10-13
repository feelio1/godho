import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

/// 로그인·가입·Firestore 저장/조회처럼 네트워크가 필요한 동작이 실패한
/// 원인이 연결 문제인지 가려낸다("오프라인 안내" 지시서 E). 정확한 판정이
/// 불가능한 경우(알 수 없는 예외 타입)는 메시지 문자열에서 흔한 신호를
/// 찾아 보수적으로 판단한다 — 아니다 싶으면 네트워크가 아닌 쪽(일반
/// 실패 안내)으로 넘어간다.
bool isNetworkError(Object error) {
  if (error is SocketException) return true;
  if (error is FirebaseAuthException) {
    return error.code == 'network-request-failed';
  }
  if (error is FirebaseException) {
    return error.code == 'unavailable' || error.code == 'deadline-exceeded';
  }
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('network') ||
      text.contains('failed host lookup') ||
      text.contains('unavailable');
}

/// 어떤 동작([action], 예: "반려동물 추가")이 실패했을 때 보여줄 안내
/// 문구. 원인이 네트워크면 항상 같은 안내로 수렴시켜 사용자가 "뭘 해야
/// 하는지"를 바로 알 수 있게 하고, 그 외엔 어떤 동작이 실패했는지만
/// 담백하게 알린다 — 크래시도, 원인 불명 상태로 방치하지도 않는다.
String actionFailureMessage(Object error, String action) {
  if (isNetworkError(error)) {
    return '인터넷 연결을 확인해주세요. 연결되면 다시 시도해주세요.';
  }
  return '$action에 실패했어요. 잠시 후 다시 시도해주세요.';
}
