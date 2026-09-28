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

  group('SignupPet.copyWith / toFirestoreUpdate — 계정 반려동물 수정', () {
    const base = SignupPet(
      id: 'pet-9',
      species: PetSpecies.dog,
      breed: '말티즈',
      weightKg: 3.2,
      birth: '2023-05',
      name: '뭉치',
      photoUrl: 'https://example.com/old.jpg',
    );

    test('아무 값도 안 주면 원본과 완전히 같다(그 외 필드는 전부 유지)', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.breed, base.breed);
      expect(copy.photoUrl, base.photoUrl);
    });

    test('photoUrl만 새로 얹으면(사진 업로드 완료) 그 값만 바뀐다', () {
      final copy = base.copyWith(photoUrl: 'https://example.com/new.jpg');
      expect(copy.photoUrl, 'https://example.com/new.jpg');
      expect(copy.breed, base.breed);
      expect(copy.id, base.id);
    });

    test('clearPhotoUrl이면 photoUrl을 새로 줘도 무시하고 null로 지운다(사진 삭제)', () {
      final copy = base.copyWith(photoUrl: 'https://example.com/ignored.jpg', clearPhotoUrl: true);
      expect(copy.photoUrl, isNull);
    });

    test('id만 새로 얹으면(문서 생성 직후 id 확정) 나머지는 그대로다', () {
      const noId = SignupPet(species: PetSpecies.cat, breed: '코숏', weightKg: 4.0, birth: '2022-11');
      final withId = noId.copyWith(id: 'generated-id');
      expect(withId.id, 'generated-id');
      expect(withId.breed, '코숏');
    });

    test('toFirestoreUpdate는 createdAt을 빼고 나머지는 toFirestore와 같다(수정 시 생성일 보존)', () {
      final update = base.toFirestoreUpdate();
      expect(update.containsKey('createdAt'), isFalse);
      expect(update['breed'], '말티즈');
      expect(update['photoUrl'], 'https://example.com/old.jpg');
    });
  });
}
