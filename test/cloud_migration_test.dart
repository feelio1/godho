import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/models/signup_pet.dart';
import 'package:petcliniccheck/utils/cloud_migration.dart';

void main() {
  group('matchLocalPetsToAccountPets — "진료기록·예약 Firestore 저장" 지시서 B-3', () {
    test('이름·종류가 정확히 하나와만 일치하면 매칭된다', () {
      const local = Pet(id: 'local-1', name: '보리', species: PetSpecies.dog);
      const account = SignupPet(id: 'acct-1', species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01', name: '보리');

      final matches = matchLocalPetsToAccountPets([local], [account]);

      expect(matches, hasLength(1));
      expect(matches.single.isMatched, isTrue);
      expect(matches.single.accountPet, account);
      expect(matches.single.skipReason, isNull);
    });

    test('이름이 일치하는 계정 반려동물이 없으면 건너뛴다', () {
      const local = Pet(id: 'local-1', name: '보리', species: PetSpecies.dog);
      const account = SignupPet(id: 'acct-1', species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01', name: '콩이');

      final matches = matchLocalPetsToAccountPets([local], [account]);

      expect(matches.single.isMatched, isFalse);
      expect(matches.single.skipReason, isNotNull);
    });

    test('이름은 같아도 종류(강아지/고양이)가 다르면 매칭하지 않는다', () {
      const local = Pet(id: 'local-1', name: '보리', species: PetSpecies.dog);
      const account = SignupPet(id: 'acct-1', species: PetSpecies.cat, breed: '코숏', weightKg: 3.0, birth: '2023-01', name: '보리');

      final matches = matchLocalPetsToAccountPets([local], [account]);

      expect(matches.single.isMatched, isFalse);
    });

    test('같은 이름·종류의 계정 반려동물이 여러 마리면 애매해서 건너뛴다(임의 병합 금지)', () {
      const local = Pet(id: 'local-1', name: '보리', species: PetSpecies.dog);
      const account1 = SignupPet(id: 'acct-1', species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01', name: '보리');
      const account2 = SignupPet(id: 'acct-2', species: PetSpecies.dog, breed: '푸들', weightKg: 4.0, birth: '2022-01', name: '보리');

      final matches = matchLocalPetsToAccountPets([local], [account1, account2]);

      expect(matches.single.isMatched, isFalse);
      expect(matches.single.skipReason, contains('여러 마리'));
    });

    test('로컬 반려동물이 여러 마리면 각각 독립적으로 판단한다', () {
      const boree = Pet(id: 'local-1', name: '보리', species: PetSpecies.dog);
      const kongi = Pet(id: 'local-2', name: '콩이', species: PetSpecies.cat);
      const acctBoree = SignupPet(id: 'acct-1', species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01', name: '보리');

      final matches = matchLocalPetsToAccountPets([boree, kongi], [acctBoree]);

      expect(matches.firstWhere((m) => m.localPet.id == 'local-1').isMatched, isTrue);
      expect(matches.firstWhere((m) => m.localPet.id == 'local-2').isMatched, isFalse);
    });

    test('공백만 다른 이름은 trim 후 비교되지만, 완전히 빈 이름은 매칭되지 않는다', () {
      const local = Pet(id: 'local-1', name: '  보리  ', species: PetSpecies.dog);
      const account = SignupPet(id: 'acct-1', species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01', name: '보리');

      expect(matchLocalPetsToAccountPets([local], [account]).single.isMatched, isTrue);

      const unnamedLocal = Pet(id: 'local-2', name: '', species: PetSpecies.dog);
      const unnamedAccount = SignupPet(id: 'acct-2', species: PetSpecies.dog, breed: '말티즈', weightKg: 3.0, birth: '2023-01');
      expect(matchLocalPetsToAccountPets([unnamedLocal], [unnamedAccount]).single.isMatched, isFalse);
    });
  });
}
