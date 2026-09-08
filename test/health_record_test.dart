import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/data/local_store.dart';
import 'package:petcliniccheck/models/medical_record.dart';
import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/providers/designated_provider.dart';
import 'package:petcliniccheck/providers/medical_record_provider.dart';
import 'package:petcliniccheck/providers/pet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pet/MedicalRecord JSON 직렬화', () {
    test('Pet은 toJson/fromJson을 거쳐도 값이 그대로 보존된다 (스프린트 8 지시서 3 — Firebase 이관 대비)', () {
      final pet = Pet(
        id: 'p1',
        name: '보리',
        species: PetSpecies.dog,
        breed: '푸들',
        birthday: DateTime(2020, 3, 15),
        photoPath: '/tmp/boree.jpg',
      );
      final restored = Pet.fromJson(jsonDecode(jsonEncode(pet.toJson())) as Map<String, dynamic>);

      expect(restored.id, pet.id);
      expect(restored.name, pet.name);
      expect(restored.species, PetSpecies.dog);
      expect(restored.breed, pet.breed);
      expect(restored.birthday, pet.birthday);
      expect(restored.photoPath, pet.photoPath);
    });

    test('선택 필드가 비어 있는 Pet도 정상적으로 직렬화된다', () {
      const pet = Pet(id: 'p2', name: '나비', species: PetSpecies.cat);
      final restored = Pet.fromJson(jsonDecode(jsonEncode(pet.toJson())) as Map<String, dynamic>);
      expect(restored.breed, isNull);
      expect(restored.birthday, isNull);
      expect(restored.photoPath, isNull);
    });

    test('MedicalRecord는 toJson/fromJson을 거쳐도 값이 그대로 보존된다', () {
      final record = MedicalRecord(
        id: 'r1',
        petId: 'p1',
        date: DateTime(2024, 5, 1),
        hospitalId: 'h1',
        hospitalName: '동물병원',
        memo: '정기검진',
        weightKg: 4.2,
        costWon: 35000,
        photoPath: '/tmp/receipt.jpg',
      );
      final restored =
          MedicalRecord.fromJson(jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>);

      expect(restored.id, record.id);
      expect(restored.petId, record.petId);
      expect(restored.date, record.date);
      expect(restored.hospitalId, record.hospitalId);
      expect(restored.hospitalName, record.hospitalName);
      expect(restored.memo, record.memo);
      expect(restored.weightKg, record.weightKg);
      expect(restored.costWon, record.costWon);
      expect(restored.photoPath, record.photoPath);
    });

    test('병원을 직접 입력한 기록(hospitalId 없음)도 정상적으로 직렬화된다', () {
      final record = MedicalRecord(
        id: 'r2',
        petId: 'p1',
        date: DateTime(2024, 6, 1),
        hospitalName: '동네 동물병원(직접 입력)',
      );
      final restored =
          MedicalRecord.fromJson(jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>);
      expect(restored.hospitalId, isNull);
      expect(restored.hospitalName, record.hospitalName);
      expect(restored.weightKg, isNull);
      expect(restored.costWon, isNull);
    });
  });

  group('LocalStore — 기기 로컬 저장(스프린트 8)', () {
    test('지정 병원 id는 저장 없이 토글로 추가·해제된다', () async {
      SharedPreferences.setMockInitialValues({});
      const store = LocalStore();
      expect(await store.loadDesignatedIds(), isEmpty);

      final afterAdd = await store.toggleDesignated('h1');
      expect(afterAdd, ['h1']);

      final afterRemove = await store.toggleDesignated('h1');
      expect(afterRemove, isEmpty);
    });

    test('반려동물 목록이 기기에 저장되고 그대로 복원된다', () async {
      SharedPreferences.setMockInitialValues({});
      const store = LocalStore();
      final pet = Pet(id: 'p1', name: '보리', species: PetSpecies.dog, birthday: DateTime(2021, 1, 1));

      await store.savePets([pet]);
      final restored = await store.loadPets();

      expect(restored, hasLength(1));
      expect(restored.single.name, '보리');
      expect(restored.single.birthday, pet.birthday);
    });

    test('진료기록이 기기에 저장되고 그대로 복원된다', () async {
      SharedPreferences.setMockInitialValues({});
      const store = LocalStore();
      final record = MedicalRecord(
        id: 'r1',
        petId: 'p1',
        date: DateTime(2024, 1, 1),
        hospitalName: '동물병원',
        costWon: 10000,
      );

      await store.saveMedicalRecords([record]);
      final restored = await store.loadMedicalRecords();

      expect(restored, hasLength(1));
      expect(restored.single.hospitalName, '동물병원');
      expect(restored.single.costWon, 10000);
    });
  });

  group('Riverpod providers', () {
    test('DesignatedHospitalsNotifier.toggle은 id를 추가·제거하고 상태를 갱신한다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(designatedHospitalsProvider.future);
      await container.read(designatedHospitalsProvider.notifier).toggle('h1');
      expect(container.read(designatedHospitalsProvider).value, ['h1']);

      await container.read(designatedHospitalsProvider.notifier).toggle('h1');
      expect(container.read(designatedHospitalsProvider).value, isEmpty);
    });

    test('PetsNotifier.upsert는 새 반려동물을 추가하고 같은 id면 덮어쓴다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(petsProvider.future);
      await container.read(petsProvider.notifier).upsert(
            const Pet(id: 'p1', name: '보리', species: PetSpecies.dog),
          );
      expect(container.read(petsProvider).value!.single.name, '보리');

      await container.read(petsProvider.notifier).upsert(
            const Pet(id: 'p1', name: '보리(개명)', species: PetSpecies.dog),
          );
      final pets = container.read(petsProvider).value!;
      expect(pets, hasLength(1));
      expect(pets.single.name, '보리(개명)');
    });

    test('recordsForPetProvider는 해당 반려동물의 기록만 최신순으로 정렬해 반환한다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(medicalRecordsProvider.future);
      final notifier = container.read(medicalRecordsProvider.notifier);
      await notifier.upsert(MedicalRecord(
        id: 'r1',
        petId: 'p1',
        date: DateTime(2024, 1, 1),
        hospitalName: '병원A',
      ));
      await notifier.upsert(MedicalRecord(
        id: 'r2',
        petId: 'p1',
        date: DateTime(2024, 6, 1),
        hospitalName: '병원B',
      ));
      await notifier.upsert(MedicalRecord(
        id: 'r3',
        petId: 'p2', // 다른 반려동물 — 걸러져야 한다.
        date: DateTime(2024, 12, 1),
        hospitalName: '병원C',
      ));

      final records = container.read(recordsForPetProvider('p1'));
      expect(records.map((r) => r.id).toList(), ['r2', 'r1']); // 최신순.

      await notifier.remove('r2');
      final afterRemove = container.read(recordsForPetProvider('p1'));
      expect(afterRemove.map((r) => r.id).toList(), ['r1']);
    });
  });
}
