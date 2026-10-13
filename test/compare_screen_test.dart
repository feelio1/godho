import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geolocator/geolocator.dart';
import 'package:petcliniccheck/providers/bundle_provider.dart';
import 'package:petcliniccheck/providers/compare_provider.dart';
import 'package:petcliniccheck/providers/location_provider.dart';
import 'package:petcliniccheck/screens/compare_screen.dart';
import 'package:petcliniccheck/widgets/mascot_message.dart';

// 테스트 환경엔 Geolocator 네이티브 플랫폼 채널이 없어, 실제
// locationProvider를 그대로 두면 내부적으로 재시도 타이머가 걸려
// "타이머가 남아있다" 실패로 이어진다 — "거리" 행 자체의 동작(위치
// 있으면 km, 없으면 "확인 불가")과는 무관한 플러그인 부재 문제라 위치를
// null로 고정해 우회한다.
class _NullLocationNotifier extends LocationNotifier {
  @override
  Future<Position?> build() async => null;
}

// hospitals.json(실제 asset) 로딩이 필요해 이 파일에는 테스트 하나만
// 둔다 — 같은 파일 안에서 두 번째 real-asset 로드를 하면 끝나지 않는
// 현상이 재현된다는 점이 fee_summary_card_no_data_test.dart 등 여러
// 테스트에서 이미 확인됐다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('비교 목록이 비어 있으면 안내 문구만 보이고(0개), 2곳을 담으면 거리·지역 시세 행과 '
      '"병원별 가격 아님" 고지가 함께 보인다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        locationProvider.overrideWith(_NullLocationNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CompareScreen()),
      ),
    );

    // 0개 상태 — 비교 담기 안내만 보인다.
    expect(find.byType(MascotMessage), findsOneWidget);
    expect(find.text('거리'), findsNothing);

    // 실제 번들을 기다렸다가, 인천 부평구(기준일 시점 fees.json/
    // hospitals.json 양쪽에 모두 있는 구)의 병원 2곳을 비교 목록에 담는다
    // — 같은 구라 "지역 시세" 값이 같게 보이는 것이 의도된 동작이다.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    final bundle = await container.read(bundleProvider.future);
    final bupyeongHospitals = bundle.hospitals
        .where((h) => h.sido == '인천' && h.sigungu == '부평구' && h.hasCoordinates)
        .take(2)
        .toList();
    expect(bupyeongHospitals, hasLength(2));

    container.read(compareListProvider.notifier).add(bupyeongHospitals[0].id);
    container.read(compareListProvider.notifier).add(bupyeongHospitals[1].id);
    await tester.pump();
    await tester.pump();

    expect(find.byType(MascotMessage), findsNothing);
    expect(find.text('거리'), findsOneWidget);
    expect(find.text('지역 시세'), findsOneWidget);
    expect(find.textContaining('지역(구) 시세'), findsOneWidget);
    expect(find.textContaining('병원별 가격 아님'), findsOneWidget);
    // 같은 구 시세라 두 칸 모두 같은 값("중간 ...")으로 표시된다.
    expect(find.textContaining('중간 '), findsNWidgets(2));
  });
}
