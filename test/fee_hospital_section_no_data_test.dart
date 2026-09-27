import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/widgets/fee_hospital_section.dart';

import 'fee_hospital_section_test.dart' show hospitalForFeeTest;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fees.json에 아예 없는 구(검단구, 신설 구)는 다른 구 값으로 대체하지 않고 '
    '신설 구 안내로 안전하게 보여준다 — 홈 카드·화면21과 같은 문구',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FeeHospitalSection(hospital: hospitalForFeeTest(sigungu: '검단구')),
            ),
          ),
        ),
      );

      // fee_hospital_section_test.dart의 설명과 같은 이유로 특정 Future를
      // 집어 기다리지 않고 실제 시간을 흘려보낸다.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('2026년 7월'), findsOneWidget);
      // 다른 구 시세("중간 ...원")를 대신 보여주지 않는다.
      expect(find.textContaining('중간'), findsNothing);
    },
  );
}
