import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/models/region_filter.dart';
import 'package:petcliniccheck/providers/region_provider.dart';
import 'package:petcliniccheck/widgets/fee_summary_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '핀(수동 선택) 없이 위치 자동 감지만으로 regionProvider가 채워지면 홈 카드가 '
    '"지역을 선택하면..."에 머물지 않고 그 지역 시세 카드로 전환된다 '
    '(홈 자동 시세 표시 지시서 변경 1)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: FeeSummaryCard())),
        ),
      );

      // region/fee 번들 모두 실제 asset I/O(SharedPreferences, fees.json)를
      // 거치므로 FakeAsync가 아닌 실제 존을 통해 정착시켜야 한다.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump();

      // 지역이 아직 없으므로 "지역을 선택하면..." 문구가 보여야 한다.
      expect(find.textContaining('지역을 선택하면'), findsOneWidget);
      expect(find.textContaining('중간값'), findsNothing);

      final element = tester.element(find.byType(FeeSummaryCard));
      final container = ProviderScope.containerOf(element);

      // 수동 선택(핀) 없이, 위치 자동 감지가 성공한 것과 동일한 경로로
      // applyGpsRegionIfUnset만 호출한다 — fees.json에 데이터가 있는 구
      // (인천 서구)를 써서 정상 시세 전환까지 확인한다.
      await container.read(regionProvider.notifier).applyGpsRegionIfUnset(
            const RegionFilter(sido: '인천', sigungu: '서구'),
          );

      await tester.pump();
      await tester.pump();

      // "지역을 선택하면..."에 더 이상 머물지 않고, 실제 시세 카드
      // (_WithData만 쓰는 "중간값" 표기)가 렌더링돼야 한다.
      expect(find.textContaining('지역을 선택하면'), findsNothing);
      expect(find.textContaining('중간값'), findsOneWidget);
      expect(find.textContaining('서구'), findsOneWidget);
    },
  );
}
