# 펫병원체크 (PetClinicCheck)

동물병원 방문 전, 공개된 행정·인허가 정보를 확인하는 팩트체크 앱입니다.
병원을 평가·판정하지 않고, 보호자가 스스로 판단할 수 있도록 공공데이터 사실만 보여줍니다.
자세한 원칙과 워딩 규칙은 `CLAUDE.md`를 참고하세요.

## 시작하기

```bash
flutter pub get
flutter run
```

### 네이버 지도 연동 (선택)

네이버 클라우드 플랫폼에서 발급받은 Maps Client ID가 있다면 아래처럼 전달하세요.
없어도 앱은 정상 빌드되며, '주변 병원' 탭은 준비 중 화면으로 대체됩니다.

```bash
flutter run --dart-define=NAVER_MAP_CLIENT_ID=발급받은_클라이언트_ID
```

## 데이터

`assets/hospitals.json`은 인천 지역 동물병원 인허가 데이터 번들입니다. 앱 시작 시 한 번 로드되어
메모리에서 검색·필터링됩니다 (서버·계정 없음).

## 폴더 구조

- `lib/models` — Hospital, Timeline 등 데이터 모델
- `lib/data` — 번들 로더, 저장소, 로컬 저장(SharedPreferences)
- `lib/providers` — Riverpod 프로바이더
- `lib/screens` — 홈/검색/상세/주변 병원/저장/비교 화면
- `lib/widgets` — 공용 위젯 (팩트카드, 타임라인, 진료비 섹션 등)
