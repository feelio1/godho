import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/hospital.dart';
import 'package:petcliniccheck/models/hospital_status.dart';
import 'package:petcliniccheck/widgets/fee_hospital_section.dart';

Hospital hospitalForFeeTest({required String sigungu, HospitalStatus status = HospitalStatus.open}) {
  return Hospital(
    id: 'h-$sigungu',
    name: '테스트동물병원',
    status: status,
    sido: '인천',
    sigungu: sigungu,
    roadAddr: '인천 $sigungu 어딘가',
    jibunAddr: '인천 $sigungu 어딘가',
  );
}

// 실제 asset I/O(fees.json)를 거치는 위젯 테스트를 다른 위젯 테스트와
// 같은 파일에 두면 두 번째 real-asset 로드가 먹통되는 현상이 재현된다
// (이전 스프린트에서 확인·해결한 것과 같은 원인 — flutter test는 파일
// 단위로 별도 isolate를 쓰므로 시나리오를 파일로 분리해 피한다). 검단구
// (데이터 없음) 케이스는 fee_hospital_section_no_data_test.dart에 있다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fees.json에 데이터가 있는 구(서구)는 중간값과 범위를 함께 보여준다 — 평균 아님(제품 헌법)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FeeHospitalSection(hospital: hospitalForFeeTest(sigungu: '서구')),
            ),
          ),
        ),
      );

      // FeeHospitalSection이 build() 안에서 곧바로 feeBundleProvider를
      // watch하므로, 그 provider의 Future는 pumpWidget 시점(FakeAsync 존)에
      // 이미 만들어진다. 이 특정 Future를 capturedRef.read(...).future로
      // 콕 집어 runAsync(REAL 존) 안에서 기다리면 FakeAsync 존에 묶인
      // Future를 REAL 존에서 건너서 기다리는 셈이 되어 데드락난다(이번
      // 세션에서 위치 자동감지 테스트 조사 때 확인한 것과 같은 메커니즘 —
      // pump()가 마이크로태스크를 처리해줘야 풀리는데 pump()는 runAsync
      // 콜백이 끝나야 부를 수 있다). 특정 Future를 집어 기다리지 않고,
      // 실제 시간을 흘려보내 실(real) I/O가 자연히 끝나게 한다(widget_test.
      // dart/fee_summary_card_test.dart와 같은 패턴).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('이 지역 진료비 시세'), findsOneWidget);
      expect(find.textContaining('서구'), findsWidgets);
      expect(find.textContaining('중간'), findsWidgets);
      expect(find.textContaining('범위'), findsWidgets);
      // "평균"이라는 표현은 절대 쓰지 않는다(중간값만 대표값).
      expect(find.textContaining('평균'), findsNothing);
    },
  );
}
