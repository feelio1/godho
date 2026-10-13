import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/models/medical_record.dart';
import 'package:petcliniccheck/providers/bundle_provider.dart';
import 'package:petcliniccheck/screens/appointment_form_screen.dart';
import 'package:petcliniccheck/screens/medical_record_form_screen.dart';
import 'package:petcliniccheck/utils/record_appointment_flow.dart';

// record_appointment_switch_test.dart와 같은 이유(real-asset 로딩)로
// 이 파일에도 테스트를 하나만 둔다. 기존 기록/예약을 수정할 때는 종류를
// 바꿀 수 없다는 "진료기록·예약 통합 입력" 지시서 4를 두 폼 모두에서
// 함께 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('기존 기록·예약을 수정할 때는 두 폼 모두 [진료기록|예약] 세그먼트가 보이지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(bundleProvider.future));

    final existingRecord = MedicalRecord(
      id: 'r1',
      petId: 'local1',
      date: DateTime(2026, 1, 5),
      hospitalName: '가온동물병원',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MedicalRecordFormScreen(petId: 'local1', existing: existingRecord),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<RecordOrAppointmentKind>), findsNothing);
    expect(find.text('진료 기록 수정'), findsOneWidget);

    final existingAppointment = Appointment(
      id: 'a1',
      petId: 'local1',
      dateTime: DateTime(2027, 1, 5, 10, 0),
      hospitalName: '가온동물병원',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppointmentFormScreen(petId: 'local1', existing: existingAppointment),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<RecordOrAppointmentKind>), findsNothing);
    expect(find.text('예약 알림'), findsOneWidget);
  });
}
