import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/models/seller.dart';

/// `tool/shop_import/out/`에 커밋된 첫 상품 데이터(29개)와 판매자 문서가
/// 앱 모델로 그대로 읽히는지 — 타임스탬프 필드가 없어도 기본값으로 떨어진다.
void main() {
  test('products.json 29개가 전부 Product.fromFirestore로 파싱된다', () {
    final raw = jsonDecode(File('tool/shop_import/out/products.json').readAsStringSync()) as List<dynamic>;
    expect(raw, hasLength(29));
    final products = [
      for (final e in raw.cast<Map<String, dynamic>>()) Product.fromFirestore(e['id'] as String, e),
    ];
    expect(products.every((p) => p.sellerId == 'aggaeng'), isTrue);
    expect(products.every((p) => p.name.isNotEmpty && p.price > 0), isTrue);
    // 할인 연출 없음.
    expect(products.every((p) => p.salePrice == null && !p.isOnSale), isTrue);
    // 데이터에 들어 있는 새 필드가 그대로 읽힌다.
    expect(products.where((p) => p.category == ProductCategory.apparel), isNotEmpty);
    expect(products.where((p) => p.isBulky).length, 2);
    expect(products.where((p) => p.minQty == 10).length, 1);
    expect(products.where((p) => p.isDiscontinuing), isNotEmpty);
    expect(products.any((p) => p.category == ProductCategory.etc), isFalse);
    // 고시는 데이터의 noticeKeys 순서 그대로 보인다.
    for (final (i, p) in products.indexed) {
      final keys = (raw[i] as Map<String, dynamic>)['noticeKeys'] as List<dynamic>;
      expect(p.orderedNotice.map((e) => e.key).toList(), keys, reason: p.name);
    }
  });

  test('sellers.json 아깽이상점 배송 정책(3,000 / 30,000 / 따로 배송 4,000 / 제주 3,000)', () {
    final raw = jsonDecode(File('tool/shop_import/out/sellers.json').readAsStringSync()) as List<dynamic>;
    final data = (raw.single as Map<String, dynamic>);
    final seller = Seller.fromFirestore(data['id'] as String, data);
    expect(seller.id, 'aggaeng');
    expect(seller.name, '아깽이상점');
    expect(seller.shipping.baseFee, 3000);
    expect(seller.shipping.freeOver, 30000);
    expect(seller.shipping.bulkyFee, 4000);
    expect(seller.shipping.extraJejuFee, 3000);
  });
}
