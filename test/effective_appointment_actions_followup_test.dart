import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/data/effective_appointment_actions.dart';
import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/providers/appointment_provider.dart';

// Consumer로 WidgetRef를 꺼내 쓰는 패턴 — firebase_auth 없이 로컬(게스트)
// 저장소 경로를 직접 검증한다(logout_ref_disposal_test.dart와 같은
// 패턴). 이 확인 흐름은 로그인 사용자에게만 노출되지만, markFollowUp
// 자체의 분기 로직(계정/로컬)은 petId 접두사만으로 갈리므로 로컬 경로를
// 이렇게 직접 테스트할 수 있다.
void main() {
  testWidgets('markFollowUp(recorded) — 로컬 저장소의 그 예약만 recorded로 바뀌고 나머지는 그대로다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            capturedRef = ref;
            return const SizedBox();
          }),
        ),
      ),
    );
    await tester.pump();

    final target = Appointment(id: 'a1', petId: 'local1', dateTime: DateTime(2026, 1, 1), hospitalName: '가온동물병원');
    final other = Appointment(id: 'a2', petId: 'local1', dateTime: DateTime(2026, 2, 1), hospitalName: '다른병원');
    await capturedRef.read(appointmentsProvider.notifier).upsert(target);
    await capturedRef.read(appointmentsProvider.notifier).upsert(other);

    await EffectiveAppointmentActions.markFollowUp(capturedRef, target, AppointmentFollowUp.recorded);

    final stored = capturedRef.read(appointmentsProvider).value!;
    expect(stored.firstWhere((a) => a.id == 'a1').followUp, AppointmentFollowUp.recorded);
    expect(stored.firstWhere((a) => a.id == 'a2').followUp, isNull);
  });

  testWidgets('markFollowUp(skipped) — skipped로 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            capturedRef = ref;
            return const SizedBox();
          }),
        ),
      ),
    );
    await tester.pump();

    final target = Appointment(id: 'a1', petId: 'local1', dateTime: DateTime(2026, 1, 1), hospitalName: '가온동물병원');
    await capturedRef.read(appointmentsProvider.notifier).upsert(target);

    await EffectiveAppointmentActions.markFollowUp(capturedRef, target, AppointmentFollowUp.skipped);

    final stored = capturedRef.read(appointmentsProvider).value!;
    expect(stored.single.followUp, AppointmentFollowUp.skipped);
  });
}
