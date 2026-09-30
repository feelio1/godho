import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/providers/appointment_provider.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/providers/effective_appointments_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'effectiveAppointmentsForPetProvider — 게스트(로컬) 반려동물이면 기존 '
    'appointmentsForPetProvider를 그대로 반영한다("진료기록·예약 Firestore 저장" 지시서 '
    'B-2). 계정 쪽 스트림 자체는 user_repository_test.dart가 fake_cloud_firestore로 '
    '직접 검증한다(실제 User 인스턴스를 이 환경에서 만들 수 없는 제약은 이전 단계와 동일).',
    () {
      test('로컬 반려동물 id면 appointmentsForPetProvider와 같은 값을 낸다(이른 순 정렬 포함)', () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        );
        addTearDown(container.dispose);

        final notifier = container.read(appointmentsProvider.notifier);
        await notifier.upsert(
          Appointment(id: 'a-far', petId: 'local-1', dateTime: DateTime.now().add(const Duration(days: 10)), hospitalName: '병원A'),
        );
        await notifier.upsert(
          Appointment(id: 'a-near', petId: 'local-1', dateTime: DateTime.now().add(const Duration(days: 1)), hospitalName: '병원B'),
        );

        // .autoDispose 프로바이더라(리스너 최소화 — 지시서 B-4)
        // container.read(...future)만 하면 값이 나오기 전에 dispose될 수
        // 있어, 짧게 구독을 하나 잡아둔다(실제 화면은 위젯의 ref.watch가
        // 이 역할을 한다).
        final sub = container.listen(effectiveAppointmentsForPetProvider('local-1'), (previous, next) {});
        final appointments = await container.read(effectiveAppointmentsForPetProvider('local-1').future);
        sub.close();

        expect(appointments.map((a) => a.id).toList(), ['a-near', 'a-far']);
      });

      test('로그아웃 상태(uid 없음)에서 계정(account:) petId를 조회하면 빈 목록이다', () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [authStateProvider.overrideWith((ref) => Stream<User?>.value(null))],
        );
        addTearDown(container.dispose);

        final sub = container.listen(effectiveAppointmentsForPetProvider('account:doc-1'), (previous, next) {});
        final appointments = await container.read(effectiveAppointmentsForPetProvider('account:doc-1').future);
        sub.close();

        expect(appointments, isEmpty);
      });
    },
  );
}
