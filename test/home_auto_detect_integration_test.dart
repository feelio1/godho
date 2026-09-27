import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/providers/bundle_provider.dart';
import 'package:petcliniccheck/providers/fee_provider.dart';
import 'package:petcliniccheck/providers/region_auto_detect.dart';
import 'package:petcliniccheck/providers/region_provider.dart';
import 'package:petcliniccheck/widgets/fee_summary_card.dart';

// main_shell.dart의 ref.listen(locationProvider, ...)이 실제로 호출하는
// 함수(applyDetectedRegionFromPosition)를 직접 호출해, 이전 스프린트
// 테스트(fee_summary_card_test.dart)가 지나쳤던 구간 — detectNormalizedRegion
// (REST/오프라인 폴백 + normalizeRegion) — 까지 전부 거쳐 실제로 홈 카드가
// 갱신되는지 확인한다. 이전 테스트는 regionProvider.applyGpsRegionIfUnset을
// 직접 호출해 이 구간을 건너뛰었다 — 릴리스 빌드에서 재현된 버그가 이
// 구간에 있는지 가려내기 위한 엔드투엔드 테스트다.
Position _fakePosition(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'applyDetectedRegionFromPosition(main_shell.dart이 실제로 호출하는 함수)을 '
    '검단구 병원 좌표로 호출하면 — detectNormalizedRegion의 오프라인 폴백까지 '
    '전부 거쳐 regionProvider가 갱신되고, 홈 카드가 "지역을 선택하면..."에서 '
    '검단구의 "아직 없음"(신설 안내) 카드로 전환된다',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const FeeSummaryCard();
                },
              ),
            ),
          ),
        ),
      );

      // hospitals.json/fees.json 실제 asset I/O + regionProvider의
      // SharedPreferences 읽기까지 전부 정착시켜야 한다 — FeeSummaryCard가
      // regionProvider도 watch하므로 build()가 이미 시작은 됐지만, 이
      // 완료를 기다리지 않고 넘어가면(과거엔 bundle/fee만 기다렸다)
      // applyGpsRegionIfUnset의 `await future`가 멈춰 있는 채로 나머지
      // 코드를 진행하게 되어 실제로는 일어나지 않을 "무한 대기"처럼
      // 보이는 테스트 아티팩트가 생긴다 — regionProvider.future도 명시
      // 적으로 기다려 그 함정을 피한다. 여러 개의 실제 asset/plugin
      // I/O를 하나의 runAsync 안에서 Future.wait로 동시에 기다리면(발견:
      // fee_summary_card_test.dart 분리 사례와 별개로) 테스트 환경에서
      // 먹통이 되는 경우가 있어, 한 번에 하나씩 순서대로 기다린다.
      await tester.runAsync(() => capturedRef.read(bundleProvider.future));
      await tester.runAsync(() => capturedRef.read(feeBundleProvider.future));
      await tester.runAsync(() => capturedRef.read(regionProvider.future));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('지역을 선택하면'), findsOneWidget);

      // 검단구 소재 병원의 실제 좌표(assets/hospitals.json) — REST 키 없는
      // 테스트 환경에서는 오프라인 폴백(최단거리 병원)이 이 좌표로 정확히
      // "인천 검단구"를 판정해야 한다.
      //
      // 여기서는 runAsync로 감싸지 않는다 — REST는 건너뛰고 병원 최단거리
      // 조회는 메모리 내 동기 연산이라 진짜 실(real) I/O가 없고,
      // regionProvider.future도 위에서 이미 정착시켜 놨다. runAsync로 감싸면
      // FakeAsync 테스트 존을 벗어난 채로 그 존에 묶인 completer(future
      // getter)를 기다리게 돼 test/production 어느 쪽 버그도 아닌 순수
      // 데드락이 생긴다는 걸 실측으로 확인했다 — pump()가 마이크로태스크를
      // 처리해줘야 하는데 runAsync 콜백이 끝나기 전엔 pump()를 부를 수
      // 없어서 서로를 막는다.
      await applyDetectedRegionFromPosition(
        capturedRef,
        _fakePosition(37.5947337315248, 126.713749299963),
      );
      await tester.pump();
      await tester.pump();

      // 지역은 감지·반영됐으니 "지역을 선택하면..."에 더는 머물지 않는다.
      expect(find.textContaining('지역을 선택하면'), findsNothing);
      // 검단구는 fees.json에 없으므로 대체값이 아니라 신설 구 안내가 떠야
      // 하고, 다른 구 시세("중간값")를 보여줘선 안 된다.
      expect(find.textContaining('중간값'), findsNothing);
      // 헤딩("검단구 진료비 시세")과 부제 둘 다 "검단구"를 포함하므로
      // findsWidgets(2개)로 존재만 확인하고, 신설 구 전용 이유 문구
      // (2026년 7월)가 정확히 그 부제에 있는지로 구체적으로 검증한다.
      expect(find.textContaining('검단구'), findsWidgets);
      expect(find.textContaining('2026년 7월'), findsOneWidget);
    },
  );
}
