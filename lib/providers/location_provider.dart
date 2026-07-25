import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Current device location. Only fetched when explicitly requested by a
/// screen that needs it (주변 병원 tab) — never on app start
/// (see CLAUDE.md 하지 말 것: 위치 권한을 앱 시작 시 강제 요청).
class LocationNotifier extends AsyncNotifier<Position?> {
  @override
  Future<Position?> build() async => null;

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
