import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/recommend.dart';

Product _product({
  required String id,
  List<PetTypeTag> petTypes = const [],
  List<LifeStageTag> lifeStages = const [],
  double? weightMinKg,
  double? weightMaxKg,
  ProductStatus status = ProductStatus.active,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    sellerId: 's1',
    name: '상품 $id',
    petTypes: petTypes,
    lifeStages: lifeStages,
    weightMinKg: weightMinKg,
    weightMaxKg: weightMaxKg,
    price: 10000,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

Pet _pet({PetSpecies species = PetSpecies.dog, DateTime? birthday, double? weightKg}) => Pet(
      id: 'pet1',
      name: '보리',
      species: species,
      birthday: birthday,
      weightKg: weightKg,
    );

void main() {
  final now = DateTime.now();

  group('filterRecommendedProducts — "쇼핑 기초" 지시서 4 (진료기록 참조 금지, 종·체중·생애주기만)', () {
    test('반려동물이 없으면 빈 목록이다', () {
      final products = [_product(id: 'p1', petTypes: const [PetTypeTag.dog])];
      expect(filterRecommendedProducts(products, const []), isEmpty);
    });

    test('종 태그가 다르면(강아지 상품 vs 고양이) 추천하지 않는다', () {
      final products = [_product(id: 'p1', petTypes: const [PetTypeTag.dog])];
      final cat = _pet(species: PetSpecies.cat);
      expect(filterRecommendedProducts(products, [cat]), isEmpty);
    });

    test('기타 종(PetSpecies.other)은 태그가 없어 매칭되지 않는다', () {
      final products = [_product(id: 'p1', petTypes: const [PetTypeTag.dog, PetTypeTag.cat])];
      final other = _pet(species: PetSpecies.other);
      expect(filterRecommendedProducts(products, [other]), isEmpty);
    });

    test('종만 지정된 상품은 생애주기·체중을 몰라도 추천된다', () {
      final products = [_product(id: 'p1', petTypes: const [PetTypeTag.dog])];
      final dog = _pet(species: PetSpecies.dog);
      expect(filterRecommendedProducts(products, [dog]).map((p) => p.id), ['p1']);
    });

    test('생애주기가 지정된 상품은 반려동물 생애주기를 몰라서(생일 없음) 매칭하지 않는다', () {
      final products = [
        _product(id: 'p1', petTypes: const [PetTypeTag.dog], lifeStages: const [LifeStageTag.senior]),
      ];
      final unknownAge = _pet(species: PetSpecies.dog, birthday: null);
      expect(filterRecommendedProducts(products, [unknownAge]), isEmpty);
    });

    test('1살 미만은 puppy, 7살 이상은 senior, 그 사이는 adult로 매칭된다', () {
      final puppyProduct = _product(id: 'puppy', petTypes: const [PetTypeTag.dog], lifeStages: const [LifeStageTag.puppy]);
      final adultProduct = _product(id: 'adult', petTypes: const [PetTypeTag.dog], lifeStages: const [LifeStageTag.adult]);
      final seniorProduct = _product(id: 'senior', petTypes: const [PetTypeTag.dog], lifeStages: const [LifeStageTag.senior]);
      final products = [puppyProduct, adultProduct, seniorProduct];

      final puppy = _pet(species: PetSpecies.dog, birthday: now.subtract(const Duration(days: 100)));
      expect(filterRecommendedProducts(products, [puppy]).map((p) => p.id), ['puppy']);

      final adult = _pet(species: PetSpecies.dog, birthday: now.subtract(const Duration(days: 365 * 3)));
      expect(filterRecommendedProducts(products, [adult]).map((p) => p.id), ['adult']);

      final senior = _pet(species: PetSpecies.dog, birthday: now.subtract(const Duration(days: 365 * 8)));
      expect(filterRecommendedProducts(products, [senior]).map((p) => p.id), ['senior']);
    });

    test('체중 범위가 지정된 상품은 체중을 몰라서 매칭하지 않는다', () {
      final products = [_product(id: 'p1', petTypes: const [PetTypeTag.dog], weightMinKg: 2, weightMaxKg: 10)];
      final unknownWeight = _pet(species: PetSpecies.dog, weightKg: null);
      expect(filterRecommendedProducts(products, [unknownWeight]), isEmpty);
    });

    test('체중이 범위 안이면 추천, 범위 밖이면 추천하지 않는다', () {
      final products = [_product(id: 'p1', petTypes: const [PetTypeTag.dog], weightMinKg: 2, weightMaxKg: 10)];
      final inRange = _pet(species: PetSpecies.dog, weightKg: 5);
      final tooLight = _pet(species: PetSpecies.dog, weightKg: 1);
      final tooHeavy = _pet(species: PetSpecies.dog, weightKg: 20);

      expect(filterRecommendedProducts(products, [inRange]).map((p) => p.id), ['p1']);
      expect(filterRecommendedProducts(products, [tooLight]), isEmpty);
      expect(filterRecommendedProducts(products, [tooHeavy]), isEmpty);
    });

    test('여러 반려동물 중 하나라도 맞으면 추천된다', () {
      final products = [_product(id: 'p1', petTypes: const [PetTypeTag.cat])];
      final dog = _pet(species: PetSpecies.dog);
      final cat = _pet(species: PetSpecies.cat);
      expect(filterRecommendedProducts(products, [dog, cat]).map((p) => p.id), ['p1']);
    });

    test('판매 중(active)이 아닌 상품은 추천하지 않는다(soldout 포함)', () {
      final products = [
        _product(id: 'soldout', petTypes: const [PetTypeTag.dog], status: ProductStatus.soldout),
        _product(id: 'draft', petTypes: const [PetTypeTag.dog], status: ProductStatus.draft),
      ];
      final dog = _pet(species: PetSpecies.dog);
      expect(filterRecommendedProducts(products, [dog]), isEmpty);
    });
  });
}
