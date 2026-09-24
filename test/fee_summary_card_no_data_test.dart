import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/models/region_filter.dart';
import 'package:petcliniccheck/providers/region_provider.dart';
import 'package:petcliniccheck/widgets/fee_summary_card.dart';

// 진짜 asset I/O(rootBundle.loadString)를 거치는 위젯 테스트를 다른
// fee_summary_card_test.dart와 같은 파일에 함께 두면, 같은 파일 내
// 두 번째 real-asset 로드가 절대 끝나지 않는(rootBundle 캐시/존 상호작용
// 추정) 현상이 재현된다 — `flutter test`는 파일 단위로 별도 isolate를
// 쓰므로, 이 시나리오를 별도 파일로 분리해 그 문제를 피한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fees.json에 없는 구(신설 구, 검단구)로 지역이 설정되면 다른 구 값으로 대체하지 '
    '않고 "아직 없음" 안내를 보여준다 — "지역을 선택하면..."(미설정 문구)이 아니다 '
    '(홈 자동 시세 표시 지시서 변경 2)',
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
            const RegionFilter(sido: '인천', sigungu: '검단구'),
          );

      await tester.pump();
      await tester.pump();

      // 지역은 설정됐으므로 "지역을 선택하면..."이 아니어야 하고, 다른 구
      // 값을 빌려오지 않았으므로 "중간값"(실제 시세) 표기도 없어야 한다.
      expect(find.textContaining('지역을 선택하면'), findsNothing);
      expect(find.textContaining('중간값'), findsNothing);
      // 신설 구 전용 이유 문구(2026년 7월)가 그대로 노출돼야 한다.
      expect(find.textContaining('2026년 7월'), findsOneWidget);
    },
  );
}
