import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/shop/models/cart_item.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/models/seller.dart';
import 'package:petcliniccheck/shop/models/shop_order.dart';

/// "쇼핑 기초" 지시서 2 — 모든 모델이 Firestore 왕복에서 값을 그대로
/// 보존하는지, 그리고 필드가 누락된(예전/다른 서비스가 쓴) 문서를 읽어도
/// 안전한 기본값으로 떨어지는지 확인한다. fake_cloud_firestore로 실제
/// Timestamp 변환까지 거쳐야 toFirestore/fromFirestore 쌍이 맞는지 제대로
/// 검증되므로, 순수 Map 대신 매번 컬렉션에 써서 다시 읽는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('Seller', () {
    test('toFirestore/fromFirestore 왕복에서 값이 보존된다', () async {
      const seller = Seller(
        id: 'ignored',
        name: '아깽이상점',
        brandName: '아깽이',
        ceoName: '김대표',
        bizRegNo: '123-45-67890',
        mailOrderNo: '2026-서울강남-0001',
        address: '서울시 강남구',
        csPhone: '02-1234-5678',
        csEmail: 'cs@example.com',
        shipping: ShippingPolicy(baseFee: 3000, freeOver: 50000, extraJejuFee: 5000, carrier: 'CJ대한통운', dispatchDays: 2),
        returnPolicy: ReturnPolicy(returnFee: 3000, exchangeFee: 6000, returnAddress: '서울시 강남구', note: '단순 변심 7일'),
        status: SellerStatus.active,
      );

      final ref = await firestore.collection('sellers').add(seller.toFirestore());
      final doc = await ref.get();
      final restored = Seller.fromFirestore(doc.id, doc.data()!);

      expect(restored.name, seller.name);
      expect(restored.bizRegNo, seller.bizRegNo);
      expect(restored.shipping.baseFee, 3000);
      expect(restored.shipping.freeOver, 50000);
      expect(restored.shipping.extraJejuFee, 5000);
      expect(restored.returnPolicy.returnFee, 3000);
      expect(restored.status, SellerStatus.active);
    });

    test('필드가 누락된 문서는 안전한 기본값으로 떨어진다(하위호환)', () async {
      final ref = await firestore.collection('sellers').add({'name': '이름만 있는 판매자'});
      final doc = await ref.get();
      final restored = Seller.fromFirestore(doc.id, doc.data()!);

      expect(restored.name, '이름만 있는 판매자');
      expect(restored.status, SellerStatus.paused);
      expect(restored.shipping.baseFee, 0);
      expect(restored.shipping.freeOver, isNull);
      expect(restored.returnPolicy.note, '');
    });
  });

  group('Product', () {
    test('toFirestore/fromFirestore 왕복에서 값이 보존된다', () async {
      final now = DateTime(2026, 1, 1);
      final product = Product(
        id: 'ignored',
        sellerId: 's1',
        name: '강아지 사료 1kg',
        category: ProductCategory.food,
        petTypes: const [PetTypeTag.dog],
        lifeStages: const [LifeStageTag.puppy, LifeStageTag.adult],
        weightMinKg: 2,
        weightMaxKg: 15,
        price: 20000,
        salePrice: 18000,
        images: const ['https://example.com/a.jpg'],
        description: '맛있어요',
        options: const [ProductOption(id: 'o1', name: '1kg', extraPrice: 0), ProductOption(id: 'o2', name: '3kg', extraPrice: 10000, soldOut: true)],
        notice: const {'원산지': '국내산'},
        status: ProductStatus.active,
        sortOrder: 5,
        createdAt: now,
        updatedAt: now,
      );

      final ref = await firestore.collection('products').add(product.toFirestore());
      final doc = await ref.get();
      final restored = Product.fromFirestore(doc.id, doc.data()!);

      expect(restored.name, product.name);
      expect(restored.category, ProductCategory.food);
      expect(restored.petTypes, [PetTypeTag.dog]);
      expect(restored.lifeStages, [LifeStageTag.puppy, LifeStageTag.adult]);
      expect(restored.weightMinKg, 2);
      expect(restored.weightMaxKg, 15);
      expect(restored.price, 20000);
      expect(restored.salePrice, 18000);
      expect(restored.displayPrice, 18000);
      expect(restored.isOnSale, isTrue);
      expect(restored.options, hasLength(2));
      expect(restored.options[1].soldOut, isTrue);
      expect(restored.notice['원산지'], '국내산');
      expect(restored.status, ProductStatus.active);
      expect(restored.isPurchasable, isTrue);
    });

    test('필드가 누락된 문서는 안전한 기본값으로 떨어진다(하위호환)', () async {
      final ref = await firestore.collection('products').add({'name': '이름만 있는 상품'});
      final doc = await ref.get();
      final restored = Product.fromFirestore(doc.id, doc.data()!);

      expect(restored.name, '이름만 있는 상품');
      expect(restored.price, 0);
      expect(restored.salePrice, isNull);
      expect(restored.displayPrice, 0);
      expect(restored.isOnSale, isFalse);
      expect(restored.petTypes, isEmpty);
      expect(restored.lifeStages, isEmpty);
      expect(restored.options, isEmpty);
      expect(restored.notice, isEmpty);
      expect(restored.status, ProductStatus.draft);
      expect(restored.isPurchasable, isFalse);
    });

    test('알 수 없는 카테고리/상태 값은 기타/draft로 안전하게 떨어진다', () async {
      final ref = await firestore.collection('products').add({
        'name': '미래의 카테고리',
        'category': 'future-category',
        'status': 'future-status',
      });
      final doc = await ref.get();
      final restored = Product.fromFirestore(doc.id, doc.data()!);

      expect(restored.category, ProductCategory.etc);
      expect(restored.status, ProductStatus.draft);
    });
  });

  group('CartItem', () {
    test('toFirestore/fromFirestore 왕복에서 값이 보존되고, 가격은 저장하지 않는다', () async {
      final item = CartItem(id: 'ignored', productId: 'p1', optionId: 'o1', quantity: 2, addedAt: DateTime(2026, 2, 1));
      final data = item.toFirestore();
      expect(data.containsKey('price'), isFalse);

      final ref = await firestore.collection('users').doc('u1').collection('cart').add(data);
      final doc = await ref.get();
      final restored = CartItem.fromFirestore(doc.id, doc.data()!);

      expect(restored.productId, 'p1');
      expect(restored.optionId, 'o1');
      expect(restored.quantity, 2);
    });

    test('copyWith로 수량만 바꿀 수 있다', () {
      final item = CartItem(id: 'c1', productId: 'p1', quantity: 1, addedAt: DateTime(2026, 2, 1));
      final updated = item.copyWith(quantity: 5);
      expect(updated.quantity, 5);
      expect(updated.productId, item.productId);
    });
  });

  group('ShopOrder', () {
    test('toFirestore/fromFirestore 왕복에서 items·배송비·주소가 보존된다', () async {
      final now = DateTime(2026, 3, 1);
      final order = ShopOrder(
        id: 'ignored',
        uid: 'u1',
        createdAt: now,
        updatedAt: now,
        items: const [
          OrderItem(productId: 'p1', sellerId: 's1', nameSnapshot: '사료', unitPrice: 18000, quantity: 2, lineTotal: 36000),
        ],
        shippingFees: const {'s1': 3000},
        itemsTotal: 36000,
        shippingTotal: 3000,
        grandTotal: 39000,
        shippingAddress: const ShippingAddress(name: '홍길동', phone: '010-0000-0000', zip: '12345', address1: '서울시 어딘가'),
      );

      final ref = await firestore.collection('orders').add(order.toFirestore());
      final doc = await ref.get();
      final restored = ShopOrder.fromFirestore(doc.id, doc.data()!);

      expect(restored.uid, 'u1');
      expect(restored.status, OrderStatus.pendingPayment);
      expect(restored.items, hasLength(1));
      expect(restored.items.single.lineTotal, 36000);
      expect(restored.shippingFees['s1'], 3000);
      expect(restored.grandTotal, 39000);
      expect(restored.shippingAddress.name, '홍길동');
      expect(restored.payment.isEmpty, isTrue);
      expect(restored.shipments, isEmpty);
    });

    test('필드가 누락된 문서는 안전한 기본값으로 떨어진다(하위호환)', () async {
      final ref = await firestore.collection('orders').add({'uid': 'u1'});
      final doc = await ref.get();
      final restored = ShopOrder.fromFirestore(doc.id, doc.data()!);

      expect(restored.status, OrderStatus.pendingPayment);
      expect(restored.items, isEmpty);
      expect(restored.itemsTotal, 0);
      expect(restored.shippingAddress.name, '');
    });
  });
}
