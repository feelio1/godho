import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/utils/map_first_fix.dart';

void main() {
  test('새로 설치 → 병원 탭에서 권한을 막 허용: 지도는 서울시청에서 떴고, 위치가 확인되면 한 번만 옮긴다', () {
    final fix = FirstFixCentering();
    // 지도는 이미 떠 있다(위치 모름 → 서울시청).
    expect(fix.onLocation(37.596, 126.673, mapReady: true), (lat: 37.596, lng: 126.673));
    expect(fix.done, isTrue);
    // 그 뒤 위치가 다시 들어와도(재확인·이동) 다시 옮기지 않는다.
    expect(fix.onLocation(37.600, 126.680, mapReady: true), isNull);
  });

  test('지도가 준비되기 전에 위치가 오면 기억했다가 준비되면 옮긴다', () {
    final fix = FirstFixCentering();
    expect(fix.onLocation(37.596, 126.673, mapReady: false), isNull);
    expect(fix.onMapReady(), (lat: 37.596, lng: 126.673));
    expect(fix.onMapReady(), isNull);
    expect(fix.onLocation(37.6, 126.7, mapReady: true), isNull);
  });

  test('사용자가 지도를 먼저 만지면 옮기지 않는다(기억해 둔 위치도 버림)', () {
    final fix = FirstFixCentering();
    fix.onLocation(37.596, 126.673, mapReady: false);
    fix.markUserInteracted();
    expect(fix.onMapReady(), isNull);
    expect(fix.onLocation(37.596, 126.673, mapReady: true), isNull);
  });

  test('처음부터 현재 위치에서 시작했으면 옮기지 않는다', () {
    final fix = FirstFixCentering()..startedAtLocation();
    expect(fix.onLocation(37.596, 126.673, mapReady: true), isNull);
  });

  test('위치를 모르는 채로 지도가 준비되면 아무것도 하지 않는다', () {
    final fix = FirstFixCentering();
    expect(fix.onMapReady(), isNull);
    expect(fix.done, isFalse);
  });
}
