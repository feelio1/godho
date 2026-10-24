import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/models/seller.dart';
import 'package:petcliniccheck/shop/pricing.dart';

Product _product({
  required String id,
  required String sellerId,
  int price = 10000,
  int? salePrice,
  ProductStatus status = ProductStatus.active,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    sellerId: sellerId,
    name: '상품 $id',
    price: price,
    salePrice: salePrice,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

Seller _seller(String id, {int baseFee = 3000, int? freeOver, int extraJejuFee = 0}) => Seller(
      id: id,
      name: '판매자 $id',
      shipping: ShippingPolicy(baseFee: baseFee, freeOver: freeOver, extraJejuFee: extraJejuFee),
      status: SellerStatus.active,
    );

void main() {
  group('summarizeCart — "쇼핑 기초" 지시서 4', () {
    test('브랜드 2곳이 각자 소계·배송비로 나뉘고, 총액은 둘을 합친 값이다', () {
      final sellerA = _seller('A', baseFee: 3000);
      final sellerB = _seller('B', baseFee: 2500);
      final lines = [
        CartLine(product: _product(id: 'p1', sellerId: 'A', price: 10000), quantity: 2), // 20000
        CartLine(product: _product(id: 'p2', sellerId: 'B', price: 5000), quantity: 1), // 5000
      ];

      final summary = summarizeCart(lines, sellersById: {'A': sellerA, 'B': sellerB});

      expect(summary.sellerGroups, hasLength(2));
      final groupA = summary.sellerGroups.firstWhere((g) => g.sellerId == 'A');
      final groupB = summary.sellerGroups.firstWhere((g) => g.sellerId == 'B');
      expect(groupA.subtotal, 20000);
      expect(groupA.shippingFee, 3000);
      expect(groupB.subtotal, 5000);
      expect(groupB.shippingFee, 2500);
      expect(summary.itemsTotal, 25000);
      expect(summary.shippingTotal, 5500);
      expect(summary.grandTotal, 30500);
    });

    test('무료배송 기준(freeOver) 이상이면 기본 배송비가 면제된다', () {
      final seller = _seller('A', baseFee: 3000, freeOver: 50000);
      final under = summarizeCart(
        [CartLine(product: _product(id: 'p1', sellerId: 'A', price: 49000), quantity: 1)],
        sellersById: {'A': seller},
      );
      expect(under.sellerGroups.single.shippingFee, 3000);

      final over = summarizeCart(
        [CartLine(product: _product(id: 'p1', sellerId: 'A', price: 50000), quantity: 1)],
        sellersById: {'A': seller},
      );
      expect(over.sellerGroups.single.shippingFee, 0);
    });

    test('freeOver가 없으면 소계가 아무리 커도 배송비는 면제되지 않는다', () {
      final seller = _seller('A', baseFee: 3000);
      final summary = summarizeCart(
        [CartLine(product: _product(id: 'p1', sellerId: 'A', price: 1000000), quantity: 1)],
        sellersById: {'A': seller},
      );
      expect(summary.sellerGroups.single.shippingFee, 3000);
    });

    test('제주 추가 배송비는 무료배송 여부와 무관하게 더해진다', () {
      final seller = _seller('A', baseFee: 3000, freeOver: 50000, extraJejuFee: 5000);
      final summary = summarizeCart(
        [CartLine(product: _product(id: 'p1', sellerId: 'A', price: 60000), quantity: 1)],
        sellersById: {'A': seller},
        isJeju: true,
      );
      expect(summary.sellerGroups.single.shippingFee, 5000); // 기본 배송비는 면제, 제주 추가만 남음
    });

    test('품절(상품 soldout, 옵션 soldOut)은 결제 대상에서 제외된다', () {
      final seller = _seller('A');
      final soldOutProduct = CartLine(
        product: _product(id: 'p1', sellerId: 'A', price: 10000, status: ProductStatus.soldout),
        quantity: 1,
      );
      final soldOutOption = CartLine(
        product: _product(id: 'p2', sellerId: 'A', price: 10000),
        option: const ProductOption(id: 'o1', name: '품절옵션', soldOut: true),
        quantity: 1,
      );
      final normal = CartLine(product: _product(id: 'p3', sellerId: 'A', price: 7000), quantity: 1);

      final summary = summarizeCart([soldOutProduct, soldOutOption, normal], sellersById: {'A': seller});

      expect(summary.sellerGroups, hasLength(1));
      expect(summary.sellerGroups.single.lines, hasLength(1));
      expect(summary.itemsTotal, 7000);
    });

    test('할인가가 있으면 할인가 기준으로 계산한다', () {
      final seller = _seller('A');
      final summary = summarizeCart(
        [CartLine(product: _product(id: 'p1', sellerId: 'A', price: 10000, salePrice: 8000), quantity: 3)],
        sellersById: {'A': seller},
      );
      expect(summary.itemsTotal, 24000);
    });

    test('옵션 추가금은 수량만큼 곱해져 더해진다', () {
      final seller = _seller('A');
      final summary = summarizeCart(
        [
          CartLine(
            product: _product(id: 'p1', sellerId: 'A', price: 10000),
            option: const ProductOption(id: 'o1', name: '큰 사이즈', extraPrice: 2000),
            quantity: 2,
          ),
        ],
        sellersById: {'A': seller},
      );
      expect(summary.itemsTotal, 24000); // (10000+2000) * 2
    });

    test('구매 가능한 줄이 없으면 빈 합계를 돌려준다', () {
      final summary = summarizeCart(const [], sellersById: const {});
      expect(summary.sellerGroups, isEmpty);
      expect(summary.grandTotal, 0);
    });
  });
}
