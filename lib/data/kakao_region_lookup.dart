import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/kakao_map_config.dart';

/// 카카오 로컬 REST API(coord2regioncode)로 좌표를 행정구역명으로
/// 바꾼다. 여기서 얻는 시/도·시/군/구는 카카오의 공식 명칭 그대로라
/// (예: "인천광역시"), 반드시 `utils/region_normalizer.dart`의
/// normalizeRegion을 거쳐 앱 데이터 키로 바꿔야 한다.
///
/// 키가 없거나(REST 키 미설정) 호출이 실패하면 null을 돌려준다 — 지도
/// SDK와 달리 이 기능 전체를 막지 않고, 호출부가 hospitals.json 최단거리
/// 병원 기준 오프라인 폴백으로 조용히 넘어간다.
class KakaoRegionLookup {
  const KakaoRegionLookup();

  static final Uri _endpoint =
      Uri.parse('https://dapi.kakao.com/v2/local/geo/coord2regioncode.json');

  Future<({String sido, String sigungu})?> lookup(double lat, double lng) async {
    if (!isKakaoRestConfigured) return null;
    try {
      final uri = _endpoint.replace(queryParameters: {
        'x': lng.toString(),
        'y': lat.toString(),
      });
      final response = await http
          .get(uri, headers: {'Authorization': 'KakaoAK $kakaoRestKey'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final documents = body['documents'] as List<dynamic>? ?? const [];
      if (documents.isEmpty) return null;

      // 행정동(H) 결과를 우선하고, 없으면 첫 결과(보통 법정동 B)를
      // 쓴다 — 시/도·시/군/구 이름 자체는 두 region_type에서 보통 같다.
      final doc = documents.firstWhere(
        (d) => (d as Map<String, dynamic>)['region_type'] == 'H',
        orElse: () => documents.first,
      ) as Map<String, dynamic>;

      final sido = doc['region_1depth_name'] as String?;
      final sigungu = doc['region_2depth_name'] as String?;
      if (sido == null || sido.isEmpty || sigungu == null || sigungu.isEmpty) {
        return null;
      }
      return (sido: sido, sigungu: sigungu);
    } catch (_) {
      // 네트워크 오류·타임아웃·응답 형식 이상 — 호출부가 폴백으로 넘어간다.
      return null;
    }
  }
}
