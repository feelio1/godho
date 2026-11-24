# 펫클 iOS 빌드 — Codemagic(맥 없이) → TestFlight

`codemagic.yaml`의 `ios-testflight` 워크플로가 저장소를 받아 비밀 파일을 만들고,
서명하고, `flutter build ipa`로 빌드해 **TestFlight에만** 올린다. App Store 심사
제출은 App Store Connect에서 직접 한다. 저장소에는 키·인증서·설정 파일 원본을
**절대** 넣지 않는다(`ios/Runner/GoogleService-Info.plist`, `ios/Flutter/Secrets.xcconfig`는
`.gitignore`에 있다).

## 1. 환경 변수 그룹 `petcli_ios`

Codemagic > 앱 > Environment variables에서 그룹 이름을 `petcli_ios`로 만들고, 아래 이름
그대로 넣는다. 전부 **Secure** 체크. 값은 로그에 찍히지 않는다(스크립트는 "있음/없음"만 출력).

| 이름 | 값 | 없으면 |
|---|---|---|
| `GOOGLE_SERVICE_INFO_PLIST` | Firebase 콘솔 iOS 앱(번들 ID `com.petcheck.petcliniccheck`)의 `GoogleService-Info.plist`를 **base64로 바꾼 한 줄** | Firebase 없이 빌드(게스트 기능만) |
| `ADMOB_APP_ID_IOS` | AdMob iOS 앱 ID (`ca-app-pub-…~…`) | 구글 공개 iOS 테스트 앱 ID |
| `GOOGLE_IOS_CLIENT_ID` | `GoogleService-Info.plist`의 `CLIENT_ID` 값 | 구글 로그인 버튼만 실패 안내 |
| `GOOGLE_REVERSED_CLIENT_ID` | `GoogleService-Info.plist`의 `REVERSED_CLIENT_ID` 값 | 구글 로그인 버튼만 실패 안내 |
| `DART_DEFINES_JSON` | 아래 JSON 한 덩어리 | 지도 "준비 중", 광고는 테스트 ID |

`DART_DEFINES_JSON` 모양(값은 실제 키로 바꾼다 — 필요 없는 줄은 빼도 된다):

```json
{
  "KAKAO_NATIVE_KEY": "카카오 네이티브 앱 키",
  "KAKAO_REST_KEY": "카카오 REST API 키",
  "ADMOB_BANNER_UNIT_ID_IOS": "ca-app-pub-…/…",
  "ADMOB_APP_OPEN_UNIT_ID_IOS": "ca-app-pub-…/…"
}
```

안드로이드용 `ADMOB_BANNER_UNIT_ID`·`ADMOB_APP_OPEN_UNIT_ID`는 iOS에서 쓰지 않는다(넣어도
무시된다). 카카오 키는 카카오 개발자 콘솔의 앱 플랫폼에 **iOS 번들 ID
`com.petcheck.petcliniccheck`**를 등록해야 iOS에서 지도가 뜬다(등록 전에는 지도 화면만 "준비 중").

### `GOOGLE_SERVICE_INFO_PLIST` 만들기 (윈도우 PowerShell)

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("GoogleService-Info.plist")) | Set-Clipboard
```

복사된 한 줄을 그대로 붙여 넣는다. 맥이라면 `base64 -i GoogleService-Info.plist | pbcopy`.

## 2. App Store Connect API 키 연동 (서명·업로드)

1. App Store Connect > 사용자 및 액세스 > 통합 > App Store Connect API에서 키를 만든다
   (역할: App Manager). `.p8` 파일은 한 번만 받을 수 있다 — 안전한 곳에 보관.
2. Codemagic > Team settings > Integrations > Developer Portal > Manage keys에서 그 키를
   등록하고 이름을 **`petcli_asc`**로 한다(`codemagic.yaml`의 `integrations.app_store_connect`).
3. Apple Developer > Identifiers에서 `com.petcheck.petcliniccheck`를 만들고 **Sign In with Apple**
   기능을 켠다(앱의 `Runner.entitlements`에 들어 있어 프로필에 없으면 서명이 실패한다).
4. Codemagic > Team settings > codemagic.yaml settings > Code signing identities에서
   - iOS certificates: Apple Distribution 인증서를 **Generate**(또는 가진 것 업로드).
   - iOS provisioning profiles: **Fetch profiles**로 `com.petcheck.petcliniccheck`의 App Store 프로필을 받는다.
   `ios_signing`(distribution_type `app_store`)이 이 둘을 자동으로 골라 쓴다.
5. App Store Connect에 같은 번들 ID로 앱(아이폰)을 먼저 만들어 둔다 — 없으면 업로드가 실패한다.

## 3. 빌드

Codemagic에서 `iOS TestFlight` 워크플로를 **직접 시작**한다(푸시로 자동 시작하지 않음).
순서: 비밀 파일 만들기 → `flutter pub get` → `xcode-project use-profiles` →
`flutter build ipa --release --dart-define-from-file=<임시 파일>` → TestFlight 업로드.

- 버전·빌드 번호는 `pubspec.yaml`의 `version: 1.0.0+N`을 그대로 쓴다. 같은 번호로 두 번
  올릴 수 없으니, 다시 올릴 때는 `+N`을 올린 커밋으로 빌드한다.
- dart-define 임시 파일은 저장소·`build/` 밖(`$HOME/petcli_dart_defines.json`)에 만든다.
- Flutter 버전은 `3.47.8`로 고정(저장소 개발 환경과 같게). iOS 플러그인은 전부
  Swift Package Manager로 받으므로 CocoaPods 단계가 없다.

## 4. 처음 TestFlight에서 확인할 것

맥 없이 저장소만으로는 확인할 수 없어 실기기·첫 업로드에서 본다.

- `Info.plist`에 `NSLocationAlwaysAndWhenInUseUsageDescription`도 넣어 두었다 — 위치 패키지가 "항상 허용" API를
  코드에 갖고 있어 업로드 검사(`ITMS-90683`)를 피하려는 것이고, 앱은 "사용하는 동안"만 요청한다.
- 첫 실행: 온보딩 → 메인 화면에서 추적 허용(ATT) 창이 한 번 뜨는지, 광고가 그 뒤에 뜨는지.
- 애플 로그인·구글 로그인, 회원 탈퇴(애플 계정은 탈퇴 전에 애플 확인 창이 한 번 더 뜬다).
- 예약 알림·일기 알림: 처음 켤 때만 알림 권한 창, 앱이 떠 있을 때도 알림이 보이는지.
- 카카오 지도(키·번들 ID 등록 후), 네이버 지도 앱 열기, 전화 걸기, 그림일기 장 공유.
- 홈 인디케이터·노치 아래로 하단 탭·광고·고정 버튼이 가려지지 않는지.
