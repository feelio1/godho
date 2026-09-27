const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * 카카오 액세스 토큰 → Firebase Custom Token 교환 (펫클 2단계 지시서 1).
 *
 * 배포 전제: 아직 배포하지 않았다(Blaze 요금제 미활성). 클라이언트
 * (lib/data/auth_repository.dart의 signInWithKakao)는 이 함수가 없다는
 * 전제로 항상 안전하게 "카카오 로그인 준비 중입니다"로 끝난다 — 이
 * 함수를 배포한 뒤에 클라이언트 쪽 연결을 마저 이어가면 된다.
 *
 * 흐름: 클라이언트가 카카오 SDK(kakao_flutter_sdk_user)로 로그인해 얻은
 * accessToken을 넘기면, 카카오 사용자 정보 API로 그 토큰이 실제 유효한
 * 카카오 세션인지 서버에서 확인한 뒤(클라이언트가 보낸 값을 그대로
 * 믿지 않는다), 같은 카카오 사용자 ID로 Firebase Custom Token을 만들어
 * 돌려준다. 클라이언트는 이 토큰으로 signInWithCustomToken을 호출해
 * Firebase 세션을 얻는다.
 */
exports.exchangeKakaoToken = onCall(async (request) => {
  const accessToken = request.data && request.data.accessToken;
  if (!accessToken || typeof accessToken !== 'string') {
    throw new HttpsError('invalid-argument', 'accessToken이 필요합니다.');
  }

  const response = await fetch('https://kapi.kakao.com/v2/user/me', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok) {
    throw new HttpsError('unauthenticated', '카카오 액세스 토큰이 유효하지 않습니다.');
  }
  const kakaoUser = await response.json();

  // Firebase uid와 카카오 회원번호가 절대 우연히 겹치지 않게 접두사를
  // 붙인다 — 다른 로그인 제공자(구글 등)의 uid는 Firebase Auth가 이미
  // 자체 형식으로 발급하므로 충돌 여지가 없다.
  const uid = `kakao:${kakaoUser.id}`;
  const account = kakaoUser.kakao_account || {};

  const customToken = await admin.auth().createCustomToken(uid, {
    provider: 'kakao',
  });

  return {
    customToken,
    profile: {
      email: account.email || null,
      displayName: (account.profile && account.profile.nickname) || null,
    },
  };
});
