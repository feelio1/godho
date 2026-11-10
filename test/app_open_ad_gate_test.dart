import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/ads/app_open_ad_gate.dart';
import 'package:petcliniccheck/ads/app_open_ad_manager.dart';
import 'package:petcliniccheck/ads/app_open_ad_suppression.dart';
import 'package:petcliniccheck/models/hospital_bundle.dart';
import 'package:petcliniccheck/providers/bundle_provider.dart';
import 'package:petcliniccheck/providers/followup_appointment_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 광고 SDK 없이 "매니저에게 표시를 요청했는가"만 센다. 쿨다운 기록은
/// 실제 매니저만 쓰므로, 요청이 없으면 쿨다운도 그대로다.
class _FakeAppOpenAdManager extends AppOpenAdManager {
  int showCalls = 0;

  @override
  void loadAd() {}

  @override
  Future<void> showAdIfAvailable({VoidCallback? onFlowComplete}) async {
    showCalls++;
    onFlowComplete?.call();
  }
}

// AppOpenAdManager가 마지막 표시 시각을 남기는 키.
const _lastShownKey = 'app_open_ad_last_shown_at_millis';

const _emptyBundle = HospitalBundle(
  generatedAt: null,
  source: '',
  region: '',
  hospitals: [],
  timelines: {},
);

/// 억제 해제 직후 유예(2초)를 테스트가 넘길 수 있게 하는 시계.
DateTime _now = DateTime(2026, 11, 10, 12);
void _advance(Duration d) => _now = _now.add(d);

/// 권한 요청 같은 시스템 창 왕복 — 앱은 inactive까지만 갔다가 돌아온다.
Future<void> _systemDialogRoundTrip(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

/// 백그라운드에 갔다가 돌아오는 실제 생명주기 순서를 흉내 낸다.
Future<void> _backgroundAndResume(WidgetTester tester) async {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

/// [shellChild]는 MainShell 자리에 놓인다 — 게이트와 같은 (홈) 라우트.
/// [warmUp]이면 "앱 실행 후 첫 복귀(건너뜀)"를 미리 한 번 지나고 흐름 종료
/// 신호 수를 0으로 되돌려, 각 테스트가 그다음 복귀부터 보게 한다.
Future<_FakeAppOpenAdManager> _pumpGate(WidgetTester tester, {Widget? shellChild, bool warmUp = true}) async {
  final manager = _FakeAppOpenAdManager();
  final bundle = Completer<HospitalBundle>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bundleProvider.overrideWith((ref) => bundle.future),
        adSuppressionProvider.overrideWith((ref) => AppOpenAdSuppression(clock: () => _now)),
      ],
      child: MaterialApp(
        home: AppOpenAdGate(
          manager: manager,
          child: shellChild ??
              Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (pushed) => Scaffold(
                              body: ElevatedButton(
                                onPressed: () => Navigator.of(pushed).pop(),
                                child: const Text('닫기'),
                              ),
                            ),
                          ),
                        ),
                        child: const Text('화면 열기'),
                      ),
                      ElevatedButton(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => const SizedBox(height: 100, child: Text('시트')),
                        ),
                        child: const Text('시트 열기'),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    ),
  );
  // 번들 로딩이 끝나야 게이트가 복귀 광고를 고려한다(콜드 스타트 경쟁 방지).
  bundle.complete(_emptyBundle);
  await tester.pump();
  if (warmUp) {
    await _backgroundAndResume(tester);
    expect(manager.showCalls, 0, reason: '앱 실행 후 첫 복귀는 건너뛴다');
    _container(tester).read(appOpenAdFlowSettledProvider.notifier).state = 0;
  }
  return manager;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppOpenAdGate, skipOffstage: false)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('shouldTryAppOpenAd', () {
    test('메인 화면이 최상단이고 억제가 없을 때만 true', () {
      expect(shouldTryAppOpenAd(shellIsTopRoute: true, suppressionCount: 0), isTrue);
      expect(shouldTryAppOpenAd(shellIsTopRoute: false, suppressionCount: 0), isFalse);
      expect(shouldTryAppOpenAd(shellIsTopRoute: true, suppressionCount: 1), isFalse);
      expect(shouldTryAppOpenAd(shellIsTopRoute: false, suppressionCount: 2), isFalse);
    });

    test('시스템 창 왕복·앱 실행 후 첫 복귀·방금 풀린 억제는 건너뛴다', () {
      bool tryWith({bool background = true, bool first = false, bool recent = false}) => shouldTryAppOpenAd(
            shellIsTopRoute: true,
            suppressionCount: 0,
            returnedFromBackground: background,
            firstReturnSinceLaunch: first,
            recentlySuppressed: recent,
          );
      expect(tryWith(), isTrue);
      expect(tryWith(background: false), isFalse);
      expect(tryWith(first: true), isFalse);
      expect(tryWith(recent: true), isFalse);
    });
  });

  group('AppOpenAdSuppression', () {
    test('during은 예외로 끝나도 억제를 내린다', () async {
      final suppression = AppOpenAdSuppression();
      await expectLater(
        suppression.during<void>(() async {
          expect(suppression.isSuppressed, isTrue);
          throw StateError('picker failed');
        }),
        throwsStateError,
      );
      expect(suppression.count, 0);
    });

    test('억제가 풀린 뒤 2초 동안은 "방금 풀림"으로 본다', () {
      var now = DateTime(2026, 11, 10);
      final suppression = AppOpenAdSuppression(clock: () => now);
      expect(suppression.recentlyReleased, isFalse);
      suppression
        ..acquire()
        ..release();
      expect(suppression.recentlyReleased, isTrue);
      now = now.add(const Duration(milliseconds: 1999));
      expect(suppression.recentlyReleased, isTrue);
      now = now.add(const Duration(milliseconds: 2));
      expect(suppression.recentlyReleased, isFalse);
    });

    test('짝이 맞지 않는 release는 0 아래로 내려가지 않는다', () {
      final suppression = AppOpenAdSuppression()..release();
      expect(suppression.count, 0);
      suppression.acquire();
      expect(suppression.isSuppressed, isTrue);
    });
  });

  group('AppOpenAdGate', () {
    testWidgets('정상 복귀(메인 화면 최상단, 억제 없음)면 기존처럼 광고 표시를 요청한다', (tester) async {
      final manager = await _pumpGate(tester);

      await _backgroundAndResume(tester);

      expect(manager.showCalls, 1);
      expect(_container(tester).read(appOpenAdFlowSettledProvider), 1);
    });

    testWidgets('다른 화면이 위에 떠 있으면 건너뛰고, 쿨다운은 소모하지 않으며, 흐름 종료 신호는 올린다', (tester) async {
      final manager = await _pumpGate(tester);
      await tester.tap(find.text('화면 열기'));
      await tester.pumpAndSettle();

      await _backgroundAndResume(tester);

      expect(manager.showCalls, 0);
      expect(_container(tester).read(appOpenAdFlowSettledProvider), 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_lastShownKey), isNull);

      // 위 화면을 닫고 다음 복귀 때는 다시 표시 대상이 된다.
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      await _backgroundAndResume(tester);

      expect(manager.showCalls, 1);
      expect(_container(tester).read(appOpenAdFlowSettledProvider), 2);
    });

    testWidgets('바텀시트가 떠 있어도 건너뛴다', (tester) async {
      final manager = await _pumpGate(tester);
      await tester.tap(find.text('시트 열기'));
      await tester.pumpAndSettle();

      await _backgroundAndResume(tester);

      expect(manager.showCalls, 0);
      expect(_container(tester).read(appOpenAdFlowSettledProvider), 1);
    });

    testWidgets('억제 카운터가 0보다 크면 메인 화면이 최상단이어도 건너뛴다', (tester) async {
      final manager = await _pumpGate(tester);
      final suppression = _container(tester).read(adSuppressionProvider)..acquire();

      await _backgroundAndResume(tester);

      expect(manager.showCalls, 0);
      expect(_container(tester).read(appOpenAdFlowSettledProvider), 1);

      suppression.release();
      _advance(const Duration(seconds: 3));
      await _backgroundAndResume(tester);
      expect(manager.showCalls, 1);
    });

    testWidgets('AppOpenAdSuppressor는 마운트 동안 억제하고 사라지면 반드시 푼다', (tester) async {
      final showSuppressor = ValueNotifier<bool>(true);
      final manager = await _pumpGate(
        tester,
        shellChild: ValueListenableBuilder<bool>(
          valueListenable: showSuppressor,
          builder: (context, show, _) =>
              show ? const AppOpenAdSuppressor(child: Text('작성 중')) : const Text('작성 끝'),
        ),
      );
      expect(_container(tester).read(adSuppressionProvider).count, 1);

      await _backgroundAndResume(tester);
      expect(manager.showCalls, 0);

      showSuppressor.value = false;
      await tester.pump();
      expect(_container(tester).read(adSuppressionProvider).count, 0);

      _advance(const Duration(seconds: 3));
      await _backgroundAndResume(tester);
      expect(manager.showCalls, 1);
    });

    testWidgets('앱 실행 후 첫 복귀는 건너뛰고(신호는 올림), 다음 복귀부터 광고를 시도한다', (tester) async {
      final manager = await _pumpGate(tester, warmUp: false);

      await _backgroundAndResume(tester);
      expect(manager.showCalls, 0);
      expect(_container(tester).read(appOpenAdFlowSettledProvider), 1);

      await _backgroundAndResume(tester);
      expect(manager.showCalls, 1);
    });

    testWidgets('권한 창 같은 시스템 창 왕복(inactive→resumed)은 복귀로 치지 않는다', (tester) async {
      final manager = await _pumpGate(tester);

      await _systemDialogRoundTrip(tester);
      await _systemDialogRoundTrip(tester);
      expect(manager.showCalls, 0);
      expect(_container(tester).read(appOpenAdFlowSettledProvider), 2);
    });

    testWidgets('콜드 스타트 직후 권한 창에서 돌아와도 광고가 뜨지 않는다', (tester) async {
      final manager = await _pumpGate(tester, warmUp: false);
      final suppression = _container(tester).read(adSuppressionProvider);

      // 권한 요청(during)이 끝난 직후 복귀 알림이 온다 — 실기기에서 광고가 뜬 순서.
      await suppression.during(() async {});
      await _backgroundAndResume(tester);
      expect(manager.showCalls, 0);
    });

    testWidgets('억제가 풀린 지 2초 안의 복귀는 건너뛰고, 그 뒤 복귀는 시도한다', (tester) async {
      final manager = await _pumpGate(tester);
      final suppression = _container(tester).read(adSuppressionProvider);

      await suppression.during(() async {});
      await _backgroundAndResume(tester);
      expect(manager.showCalls, 0);

      _advance(const Duration(seconds: 3));
      await _backgroundAndResume(tester);
      expect(manager.showCalls, 1);
    });
  });
}
