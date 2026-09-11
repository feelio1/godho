스프린트 10 지시서 — 펫병원체크 전체 디자인 적용 (장구름 브랜드)

목표: 첨부한 디자인 목업(9화면)대로 앱 전체 룩앤필을 정비하고, 이미 추가된 장구름 마스코트 이미지들을 각 자리에 배치. 기능·데이터·로직은 절대 변경 금지 — 화면(스타일·레이아웃·이미지)만 수정. CLAUDE.md 원칙·워딩·중립성 준수. Riverpod·데이터·검색·타임라인·지도·진료기록 로직 그대로 유지.
전제: assets/mascot/에 이미지 준비됨(pubspec 등록 완료) — logo.png, home_banner.png, marker.png, my_location.png, janggureum.png, hospital_placeholder.png, empty_search.png, empty_record.png.

1. 디자인 시스템 (theme)

* `lib/theme/app_colors.dart`: 목업 톤(민트/세이지 그린 + 따뜻한 회갈색)에 맞춰 토큰 재작성.
  - primary: 0xFF0FA88B(청록) → 0xFF6FA98A(세이지 그린), primaryDark 0xFF4C8267, primarySoft 0xFFE3F1E7.
  - textPrimary: 0xFF1B1D1C(거의 검정) → 0xFF4A3F35(따뜻한 회갈색). textSecondary/textCaption도 같은 계열로.
  - background/surface도 아주 옅은 웜톤 화이트/민트로.
  - **폐업 = 회색으로 변경(빨강 아님)**: `closed`를 `neutral`과 같은 회갈색 계열로. 대신 실제 시스템 오류에만 쓰는 `AppColors.error`(구 closed 빨강값)를 새로 분리해, `app_theme.dart`의 `colorScheme.error`가 여기를 가리키게 함 — 폐업 배지 색과 시스템 에러 색이 이전엔 같은 상수를 공유하고 있었는데, 이번에 완전히 분리했다.
* `lib/theme/app_theme.dart`: 카드에 옅은 그림자(elevation 1.5, 은은한 shadowColor) + 더 둥근 모서리(16→18) 추가로 "또렷한 카드" 톤 보강. 나머지 텍스트 위계·칩·버튼 테마는 기존 구조 유지(이미 충분히 정리되어 있었음).
* `StatusBadge`/`TimelineView`의 상태 점 색은 모두 `AppColors.forStatus()`를 그대로 쓰고 있어, 토큰만 바꿔도 전 화면에서 폐업 표시가 자동으로 회색이 됨(코드 변경 없이 전파).

2. 마스코트 이미지 배치

* `MascotImage`(`lib/widgets/mascot_image.dart`)에 `assetPath` 파라미터를 추가해 기본 janggureum.png 외에 상황별 이미지(예: 검색결과 없음, 빈 기록)로 바꿔 쓸 수 있게 함. `MascotMessage`도 같은 파라미터를 그대로 전달.
  - 검색 결과 없음(`search_result_screen.dart` 2곳) → `empty_search.png`
  - 저장 없음(`saved_screen.dart`), 반려동물 미등록(`health_record_screen.dart`) → `empty_record.png`
  - 그 외 기존 MascotMessage 사용처(로딩, 지도 준비중, 비교 없음)는 기본 janggureum.png 유지 — 지시서에 명시된 자리만 변경.
* 새 `HospitalThumbnail` 위젯(`lib/widgets/hospital_thumbnail.dart`) — `hospital_placeholder.png`를 병원 사진 자리에 일괄 사용(실제 병원 사진 크롤링 없음, 모든 병원이 동일 이미지). 검색 결과 카드(`HospitalCard`), 지정 병원 카드, 병원 상세 상단, 주변 지도 하단 시트에 배치.
* 새 `HomeBanner` 위젯(`lib/widgets/home_banner.dart`) — `home_banner.png` + "동물병원 방문 전, 공개된 정보를 확인해보세요." 문구, 홈 검색창 바로 아래.
* `logo.png` — 홈 AppBar에는 janggureum 마스코트를 작은 아이콘으로(로고 전체 워드마크는 검색창 옆에 넣기엔 과함), 전체 워드마크 로고는 "이용안내" 화면 상단에 크게 배치.
* 지도 마커(`marker.png`)·내 위치(`my_location.png`)는 스프린트 6~7에서 이미 자산 경로가 연결되어 있어(에셋 존재 확인 후 자동 교체 패턴), 이번에 실제 파일이 추가되며 코드 변경 없이 자동으로 실제 이미지가 표시됨. 크기(44/56px)·anchor(하단 중앙, 핀 모양과 일치)는 목업과 맞아 추가 조정 없음.

3. 화면별 변경

* 홈(`home_screen.dart`): AppBar에 마스코트 아이콘 추가. 순서를 검색창 → 배너 → 지정 병원 → 지역/내 주변 병원 버튼 → 병원 둘러보기 → 저장한 병원으로 재배치(목업 순서에 맞춤). 기존 섹션(지역 선택, 내 주변 병원, 병원 둘러보기 탭, 저장한 병원)은 전부 그대로 유지 — 순서와 스타일만 조정.
* 검색 결과(`search_result_screen.dart`): 로직 변경 없음, `HospitalCard`에 썸네일이 자동으로 반영됨. 빈 상태 이미지만 교체.
* 병원 상세(`detail_screen.dart`): 상단에 `HospitalThumbnail` 배너(높이 160) 추가. 영업상태 배지는 기존 `StatusBadge` 그대로라 폐업이 자동으로 회색이 됨. 지정 병원 토글(스프린트 9에서 이미 `FilterChip`으로 눈에 띄게 만들어 둠)은 그대로 유지.
* 지정 병원 카드(`designated_hospital_card.dart`): 썸네일 추가, 전화 버튼을 원형 채움 버튼으로 강조하고 길찾기는 보조 원형 버튼으로 — 카드를 탭하면 상세로 이동하므로 중복이던 "상세보기" 버튼은 정리(탭 동작 자체는 그대로 유지되어 기능 손실 없음).
* 주변 지도(`nearby_map_screen.dart`): 마커 탭 시 뜨는 바텀시트에 썸네일 추가. 지도·클러스터링·내 위치 로직은 전혀 건드리지 않음(스타일 한 군데만 수정).
* 진료기록(`health_record_screen.dart`): 프로필 카드·기기 저장 고지·요약은 그대로 두고, "다가오는 예약"/"진료 기록"을 목업처럼 실제 `TabBar`+`TabBarView`(진료 기록 / 예약 알림) 두 탭으로 재구성 — 데이터 소스(`recordsForPetProvider`, `upcomingAppointmentsForPetProvider`)와 추가/수정/삭제 로직은 완전히 동일, 화면에 배치되는 방식만 바뀜. 기록 카드에 반려동물 사진 썸네일 추가.
* 이용안내(`info_screens.dart`): 상단에 `logo.png` 워드마크 배치. 본문 문구는 그대로.

하지 말 것 (준수 확인)

* 기능·데이터·상태관리·로직 변경 — 없음. 모든 Provider/Notifier/데이터 모델/검색·필터·지역·타임라인·병합·지도 클러스터·진료기록·예약알림·광고 로직 파일은 건드리지 않았고, 건드린 화면 파일들도 위젯 트리 재배치·스타일·이미지 삽입만 했다.
* 폐업 빨강 — 제거, 회색으로 통일.
* 실제 병원 사진 크롤링 — 없음, 전부 `hospital_placeholder.png`.
* 실시간 영업여부로 오해되는 표기 — 없음(기존 `StatusBadge` 라벨 "영업"/"폐업"/"상태 확인 필요" 문구 자체는 변경하지 않음).

완료 기준

* [x] theme 토큰 정비, 전 화면 일관된 목업 톤(민트+회갈색, 또렷한 카드)
* [x] home_banner·placeholder·빈화면·로고 이미지가 각 자리에 표시
* [x] 폐업 배지 회색, 영업중 워딩 실시간 오해 없음(문구 자체 미변경)
* [x] 병원 사진 자리는 전부 placeholder로 깔끔 처리
* [~] 기능 회귀 전혀 없음(검색·지도·타임라인·진료기록·알림·광고 그대로), flutter analyze/test 통과 — analyze 이슈 없음, test 37개 전체 통과. 빌드 성공 여부는 이 환경에 Android SDK가 없어 직접 확인하지 못했다(기존 스프린트들과 동일한 제약) — 실기기/로컬 환경에서 `flutter build apk`·실제 화면 확인을 권장.

다음 예고

* 진료비 지역 시세 데이터 확보·연동
* juso 2차 지오코딩으로 좌표 없는 병원 보강
* 출시 준비(앱 아이콘=logo, 개인정보처리방침, 릴리스 서명, 스토어 등록)

---

## 구현 메모

- `AppColors.closed`와 Material `colorScheme.error`가 예전엔 같은 빨강 상수를 공유하고 있었다 — 폐업을 회색으로 바꾸면서 이 결합을 반드시 풀어야 했다(안 풀면 시스템 에러 색까지 같이 회색이 되어 CLAUDE.md의 "빨강은 시스템 오류에만" 원칙과 충돌). 그래서 `AppColors.error`를 새로 만들고 `app_theme.dart`가 그쪽을 가리키게 분리했다.
- `MascotImage`/`MascotMessage`에 `assetPath` 파라미터를 추가한 것은 이 스프린트에서 유일하게 "위젯 API가 늘어난" 부분이지만, 순수하게 표시할 이미지를 고르는 용도라 상태·로직에는 영향이 없다. 제공하지 않으면 이전과 동일하게 janggureum.png를 쓴다.
- 진료기록 탭의 TabBar 전환은 `DefaultTabController`로 구현했다 — 별도 상태 관리 없이 Flutter 기본 위젯만으로 목업의 탭 UI를 재현했고, 실제 데이터 흐름(레코드/예약 provider)은 스프린트 8-9와 완전히 동일하다.
- `hospital_placeholder.png`는 4:3 비율이라 정사각형(카드 썸네일)이나 넓은 배너(상세 상단)로 쓸 때 `BoxFit.cover`가 중앙 부분을 잘라 보여준다 — 실기기 화면에서 크롭이 부자연스러우면 다음 스프린트에서 이미지 자체를 다시 크롭해 받는 것을 고려할 수 있다.
