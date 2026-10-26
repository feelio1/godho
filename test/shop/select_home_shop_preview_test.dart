import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/recommend.dart';

Product _product(String id, {List<PetTypeTag> petTypes = const []}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    sellerId: 's1',
    name: '상품 $id',
    petTypes: petTypes,
    price: 10000,
    status: ProductStatus.active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('selectHomeShopPreview — "방향 개편" 지시서 B-6', () {
    test('판매 중 상품이 없으면 빈 목록이다', () {
      expect(selectHomeShopPreview(activeProducts: const [], pets: const []), isEmpty);
    });

    test('반려동물이 없으면(게스트) 판매 중 상품을 앞에서부터 자른다', () {
      final products = List.generate(6, (i) => _product('p$i'));
      final result = selectHomeShopPreview(activeProducts: products, pets: const []);
      expect(result.map((p) => p.id), ['p0', 'p1', 'p2', 'p3']);
    });

    test('limit을 바꿀 수 있다', () {
      final products = List.generate(6, (i) => _product('p$i'));
      final result = selectHomeShopPreview(activeProducts: products, pets: const [], limit: 2);
      expect(result, hasLength(2));
    });

    test('반려동물이 있고 맞는 상품이 있으면 추천 결과만 보여준다', () {
      final dogProduct = _product('dog', petTypes: const [PetTypeTag.dog]);
      final catProduct = _product('cat', petTypes: const [PetTypeTag.cat]);
      final dog = Pet(id: 'pet1', name: '보리', species: PetSpecies.dog);

      final result = selectHomeShopPreview(activeProducts: [dogProduct, catProduct], pets: [dog]);
      expect(result.map((p) => p.id), ['dog']);
    });

    test('반려동물이 있지만 맞는 상품이 하나도 없으면 빈 섹션 대신 판매 중 상품으로 채운다', () {
      final catProduct = _product('cat', petTypes: const [PetTypeTag.cat]);
      final dog = Pet(id: 'pet1', name: '보리', species: PetSpecies.dog);

      final result = selectHomeShopPreview(activeProducts: [catProduct], pets: [dog]);
      expect(result.map((p) => p.id), ['cat']);
    });
  });
}
