import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/models/medical_record.dart';
import 'package:petcliniccheck/models/reminder_offset.dart';

void main() {
  group('MedicalRecord.toFirestore/fromFirestore — "진료기록·예약 Firestore 저장" 지시서 B-1', () {
    test('필수·선택 필드가 왕복 후 그대로 보존된다(사진 경로 제외)', () {
      final record = MedicalRecord(
        id: 'r1',
        petId: 'p1',
        date: DateTime(2024, 6, 10),
        hospitalId: 'h1',
        hospitalName: '행복동물병원',
        memo: '슬개골 검진',
        weightKg: 4.2,
        costWon: 35000,
        photoPath: '/local/only/receipt.jpg',
      );

      final data = record.toFirestore();
      final restored = MedicalRecord.fromFirestore('p1', 'r1', data);

      expect(restored.id, 'r1');
      expect(restored.petId, 'p1');
      expect(restored.date, DateTime(2024, 6, 10));
      expect(restored.hospitalId, 'h1');
      expect(restored.hospitalName, '행복동물병원');
      expect(restored.memo, '슬개골 검진');
      expect(restored.weightKg, 4.2);
      expect(restored.costWon, 35000);
      // 로컬 파일 경로는 다른 기기에서 의미가 없어 클라우드에 올리지 않는다.
      expect(data.containsKey('photoPath'), isFalse);
      expect(restored.photoPath, isNull);
    });

    test('선택 필드가 비어 있어도 정상 왕복된다', () {
      final record = MedicalRecord(id: 'r2', petId: 'p1', date: DateTime(2025, 1, 1), hospitalName: '병원');
      final restored = MedicalRecord.fromFirestore('p1', 'r2', record.toFirestore());

      expect(restored.hospitalId, isNull);
      expect(restored.memo, '');
      expect(restored.weightKg, isNull);
      expect(restored.costWon, isNull);
    });

    test('toFirestore는 createdAt을 포함하고, toFirestoreUpdate는 그 키를 뺀다(수정 시 생성일 보존)', () {
      final record = MedicalRecord(id: 'r3', petId: 'p1', date: DateTime(2025, 1, 1), hospitalName: '병원');

      expect(record.toFirestore().containsKey('createdAt'), isTrue);
      final update = record.toFirestoreUpdate();
      expect(update.containsKey('createdAt'), isFalse);
      expect(update['hospitalName'], '병원');
    });
  });

  group('Appointment.toFirestore/fromFirestore', () {
    test('reminders를 포함한 모든 필드가 왕복 후 그대로 보존된다', () {
      final appointment = Appointment(
        id: 'a1',
        petId: 'p1',
        dateTime: DateTime(2026, 3, 5, 14, 30),
        hospitalId: 'h1',
        hospitalName: '행복동물병원',
        reason: '예방접종',
        memo: '공복 필요',
        reminders: const [ReminderOffset(daysBefore: 1, hour: 9, minute: 0)],
      );

      final data = appointment.toFirestore();
      final restored = Appointment.fromFirestore('p1', 'a1', data);

      expect(restored.dateTime, DateTime(2026, 3, 5, 14, 30));
      expect(restored.hospitalId, 'h1');
      expect(restored.hospitalName, '행복동물병원');
      expect(restored.reason, '예방접종');
      expect(restored.memo, '공복 필요');
      expect(restored.reminders, [const ReminderOffset(daysBefore: 1, hour: 9, minute: 0)]);
    });

    test('선택 필드가 비어 있어도(미리 알림 없음) 정상 왕복된다', () {
      final appointment = Appointment(id: 'a2', petId: 'p1', dateTime: DateTime(2026, 1, 1), hospitalName: '병원');
      final restored = Appointment.fromFirestore('p1', 'a2', appointment.toFirestore());

      expect(restored.reminders, isEmpty);
      expect(restored.reason, '');
    });

    test('toFirestoreUpdate는 createdAt을 뺀다', () {
      final appointment = Appointment(id: 'a3', petId: 'p1', dateTime: DateTime(2026, 1, 1), hospitalName: '병원');
      expect(appointment.toFirestore().containsKey('createdAt'), isTrue);
      expect(appointment.toFirestoreUpdate().containsKey('createdAt'), isFalse);
    });
  });

  group('Appointment.followUp — "지난 예약 확인" 지시서 2', () {
    test('followUp 필드가 없는(기존) Firestore 문서는 null로 읽힌다(하위호환)', () {
      final legacyData = {
        'dateTime': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'hospitalName': '병원',
      };
      final restored = Appointment.fromFirestore('p1', 'a4', legacyData);
      expect(restored.followUp, isNull);
    });

    test('followUp 필드가 없는(기존) 로컬 JSON도 null로 읽힌다(하위호환)', () {
      final legacyJson = {
        'id': 'a5',
        'petId': 'p1',
        'dateTime': DateTime(2026, 1, 1).toIso8601String(),
        'hospitalName': '병원',
      };
      final restored = Appointment.fromJson(legacyJson);
      expect(restored.followUp, isNull);
    });

    test('recorded/skipped 모두 Firestore·로컬 JSON 왕복 후 그대로 보존된다', () {
      for (final status in AppointmentFollowUp.values) {
        final appointment = Appointment(
          id: 'a6',
          petId: 'p1',
          dateTime: DateTime(2026, 1, 1),
          hospitalName: '병원',
          followUp: status,
        );
        expect(
          Appointment.fromFirestore('p1', 'a6', appointment.toFirestore()).followUp,
          status,
        );
        expect(Appointment.fromJson(appointment.toJson()).followUp, status);
      }
    });

    test('copyWith으로 followUp만 바꿔도 다른 필드는 그대로다', () {
      final appointment = Appointment(
        id: 'a7',
        petId: 'p1',
        dateTime: DateTime(2026, 1, 1),
        hospitalName: '병원',
        reason: '예방접종',
      );
      final updated = appointment.copyWith(followUp: AppointmentFollowUp.recorded);
      expect(updated.followUp, AppointmentFollowUp.recorded);
      expect(updated.reason, '예방접종');
      expect(updated.id, appointment.id);
    });
  });
}
