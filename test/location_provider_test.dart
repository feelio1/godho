import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:petcliniccheck/ads/app_open_ad_suppression.dart';
import 'package:petcliniccheck/providers/location_provider.dart';

Position _position(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 11, 10),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// OS 권한 창·GPS 대신 — 권한 상태와 응답 시점을 테스트가 정한다.
class _FakeGeolocator extends GeolocatorPlatform {
  LocationPermission permission;
  Completer<LocationPermission>? requestCompleter;
  Completer<Position>? positionCompleter;
  Position next;
  int requestCalls = 0;

  _FakeGeolocator({required this.permission, required this.next});

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() {
    requestCalls++;
    return (requestCompleter ??= Completer<LocationPermission>()).future;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      positionCompleter?.future ?? Future.value(next);

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeolocatorPlatform original;
  setUp(() => original = GeolocatorPlatform.instance);
  tearDown(() => GeolocatorPlatform.instance = original);

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('앱 시작 시 조용한 확인은 권한 창을 띄우지 않는다(권한 없으면 null)', () async {
    final fake = _FakeGeolocator(permission: LocationPermission.denied, next: _position(37.5, 127));
    GeolocatorPlatform.instance = fake;
    final c = container();

    expect(await c.read(locationProvider.future), isNull);
    expect(fake.requestCalls, 0);
  });

  test('권한 창이 떠 있는 동안 앱 오프닝 광고를 억제하고, 끝나면 푼다', () async {
    final fake = _FakeGeolocator(permission: LocationPermission.denied, next: _position(37.59, 126.67));
    GeolocatorPlatform.instance = fake;
    final c = container();
    await c.read(locationProvider.future);
    final suppression = c.read(adSuppressionProvider);

    final pending = c.read(locationProvider.notifier).requestAndFetch();
    await pumpEventQueue();
    expect(fake.requestCalls, 1);
    expect(suppression.isSuppressed, isTrue);

    fake.permission = LocationPermission.whileInUse;
    fake.requestCompleter!.complete(LocationPermission.whileInUse);
    await pending;

    expect(suppression.isSuppressed, isFalse);
    // 창에서 막 돌아온 직후 복귀 알림이 늦게 와도 건너뛰도록 "방금 풀림"이 남는다.
    expect(suppression.recentlyReleased, isTrue);
    expect(c.read(locationProvider).value?.latitude, 37.59);
  });

  test('이미 아는 위치가 있으면 다시 받는 동안 지우지 않는다(지도 첫 카메라가 위치를 알게)', () async {
    final fake = _FakeGeolocator(permission: LocationPermission.whileInUse, next: _position(37.59, 126.67));
    GeolocatorPlatform.instance = fake;
    final c = container();
    expect((await c.read(locationProvider.future))?.latitude, 37.59);

    fake.positionCompleter = Completer<Position>();
    final pending = c.read(locationProvider.notifier).requestAndFetch();
    await pumpEventQueue();
    // 다시 받는 중에도 이전 좌표가 그대로 보인다.
    expect(c.read(locationProvider).value?.latitude, 37.59);
    expect(fake.requestCalls, 0);

    fake.positionCompleter!.complete(_position(37.60, 126.68));
    await pending;
    expect(c.read(locationProvider).value?.latitude, 37.60);
  });
}
