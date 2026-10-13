import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/models/region_filter.dart';
import 'package:petcliniccheck/providers/region_provider.dart';
import 'package:petcliniccheck/widgets/fee_summary_card.dart';

// fee_summary_card_no_data_test.dart와 같은 이유로 별도 파일로 둔다 — 같은
// 파일 안에서 real-asset I/O(rootBundle.loadString)를 거치는 위젯 테스트를
// 두 번째로 실행하면 절대 끝나지 않는 현상이 재현된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '후보 항목 5개 모두 데이터가 있는 지역(인천 서구)에서는 최대 4개까지만 '
    '보여주고, 5번째 후보(혈액검사)는 생략한다("출시 전 마무리" 지시서 A-2)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: FeeSummaryCard())),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump();

      final element = tester.element(find.byType(FeeSummaryCard));
      final container = ProviderScope.containerOf(element);
      await container.read(regionProvider.notifier).applyGpsRegionIfUnset(
            const RegionFilter(sido: '인천', sigungu: '서구'),
          );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('초진 진찰료'), findsOneWidget);
      expect(find.textContaining('종합백신 접종비 개'), findsOneWidget);
      expect(find.textContaining('광견병백신 접종비'), findsOneWidget);
      expect(find.textContaining('재진 진찰료'), findsOneWidget);
      // 5번째 후보(혈액검사·CBC)도 데이터는 있지만 4개를 넘겨서 생략된다.
      expect(find.textContaining('전혈구 검사비와 판독료'), findsNothing);
    },
  );
}
