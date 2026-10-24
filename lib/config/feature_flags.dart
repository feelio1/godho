/// v1 출시 범위 플래그("v1 출시 준비" 지시서 1) — 1차 출시는 구글 +
/// 이메일 + 게스트로 나가고, 카카오·애플 로그인은 버튼만 숨긴다. 관련
/// 코드(`KakaoSdk.init`, `signInWithKakao`/`signInWithApple`, 네이티브
/// 키 등)는 전부 그대로 남겨 두고, 이 값만 true로 바꾸면 코드 변경 없이
/// 버튼이 다시 보인다(마켓 URL 확보 후 적용할 카카오 실연결 작업과는
/// 무관 — 그건 별도 지시서에서 다룬다).
const bool kEnableKakaoLogin = false;

const bool kEnableAppleLogin = false;

/// "쇼핑 기초" 지시서 1 — 입점형 스토어 코드의 컴파일 타임 스위치(이중
/// 스위치 중 하나). 이 값이 false면 쇼핑 탭은 Firestore `config/shop`
/// 문서를 아예 조회하지 않고 늘 "준비 중" 화면만 보여준다(런타임 스위치
/// [shopEnabledProvider]보다 앞서 적용되는, 앱 업데이트로만 바꿀 수 있는
/// 비상 차단 스위치). 상품·주문 기능을 실제로 열 때는 이 값은 true로 두고
/// Firestore 문서의 `enabled`만 콘솔에서 바꾼다 — 그래야 앱 업데이트 없이
/// 오픈할 수 있다.
const bool kEnableShopCode = true;
