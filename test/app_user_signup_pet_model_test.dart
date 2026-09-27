import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/app_user.dart';
import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/models/signup_pet.dart';

void main() {
  group('AppUser Firestore 직렬화', () {
    test('toFirestore/fromFirestore를 거쳐도 값이 그대로 보존된다', () {
      final createdAt = DateTime(2026, 1, 1, 9);
      final agreedAt = DateTime(2026, 1, 1, 9, 5);
      final user = AppUser(
        uid: 'uid-1',
        loginType: LoginType.google,
        email: 'user@example.com',
        displayName: '홍길동',
        ageGroup: AgeGroup.thirties,
        gender: Gender.female,
        agreedStats: true,
        agreedStatsAt: agreedAt,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      final restored = AppUser.fromFirestore('uid-1', user.toFirestore());

      expect(restored.uid, 'uid-1');
      expect(restored.loginType, LoginType.google);
      expect(restored.email, 'user@example.com');
      expect(restored.displayName, '홍길동');
      expect(restored.ageGroup, AgeGroup.thirties);
      expect(restored.gender, Gender.female);
      expect(restored.agreedStats, isTrue);
      expect(restored.agreedStatsAt, agreedAt);
      expect(restored.createdAt, createdAt);
    });

    test('선택 필드가 비어 있는 사용자(카카오 신규 등)도 정상적으로 직렬화된다', () {
      final now = DateTime(2026, 3, 1);
      final user = AppUser(
        uid: 'uid-2',
        loginType: LoginType.apple,
        createdAt: now,
        updatedAt: now,
      );

      final data = user.toFirestore();
      expect(data['email'], isNull);
      expect(data['ageGroup'], isNull);
      expect(data['agreedStatsAt'], isNull);
      expect(data['agreedStats'], isFalse);

      final restored = AppUser.fromFirestore('uid-2', data);
      expect(restored.ageGroup, isNull);
      expect(restored.gender, isNull);
      expect(restored.agreedStats, isFalse);
      expect(restored.agreedStatsAt, isNull);
    });

    test('건너뛰기 등으로 알 수 없는 loginType 문자열이 와도 크래시 없이 기본값으로 처리한다', () {
      final restored = AppUser.fromFirestore('uid-3', {
        'loginType': '알수없음',
        'createdAt': null,
        'updatedAt': null,
      });
      expect(restored.loginType, LoginType.google);
    });
  });

  group('SignupPet Firestore 직렬화', () {
    test('필수 필드(종류/품종/체중/생년월)와 선택 필드가 모두 보존된다', () {
      const pet = SignupPet(
        species: PetSpecies.dog,
        breed: '말티즈',
        weightKg: 3.2,
        birth: '2023-05',
        name: '뭉치',
        sex: PetSex.male,
        neutered: true,
      );

      final data = pet.toFirestore();
      final restored = SignupPet.fromFirestore('pet-1', data);

      expect(restored.species, PetSpecies.dog);
      expect(restored.breed, '말티즈');
      expect(restored.weightKg, 3.2);
      expect(restored.birth, '2023-05');
      expect(restored.name, '뭉치');
      expect(restored.sex, PetSex.male);
      expect(restored.neutered, isTrue);
    });

    test('선택 필드(이름/성별/중성화/사진)를 생략해도 필수 필드만으로 정상 직렬화된다', () {
      const pet = SignupPet(
        species: PetSpecies.cat,
        breed: '코리안숏헤어',
        weightKg: 4.0,
        birth: '2022-11',
      );

      final data = pet.toFirestore();
      expect(data['name'], isNull);
      expect(data['sex'], isNull);
      expect(data['neutered'], isNull);
      expect(data['photoUrl'], isNull);

      final restored = SignupPet.fromFirestore('pet-2', data);
      expect(restored.species, PetSpecies.cat);
      expect(restored.name, isNull);
      expect(restored.sex, isNull);
    });
  });
}
