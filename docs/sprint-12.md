스프린트 12 지시서 — 펫병원체크 버그 수정 (예약 알림, 전화 없는 병원)

목표: 출시 전 발견된 실사용 버그 2건 수정. (1) 예약 알림이 지정 시각에 울리지 않음, (2) 전화번호 없는 병원에서 전화 버튼이 무반응. CLAUDE.md 원칙 준수, 관련 기능만 수정.

1. 예약 알림이 울리지 않음 (핵심 버그)

* 진단: 기존 코드는 `AndroidScheduleMode.inexactAllowWhileIdle`만 썼다. 이 모드는 권한이 따로 필요 없는 대신, OS(특히 삼성 One UI 같은 제조사 커스텀 절전 정책)가 정확한 시각을 보장하지 않고 지연·누락시킬 수 있다 — 사용자가 배터리 최적화 예외까지 켰는데도 안 온 정황과 일치한다. 타임존(`Asia/Seoul` 고정)·오프셋 계산(`ReminderOffset.fireTimeFor`) 자체는 코드 검토 결과 정상이었다.
* 수정 (`lib/notifications/notification_service.dart`):
  - 예약을 실제로 저장할 때마다 `AndroidFlutterLocalNotificationsPlugin.canScheduleExactNotifications()`로 정확한 시각 알람 권한이 있는지 확인해, 있으면 `AndroidScheduleMode.exactAllowWhileIdle`(정확한 시각 + Doze 중에도 발동)을, 없으면 기존처럼 `inexactAllowWhileIdle`로 조용히 대체한다(`_bestAvailableScheduleMode()`). 권한이 없다고 예약 저장 자체를 막지 않는다.
  - `requestPermission()`이 `POST_NOTIFICATIONS`뿐 아니라 `requestExactAlarmsPermission()`도 함께 요청하도록 확장했다(이미 허용돼 있으면 시스템 설정 화면을 다시 띄우지 않음). 여전히 예약에 알림을 처음 추가해 저장하는 시점에만 호출된다(`appointment_form_screen.dart`, 변경 없음 — 호출부는 그대로, 내부 동작만 보강됨).
  - `USE_EXACT_ALARM`이 아니라 `SCHEDULE_EXACT_ALARM`을 택했다: `USE_EXACT_ALARM`은 자동 부여되지만 구글 플레이 정책상 진짜 알람시계·캘린더 앱에만 허용되어, "동물병원 예약 리마인더" 앱이 쓰면 스토어 심사 리스크가 있다. `SCHEDULE_EXACT_ALARM`은 사용자가 직접 허용하는 대신 정책 제약이 없다.
  - `AndroidManifest.xml`에 `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />` 추가.
* 안정성: 모든 단계(초기화·권한 요청·예약·취소)는 기존처럼 개별 try/catch로 감싸 실패해도 앱이 죽지 않는다. 완전히 조용히 삼키지는 않도록, "설정" 화면에 테스트 알림 버튼을 추가해 성공/실패를 스낵바로 즉시 알려준다(아래 검증 방법 참고).

2. 전화번호 없는 병원 — 전화 버튼 무반응

* 원인: `ExternalLinks.call(String phone)`이 `launchUrl` 결과(성공/실패)를 확인하지 않고 버렸다. 전화번호가 `null`인 곳은 각 화면에서 버튼을 `enabled: false`로 그레이아웃했지만(예: 쉼터동물병원처럼 데이터 자체에 번호가 없는 경우는 원래도 걸렸음), 그레이아웃은 다른 버튼들 사이에서 눈에 잘 안 띄어 "눌러도 반응 없음"으로 느껴질 수 있고, 번호가 있어도 공백·괄호 등 형식이 섞이면 `tel:` 실행이 조용히 실패할 수 있었다.
* 수정 (`lib/utils/external_links.dart`):
  - `sanitizedPhone(String? phone)` 추가 — 맨 앞 `+`만 보존하고 숫자만 남긴 뒤, 숫자가 하나도 없으면(빈 값·`null`·문자만 있는 값 등) `null`을 반환한다.
  - `call(BuildContext context, String? phone)`으로 시그니처 변경 — 정리된 번호가 없으면 "등록된 전화번호가 없습니다." 스낵바를, `launchUrl`이 실패하면 "전화 앱을 열 수 없습니다." 스낵바를 보여준다. 무반응인 경우가 없어졌다.
  - 상세 화면(`detail_screen.dart`)·지정 병원 카드(`designated_hospital_card.dart`)·비교 화면(`compare_screen.dart`) — 전화 버튼이 있는 모든 곳이 이 메서드 하나로 통일됐다. 더는 개별 화면에서 `enabled: hospital.phone != null` 같은 중복 로직을 두지 않는다(버튼은 항상 눌리고, 유효한 번호가 없을 때의 안내는 `ExternalLinks.call`이 전담).

하지 말 것 (준수 확인)

* 데이터/검색/필터/타임라인/병합/지도 로직 — 미변경.
* 알림을 예약 리마인더 외 용도로 사용 — 없음(테스트 알림도 "이 알림이 보이면 예약 알림도 정상 동작합니다" 문구로 같은 목적의 진단용).
* CLAUDE.md 워딩·중립성 — 위반 없음.

완료 기준

* [x] 예약 지정 시각에 실기기에서 알림이 울리도록 정확한 시각 모드(exactAllowWhileIdle) + 권한 처리 추가(실기기 확인 필요 — 아래 검증 방법)
* [x] 전화번호 없는 병원은 스낵바로 안내, 무반응 없음
* [x] 전화번호 형식이 깨져 있어도(공백·하이픈·괄호 등) 숫자만 추출해 정상 연결 시도
* [x] flutter analyze/test 통과(45개 전체, 신규 8개 포함) — 빌드 성공 여부는 이 환경에 Android SDK가 없어 직접 확인 못함(기존 스프린트들과 동일한 제약)

## 실기기 검증 방법 (필수)

1. 앱의 홈 화면 우측 상단 메뉴 → **설정** → "예약 알림 테스트" 카드의 **"1분 뒤 테스트 알림 보내기"** 버튼을 누른다.
   - 이 버튼은 실제 예약 알림과 똑같은 코드 경로(권한 확인 → 예약 모드 선택 → `zonedSchedule`)를 타므로, 여기서 울리면 실제 예약도 같은 조건에서 울린다고 볼 수 있다.
   - 처음 누르면 알림 권한과 "정확한 알람" 권한(기기 설정 화면)을 순서대로 요청할 수 있다 — 둘 다 허용한다.
   - 1분 뒤 "테스트 알림 — 이 알림이 보이면 예약 알림도 정상 동작합니다 (정확한 시각/근사 시각 모드)." 알림이 오는지 확인한다. 문구에 어느 모드로 예약됐는지 나온다.
2. 정확한 알람 권한이 꺼져 있으면 안드로이드 설정 → 앱 → 펫병원체크 → **알람 및 리마인더**(또는 "정확한 알람")에서 직접 켤 수도 있다.
3. 실제 예약으로도 확인하려면: 진료기록 탭 → 예약 추가 → 알림을 "당일 + 지금부터 2~3분 뒤 시각"으로 추가해 저장 → 그 시각에 알림이 오는지 확인.
* 주의: 기기별 절전 정책(특히 삼성 One UI의 "절전 앱 대기" 등 표준 배터리 최적화 예외와 별개인 항목들)이 여전히 지연시킬 가능성은 남아 있다 — `exactAllowWhileIdle` + `SCHEDULE_EXACT_ALARM`은 표준 Android API가 보장하는 범위까지만 정확도를 높인다.

---

## 구현 메모

- `canScheduleExactNotifications()`는 Android 12 미만 기기에서도 안전하게 호출된다(플러그인이 내부적으로 버전 분기 처리) — 굳이 앱에서 `Platform.version`을 따로 확인하지 않았다.
- 알림 id 체계(`appointmentId.hashCode` 기반)와 슬롯 수 상한(`_maxRemindersPerAppointment = 8`)은 스프린트 9 그대로 유지했다 — 이번엔 "어떤 모드로 예약하는지"만 바뀌었을 뿐, 예약/취소 흐름 자체는 손대지 않았다.
