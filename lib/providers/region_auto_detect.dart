import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kakao_region_lookup.dart';
import '../providers/bundle_provider.dart';
import '../utils/region_normalizer.dart';

/// 좌표 하나를 정규화된 지역으로 바꾼다 — 1순위 카카오 REST 역지오코딩
/// (coord2regioncode), 실패(키 없음/네트워크 오류/정규화 실패)하면 2순위
/// hospitals.json 최단거리 병원. 두 경로 모두 마지막에 반드시
/// [normalizeRegion]을 거쳐 실제 데이터 키인지 확인한다 — 위치 기반
/// 자동 감지(수동 "현재 위치로" 포함)가 모두 이 한 함수를 거치므로,
/// 정규화 규칙이 갈라져 경계 지역 사용자만 조용히 "데이터 없음"에
/// 빠지는 회귀를 막는다.
Future<NormalizedRegion?> detectNormalizedRegion(
  WidgetRef ref,
  double lat,
  double lng,
) async {
  final repo = ref.read(repositoryProvider);

  final restResult = await const KakaoRegionLookup().lookup(lat, lng);
  if (restResult != null) {
    final normalized = normalizeRegion(restResult.sido, restResult.sigungu, repo);
    if (normalized != null) return normalized;
  }

  final nearest = repo.nearestRegion(lat, lng);
  if (nearest == null) return null;
  return normalizeRegion(nearest.sido, nearest.sigungu, repo);
}
