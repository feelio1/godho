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
    expect(find.text('내 주변 병원'), findsOneWidget);
  });
}
