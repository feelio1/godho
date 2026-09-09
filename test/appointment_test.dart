import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/data/local_store.dart';
import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/models/reminder_offset.dart';
import 'package:petcliniccheck/providers/appointment_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderOffset', () {
    test('fireTimeFor는 예약 시각 기준 며칠 전 지정한 시·분으로 계산된다', () {
      const reminder = ReminderOffset(daysBefore: 1, hour: 20, minute: 30);
      final appointmentDateTime = DateTime(2024, 6, 10, 14, 0);
      final fireAt = reminder.fireTimeFor(appointmentDateTime);
      expect(fireAt, DateTime(2024, 6, 9, 20, 30));
    });

    test('daysBefore가 0이면 예약 당일 지정한 시·분으로 계산된다', () {
      const reminder = ReminderOffset(daysBefore: 0, hour: 9, minute: 0);
      final appointmentDateTime = DateTime(2024, 6, 10, 14, 0);
      expect(reminder.fireTimeFor(appointmentDateTime), DateTime(2024, 6, 10, 9, 0));
    });

    test('label은 당일과 며칠 전을 구분해 표시한다', () {
      expect(const ReminderOffset(daysBefore: 0, hour: 9, minute: 0).label, '당일 09:00');
      expect(const ReminderOffset(daysBefore: 1, hour: 20, minute: 0).label, '1일 전 20:00');
    });

    test('JSON 직렬화 라운드트립', () {
      const reminder = ReminderOffset(daysBefore: 3, hour: 8, minute: 15);
      final restored =
          ReminderOffset.fromJson(jsonDecode(jsonEncode(reminder.toJson())) as Map<String, dynamic>);
      expect(restored, reminder);
    });
  });

  group('Appointment', () {
    test('isUpcoming은 예약 시각이 미래일 때만 true다', () {
      final future = Appointment(
        id: 'a1',
        petId: 'p1',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        hospitalName: '병원A',
      );
      final past = Appointment(
        id: 'a2',
        petId: 'p1',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        hospitalName: '병원B',
      );
      expect(future.isUpcoming, isTrue);
      expect(past.isUpcoming, isFalse);
    });

    test('JSON 직렬화는 알림 목록을 포함해 그대로 보존된다 (Firebase 이관 대비)', () {
      final appointment = Appointment(
        id: 'a1',
        petId: 'p1',
        dateTime: DateTime(2024, 12, 25, 10, 0),
        hospitalId: 'h1',
        hospitalName: '동물병원',
        reason: '중성화',
        memo: '아침 금식',
        reminders: const [
          ReminderOffset(daysBefore: 1, hour: 20, minute: 0),
          ReminderOffset(daysBefore: 0, hour: 9, minute: 0),
        ],
      );
      final restored =
          Appointment.fromJson(jsonDecode(jsonEncode(appointment.toJson())) as Map<String, dynamic>);

      expect(restored.id, appointment.id);
      expect(restored.dateTime, appointment.dateTime);
      expect(restored.hospitalId, appointment.hospitalId);
      expect(restored.reason, appointment.reason);
      expect(restored.reminders, appointment.reminders);
    });

    test('알림이 없는 예약도 정상적으로 직렬화된다', () {
      final appointment = Appointment(
        id: 'a2',
        petId: 'p1',
        dateTime: DateTime(2024, 1, 1),
        hospitalName: '직접 입력한 병원',
      );
      final restored =
          Appointment.fromJson(jsonDecode(jsonEncode(appointment.toJson())) as Map<String, dynamic>);
      expect(restored.reminders, isEmpty);
      expect(restored.hospitalId, isNull);
    });
  });

  group('LocalStore — 예약(스프린트 9)', () {
    test('예약 목록이 기기에 저장되고 그대로 복원된다', () async {
      SharedPreferences.setMockInitialValues({});
      const store = LocalStore();
      final appointment = Appointment(
        id: 'a1',
        petId: 'p1',
        dateTime: DateTime(2024, 6, 1, 10, 0),
        hospitalName: '동물병원',
        reminders: const [ReminderOffset(daysBefore: 1, hour: 20, minute: 0)],
      );

      await store.saveAppointments([appointment]);
      final restored = await store.loadAppointments();

      expect(restored, hasLength(1));
      expect(restored.single.hospitalName, '동물병원');
      expect(restored.single.reminders, hasLength(1));
    });
  });

  group('AppointmentsNotifier', () {
    test(
      'upsert/remove는 알림 스케줄링(플랫폼 채널 없음)이 실패해도 예외 없이 상태를 갱신한다 '
      '— 스프린트 9 지시서 "알림 권한 거부/실패해도 앱 정상 동작"',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container.read(appointmentsProvider.future);
        final notifier = container.read(appointmentsProvider.notifier);

        final appointment = Appointment(
          id: 'a1',
          petId: 'p1',
          dateTime: DateTime.now().add(const Duration(days: 2)),
          hospitalName: '동물병원',
          reminders: const [
            ReminderOffset(daysBefore: 1, hour: 9, minute: 0),
            ReminderOffset(daysBefore: 0, hour: 9, minute: 0),
          ],
        );

        // 테스트 환경에는 flutter_local_notifications의 플랫폼 채널이 없어
        // 알림 예약은 내부적으로 조용히 실패한다 — 그래도 이 호출 자체는
        // 예외를 던지지 않고 정상 완료되어야 한다.
        await notifier.upsert(appointment);
        expect(container.read(appointmentsProvider).value, hasLength(1));

        await notifier.remove('a1');
        expect(container.read(appointmentsProvider).value, isEmpty);
      },
    );

    test('upcomingAppointmentsForPetProvider는 다가오는 예약만 이른 순으로 반환한다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(appointmentsProvider.future);
      final notifier = container.read(appointmentsProvider.notifier);

      await notifier.upsert(Appointment(
        id: 'future-far',
        petId: 'p1',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        hospitalName: '병원A',
      ));
      await notifier.upsert(Appointment(
        id: 'future-near',
        petId: 'p1',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        hospitalName: '병원B',
      ));
      await notifier.upsert(Appointment(
        id: 'past',
        petId: 'p1',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        hospitalName: '병원C',
      ));
      await notifier.upsert(Appointment(
        id: 'other-pet',
        petId: 'p2',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        hospitalName: '병원D',
      ));

      final upcoming = container.read(upcomingAppointmentsForPetProvider('p1'));
      expect(upcoming.map((a) => a.id).toList(), ['future-near', 'future-far']);
    });
  });
}
