import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bundle_provider.dart';
import '../providers/followup_appointment_provider.dart';
import 'app_open_ad_manager.dart';

/// Wraps the app and shows the app-open ad only on a genuine
/// background→foreground return — never on the initial cold start (there is
/// no prior "paused" state to resume from, so [didChangeAppLifecycleState]
/// simply never fires on first launch) and never while the bundle is still
/// loading (스프린트 5 지시서 3).
class AppOpenAdGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppOpenAdGate({super.key, required this.child});

  @override
  ConsumerState<AppOpenAdGate> createState() => _AppOpenAdGateState();
}

class _AppOpenAdGateState extends ConsumerState<AppOpenAdGate> with WidgetsBindingObserver {
  final _manager = AppOpenAdManager();
  bool _bundleReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _bundleReady) {
      _manager.showAdIfAvailable(
        // 광고가 떠 있지 않다고 확실해지면(안 떴거나, 뜬 뒤 닫혔으면)
        // 올린다 — 홈의 지난 예약 확인 시트가 이 신호를 보고서야 뜬다
        // ("지난 예약 확인" 지시서 3, 겹침 금지).
        onFlowComplete: () {
          if (!mounted) return;
          ref.read(appOpenAdFlowSettledProvider.notifier).state++;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bundleProvider, (previous, next) {
      if (!_bundleReady && next.hasValue) {
        _bundleReady = true;
        // 번들 파싱이 끝난 뒤에만 프리로드를 시작해 로딩 화면과 경쟁하지 않는다.
        _manager.loadAd();
      }
    });
    return widget.child;
  }
}
