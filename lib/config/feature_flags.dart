/// v1 출시 범위 플래그("v1 출시 준비" 지시서 1) — 1차 출시는 구글 +
/// 이메일 + 게스트로 나가고, 카카오·애플 로그인은 버튼만 숨긴다. 관련
/// 코드(`KakaoSdk.init`, `signInWithKakao`/`signInWithApple`, 네이티브
/// 키 등)는 전부 그대로 남겨 두고, 이 값만 true로 바꾸면 코드 변경 없이
/// 버튼이 다시 보인다(마켓 URL 확보 후 적용할 카카오 실연결 작업과는
/// 무관 — 그건 별도 지시서에서 다룬다).
const bool kEnableKakaoLogin = false;

const bool kEnableAppleLogin = false;
