import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/providers/auth_provider.dart';

// authStateProvider는 firebase_auth의 authStateChanges를 감싼 얇은
// StreamProvider다(펫클 2단계 지시서 4). firebase_auth_mocks는
// kakao_flutter_sdk_user가 요구하는 pointycastle 버전과 충돌해 이
// 프로젝트에 추가할 수 없었다(2단계 지시서 6 검증 섹션의 "authState
// provider" 테스트 요구사항을 이 경계 안에서 해석) — 그래서 실제 User
// 객체를 흉내 내는 대신, authStateProvider 자체를 override해 "게스트
// (로그아웃) 상태에서 currentUserProfileProvider가 확실히 null을
// 돌려주는지"만 검증한다. "로그인 상태에서 Firestore 문서를 읽어오는"
// 실제 로직은 user_repository_test.dart가 FakeFirebaseFirestore로 직접
// 검증한다.
void main() {
  test('로그아웃 상태(authStateProvider가 null)면 currentUserProfileProvider도 null이다', () async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      ],
    );
    addTearDown(container.dispose);

    final profile = await container.read(currentUserProfileProvider.future);
    expect(profile, isNull);
  });
}
