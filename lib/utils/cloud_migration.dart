import '../models/pet.dart';
import '../models/signup_pet.dart';

/// 로컬 반려동물 하나를 계정(Firestore) 반려동물과 매칭한 결과 —
/// [accountPet]이 있으면 정확히 하나와만 이름·종류가 일치해 매칭된 것이고,
/// null이면 [skipReason]에 왜 건드리지 않았는지가 담긴다. 여러 계정
/// 반려동물과 동시에 일치하거나(이름 중복) 하나도 일치하지 않으면 임의로
/// 병합·삭제하지 않고 건너뛴다("진료기록·예약 Firestore 저장" 지시서 B-3
/// "애매/불일치 → 멈추고 보고").
class PetMigrationMatch {
  final Pet localPet;
  final SignupPet? accountPet;
  final String? skipReason;

  const PetMigrationMatch({required this.localPet, this.accountPet, this.skipReason});

  bool get isMatched => accountPet != null;
}

bool _sameSpeciesAndName(Pet local, SignupPet account) {
  final localName = local.name.trim();
  final accountName = (account.name ?? '').trim();
  return local.species == account.species && localName.isNotEmpty && localName == accountName;
}

/// [localPets] 각각을 [accountPets]와 이름(정확히 일치)·종류 기준으로
/// 매칭한다. 정확히 하나와만 일치하는 경우만 매칭으로 보고, 그 외(0개 또는
/// 2개 이상 일치)는 [PetMigrationMatch.skipReason]에 이유를 남겨 건너뛴다.
List<PetMigrationMatch> matchLocalPetsToAccountPets(
  List<Pet> localPets,
  List<SignupPet> accountPets,
) {
  return localPets.map((local) {
    final candidates = accountPets.where((account) => _sameSpeciesAndName(local, account)).toList();
    if (candidates.isEmpty) {
      return PetMigrationMatch(localPet: local, skipReason: '이름·종류가 일치하는 계정 반려동물을 찾지 못함');
    }
    if (candidates.length > 1) {
      return PetMigrationMatch(localPet: local, skipReason: '이름·종류가 일치하는 계정 반려동물이 여러 마리라 애매함');
    }
    return PetMigrationMatch(localPet: local, accountPet: candidates.single);
  }).toList();
}
