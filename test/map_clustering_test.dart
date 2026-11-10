import 'dart:math' as math;

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

  test('markerSearchRadiusKmForZoom grows as zoom decreases (더 멀리 볼수록 더 넓게 조회) and is always positive', () {
    for (var zoom = 20; zoom > -5; zoom--) {
      final radius = markerSearchRadiusKmForZoom(zoom);
      expect(radius, greaterThan(0), reason: 'zoom=$zoom');
      expect(radius, greaterThanOrEqualTo(markerSearchRadiusKmForZoom(zoom + 1)), reason: 'zoom=$zoom');
    }
  });

  group('보이는 영역 기준 마커 후보(실기기 2차 보정)', () {
    test('MapViewport.fromCorners: 모서리 순서와 무관, 비정상 값은 null', () {
      final v = MapViewport.fromCorners(37.60, 126.90, 37.50, 127.05)!;
      expect(v.south, 37.50);
      expect(v.north, 37.60);
      expect(v.west, 126.90);
      expect(v.east, 127.05);
      expect(MapViewport.fromCorners(37.5, 127, 37.5, 127.1), isNull); // 넓이 0
      expect(MapViewport.fromCorners(double.nan, 127, 37.6, 127.1), isNull);
      expect(MapViewport.fromCorners(10, 100, 40, 140), isNull); // 비정상적으로 넓음
    });

    test('around·expanded·contains', () {
      final v = MapViewport.around(37.5665, 126.9780, 11.1);
      expect(v.contains(37.5665, 126.9780), isTrue);
      expect(v.contains(37.66, 126.978), isTrue); // 북쪽 약 10km
      expect(v.contains(37.70, 126.978), isFalse); // 북쪽 약 15km
      expect(v.expanded(0.5).contains(37.70, 126.978), isTrue);
    });

    test('서울시청 줌 12: 화면 안 영업중 병원은 모두 후보(클러스터 줌이라 자르지 않음), 폐업·영역 밖·좌표 없음 제외', () {
      final viewport = MapViewport.around(37.5665, 126.9780, 16);
      final hospitals = [
        for (var i = 0; i < 500; i++) _hospitalAt('in$i', 37.50 + (i % 25) * 0.005, 126.90 + (i ~/ 25) * 0.008),
        _hospitalAt('far', 37.45, 126.66), // 인천 쪽 — 화면 밖
        Hospital(
          id: 'closed',
          name: '폐업',
          status: HospitalStatus.closed,
          sido: '서울',
          sigungu: '중구',
          roadAddr: '',
          jibunAddr: '',
          lat: 37.5665,
          lng: 126.9780,
        ),
        const Hospital(
          id: 'nocoord',
          name: '좌표 없음',
          status: HospitalStatus.open,
          sido: '서울',
          sigungu: '중구',
          roadAddr: '',
          jibunAddr: '',
          lat: null,
          lng: null,
        ),
      ];
      final candidates = selectMarkerCandidates(
        hospitals,
        viewport: viewport,
        centerLat: 37.5665,
        centerLng: 126.9780,
        zoomLevel: 12,
        individualCap: 300,
      );
      expect(candidates.length, 500);
      expect(candidates.map((h) => h.id), isNot(contains('far')));
      expect(candidates.map((h) => h.id), isNot(contains('closed')));
      expect(candidates.map((h) => h.id), isNot(contains('nocoord')));
      // 줌이 멀면 클러스터로 묶여 화면에 뭔가는 반드시 보인다.
      final groups = clusterHospitals(candidates, 12);
      expect(groups, isNotEmpty);
      expect(groups.any((g) => g.isCluster), isTrue);
    });

    test('지도를 옮기면 옮긴 곳의 병원이 후보가 된다(검단)', () {
      final hospitals = [_hospitalAt('seoul', 37.5665, 126.9780), _hospitalAt('geomdan', 37.5960, 126.6730)];
      final atGeomdan = selectMarkerCandidates(
        hospitals,
        viewport: MapViewport.around(37.5960, 126.6730, 4),
        centerLat: 37.5960,
        centerLng: 126.6730,
        zoomLevel: 15,
      );
      expect(atGeomdan.map((h) => h.id), ['geomdan']);
    });

    test('개별 마커 줌에서는 상한까지 중심에 가까운 순으로 자른다', () {
      final hospitals = [for (var i = 0; i < 10; i++) _hospitalAt('h$i', 37.5 + i * 0.001, 127.0)];
      final candidates = selectMarkerCandidates(
        hospitals.reversed,
        viewport: MapViewport.around(37.5, 127.0, 5),
        centerLat: 37.5,
        centerLng: 127.0,
        zoomLevel: 15,
        individualCap: 3,
      );
      expect(candidates.map((h) => h.id), ['h0', 'h1', 'h2']);
    });
  });

  group('화면 픽셀 기준 클러스터(실기기: 서울시청 줌 12에서 원끼리 겹침)', () {
    // 줌 12 서울 근처를 흉내: 가로 1픽셀 ≈ 경도 0.0009도.
    const degPerPx = 0.0009;

    double pxDistance(MarkerGroup a, MarkerGroup b) {
      final cosLat = math.cos(a.position.lat * math.pi / 180);
      final dx = (a.position.lng - b.position.lng) / degPerPx;
      final dy = (a.position.lat - b.position.lat) / (degPerPx * cosLat);
      return math.sqrt(dx * dx + dy * dy);
    }

    test('어떤 두 그룹(클러스터·개별 마커)도 화면에서 최소 간격보다 가깝지 않다', () {
      final rnd = math.Random(7);
      final hospitals = [
        for (var i = 0; i < 600; i++)
          _hospitalAt('h$i', 37.45 + rnd.nextDouble() * 0.2, 126.85 + rnd.nextDouble() * 0.25),
      ];
      final groups = clusterHospitals(hospitals, 12, degreesPerPixel: degPerPx);
      expect(groups.expand((g) => g.hospitals).length, hospitals.length);
      for (var i = 0; i < groups.length; i++) {
        for (var j = i + 1; j < groups.length; j++) {
          expect(pxDistance(groups[i], groups[j]), greaterThanOrEqualTo(kMarkerMinSeparationPx - 1e-6),
              reason: '그룹 $i·$j가 겹친다');
        }
      }
    });

    test('화면에서 30px 떨어진 두 병원은 묶이고, 200px 떨어지면 따로 보인다', () {
      final near = clusterHospitals(
        [_hospitalAt('a', 37.5665, 126.9780), _hospitalAt('b', 37.5665, 126.9780 + 30 * degPerPx)],
        12,
        degreesPerPixel: degPerPx,
      );
      expect(near, hasLength(1));
      expect(near.single.isCluster, isTrue);

      final far = clusterHospitals(
        [_hospitalAt('a', 37.5665, 126.9780), _hospitalAt('b', 37.5665, 126.9780 + 200 * degPerPx)],
        12,
        degreesPerPixel: degPerPx,
      );
      expect(far, hasLength(2));
      expect(far.every((g) => !g.isCluster), isTrue);
    });

    test('격자 칸 경계 양쪽에 붙은 두 병원도 한 그룹이 된다', () {
      const sep = kMarkerMinSeparationPx * degPerPx;
      final boundary = (126.9780 / sep).ceil() * sep;
      final groups = clusterHospitals(
        [_hospitalAt('a', 37.5665, boundary - 2 * degPerPx), _hospitalAt('b', 37.5665, boundary + 2 * degPerPx)],
        12,
        degreesPerPixel: degPerPx,
      );
      expect(groups, hasLength(1));
    });

    test('개별 마커 줌에서는 픽셀 정보가 있어도 묶지 않는다', () {
      final groups = clusterHospitals(
        [_hospitalAt('a', 37.5665, 126.9780), _hospitalAt('b', 37.5665, 126.9781)],
        14,
        degreesPerPixel: 0.00005,
      );
      expect(groups, hasLength(2));
    });
  });
}
