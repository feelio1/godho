import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/main.dart';

void main() {
  testWidgets('App boots and shows the home tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PetClinicCheckApp()),
    );

    // The bundle load is real asset I/O, which FakeAsync's pump() doesn't
    // drive — hop out to the real zone so it can actually complete.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump();

    expect(find.text('펫병원체크'), findsOneWidget);
    expect(find.text('지도에서 보기'), findsOneWidget);

    // 스프린트 13 지시서 2 — 홈이 병원 리스트 섹션으로 세로로 채워지는지
    // (전국 데이터 기준으로는 항상 데이터가 있어야 하는 섹션들만 확인).
    // 아래쪽 섹션은 초기 뷰포트 밖이라 스크롤해서 실제로 빌드되게 한다.
    expect(find.text('내 주변 가까운 병원'), findsOneWidget);
    expect(find.text('전체 병원 보기'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('운영 20년 이상 병원'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('운영 20년 이상 병원'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('최근 개원한 병원'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('최근 개원한 병원'), findsOneWidget);
  });
}
