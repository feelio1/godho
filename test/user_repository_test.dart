import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/data/user_repository.dart';
import 'package:petcliniccheck/models/app_user.dart';
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
}
