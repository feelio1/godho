import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/admob_config.dart';
import '../theme/app_colors.dart';

/// Bottom-fixed banner ad, meant to sit in a `Scaffold.bottomNavigationBar`
/// slot (alongside the bottom tab bar or a floating action bar) so it never
/// overlaps scrollable content (스프린트 5 지시서 2). Renders nothing —
/// zero height, no layout gap — until an ad has actually loaded, and again
/// if loading fails, so a failure never leaves a broken-looking empty box.
///
/// 스프린트 14(Petcli 시안): 병원 카드와 확실히 구분되도록 작은 "광고"
/// 라벨을 함께 보여준다 — 광고 로딩·표시 로직 자체는 그대로.
///
/// 스프린트 15 지시서 6: 전역(4탭 공용) 배너를 걷어내고 홈 화면 스크롤
/// 목록 안에서만 보여주게 됐다 — 그 자리에서는 화면 맨 아래가 아니라
/// 중간에 놓이므로 [inline]을 true로 주면 하단 안전영역 패딩(SafeArea)을
/// 더하지 않는다. 상세·검색결과 화면은 여전히 하단 바 자리에 그대로
/// 쓰이므로 기본값(false)을 유지한다.
class GlobalBannerAd extends StatefulWidget {
  final bool inline;

  const GlobalBannerAd({super.key, this.inline = false});

  @override
  State<GlobalBannerAd> createState() => _GlobalBannerAdState();
}

class _GlobalBannerAdState extends State<GlobalBannerAd> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: admobBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _bannerAd = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();
    final content = Container(
      width: double.infinity,
      color: AppColors.adLabelBg,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '광고',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.adLabelText),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
    if (widget.inline) return content;
    return SafeArea(top: false, child: content);
  }
}
