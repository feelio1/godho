import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Current device location.
///
/// [build] only ever performs a silent, non-prompting check: if permission
/// was already granted in an earlier session, it quietly fetches the
/// position so 가까운 순 / distance can default to "내 주변" without asking
/// again. It never shows the OS permission dialog itself. Only
/// [requestAndFetch] — called from an explicit "내 주변 병원" tap — does
/// that (see CLAUDE.md 하지 말 것: 위치 권한을 앱 시작 시 강제 요청).
///
/// 위치 자동감지 디버깅 지시서 B: `getCurrentPosition`에 타임아웃을 걸고
/// (실내 등에서 GPS 픽스가 오래 걸리거나 아예 안 잡히는 경우, 타임아웃
/// 없이는 이 Future가 사실상 멈춘 것처럼 보여 아래로 아무 것도 흐르지
/// 않는다), 실패하면 `getLastKnownPosition`(캐시된 마지막 위치)으로
/// 한 번 더 시도한다. 각 단계는 `debugPrint`로 남겨 "조용한 실패"가
/// 진단을 막지 않게 한다.
class LocationNotifier extends AsyncNotifier<Position?> {
  static const _timeLimit = Duration(seconds: 8);

  static void _log(String message) => debugPrint('[LocationProvider] $message');

  @override
  Future<Position?> build() async {
    final permission = await Geolocator.checkPermission();
    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    _log('build(): 조용한 확인 — 권한=$permission, granted=$granted');
    if (!granted) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('build(): 위치 서비스 꺼짐');
      return null;
    }

    return _fetchPosition();
  }

  Future<void> requestAndFetch() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _log('requestAndFetch(): 위치 서비스 활성화=$serviceEnabled');
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      _log('requestAndFetch(): 권한 상태(요청 전)=$permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        _log('requestAndFetch(): 권한 상태(요청 후)=$permission');
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _log('requestAndFetch(): 권한 거부 — 중단');
        return null;
      }

      return _fetchPosition();
    });
  }

  /// `getCurrentPosition`을 [_timeLimit] 안에 시도하고, 타임아웃·실패하면
  /// `getLastKnownPosition`(캐시된 마지막 좌표)으로 한 번 더 시도한다.
  /// 둘 다 실패해야 null — 권한/서비스는 이미 확인된 상태에서 호출된다.
  Future<Position?> _fetchPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _timeLimit,
        ),
      );
      _log('getCurrentPosition 성공: (${position.latitude}, ${position.longitude})');
      return position;
    } catch (e) {
      _log('getCurrentPosition 실패($e) — getLastKnownPosition으로 폴백');
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _log('getLastKnownPosition 성공: (${last.latitude}, ${last.longitude})');
      } else {
        _log('getLastKnownPosition도 null — 좌표 획득 실패');
      }
      return last;
    } catch (e) {
      _log('getLastKnownPosition도 실패($e)');
      return null;
    }
  }
}

final locationProvider = AsyncNotifierProvider<LocationNotifier, Position?>(
  LocationNotifier.new,
);
