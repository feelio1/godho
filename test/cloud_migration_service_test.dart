import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/data/cloud_migration_service.dart';
import 'package:petcliniccheck/data/local_store.dart';
import 'package:petcliniccheck/data/user_repository.dart';
import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/models/medical_record.dart';
import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/models/signup_pet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late UserRepository userRepo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    userRepo = UserRepository(firestore: firestore);
  });

  group('CloudMigrationService — "진료기록·예약 Firestore 저장" 지시서 B-3(비파괴 1회 이관)', () {
    test('이름·종류가 일치하는 반려동물의 로컬 기록·예약을 계정으로 복사한다(원본은 그대로 남음)', () async {
      SharedPreferences.setMockInitialValues({
        'pets_json_v1': jsonEncode([
          const Pet(id: 'local-1', name: '보리', species: PetSpecies.dog).toJson(),
        ]),
        'medical_records_json_v1': jsonEncode([
          MedicalRecord(id: 'r1', petId: 'local-1', date: DateTime(2024, 1, 1), hospitalName: '병원A').toJson(),
        ]),
        'appointments_json_v1': jsonEncode([
          Appointment(id: 'a1', petId: 'local-1', dateTime: DateTime(2026, 1, 1), hospitalName: '병원B').toJson(),
        ]),
      });

      await firestore.collection('users').doc('uid-1').set({'loginType': 'google'});
      final docId = await userRepo.addPet(
        'uid-1',
        const SignupPet(species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01', name: '보리'),
      );

      final service = CloudMigrationService(userRepository: userRepo);
      final result = await service.migrateIfNeeded('uid-1');

      expect(result, isNotNull);
      expect(result!.migratedPetNames, ['보리']);
      expect(result.skippedPetNames, isEmpty);

      final cloudRecords = await userRepo.fetchRecords('uid-1', docId);
      expect(cloudRecords, hasLength(1));
      expect(cloudRecords.single.hospitalName, '병원A');

      final cloudAppointments = await userRepo.fetchAppointments('uid-1', docId);
      expect(cloudAppointments, hasLength(1));
      expect(cloudAppointments.single.hospitalName, '병원B');

      // 원본 로컬 데이터는 지우거나 바꾸지 않는다 — 비파괴 이관.
      const localStore = LocalStore();
      final localPetsAfter = await localStore.loadPets();
      final localRecordsAfter = await localStore.loadMedicalRecords();
      expect(localPetsAfter, hasLength(1));
      expect(localRecordsAfter, hasLength(1));
    });

    test('계정당 1회만 시도 — 두 번째 호출은 아무 일도 하지 않는다(플래그)', () async {
      SharedPreferences.setMockInitialValues({
        'pets_json_v1': jsonEncode([const Pet(id: 'local-1', name: '보리', species: PetSpecies.dog).toJson()]),
        'medical_records_json_v1': jsonEncode([
          MedicalRecord(id: 'r1', petId: 'local-1', date: DateTime(2024, 1, 1), hospitalName: '병원A').toJson(),
        ]),
      });
      await firestore.collection('users').doc('uid-2').set({'loginType': 'google'});
      final docId = await userRepo.addPet(
        'uid-2',
        const SignupPet(species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01', name: '보리'),
      );

      final service = CloudMigrationService(userRepository: userRepo);
      final first = await service.migrateIfNeeded('uid-2');
      expect(first, isNotNull);

      final second = await service.migrateIfNeeded('uid-2');
      expect(second, isNull);

      // 중복 복사되지 않았는지 확인 — 여전히 1건.
      final cloudRecords = await userRepo.fetchRecords('uid-2', docId);
      expect(cloudRecords, hasLength(1));
    });

    test('로컬 반려동물이 없으면 스킵하고 플래그만 세운다', () async {
      SharedPreferences.setMockInitialValues({});
      await firestore.collection('users').doc('uid-3').set({'loginType': 'google'});

      final service = CloudMigrationService(userRepository: userRepo);
      final result = await service.migrateIfNeeded('uid-3');

      expect(result, isNull);
      expect(await service.migrateIfNeeded('uid-3'), isNull); // 플래그로 재시도 안 함
    });

    test('계정 반려동물이 없으면 스킵한다(이관 대상 없음)', () async {
      SharedPreferences.setMockInitialValues({
        'pets_json_v1': jsonEncode([const Pet(id: 'local-1', name: '보리', species: PetSpecies.dog).toJson()]),
      });
      await firestore.collection('users').doc('uid-4').set({'loginType': 'google'});

      final service = CloudMigrationService(userRepository: userRepo);
      final result = await service.migrateIfNeeded('uid-4');

      expect(result, isNull);
    });

    test('이름이 일치하는 계정 반려동물이 없는 로컬 반려동물은 건드리지 않고 스킵 목록에 남는다', () async {
      SharedPreferences.setMockInitialValues({
        'pets_json_v1': jsonEncode([const Pet(id: 'local-1', name: '보리', species: PetSpecies.dog).toJson()]),
      });
      await firestore.collection('users').doc('uid-5').set({'loginType': 'google'});
      await userRepo.addPet(
        'uid-5',
        const SignupPet(species: PetSpecies.cat, breed: '코숏', weightKg: 3.0, birth: '2023-01', name: '콩이'),
      );

      final service = CloudMigrationService(userRepository: userRepo);
      final result = await service.migrateIfNeeded('uid-5');

      expect(result, isNotNull);
      expect(result!.migratedPetNames, isEmpty);
      expect(result.skippedPetNames, ['보리']);
    });
  });
}
