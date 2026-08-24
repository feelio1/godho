import 'dart:async';

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
  Future<void> showAdIfAvailable() async {
    if (_isShowingAd) return;

    if (!await _cooldownElapsed()) {
      return;
    }

    final ad = _ad;
    if (ad == null) {
      loadAd();
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
      },
      onAdDismissedFullScreenContent: (shownAd) {
        _isShowingAd = false;
        shownAd.dispose();
        _ad = null;
        unawaited(_recordShown());
        loadAd();
      },
    );
    await ad.show();
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
