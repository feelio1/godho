import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pet.dart';
import '../models/signup_pet.dart';
import 'auth_provider.dart';
import 'pet_provider.dart';

/// Firestore `users/{uid}/pets` 문서에서 온 반려동물임을 구분하는 ID
/// 접두사 — 로컬(SharedPreferences) [Pet.id]는 타임스탬프 기반 숫자라
/// 절대 이 접두사로 시작하지 않는다. 진료기록/예약이 petId로 로컬에
/// 저장되므로, 이 접두사 덕분에 계정 반려동물의 기록도 로컬 반려동물
/// 기록과 절대 섞이지 않는다.
const _accountPetIdPrefix = 'account:';

bool isAccountPetId(String petId) => petId.startsWith(_accountPetIdPrefix);

/// 가입 때 등록한 [SignupPet](생년월만 아는 "YYYY-MM")을 진료기록 화면이
/// 이미 알고 있는 [Pet] 모양으로 바꾼다 — 화면 쪽 위젯을 새로 만들지 않고
/// 그대로 재사용하기 위한 디스플레이 전용 변환이다(펫클 3단계 지시서 2).
/// 사진은 이번 범위에 저장소가 없어 항상 비운다(가짜로 채우지 않는다).
Pet accountPetToLocalPet(SignupPet pet) {
  DateTime? birthday;
  final parts = pet.birth.split('-');
  if (parts.length == 2) {
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year != null && month != null) {
      birthday = DateTime(year, month);
    }
  }
  final name = pet.name?.trim();
  return Pet(
    id: '$_accountPetIdPrefix${pet.id}',
    name: name != null && name.isNotEmpty ? name : pet.species.label,
    species: pet.species,
    breed: pet.breed,
    birthday: birthday,
    sex: pet.sex ?? PetSex.unknown,
    neutered: pet.neutered ?? false,
    weightKg: pet.weightKg,
  );
}

/// 진료기록 화면(및 진료기록 추가 폼의 반려동물 선택지)이 실제로 보여줄
/// 반려동물 목록 — 로그인 여부에 따라 소스를 바꾼다(펫클 3단계 지시서 2).
///
/// - 게스트(비로그인): 기존 로컬 [petsProvider] 그대로. 이 브랜치는 이번
///   지시서 전과 완전히 동일한 코드 경로라 회귀 위험이 없다.
/// - 로그인: 계정(Firestore) 반려동물이 소스 오브 트루스다. 로컬에 남아
///   있는 반려동물(보리/콩이 등)은 절대 건드리거나 지우지 않는다 — 그냥
///   이 provider가 보여주지 않을 뿐, [petsProvider]/로컬 저장소는 그대로
///   있고 로그아웃하면 다시 보인다.
final effectivePetsProvider = FutureProvider<List<Pet>>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) {
    return ref.watch(petsProvider.future);
  }
  final accountPets = await ref.watch(userRepositoryProvider).fetchPets(uid);
  return accountPets.map(accountPetToLocalPet).toList();
});
