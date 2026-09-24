import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/kakao_region_lookup.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/region_detection_status.dart';
import '../providers/region_provider.dart';
import '../utils/region_normalizer.dart';

void _log(String message) => debugPrint('[RegionAutoDetect] $message');

/// 좌표 하나를 정규화된 지역으로 바꾼다 — 1순위 카카오 REST 역지오코딩
/// (coord2regioncode), 실패(키 없음/네트워크 오류/정규화 실패)하면 2순위
/// hospitals.json 최단거리 병원. 두 경로 모두 마지막에 반드시
/// [normalizeRegion]을 거쳐 실제 데이터 키인지 확인한다 — 위치 기반
/// 자동 감지(수동 "현재 위치로" 포함)가 모두 이 한 함수를 거치므로,
/// 정규화 규칙이 갈라져 경계 지역 사용자만 조용히 "데이터 없음"에
/// 빠지는 회귀를 막는다.
///
/// 위치 자동감지 디버깅 지시서 A·C: 각 단계를 `debugPrint`로 남기고,
/// "REST 키 없음/실패"와 "폴백까지 실패"를 분명히 구분한다 — REST가
/// 실패해도 반드시 오프라인 폴백으로 이어지는지가 이번 지시서의 핵심
/// 확인 대상이라, 그 분기를 로그로 명시적으로 보여준다.
Future<NormalizedRegion?> detectNormalizedRegion(
  WidgetRef ref,
  double lat,
  double lng,
) async {
  final repo = ref.read(repositoryProvider);

  final restResult = await const KakaoRegionLookup().lookup(lat, lng);
  if (restResult != null) {
    _log('REST 역지오코딩 응답: 시도=${restResult.sido}, 시군구=${restResult.sigungu}');
    final normalized = normalizeRegion(restResult.sido, restResult.sigungu, repo);
    if (normalized != null) {
      _log('REST 결과 정규화 성공: $normalized');
      return normalized;
    }
    _log('REST 결과가 데이터 키에 없음(정규화 실패) — 오프라인 폴백으로 진행');
  } else {
    _log('REST 역지오코딩 미사용(키 없음) 또는 호출 실패 — 오프라인 폴백으로 진행');
  }

  final nearest = repo.nearestRegion(lat, lng);
  if (nearest == null) {
    _log('오프라인 폴백 실패: 좌표·지역이 모두 있는 최단거리 병원을 찾지 못함');
    return null;
  }
  _log('오프라인 폴백 최단거리 병원 지역: 시도=${nearest.sido}, 시군구=${nearest.sigungu}');
  final normalized = normalizeRegion(nearest.sido, nearest.sigungu, repo);
  _log(normalized != null ? '오프라인 폴백 정규화 성공: $normalized' : '오프라인 폴백 정규화도 실패');
  return normalized;
}

/// [locationProvider]가 로딩이 아닌 최종 상태로 settle됐을 때 호출한다.
/// [position]이 null이면 권한/서비스 상태를 다시 확인해 사유를 분류해
/// [regionDetectionReasonProvider]에 남기고(화면 26이 사유별 문구를
/// 보여준다), 값이 있으면 [detectNormalizedRegion]으로 지역을 판정해
/// [RegionNotifier.applyGpsRegionIfUnset]으로 반영한다(사용자가 이미
/// 직접 고른 지역은 덮어쓰지 않는다).
///
/// 위치 자동감지 디버깅 지시서 D: 여기서 하는 일은 "지역을 정하는 것"
/// 뿐이다 — 그 지역에 진료비 데이터가 있는지는 이 함수의 관심사가
/// 아니다(화면 21이 카테고리별로 따로 확인해 25로 안내한다). 좌표
/// 판정이 성공하면 데이터 유무와 무관하게 항상 success로 남긴다.
Future<void> applyDetectedRegionFromPosition(WidgetRef ref, Position? position) async {
  final reasonNotifier = ref.read(regionDetectionReasonProvider.notifier);

  if (position == null) {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('좌표 없음 — 사유: 위치 서비스(GPS) 꺼짐');
      reasonNotifier.state = RegionDetectionReason.locationServiceDisabled;
      return;
    }
    final permission = await Geolocator.checkPermission();
    final denied =
        permission == LocationPermission.denied || permission == LocationPermission.deniedForever;
    _log('좌표 없음 — 사유: ${denied ? "권한 거부($permission)" : "좌표 획득 실패(타임아웃 등, 권한=$permission)"}');
    reasonNotifier.state =
        denied ? RegionDetectionReason.permissionDenied : RegionDetectionReason.positionUnavailable;
    return;
  }

  reasonNotifier.state = RegionDetectionReason.detecting;
  _log('좌표 확보: (${position.latitude}, ${position.longitude}) — 지역 판정 시작');
  final normalized = await detectNormalizedRegion(ref, position.latitude, position.longitude);
  if (normalized == null) {
    _log('지역 판정 실패 — REST·오프라인 폴백 모두 데이터 키로 매핑되지 않음');
    reasonNotifier.state = RegionDetectionReason.regionNotFound;
    return;
  }

  _log('지역 판정 성공: $normalized — regionProvider에 반영 시도(사용자가 이미 직접 고르지 않았을 때만)');
  await ref.read(regionProvider.notifier).applyGpsRegionIfUnset(
        RegionFilter(sido: normalized.sido, sigungu: normalized.sigungu),
      );
  reasonNotifier.state = RegionDetectionReason.success;
}
