import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bundle_provider.dart';
import '../providers/followup_appointment_provider.dart';
import 'app_open_ad_manager.dart';
import 'app_open_ad_suppression.dart';

/// 이번 복귀에 앱 오프닝 광고를 시도해도 되는가 — 모두 만족할 때만 true:
/// - 실제로 백그라운드(hidden/paused)에 갔다가 돌아왔다([returnedFromBackground]).
///   권한 요청 같은 시스템 창은 앱을 inactive까지만 보내므로 복귀로 치지 않는다.
/// - 앱 실행 후 첫 복귀가 아니다([firstReturnSinceLaunch]).
/// - 메인 탭 화면(MainShell)의 라우트가 최상단이다(위에 화면·시트·다이얼로그 없음).
/// - 진행 중인 흐름의 억제([adSuppressionProvider])가 없고, 방금(2초 안) 풀린
///   억제도 없다([recentlySuppressed]).
bool shouldTryAppOpenAd({
  required bool shellIsTopRoute,
  required int suppressionCount,
  bool returnedFromBackground = true,
  bool firstReturnSinceLaunch = false,
  bool recentlySuppressed = false,
}) =>
    returnedFromBackground &&
    !firstReturnSinceLaunch &&
    shellIsTopRoute &&
    suppressionCount == 0 &&
    !recentlySuppressed;

/// Wraps the app and shows the app-open ad only on a genuine
/// background→foreground return — never on the initial cold start and never
/// while the bundle is still loading (스프린트 5 지시서 3). 실기기 2차 보정:
/// 콜드 스타트 직후 위치 권한 창에서 돌아올 때 광고가 떴다 — 그래서 실제
/// 백그라운드(hidden/paused)를 거친 복귀만 세고, 앱 실행 후 첫 복귀는 건너뛴다.
///
/// 진행 중인 화면 위에는 띄우지 않는다: 이 게이트가 놓인 메인 탭 화면의
/// 라우트가 최상단이 아니거나(다른 화면·시트·다이얼로그가 위에 있음)
/// [adSuppressionProvider]가 올라가 있으면(일기 작성·기록 입력·로그인·
/// 결제·사진 선택 등) 이번 복귀는 광고 매니저를 아예 부르지 않고 건너뛴다
/// — 광고가 뜨지 않았으니 쿨다운도 소모되지 않는다. 지난 예약 확인
/// 시트가 기다리는 흐름 종료 신호는 건너뛸 때도 똑같이 올린다.
class AppOpenAdGate extends ConsumerStatefulWidget {
  final Widget child;

  /// 테스트에서 광고 SDK 없이 표시 여부를 확인하려고 주입한다.
  final AppOpenAdManager? manager;

  const AppOpenAdGate({super.key, required this.child, this.manager});

  @override
  ConsumerState<AppOpenAdGate> createState() => _AppOpenAdGateState();
}

class _AppOpenAdGateState extends ConsumerState<AppOpenAdGate> with WidgetsBindingObserver {
  late final AppOpenAdManager _manager = widget.manager ?? AppOpenAdManager();
  bool _bundleReady = false;

  /// 지난 resumed 이후 실제로 백그라운드(hidden/paused)에 갔는가.
  bool _wentToBackground = false;

  /// 앱 실행 후 첫 (실제) 복귀를 이미 건너뛰었는가.
  bool _firstReturnPassed = false;

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
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      _wentToBackground = true;
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final returnedFromBackground = _wentToBackground;
    _wentToBackground = false;
    if (!_bundleReady) return;
    final firstReturn = returnedFromBackground && !_firstReturnPassed;
    if (returnedFromBackground) _firstReturnPassed = true;

    // 광고가 떠 있지 않다고 확실해지면(안 떴거나, 뜬 뒤 닫혔거나, 이번
    // 복귀는 건너뛰었으면) 올린다 — 홈의 지난 예약 확인 시트가 이 신호를
    // 보고서야 뜬다("지난 예약 확인" 지시서 3, 겹침 금지).
    void onFlowComplete() {
      if (!mounted) return;
      ref.read(appOpenAdFlowSettledProvider.notifier).state++;
    }

    final suppression = ref.read(adSuppressionProvider);
    final shouldTry = shouldTryAppOpenAd(
      shellIsTopRoute: ModalRoute.of(context)?.isCurrent == true,
      suppressionCount: suppression.count,
      returnedFromBackground: returnedFromBackground,
      firstReturnSinceLaunch: firstReturn,
      recentlySuppressed: suppression.recentlyReleased,
    );
    if (!shouldTry) {
      onFlowComplete();
      return;
    }
    _manager.showAdIfAvailable(onFlowComplete: onFlowComplete);
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
