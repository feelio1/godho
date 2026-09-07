import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/models/hospital.dart';
import 'package:petcliniccheck/models/hospital_status.dart';
import 'package:petcliniccheck/utils/map_clustering.dart';

Hospital _hospitalAt(String id, double lat, double lng) => Hospital(
      id: id,
      name: '병원 $id',
      status: HospitalStatus.open,
      sido: '서울',
      sigungu: '중구',
      roadAddr: '주소 $id',
      jibunAddr: '지번 $id',
      lat: lat,
      lng: lng,
    );

void main() {
  test('cellSizeForZoom shrinks as zoom increases and disables at the cap', () {
    expect(cellSizeForZoom(14), 0);
    expect(cellSizeForZoom(20), 0);
    expect(cellSizeForZoom(13), greaterThan(0));
    expect(cellSizeForZoom(8), greaterThan(cellSizeForZoom(13)));
    expect(cellSizeForZoom(2), greaterThan(cellSizeForZoom(8)));
  });

  test('cellSizeForZoom never plateaus or returns zero below the disabled zoom — '
      '스프린트 7 문제 2: 줌아웃할수록 계속 커져야 "아무것도 안 보이는 구간"이 없다', () {
    for (var zoom = 13; zoom >= -5; zoom--) {
      final size = cellSizeForZoom(zoom);
      expect(size, greaterThan(0), reason: 'zoom=$zoom');
      if (zoom < 13) {
        expect(size, greaterThan(cellSizeForZoom(zoom + 1)), reason: 'zoom=$zoom');
      }
    }
  });

  test('at/above the disabled zoom, every hospital is its own group', () {
    final hospitals = [
      _hospitalAt('1', 37.50, 127.00),
      _hospitalAt('2', 37.50, 127.00), // 완전히 같은 좌표라도 개별로 남는다.
      _hospitalAt('3', 40.00, 130.00),
    ];
    final groups = clusterHospitals(hospitals, 14);
    expect(groups, hasLength(3));
    expect(groups.every((g) => !g.isCluster), isTrue);
  });

  test('nearby hospitals merge into one cluster group when zoomed out', () {
    final hospitals = [
      _hospitalAt('1', 37.5000, 127.0000),
      _hospitalAt('2', 37.5001, 127.0001), // 같은 칸에 들어갈 만큼 가까움.
      _hospitalAt('3', 40.0000, 130.0000), // 멀리 떨어진 별도 병원.
    ];
    final groups = clusterHospitals(hospitals, 7);

    final clusters = groups.where((g) => g.isCluster).toList();
    final singles = groups.where((g) => !g.isCluster).toList();
    expect(clusters, hasLength(1));
    expect(clusters.single.hospitals.map((h) => h.id), containsAll(['1', '2']));
    expect(singles, hasLength(1));
    expect(singles.single.hospitals.single.id, '3');
  });

  test('at extreme zoom-out, widely spread hospitals still collapse into a visible cluster '
      '(never an empty result) — 스프린트 7 완료 기준: 최대로 멀리해도 클러스터(N)가 보임', () {
    final hospitals = List.generate(
      50,
      (i) => _hospitalAt('$i', 33.0 + i * 0.2, 124.0 + i * 0.16), // 전국에 걸쳐 흩어짐.
    );
    for (final zoom in [1, 0, -2]) {
      final groups = clusterHospitals(hospitals, zoom);
      expect(groups, isNotEmpty, reason: 'zoom=$zoom');
      final coveredIds = groups.expand((g) => g.hospitals).map((h) => h.id).toSet();
      expect(coveredIds, hasLength(hospitals.length), reason: 'zoom=$zoom');
    }
  });

  test('every hospital appears in exactly one group regardless of zoom', () {
    final hospitals = List.generate(
      30,
      (i) => _hospitalAt('$i', 37.0 + i * 0.01, 127.0 + i * 0.01),
    );
    for (final zoom in [-3, 1, 4, 7, 10, 13, 14, 17]) {
      final groups = clusterHospitals(hospitals, zoom);
      final coveredIds = groups.expand((g) => g.hospitals).map((h) => h.id).toSet();
      expect(coveredIds, hasLength(hospitals.length), reason: 'zoom=$zoom');
    }
  });

  test('a cluster\'s position is the centroid of its hospitals', () {
    final hospitals = [
      _hospitalAt('1', 37.0, 127.0),
      _hospitalAt('2', 39.0, 129.0),
    ];
    final group = MarkerGroup(hospitals);
    expect(group.isCluster, isTrue);
    expect(group.position.lat, closeTo(38.0, 1e-9));
    expect(group.position.lng, closeTo(128.0, 1e-9));
  });

  test('a single hospital\'s position is its own coordinates, not a computed centroid', () {
    final group = MarkerGroup([_hospitalAt('1', 12.34, 56.78)]);
    expect(group.isCluster, isFalse);
    expect(group.position, (lat: 12.34, lng: 56.78));
  });
}
