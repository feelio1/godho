import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/data/user_repository.dart';
import 'package:petcliniccheck/models/app_user.dart';
import 'package:petcliniccheck/models/appointment.dart';
import 'package:petcliniccheck/models/medical_record.dart';
import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/models/signup_pet.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late UserRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = UserRepository(firestore: firestore);
  });

  group('신규/기존 사용자 판별 — users/{uid} 문서 존재 여부', () {
    test('한 번도 로그인한 적 없는 uid는 존재하지 않는다', () async {
      expect(await repository.userExists('uid-new'), isFalse);
      expect(await repository.fetchUser('uid-new'), isNull);
    });

    test('createUser로 만든 문서는 곧바로 존재하고 fetchUser로 그대로 읽힌다', () async {
      final now = DateTime(2026, 1, 1);
      await repository.createUser(AppUser(
        uid: 'uid-1',
        loginType: LoginType.google,
        email: 'a@b.com',
        displayName: '홍길동',
        createdAt: now,
        updatedAt: now,
      ));

      expect(await repository.userExists('uid-1'), isTrue);
      final fetched = await repository.fetchUser('uid-1');
      expect(fetched, isNotNull);
      expect(fetched!.loginType, LoginType.google);
      expect(fetched.email, 'a@b.com');
      expect(fetched.displayName, '홍길동');
    });
  });

  test('updateProfile은 나이대·성별·통계동의만 갱신하고 다른 필드는 그대로 둔다', () async {
    final now = DateTime(2026, 1, 1);
    await repository.createUser(AppUser(
      uid: 'uid-2',
      loginType: LoginType.apple,
      email: 'kept@example.com',
      createdAt: now,
      updatedAt: now,
    ));

    await repository.updateProfile(
      'uid-2',
      ageGroup: AgeGroup.twenties,
      gender: Gender.male,
      agreedStats: true,
    );

    final updated = await repository.fetchUser('uid-2');
    expect(updated!.ageGroup, AgeGroup.twenties);
    expect(updated.gender, Gender.male);
    expect(updated.agreedStats, isTrue);
    expect(updated.agreedStatsAt, isNotNull);
    // 가입 시점에 넣은 값이 updateProfile 이후에도 그대로 유지된다.
    expect(updated.email, 'kept@example.com');
    expect(updated.loginType, LoginType.apple);
  });

  test('건너뛰기로 통계 동의를 취소하면 agreedStatsAt도 함께 비운다', () async {
    final now = DateTime(2026, 1, 1);
    await repository.createUser(AppUser(uid: 'uid-3', loginType: LoginType.google, createdAt: now, updatedAt: now));
    await repository.updateProfile('uid-3', agreedStats: true);
    await repository.updateProfile('uid-3', agreedStats: false);

    final updated = await repository.fetchUser('uid-3');
    expect(updated!.agreedStats, isFalse);
    expect(updated.agreedStatsAt, isNull);
  });

  group('pets 서브컬렉션', () {
    test('addPet으로 여러 마리를 등록하면 fetchPets가 전부 돌려준다(최소 1마리 요구사항의 근거)', () async {
      final now = DateTime(2026, 1, 1);
      await repository.createUser(AppUser(uid: 'uid-4', loginType: LoginType.google, createdAt: now, updatedAt: now));

      await repository.addPet(
        'uid-4',
        const SignupPet(species: PetSpecies.dog, breed: '말티즈', weightKg: 3.2, birth: '2023-05'),
      );
      await repository.addPet(
        'uid-4',
        const SignupPet(species: PetSpecies.cat, breed: '코리안숏헤어', weightKg: 4.0, birth: '2022-11', name: '나비'),
      );

      final pets = await repository.fetchPets('uid-4');
      expect(pets, hasLength(2));
      expect(pets.map((p) => p.breed), containsAll(['말티즈', '코리안숏헤어']));
      expect(pets.firstWhere((p) => p.name == '나비').species, PetSpecies.cat);
    });

    test('다른 uid의 pets는 섞이지 않는다', () async {
      final now = DateTime(2026, 1, 1);
      await repository.createUser(AppUser(uid: 'uid-a', loginType: LoginType.google, createdAt: now, updatedAt: now));
      await repository.createUser(AppUser(uid: 'uid-b', loginType: LoginType.google, createdAt: now, updatedAt: now));

      await repository.addPet(
        'uid-a',
        const SignupPet(species: PetSpecies.dog, breed: '푸들', weightKg: 2.5, birth: '2021-01'),
      );

      expect(await repository.fetchPets('uid-a'), hasLength(1));
      expect(await repository.fetchPets('uid-b'), isEmpty);
    });

    test('addPet은 생성된 문서 id를 돌려주고, 사진 업로드는 그 id로 이어진다', () async {
      final now = DateTime(2026, 1, 1);
      await repository.createUser(AppUser(uid: 'uid-photo', loginType: LoginType.google, createdAt: now, updatedAt: now));

      final petId = await repository.addPet(
        'uid-photo',
        const SignupPet(species: PetSpecies.dog, breed: '푸들', weightKg: 2.5, birth: '2021-01'),
      );

      expect(petId, isNotEmpty);
      final pets = await repository.fetchPets('uid-photo');
      expect(pets.single.id, petId);
    });

    test('updatePet은 필드를 갱신하되 문서 id는 그대로 유지한다', () async {
      final now = DateTime(2026, 1, 1);
      await repository.createUser(AppUser(uid: 'uid-edit', loginType: LoginType.google, createdAt: now, updatedAt: now));
      final petId = await repository.addPet(
        'uid-edit',
        const SignupPet(species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01', name: '초코'),
      );

      await repository.updatePet(
        'uid-edit',
        petId,
        const SignupPet(species: PetSpecies.dog, breed: '말티즈', weightKg: 3.5, birth: '2023-01', name: '초코 (수정)'),
      );

      final pets = await repository.fetchPets('uid-edit');
      expect(pets.single.id, petId);
      expect(pets.single.name, '초코 (수정)');
      expect(pets.single.weightKg, 3.5);
    });

    test('updatePet은 createdAt을 덮어쓰지 않는다(toFirestoreUpdate가 그 키를 뺌)', () async {
      final now = DateTime(2026, 1, 1);
      await repository.createUser(AppUser(uid: 'uid-created', loginType: LoginType.google, createdAt: now, updatedAt: now));
      final petId = await repository.addPet(
        'uid-created',
        const SignupPet(species: PetSpecies.cat, breed: '코숏', weightKg: 4.0, birth: '2022-11'),
      );
      final beforeRaw = await firestore.collection('users').doc('uid-created').collection('pets').doc(petId).get();
      final createdAtBefore = beforeRaw.data()!['createdAt'];

      await repository.updatePet(
        'uid-created',
        petId,
        const SignupPet(species: PetSpecies.cat, breed: '코숏', weightKg: 4.2, birth: '2022-11'),
      );

      final afterRaw = await firestore.collection('users').doc('uid-created').collection('pets').doc(petId).get();
      expect(afterRaw.data()!['createdAt'], createdAtBefore);
      expect(afterRaw.data()!['weightKg'], 4.2);
    });

    test('deletePet은 문서를 지우고, 다른 반려동물은 그대로 남는다(계정 데이터만 지움, 로컬 무관)', () async {
      final now = DateTime(2026, 1, 1);
      await repository.createUser(AppUser(uid: 'uid-del', loginType: LoginType.google, createdAt: now, updatedAt: now));
      final keepId = await repository.addPet(
        'uid-del',
        const SignupPet(species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01', name: '남는애'),
      );
      final removeId = await repository.addPet(
        'uid-del',
        const SignupPet(species: PetSpecies.cat, breed: '코숏', weightKg: 4.0, birth: '2022-11', name: '지워질애'),
      );

      await repository.deletePet('uid-del', removeId);

      final pets = await repository.fetchPets('uid-del');
      expect(pets, hasLength(1));
      expect(pets.single.id, keepId);
      expect(pets.single.name, '남는애');
    });

    test('uploadPetPhoto/deletePetPhoto는 Storage가 준비되지 않아도 예외를 던지지 않는다(방어적 실패)', () async {
      // 테스트 환경엔 FirebaseApp이 초기화돼 있지 않다 — 실제 기기에서
      // Storage 버킷이 없거나 네트워크가 끊긴 경우와 같은 실패 경로를
      // 검증한다. 반려동물 정보 저장 자체는 이 실패와 무관하게 항상
      // 성공해야 한다(펫클 "계정 반려동물 추가/수정" 지시서).
      final result = await repository.uploadPetPhoto('uid-x', 'pet-x', File('/no/such/file.jpg'));
      expect(result, isNull);

      // 예외 없이 완료되면 통과 — deletePetPhoto는 실패해도 무시한다.
      await repository.deletePetPhoto('uid-x', 'pet-x');
    });
  });

  test('users 컬렉션 문서에 실제로 필드가 기록된다(원시 문서 확인)', () async {
    final now = DateTime(2026, 1, 1);
    await repository.createUser(AppUser(
      uid: 'uid-5',
      loginType: LoginType.kakao,
      createdAt: now,
      updatedAt: now,
    ));

    final raw = await firestore.collection('users').doc('uid-5').get();
    expect(raw.exists, isTrue);
    expect(raw.data()!['loginType'], 'kakao');
    expect(raw.data()!['createdAt'], isA<Timestamp>());
  });

  group('records/appointments 서브컬렉션("진료기록·예약 Firestore 저장" 지시서 B-1)', () {
    test('addRecord/fetchRecords 왕복 — 다른 반려동물의 기록과 섞이지 않는다', () async {
      await repository.addRecord(
        'uid-6',
        'pet-a',
        MedicalRecord(id: 'r1', petId: 'pet-a', date: DateTime(2024, 1, 1), hospitalName: '병원A'),
      );
      await repository.addRecord(
        'uid-6',
        'pet-b',
        MedicalRecord(id: 'r2', petId: 'pet-b', date: DateTime(2024, 1, 1), hospitalName: '병원B'),
      );

      final petARecords = await repository.fetchRecords('uid-6', 'pet-a');
      expect(petARecords, hasLength(1));
      expect(petARecords.single.hospitalName, '병원A');
      expect(petARecords.single.id, 'r1');
    });

    test('updateRecord는 필드를 갱신하되 createdAt은 그대로 둔다', () async {
      await repository.addRecord(
        'uid-7',
        'pet-a',
        MedicalRecord(id: 'r1', petId: 'pet-a', date: DateTime(2024, 1, 1), hospitalName: '초진'),
      );
      final beforeRaw =
          await firestore.collection('users').doc('uid-7').collection('pets').doc('pet-a').collection('records').doc('r1').get();
      final createdAtBefore = beforeRaw.data()!['createdAt'];

      await repository.updateRecord(
        'uid-7',
        'pet-a',
        MedicalRecord(id: 'r1', petId: 'pet-a', date: DateTime(2024, 1, 1), hospitalName: '재진'),
      );

      final records = await repository.fetchRecords('uid-7', 'pet-a');
      expect(records.single.hospitalName, '재진');
      final afterRaw =
          await firestore.collection('users').doc('uid-7').collection('pets').doc('pet-a').collection('records').doc('r1').get();
      expect(afterRaw.data()!['createdAt'], createdAtBefore);
    });

    test('deleteRecord는 그 기록만 지우고 다른 기록은 남는다', () async {
      await repository.addRecord(
        'uid-8',
        'pet-a',
        MedicalRecord(id: 'r1', petId: 'pet-a', date: DateTime(2024, 1, 1), hospitalName: '남는 기록'),
      );
      await repository.addRecord(
        'uid-8',
        'pet-a',
        MedicalRecord(id: 'r2', petId: 'pet-a', date: DateTime(2024, 1, 2), hospitalName: '지워질 기록'),
      );

      await repository.deleteRecord('uid-8', 'pet-a', 'r2');

      final records = await repository.fetchRecords('uid-8', 'pet-a');
      expect(records, hasLength(1));
      expect(records.single.id, 'r1');
    });

    test('streamRecords는 addRecord 직후 새 기록을 실시간으로 내보낸다', () async {
      // 구독 시점에 빈 스냅샷이 먼저 한 번 나올 수 있어(fake_cloud_firestore),
      // 실제로 기록이 담긴 첫 방출을 기다린다 — 그게 "실시간 반영"의 핵심이다.
      final recordsAppeared = repository.streamRecords('uid-9', 'pet-a').firstWhere((r) => r.isNotEmpty);

      await repository.addRecord(
        'uid-9',
        'pet-a',
        MedicalRecord(id: 'r1', petId: 'pet-a', date: DateTime(2024, 1, 1), hospitalName: '실시간 반영'),
      );

      final records = await recordsAppeared;
      expect(records, hasLength(1));
      expect(records.single.hospitalName, '실시간 반영');
    });

    test('addAppointment/fetchAppointments 왕복', () async {
      await repository.addAppointment(
        'uid-10',
        'pet-a',
        Appointment(id: 'a1', petId: 'pet-a', dateTime: DateTime(2026, 1, 1), hospitalName: '예약병원'),
      );

      final appointments = await repository.fetchAppointments('uid-10', 'pet-a');
      expect(appointments, hasLength(1));
      expect(appointments.single.hospitalName, '예약병원');
    });

    test('deleteAppointment는 그 예약만 지운다', () async {
      await repository.addAppointment(
        'uid-11',
        'pet-a',
        Appointment(id: 'a1', petId: 'pet-a', dateTime: DateTime(2026, 1, 1), hospitalName: '남는 예약'),
      );
      await repository.addAppointment(
        'uid-11',
        'pet-a',
        Appointment(id: 'a2', petId: 'pet-a', dateTime: DateTime(2026, 1, 2), hospitalName: '지워질 예약'),
      );

      await repository.deleteAppointment('uid-11', 'pet-a', 'a2');

      final appointments = await repository.fetchAppointments('uid-11', 'pet-a');
      expect(appointments, hasLength(1));
      expect(appointments.single.id, 'a1');
    });
  });
}
