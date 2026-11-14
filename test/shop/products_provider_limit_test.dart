import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/shop/data/shop_repository.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/providers/shop_providers.dart';

/// 실제 Firestore처럼 limit을 지키는 가짜 저장소 — 넘겨받은 limit을 기록한다.
class _LimitingRepository implements ShopRepository {
  final List<Product> products;
  final limits = <int>[];

  _LimitingRepository(this.products);

  @override
  Future<ProductPage> fetchProducts({
    ProductCategory? category,
    PetTypeTag? petType,
    LifeStageTag? lifeStage,
    int limit = 20,
    Object? cursor,
  }) async {
    limits.add(limit);
    return ProductPage(
      products: [for (final p in products) if (category == null || p.category == category) p].take(limit).toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

Product _product(int i, ProductCategory category) => Product(
      id: 'p$i',
      sellerId: 'aggaeng',
      name: '상품 $i',
      category: category,
      price: 1000,
      status: ProductStatus.active,
      sortOrder: i,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  test('스토어 홈은 판매 상품 27개를 모두 불러온다(예전 기본 20개 제한 없음), 카테고리를 바꿔도 같다', () async {
    final repo = _LimitingRepository([
      for (var i = 0; i < 18; i++) _product(i, ProductCategory.apparel),
      for (var i = 18; i < 27; i++) _product(i, ProductCategory.living),
    ]);
    final container = ProviderContainer(overrides: [shopRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    final sub = container.listen(productsProvider, (_, _) {});
    addTearDown(sub.close);

    expect((await container.read(productsProvider.future)).products, hasLength(27));

    container.read(shopCategoryFilterProvider.notifier).state = ProductCategory.apparel;
    expect((await container.read(productsProvider.future)).products, hasLength(18));

    expect(repo.limits, everyElement(kShopCatalogLimit));
    expect(kShopCatalogLimit, greaterThanOrEqualTo(100));
  });
}
