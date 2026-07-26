# 스프린트 1 지시서 — 펫병원체크

목표: 실데이터(assets/hospitals.json)로 동작하는 홈·검색·상세·주변지도·저장 뼈대 완성. Android 에뮬레이터에서 빌드 성공.

전제: Flutter 설치됨. CLAUDE.md의 원칙·워딩·스키마를 반드시 준수.

---

## 0. 프로젝트 셋업
- `flutter create` 로 프로젝트 생성 (패키지명 예: com.petcheck.app)
- 의존성 추가: flutter_riverpod, shared_preferences, flutter_naver_map, url_launcher, intl
- assets/hospitals.json 등록 (pubspec.yaml assets 경로), 준비된 인천 번들 파일을 넣는다
- lib 폴더 구조 제안:
  - models/ (Hospital, Timeline, TimelineSegment)
  - data/ (bundle_loader.dart — assets JSON 로드·파싱, hospital_repository.dart)
  - providers/ (riverpod providers: bundleProvider, searchProvider, savedProvider)
  - screens/ (home, search_result, detail, nearby_map, saved, compare)
  - widgets/ (fact_card, timeline_view, fee_section, source_footer)

## 1. 데이터 레이어
- 앱 시작 시 assets/hospitals.json 1회 로드 → 메모리 유지 (bundleProvider, FutureProvider)
- Hospital 모델: 스키마대로. 운영기간 계산 getter (continuousSince 기준, null이면 '확인 불가')
- 운영기간 구분 getter: 30년+/20년+/10년+/5년+/1년+/신규(1년미만)/확인불가
- 검색: name·roadAddr에 대한 contains 매칭 (대소문자·공백 무시). 결과 정렬 옵션: 가까운 순/운영 긴 순/최근 개원 순/이름 순 (※'신뢰도 순' 금지)

## 2. 홈 화면
- 상단: 앱명 + 우측 상단 메뉴(설정·출처·이용안내)
- "동물병원 방문 전, 공개된 정보를 확인해보세요" 한 줄
- 검색창(탭 시 검색결과 화면) + [내 주변 병원] 버튼
- 최근 확인한 병원 / 저장한 병원 (없으면 '내 지역 최근 개원 병원' 노출)
- 하단 탭 3개 (홈/주변 병원/저장)

## 3. 검색 결과 화면
- 카드: 병원명, 주소, 영업여부(영업=초록·폐업=회색), 운영기간, 진료비 정보 수(현재 번들엔 지역시세라 이 줄은 'N개 항목' 대신 우선 생략 가능), 동일 주소 기록 수, 거리
- 정렬 바 (위 옵션)
- 카드 탭 → 상세

## 4. 병원 상세 화면 (핵심)
- 상단: 병원명, 저장 하트, 영업상태 배지, 주소, 데이터 확인일, 액션 4버튼(전화/길찾기/비교/공유)
  - 전화: url_launcher tel:  · 길찾기: 네이버지도 앱 딥링크(좌표 없으면 주소 기반)
- 팩트카드 4개: 운영기간 / 영업상태 / (진료비 항목 or 지역시세 유무) / 동일 주소 기록 수
- 운영정보: 개설신고일·상태·운영기간·출처·최종갱신 + 필수 안내문(운영기간 기준 고지)
- **동일 주소 타임라인** (timelineId 있을 때만): 세로 타임라인. 병합 구간은 "재등록 기록 M건 포함"으로 접고 탭 시 원 기록 펼침. 하단 운영자 미확인 고지 필수.
- 진료비: 이번 스프린트는 자리만(지역 시세 데이터는 별도 확보 예정). "지역 시세 준비 중" placeholder + 변동 고지 문구.
- 외부 링크: 네이버지도/카카오맵 리뷰(검색 URL scheme), 국가동물보호정보시스템
- 최하단 source_footer: 출처·최종 갱신일

## 5. 주변 병원 (지도) — 셋업 주의 구간
- 네이버 클라우드 콘솔에서 Maps API 키 발급 → flutter_naver_map 초기화, AndroidManifest에 키 등록 필요
- ※ 키 발급/네이티브 설정에서 막히면 이 화면만 "준비 중" 스텁으로 두고 나머지 먼저 빌드
- 지도에 좌표 있는 병원 마커(영업=기본색/신규=회색/상태확인=옅은색). 마커 탭 → 하단 카드(상세보기·비교추가)
- 위치 권한은 이 탭 최초 진입 시 요청

## 6. 저장 & 비교
- 저장: SharedPreferences에 id 배열. 저장 탭에서 목록 표시. (알림은 v1.1, 만들지 않음)
- 비교: 검색결과·상세의 "비교 추가" → 전역 비교 목록(최대 3) → 하단 플로팅 바 → 비교 화면(표: 거리/상태/운영기간/개설일/동일주소기록/갱신일 + 각 행 물음표 설명, 하단 전화·길찾기)

## 완료 기준
- [ ] 에뮬레이터 빌드 성공, 홈→검색→상세 이동 동작
- [ ] 실번들 로드되어 인천 병원 검색됨
- [ ] 타임라인 있는 병원(예: 부평구 후정동로 60 늘푸른동물병원)에서 접기/펼치기 동작
- [ ] 저장·비교 담기 동작
- [ ] 지도: 키 되면 마커 표시 / 안 되면 스텁으로 빌드는 통과

## 다음 스프린트 예고
- make_bundle.py 수정(병합 원기록 보존), 지오코딩·juso 보강, 지역 시세 데이터 연동, 배치 자동화
