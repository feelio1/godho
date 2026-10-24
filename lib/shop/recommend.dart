import '../models/pet.dart';
import 'models/product.dart';

/// 반려동물 하나의 추천 태그 — 종·체중·생애주기만("쇼핑 기초" 지시서 4,
/// CLAUDE.md 원칙: 진료기록 내용 기반 추천 금지). [PetSpecies.other]는
/// [PetTypeTag]에 대응값이 없어 늘 null(매칭 안 함)이다.
PetTypeTag? _petTypeTagOf(Pet pet) => switch (pet.species) {
      PetSpecies.dog => PetTypeTag.dog,
      PetSpecies.cat => PetTypeTag.cat,
      PetSpecies.other => null,
    };

/// 생애주기 태그 — 생일이 없으면(모르면) null, 어느 쪽으로도 단정하지
/// 않는다(CLAUDE.md "확인 안 됨을 솔직히"와 같은 원칙). 기준은 통상적인
/// 반려동물 생애주기 구간(1살 미만 puppy, 7살 이상 senior)을 쓴다 —
/// 품종별 정밀 기준은 다음 단계.
LifeStageTag? _lifeStageTagOf(Pet pet) {
  final birthday = pet.birthday;
  if (birthday == null) return null;
  final now = DateTime.now();
  final ageDays = now.difference(birthday).inDays;
  if (ageDays < 0) return null;
  final ageYears = ageDays / 365.25;
  if (ageYears < 1) return LifeStageTag.puppy;
  if (ageYears >= 7) return LifeStageTag.senior;
  return LifeStageTag.adult;
}

/// 상품 하나가 반려동물 하나에게 추천할 만한지 — 종 태그가 있어야 하고
/// (없으면 매칭 불가), 상품이 생애주기를 지정했다면 반려동물의 생애주기를
/// 알아야 하며 그 목록에 들어 있어야 하고, 체중 범위를 지정했다면
/// 반려동물 체중을 알아야 하며 그 범위 안이어야 한다. 상품이 해당 축을
/// 지정하지 않았으면(목록이 비어 있거나 범위가 둘 다 null) 그 축은
/// 걸러내지 않는다.
bool _matches(Product product, Pet pet) {
  final petType = _petTypeTagOf(pet);
  if (petType == null || !product.petTypes.contains(petType)) return false;

  if (product.lifeStages.isNotEmpty) {
    final lifeStage = _lifeStageTagOf(pet);
    if (lifeStage == null || !product.lifeStages.contains(lifeStage)) return false;
  }

  final min = product.weightMinKg;
  final max = product.weightMaxKg;
  if (min != null || max != null) {
    final weight = pet.weightKg;
    if (weight == null) return false;
    if (min != null && weight < min) return false;
    if (max != null && weight > max) return false;
  }

  return true;
}

/// 판매 중인 상품 목록에서, 등록된 반려동물 중 하나라도 맞는 것만 골라
/// 정렬을 그대로 유지한 채 돌려준다(과장 배지 없이 — sortOrder 순서 유지).
/// 반려동물이 없으면(또는 하나도 못 맞으면) 빈 목록.
List<Product> filterRecommendedProducts(List<Product> products, List<Pet> pets) {
  if (pets.isEmpty) return const [];
  return products
      .where((p) => p.isPurchasable)
      .where((p) => pets.any((pet) => _matches(p, pet)))
      .toList();
}
