/// 지도 "첫 위치 맞춤" 판단 — 지도를 서울시청(위치 모름)에서 띄운 뒤에 위치가
/// 확인되면(예: 새로 설치 후 병원 탭에서 위치 권한을 막 허용한 경우) 사용자가
/// 지도를 직접 만지기 전이라면 딱 한 번 그 위치로 옮긴다. 지도 SDK와 무관한
/// 순수 상태라 단위 테스트로 확인한다(`nearby_map_screen.dart`가 쓴다).
class FirstFixCentering {
  bool _done = false;
  bool _userInteracted = false;
  ({double lat, double lng})? _pending;

  /// 첫 위치 맞춤을 이미 했거나(또는 처음부터 현재 위치에서 시작해) 더는 하지 않는다.
  bool get done => _done;
  bool get userInteracted => _userInteracted;

  /// 지도를 처음부터 현재 위치에서 시작했다 — 옮길 필요가 없다.
  void startedAtLocation() => _done = true;

  /// 사용자가 지도를 직접 만졌다 — 그 뒤로는 자동으로 옮기지 않는다.
  void markUserInteracted() {
    _userInteracted = true;
    _pending = null;
  }

  /// 위치가 확인됐을 때 지금 옮길 좌표. 지도가 아직 준비 전이면 기억했다가
  /// [onMapReady]에서 돌려준다. 옮길 필요가 없으면 null.
  ({double lat, double lng})? onLocation(double lat, double lng, {required bool mapReady}) {
    if (_done || _userInteracted) return null;
    if (!mapReady) {
      _pending = (lat: lat, lng: lng);
      return null;
    }
    _done = true;
    return (lat: lat, lng: lng);
  }

  /// 지도가 준비됐을 때 — 그사이 확인된 위치가 있으면 그 좌표.
  ({double lat, double lng})? onMapReady() {
    final pending = _pending;
    _pending = null;
    if (pending == null || _done || _userInteracted) return null;
    _done = true;
    return pending;
  }
}
