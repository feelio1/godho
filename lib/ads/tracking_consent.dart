import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_open_ad_suppression.dart';

/// iOS 앱 추적 투명성(ATT) 상태 — 네이티브 `ATTrackingManager.AuthorizationStatus`와
/// 같은 네 가지 + 통로가 없거나 실패했을 때의 [unknown].
enum TrackingStatus { notDetermined, restricted, denied, authorized, unknown }

TrackingStatus _parseStatus(Object? value) => switch (value) {
  'notDetermined' => TrackingStatus.notDetermined,
  'restricted' => TrackingStatus.restricted,
  'denied' => TrackingStatus.denied,
  'authorized' => TrackingStatus.authorized,
  _ => TrackingStatus.unknown,
};

/// 네이티브 통로 — 테스트에서 바꿔 끼운다.
abstract class TrackingPlatform {
  Future<TrackingStatus> status();
  Future<TrackingStatus> request();
}

/// `ios/Runner/AppDelegate.swift`의 `petcli/tracking` 통로(새 패키지 없이 직접 —
/// iOS 출시 준비 L-5). 통로가 없거나 실패하면 [TrackingStatus.unknown].
class MethodChannelTrackingPlatform implements TrackingPlatform {
  const MethodChannelTrackingPlatform();

  static const _channel = MethodChannel('petcli/tracking');

  @override
  Future<TrackingStatus> status() async => _parseStatus(await _channel.invokeMethod<String>('status'));

  @override
  Future<TrackingStatus> request() async => _parseStatus(await _channel.invokeMethod<String>('request'));
}

/// 앱이 실제로 앞에 떠 있을(active) 때까지 기다린다 — iOS는 앱이 active가
/// 아닐 때 ATT 창을 띄우지 않고 그냥 지나간다(콜드 스타트 첫 프레임 직후 등).
Future<void> _waitUntilAppActive() async {
  final binding = WidgetsBinding.instance;
  if (binding.lifecycleState == AppLifecycleState.resumed) return;
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!resumed.isCompleted) resumed.complete();
    },
  );
  try {
    await resumed.future;
  } finally {
    listener.dispose();
  }
}

/// iOS 앱 추적 투명성 — 언제 묻고, 광고 요청을 어떻게 만들지(iOS 출시 준비 L-5).
///
/// - iOS에서만: 온보딩을 마친 뒤 처음 메인 화면에 들어왔을 때 **한 번**
///   ([requestIfNeeded], MainShell이 부른다). 이미 답했으면(허용·거부·제한)
///   다시 묻지 않는다. 미리 설명하는 화면·보상 문구는 없다 — 시스템 창의
///   문구(Info.plist `NSUserTrackingUsageDescription`)만 쓴다.
/// - 첫 광고 요청 전에 묻는다: iOS의 광고 로드는 [ready]를 기다린다.
/// - 허용이 아니면(거부·제한·확인 실패) 비맞춤 광고([adRequest]).
/// - 묻는 동안 앱 오프닝 광고 억제(`adSuppressionProvider.during()`).
/// - 안드로이드는 아무것도 하지 않는다 — [ready]는 바로 끝나고 광고 요청도
///   지금과 같은 `AdRequest()`.
class TrackingConsent {
  TrackingConsent({
    this.platform = const MethodChannelTrackingPlatform(),
    TargetPlatform Function()? targetPlatform,
    Future<void> Function()? waitUntilActive,
  }) : _targetPlatform = targetPlatform ?? (() => defaultTargetPlatform),
       _waitUntilActive = waitUntilActive ?? _waitUntilAppActive;

  static TrackingConsent instance = TrackingConsent();

  /// 네이티브 통로(테스트에서 바꿔 끼운다).
  final TrackingPlatform platform;
  final TargetPlatform Function() _targetPlatform;
  final Future<void> Function() _waitUntilActive;

  final _ready = Completer<void>();
  bool _asked = false;
  TrackingStatus? _status;

  bool get isIos => _targetPlatform() == TargetPlatform.iOS;

  /// 마지막으로 확인한 상태(아직 확인 전이면 null).
  TrackingStatus? get status => _status;

  /// iOS 광고 로드가 기다리는 신호 — 추적 허용 여부가 정해지면(답했거나,
  /// 이미 답해 있었거나, 확인이 실패했으면) 끝난다. 안드로이드는 바로 끝난다.
  Future<void> get ready => isIos ? _ready.future : Future<void>.value();

  /// 맞춤 광고를 써도 되는가 — 안드로이드는 지금처럼 항상 true(따로 묻지 않음),
  /// iOS는 허용했을 때만.
  bool get personalizedAdsAllowed => !isIos || _status == TrackingStatus.authorized;

  /// 광고 요청 — 안드로이드는 지금과 똑같은 `AdRequest()`, iOS는 허용이 아니면 비맞춤.
  AdRequest adRequest() => isIos ? AdRequest(nonPersonalizedAds: !personalizedAdsAllowed) : const AdRequest();

  /// 메인 화면 첫 진입 때 한 번 부른다. iOS가 아니거나 이번 실행에서 이미
  /// 불렀으면 아무것도 하지 않는다. 어떤 경우에도 예외를 밖으로 던지지 않는다.
  Future<void> requestIfNeeded(AppOpenAdSuppression suppression) async {
    if (!isIos || _asked) return;
    _asked = true;
    try {
      var current = await platform.status();
      if (current == TrackingStatus.notDetermined) {
        current = await suppression.during(() async {
          await _waitUntilActive();
          return platform.request();
        });
      }
      _status = current;
      debugPrint('[TrackingConsent] 추적 허용 상태: $current');
    } catch (e) {
      _status = TrackingStatus.unknown;
      debugPrint('[TrackingConsent] 추적 허용 확인 실패(비맞춤 광고로): $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }
}
