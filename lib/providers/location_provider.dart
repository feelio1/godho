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
class LocationNotifier extends AsyncNotifier<Position?> {
  @override
  Future<Position?> build() async {
    final permission = await Geolocator.checkPermission();
    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!granted) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> requestAndFetch() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    });
  }
}

final locationProvider = AsyncNotifierProvider<LocationNotifier, Position?>(
  LocationNotifier.new,
);
