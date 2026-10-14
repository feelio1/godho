import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/admob_config.dart';

/// Preloads and shows the app-open ad on return-to-foreground, with the
/// safety rules from 스프린트 5 지시서 3:
/// - never shown more than once per [_cooldown] (4 hours)
/// - only shown once an ad has actually finished preloading
/// - showing is entirely the caller's responsibility to trigger (this
///   class never shows on its own), so cold start / bundle loading never
///   race against it
class AppOpenAdManager {
  static const _cooldown = Duration(hours: 4);
  static const _lastShownKey = 'app_open_ad_last_shown_at_millis';

  AppOpenAd? _ad;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;

  void loadAd() {
    if (_isLoadingAd || _ad != null) return;
    _isLoadingAd = true;
    AppOpenAd.load(
      adUnitId: admobAppOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingAd = false;
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          _isLoadingAd = false;
        },
      ),
    );
  }

  /// Shows the preloaded ad if the cooldown has elapsed. Does nothing (and
  /// the caller proceeds straight into the app) if the cooldown hasn't
  /// elapsed yet, or if no ad has finished loading — a load is kicked off
  /// either way so one is ready sooner next time.
  ///
  /// [onFlowComplete](선택, "지난 예약 확인" 지시서 3)는 화면에 광고가 더
  /// 이상 떠 있지 않다고 확실해지는 시점에 1번 불린다 — 광고가 애초에 안
  /// 뜨면(쿨다운 전/로딩 중/실패) 즉시, 뜬 적이 있으면 사용자가 닫은
  /// 뒤에. 홈의 다른 오버레이(지난 예약 확인 시트 등)가 광고와 겹치지
  /// 않게 이 신호를 기다릴 수 있다 — 광고 자체의 동작은 바뀌지 않는다.
  Future<void> showAdIfAvailable({VoidCallback? onFlowComplete}) async {
    if (_isShowingAd) {
      onFlowComplete?.call();
      return;
    }

    if (!await _cooldownElapsed()) {
      onFlowComplete?.call();
      return;
    }

    final ad = _ad;
    if (ad == null) {
      loadAd();
      onFlowComplete?.call();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdShowedFullScreenContent: (_) {
        _isShowingAd = true;
      },
      onAdFailedToShowFullScreenContent: (shownAd, error) {
        _isShowingAd = false;
        shownAd.dispose();
        _ad = null;
        loadAd();
        onFlowComplete?.call();
      },
      onAdDismissedFullScreenContent: (shownAd) {
        _isShowingAd = false;
        shownAd.dispose();
        _ad = null;
        unawaited(_recordShown());
        loadAd();
        onFlowComplete?.call();
      },
    );
    try {
      await ad.show();
    } catch (_) {
      // 광고 SDK 쪽 예외로 화면을 막지 않는다 — 실패해도 앱은 정상 진입.
      _isShowingAd = false;
      onFlowComplete?.call();
    }
  }

  Future<bool> _cooldownElapsed() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMillis = prefs.getInt(_lastShownKey);
    if (lastMillis == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    return DateTime.now().difference(last) >= _cooldown;
  }

  Future<void> _recordShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);
  }
}
