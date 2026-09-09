스프린트 9 지시서 — 펫병원체크 진료기록 탭 독립 + UI 개선 + 예약 알림

목표: (1) 건강기록을 하단 탭으로 승격("진료기록"), (2) 지정 병원 등록·사진 넣기 등 안 보이던 UI 개선, (3) 진료 예약 + 알림(사용자 지정 시각). 검색/지도/타임라인/병합 로직 변경 금지. CLAUDE.md 원칙·워딩·중립성 준수.
전제: 스프린트 8에서 지정 병원·건강기록(로컬)·image_picker 구현됨. 로컬 저장 유지(서버·계정·결제·Firebase 없음). 데이터 모델은 기존 JSON 직렬화 구조 유지·확장.

1. 하단 탭에 "진료기록" 추가 (3개 → 4개)

* `main_shell.dart`: 홈 / 주변 병원 / **진료기록** / 저장 순서로 4번째 탭 추가(아이콘 `Icons.medical_information_outlined`). `HealthRecordScreen`을 이 탭의 메인 화면으로 승격.
* 홈에 있던 "우리 아이 건강기록" 진입 카드(`_HealthRecordEntryCard`)는 완전히 제거 — 탭이 생겨 중복이라 판단.
* `CLAUDE.md`의 "정보구조" 절도 하단 탭 3개 → 4개로 갱신해 실제 구조와 문서가 어긋나지 않게 함.

2. 안 보이던 UI 개선

* 지정 병원 등록(`detail_screen.dart`): 아이콘만 있던 `IconButton` → 글자 라벨이 있는 `FilterChip`("지정 병원으로 등록" / "지정 병원")으로 교체, 저장(♡) 아이콘과 줄을 분리해 시각적으로 확실히 구분. 누르면 스낵바로 "지정 병원으로 등록했습니다. 홈 상단에서 바로 볼 수 있어요." / "지정 병원에서 해제했습니다."를 보여줌.
* 사진 첨부: 진료기록·예약 두 폼이 공유하는 `PhotoAttachField` 위젯을 새로 만들어 "사진 첨부 (선택)" 라벨 + 카메라 아이콘 버튼 + 선택 시 72×72 썸네일 미리보기 + 삭제 버튼으로 통일.
* 병원 선택 UI(진료기록·예약 공통)도 `HospitalPickerField`로 뽑아 "검색해서 선택하거나 이름을 직접 입력하세요" 도움말을 항상 보이게 함.

3. 진료 예약 + 알림 (신규)

* 모델: `Appointment`(병원·날짜시간·진료 내용·메모·반려동물 id·`List<ReminderOffset>`), `ReminderOffset`(daysBefore·hour·minute) — 둘 다 `Pet`/`MedicalRecord`와 같은 순수 클래스 + JSON 직렬화 패턴.
* 저장: `LocalStore.loadAppointments`/`saveAppointments` — 같은 "JSON 배열 문자열 하나" 패턴. `appointmentsProvider`(AsyncNotifier)가 저장·수정·삭제마다 `NotificationService`도 함께 갱신.
* UI: "진료기록" 탭 상단에 "다가오는 예약" 섹션(이른 순, `upcomingAppointmentsForPetProvider`가 지난 예약을 걸러냄 — 데이터 자체는 지우지 않고 남겨 둠), 그 아래 기존 "진료 기록"(지난 기록). `AppointmentFormScreen`에서 날짜·시간·병원·진료 내용·메모·알림을 입력.
* 알림 시각 지정: 폼 안 "알림 추가" 버튼 → 다이얼로그에서 "며칠 전"(당일/1/2/3/7일 전 칩)과 "몇 시"(`showTimePicker`)를 골라 `ReminderOffset` 하나를 추가. 여러 개 추가 가능, 칩으로 나열되고 개별 삭제 가능.
* 알림 발송: `flutter_local_notifications` + `timezone`(한국 표준시 고정 — 국내 데이터만 다루는 앱이라 별도 시간대 감지 패키지 없이 최소 구현). `AndroidScheduleMode.inexactAllowWhileIdle`로 예약 — 정확 알람(`SCHEDULE_EXACT_ALARM`) 권한 없이도 동작하고, Doze 모드에서도 대체로 울리되 초 단위 정밀도는 보장하지 않는다. 알림 문구는 "OO동물병원 예약이 있어요 (중성화)"처럼 사실만 담고 광고성 문구 없음.
* 권한: `POST_NOTIFICATIONS`를 AndroidManifest에 선언하고, 예약에 알림을 처음 추가해 저장하는 시점에만(`AppointmentFormScreen._save`) 런타임 요청. 앱 시작 시 요청하지 않음.

알림 안정성

* `NotificationService`의 초기화(`_ensureInitialized`)·권한 요청·예약·취소를 전부 개별 try/catch로 감싸, 어떤 단계가 실패해도(플랫폼 채널 없음, 권한 거부, 기기 미지원 등) 예외가 밖으로 새지 않는다 — 실패하면 그 알림 기능만 조용히 비활성화되고 앱은 정상 동작한다.
* `main.dart`(콜드 스타트 경로)에서는 알림을 전혀 초기화하지 않는다. 초기화는 실제로 알림을 요청/예약하는 시점에만 지연 실행된다(과거 WorkManager 콜드 스타트 크래시의 교훈).
* 단위 테스트(`test/appointment_test.dart`)로 "플랫폼 채널이 없는 테스트 환경에서 예약 저장/알림 예약을 시도해도 예외 없이 상태가 갱신된다"를 직접 검증.

하지 말 것 (준수 확인)

* 서버·계정·로그인·결제·Firebase 도입 — 전부 `SharedPreferences` + 기기 로컬 알림뿐.
* 그래프·통계·PDF·여러 마리 고급 UI — 미구현.
* 검색/지도/타임라인/병합 로직 변경 — 미변경.
* 실시간 영업여부·영업시간 표기 — 없음.
* 알림을 광고·마케팅 용도로 사용 — 예약 리마인더 문구만 사용.

완료 기준

* [x] 하단 탭 4개(홈/주변/진료기록/저장), 진료기록 탭에서 건강기록 바로 접근
* [x] 지정 병원 등록 버튼이 명확히 보이고 저장(♡)과 구분됨 (라벨 있는 칩 + 스낵바 피드백)
* [x] 진료기록 사진 첨부가 명확하고 갤러리 선택·미리보기 동작 (`PhotoAttachField`)
* [x] 예약 추가(병원·내용·날짜·대상), "다가오는 예약" 표시
* [x] 알림 시각 사용자 지정(며칠 전+시간, 복수 가능), 지정 시각에 로컬 알림 예약
* [x] 알림 권한 거부/실패해도 앱 정상 동작(전 구간 try/catch, 단위 테스트로 검증)
* [~] 기능 회귀 없음, flutter analyze/test 통과, 빌드/실행 확인 — analyze/test는 통과(37개 전체). 이 환경엔 Android SDK/에뮬레이터가 없어 실기기 빌드·실행 확인은 사용자 몫으로 남음. 특히 알림 권한 프롬프트·실제 알림 수신·`image_picker` 갤러리 플로우는 실기기에서 꼭 한 번 확인 권장.

다음 예고

* 로그인(카카오/구글) + Firebase 동기화(기기 변경 대비)
* 이후 고급 기능(그래프·통계·PDF·여러 마리) 유료 구독화

---

## 구현 메모

- `AndroidScheduleMode.exact`/`alarmClock` 대신 `inexactAllowWhileIdle`을 선택했다 — `SCHEDULE_EXACT_ALARM`(Android 12+) 권한 요청·거부 처리·Android 14의 특수 권한 절차까지 다루려면 복잡도와 크래시 위험이 커지는데, 이 앱은 "정확한 초 단위"가 필요한 알람이 아니라 "며칠 전/당일 대략 그 시간대에" 알림이면 충분한 예약 리마인더라 근사 시각으로도 목적에 맞는다.
- 재부팅 후 알림 유지(boot receiver)는 이번 범위에서 뺐다 — `flutter_local_notifications`의 기본 매니페스트에는 부팅 리시버가 없고, 별도로 추가하려면 새 매니페스트 컴포넌트가 필요해 "과하게 만들지 말 것" 원칙에 따라 다음 단계로 미뤘다. 기기를 재부팅하면 그 전에 예약해 둔 알림은 사라질 수 있다는 제약이 있다.
- 알림 id는 `uuid` 없이 `appointmentId.hashCode`와 알림 인덱스를 조합해 만든다(로컬 전용 데이터라 충돌 가능성이 실질적으로 없음) — 예약을 다시 저장할 때마다 같은 id 범위를 전부 취소 후 재예약해, "몇 개였는지"를 따로 기억할 필요가 없게 했다.
