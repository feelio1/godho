import '../data/hospital_repository.dart';

/// 정규화된 지역 — 앱 데이터(hospitals.json/fees.json)가 실제로 쓰는
/// 축약 시/도 키 + 시/군/구.
class NormalizedRegion {
  final String sido;
  final String sigungu;

  const NormalizedRegion(this.sido, this.sigungu);

  @override
  String toString() => '$sido $sigungu';
}

/// 공식 시/도 명칭(카카오 좌표→행정구역 API가 돌려주는 값 등) → 앱이 쓰는
/// 축약 키. tool/build_fees.py의 SIDO_MAP과 반드시 같은 규칙을 유지한다
/// — 광주광역시·전라남도는 hospitals.json/fees.json에서 이미 "전남광주
/// 통합" 하나로 합쳐져 있으므로 여기서도 같은 키로 합친다.
const Map<String, String> _sidoAliases = {
  '서울특별시': '서울',
  '부산광역시': '부산',
  '대구광역시': '대구',
  '인천광역시': '인천',
  '광주광역시': '전남광주통합',
  '대전광역시': '대전',
  '울산광역시': '울산',
  '세종특별자치시': '세종',
  '경기도': '경기',
  '강원특별자치도': '강원',
  '강원도': '강원',
  '충청북도': '충청북',
  '충청남도': '충청남',
  '전북특별자치도': '전북',
  '전라북도': '전북',
  '전라남도': '전남광주통합',
  '경상북도': '경상북',
  '경상남도': '경상남',
  '제주특별자치도': '제주',
  '제주도': '제주',
};

/// 좌표를 거꾸로 찾은 [rawSido]/[rawSigungu](카카오 API의 공식 명칭이든,
/// 최단거리 병원 폴백에서 이미 축약된 키든)를 앱 데이터 키로 정규화한다.
/// [repo]가 실제로 그 (시도, 시군구)를 갖고 있는지까지 확인해, 존재하지
/// 않으면 null을 돌려준다 — 값을 추정하지 않고 "데이터 없음"으로
/// 솔직하게 처리한다(CLAUDE.md 원칙 5).
///
/// 위치 기반 자동 감지(카카오 REST 역지오코딩 1순위, 최단거리 병원
/// 폴백 2순위)와 그 단위 테스트가 모두 이 한 함수를 거친다 — 정규화
/// 규칙이 두 곳에 따로 존재해 조용히 어긋나는 회귀를 막기 위함이다.
NormalizedRegion? normalizeRegion(
  String? rawSido,
  String? rawSigungu,
  HospitalRepository repo,
) {
  if (rawSido == null || rawSido.isEmpty) return null;
  if (rawSigungu == null || rawSigungu.isEmpty) return null;

  final sido = _sidoAliases[rawSido] ?? rawSido;
  if (!repo.sidoList.contains(sido)) return null;
  if (!repo.sigunguListFor(sido).contains(rawSigungu)) return null;

  return NormalizedRegion(sido, rawSigungu);
}
