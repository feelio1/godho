import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/data/user_repository.dart';
import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/models/signup_pet.dart';
import 'package:petcliniccheck/providers/auth_provider.dart';
import 'package:petcliniccheck/providers/effective_pets_provider.dart';
import 'package:petcliniccheck/providers/pet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('accountPetToLocalPet — SignupPet(Firestore) → Pet(화면 표시용) 변환', () {
    test('"YYYY-MM" 생년월을 그 달 1일 DateTime으로 바꾸고, id에 account: 접두사를 붙인다', () {
      const signupPet = SignupPet(
        id: 'doc-1',
        species: PetSpecies.dog,
        breed: '말티즈',
        weightKg: 3.2,
        birth: '2023-05',
        name: '뭉치',
        sex: PetSex.male,
        neutered: true,
      );

      final pet = accountPetToLocalPet(signupPet);

      expect(pet.id, 'account:doc-1');
      expect(isAccountPetId(pet.id), isTrue);
      expect(pet.name, '뭉치');
      expect(pet.species, PetSpecies.dog);
      expect(pet.breed, '말티즈');
      expect(pet.weightKg, 3.2);
      expect(pet.sex, PetSex.male);
      expect(pet.neutered, isTrue);
      expect(pet.birthday, DateTime(2023, 5));
    });

    test('이름을 안 적었으면 종류 이름(강아지/고양이)으로 대체하고, 성별 미지정은 unknown', () {
      const signupPet = SignupPet(
        id: 'doc-2',
        species: PetSpecies.cat,
        breed: '코리안숏헤어',
        weightKg: 4.0,
        birth: '2022-11',
      );

      final pet = accountPetToLocalPet(signupPet);

      expect(pet.name, '고양이');
      expect(pet.sex, PetSex.unknown);
      expect(pet.neutered, isFalse);
    });

    test('로컬 반려동물 id(타임스탬프 기반 숫자)는 account: 접두사가 없다', () {
      expect(isAccountPetId('1706000000000000_12345'), isFalse);
    });
  });

  group('effectivePetsProvider — 로그인 여부에 따라 소스가 바뀐다(펫클 3단계 지시서 2)', () {
    test('게스트(로그아웃) 상태면 기존 로컬 petsProvider를 그대로 돌려준다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
      );
      addTearDown(container.dispose);

      // 로컬에 반려동물을 하나 등록해둔다 — 기존에 있던 보리/콩이 같은
      // 로컬 데이터가 게스트 상태에선 그대로 보여야 한다는 회귀 방지
      // 시나리오다.
      await container.read(petsProvider.notifier).upsert(
            const Pet(id: 'local-1', name: '보리', species: PetSpecies.dog),
          );

      final pets = await container.read(effectivePetsProvider.future);
      expect(pets, hasLength(1));
      expect(pets.single.id, 'local-1');
      expect(pets.single.name, '보리');
    });

    test(
      '로그인 분기가 실제로 하는 일(Firestore pets 조회 → accountPetToLocalPet 변환)을 '
      '수행하면 로컬 데이터와 섞이지 않고 계정 반려동물만 나온다 — 로그인 상태의 실제 '
      'User 인스턴스는 firebase_auth_mocks 없이는 만들 수 없어(2단계 지시서에서 이미 '
      '확인한 제약) effectivePetsProvider 자체 대신 그 분기가 조합하는 두 연산을 '
      '직접 검증한다',
      () async {
        SharedPreferences.setMockInitialValues({});
        final firestore = FakeFirebaseFirestore();
        final userRepo = UserRepository(firestore: firestore);
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // 로그아웃 상태에서 로컬 반려동물(보리)을 먼저 등록해, 로그인 후에도
        // 이 로컬 데이터가 지워지지 않고 그대로 남아 있는지 뒤에서 확인한다.
        await container.read(petsProvider.notifier).upsert(
              const Pet(id: 'local-1', name: '보리', species: PetSpecies.dog),
            );

        // 가입 때 등록한 계정 반려동물(콩이)을 Firestore(fake)에 넣는다.
        await firestore.collection('users').doc('uid-1').set({'loginType': 'google'});
        await userRepo.addPet(
          'uid-1',
          const SignupPet(species: PetSpecies.cat, breed: '코리안숏헤어', weightKg: 3.5, birth: '2021-03', name: '콩이'),
        );

        // effectivePetsProvider의 로그인 분기와 동일한 두 연산(uid로 fetchPets
        // → accountPetToLocalPet 매핑)을 그대로 실행한다.
        final accountPets = (await userRepo.fetchPets('uid-1')).map(accountPetToLocalPet).toList();

        expect(accountPets, hasLength(1));
        expect(accountPets.single.name, '콩이');
        expect(isAccountPetId(accountPets.single.id), isTrue);
        // 로컬에 저장했던 보리는 계정 반려동물 목록에 전혀 섞이지 않는다.
        expect(accountPets.any((p) => p.name == '보리'), isFalse);

        // 로컬 데이터 자체는 조금도 건드리지 않았으므로 여전히 그대로 있다.
        final localPets = await container.read(petsProvider.future);
        expect(localPets.single.name, '보리');
      },
    );
  });
}
