import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/data/bundle_loader.dart';
import 'package:petcliniccheck/data/hospital_repository.dart';
import 'package:petcliniccheck/utils/region_normalizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HospitalRepository repo;

  setUpAll(() async {
    final bundle = await const BundleLoader().load();
    repo = HospitalRepository(bundle);
  });

  group('normalizeRegion — 카카오 API 공식 명칭 별칭', () {
    test('광주광역시는 전남광주통합으로 병합된다(광주 지역 좌표 시나리오)', () {
      // 실제 repo에 있는 "전남광주통합" 소속 구 하나를 골라, 카카오가
      // 공식 명칭("광주광역시")으로 돌려준 상황을 재현한다.
      final gwangjuSigungu = repo.sigunguListFor('전남광주통합').firstWhere(
            (s) => s.endsWith('구'), // 광주 쪽 구(전남의 시/군과 구분)
          );
      final result = normalizeRegion('광주광역시', gwangjuSigungu, repo);
      expect(result, isNotNull);
      expect(result!.sido, '전남광주통합');
      expect(result.sigungu, gwangjuSigungu);
    });

    test('전라남도도 같은 전남광주통합 키로 병합된다', () {
      final jeonnamSigungu = repo.sigunguListFor('전남광주통합').firstWhere(
            (s) => s.endsWith('시') || s.endsWith('군'),
          );
      final result = normalizeRegion('전라남도', jeonnamSigungu, repo);
      expect(result, isNotNull);
      expect(result!.sido, '전남광주통합');
    });

    test('공식 접미사(특별시/광역시/도)가 제거된 축약 키로 바뀐다', () {
      expect(normalizeRegion('인천광역시', repo.sigunguListFor('인천').first, repo)?.sido, '인천');
      expect(normalizeRegion('경기도', repo.sigunguListFor('경기').first, repo)?.sido, '경기');
      expect(normalizeRegion('서울특별시', '종로구', repo)?.sido, '서울');
    });

    test('데이터에 없는 (시도, 시군구) 조합은 추정하지 않고 null을 돌려준다', () {
      expect(normalizeRegion('서울특별시', '존재하지않는구', repo), isNull);
      expect(normalizeRegion('존재하지않는시도', '아무동', repo), isNull);
      expect(normalizeRegion(null, '종로구', repo), isNull);
      expect(normalizeRegion('서울특별시', null, repo), isNull);
    });
  });

  group('normalizeRegion — 좌표 기반 폴백(최단거리 병원) 경로', () {
    // 이 그룹은 실제 위치기반 자동감지의 2순위 경로(REST 키 없음/호출
    // 실패 시 hospitals.json 최단거리 병원 사용)를 그대로 재현한다 —
    // 특정 구 이름을 하드코딩해 기대하지 않고, "정규화 결과가 repo에
    // 실제 존재하는 유효한 키인지"만 검증한다(지시서 요구사항).
    void expectValidNormalizedRegion(double lat, double lng, String label) {
      final nearest = repo.nearestRegion(lat, lng);
      expect(nearest, isNotNull, reason: '$label: 좌표 근처에 좌표 있는 병원이 있어야 한다');

      final normalized = normalizeRegion(nearest!.sido, nearest.sigungu, repo);
      expect(normalized, isNotNull, reason: '$label: nearestRegion 결과는 이미 hospitals.json 자체 값이라 정규화를 그대로 통과해야 한다');
      expect(repo.sidoList, contains(normalized!.sido), reason: '$label: 정규화된 시도가 실제 데이터 키에 있어야 한다');
      expect(repo.sigunguListFor(normalized.sido), contains(normalized.sigungu),
          reason: '$label: 정규화된 시군구가 그 시도 아래 실제로 있어야 한다');
    }

    test('검단(인천 서구 북부, 경기 접경) 좌표 → 유효한 (시도, 구)로 정규화된다', () {
      expectValidNormalizedRegion(37.5985, 126.6790, '검단');
    });

    test('김포(경기, 검단과 접경) 좌표 → 유효한 (시도, 구)로 정규화된다', () {
      expectValidNormalizedRegion(37.6152, 126.7159, '김포');
    });

    test('광주 좌표 → 전남광주통합으로 정규화된다', () {
      final nearest = repo.nearestRegion(35.1595, 126.8526);
      expect(nearest, isNotNull);
      final normalized = normalizeRegion(nearest!.sido, nearest.sigungu, repo);
      expect(normalized, isNotNull);
      expect(normalized!.sido, '전남광주통합');
    });
  });
}
