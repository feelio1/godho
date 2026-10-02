/// 시/도 데이터 키 → 화면에 보여줄 축약 라벨.
///
/// `assets/hospitals.json`/`fees.json`이 쓰는 시/도 키(`충청북`,
/// `전남광주통합` 등)는 `HospitalRepository.sidoList`/`sigunguListFor`,
/// `RegionFilter.sido`, 지역 정규화(`region_normalizer.dart`) 전반의
/// 조인·필터 키라서 값 자체를 바꿀 수 없다. 이 함수는 그 키를 그대로
/// 받아 "보여지는 글자"만 축약해 돌려준다 — 내부 로직은 항상 원래
/// 키를 그대로 쓴다("지역 표시 라벨 축약" 지시서).
const Map<String, String> _sidoDisplayLabels = {
  '충청북': '충북',
  '충청남': '충남',
  '경상북': '경북',
  '경상남': '경남',
  '전남광주통합': '광주·전남',
};

/// [sidoKey]에 매핑이 있으면 축약 라벨을, 없으면 키 그대로 돌려준다.
String sidoDisplayLabel(String sidoKey) => _sidoDisplayLabels[sidoKey] ?? sidoKey;
