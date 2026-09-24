/// 진료비 조사(fees.json) 갱신보다 나중에 신설된 구 — hospitals.json은
/// 최신 행정구역을 반영해 이미 있지만, fees 조사 시점(baseDate)엔 없어서
/// 그 구가 통째로 빠져 있는 경우를 이유가 보이는 문구로 안내한다. 다른
/// 구 값으로 대체하지 않고 "아직 없다"고 정직하게 말한다(CLAUDE.md
/// 원칙 5, 홈 자동 시세 표시 지시서 변경 2).
///
/// 새로 분구되는 구가 생기면 이 목록에 한 줄만 추가하면 된다 — 날짜를
/// 정확히 아는 경우에만 적는다(모르면 일반 문구로 충분).
const Map<String, String> _newlyCreatedDistrictNotes = {
  '검단구': '검단구는 2026년 7월 새로 생긴 구라 아직 진료비 조사 자료가 없어요.',
  '서해구': '서해구는 새로 생긴 구라 아직 진료비 조사 자료가 없어요.',
};

/// [sigungu]가 아직 fees 조사에 반영되지 않은 구일 때 보여줄 안내
/// 문구. 알려진 신설 구면 그 사유를, 아니면 일반적인 "자료 없음" 문구를
/// 돌려준다 — 개수·추정치는 절대 만들어내지 않는다.
String feeNoRegionDataSubtitle(String regionLabel, String sigungu) {
  return _newlyCreatedDistrictNotes[sigungu] ??
      '$regionLabel은 공개된 진료비 조사 자료가 아직 없어요.';
}
