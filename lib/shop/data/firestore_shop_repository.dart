import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../models/shop_order.dart';
import 'shop_repository.dart';

/// [ShopRepository]의 Firestore 구현 — 생성자 주입으로 [FirebaseFirestore]
/// 인스턴스를 바꿔 끼울 수 있다(`fake_cloud_firestore` 등), `UserRepository`
/// 와 같은 관례.
class FirestoreShopRepository implements ShopRepository {
  FirestoreShopRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _products => _firestore.collection('products');

  CollectionReference<Map<String, dynamic>> get _sellers => _firestore.collection('sellers');

  CollectionReference<Map<String, dynamic>> get _orders => _firestore.collection('orders');

  CollectionReference<Map<String, dynamic>> _cart(String uid) =>
      _firestore.collection('users').doc(uid).collection('cart');

  @override
  Future<ProductPage> fetchProducts({
    ProductCategory? category,
    PetTypeTag? petType,
    LifeStageTag? lifeStage,
    int limit = 20,
    Object? cursor,
  }) async {
    // 앱은 draft/hidden을 절대 보지 않는다 — active/soldout만
    // (`firestore.rules`가 같은 조건으로 읽기를 제한한다).
    Query<Map<String, dynamic>> query = _products.where('status', whereIn: [
      ProductStatus.active.name,
      ProductStatus.soldout.name,
    ]);
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    if (petType != null) {
      query = query.where('petTypes', arrayContains: petType.name);
    }
    if (lifeStage != null) {
      query = query.where('lifeStages', arrayContains: lifeStage.name);
    }
    query = query.orderBy('sortOrder').limit(limit);
    if (cursor is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    final products = snapshot.docs.map((doc) => Product.fromFirestore(doc.id, doc.data())).toList();
    return ProductPage(
      products: products,
      cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  @override
  Future<Product?> fetchProduct(String productId) async {
    final doc = await _products.doc(productId).get();
    final data = doc.data();
    if (data == null) return null;
    return Product.fromFirestore(doc.id, data);
  }

  @override
  Future<Seller?> fetchSeller(String sellerId) async {
    final doc = await _sellers.doc(sellerId).get();
    final data = doc.data();
    if (data == null) return null;
    return Seller.fromFirestore(doc.id, data);
  }

  @override
  Stream<List<CartItem>> streamCart(String uid) {
    return _cart(uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => CartItem.fromFirestore(doc.id, doc.data())).toList());
  }

  @override
  Future<void> addToCart(String uid, {required String productId, String? optionId, int quantity = 1}) async {
    // 같은 상품(+같은 옵션)이 이미 담겨 있으면 수량만 더한다 — 장바구니에
    // 중복 줄이 생기지 않게.
    final existing = await _cart(uid)
        .where('productId', isEqualTo: productId)
        .where('optionId', isEqualTo: optionId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.single;
      final current = (doc.data()['quantity'] as num?)?.toInt() ?? 0;
      await doc.reference.update({'quantity': current + quantity});
      return;
    }
    await _cart(uid).add(
      CartItem(id: '', productId: productId, optionId: optionId, quantity: quantity, addedAt: DateTime.now())
          .toFirestore(),
    );
  }

  @override
  Future<void> updateCartQuantity(String uid, String itemId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(uid, itemId);
      return;
    }
    await _cart(uid).doc(itemId).update({'quantity': quantity});
  }

  @override
  Future<void> removeFromCart(String uid, String itemId) async {
    await _cart(uid).doc(itemId).delete();
  }

  @override
  Future<void> clearCart(String uid) async {
    final docs = await _cart(uid).get();
    final batch = _firestore.batch();
    for (final doc in docs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<ShopOrder> createPendingOrder({
    required String uid,
    required List<OrderItem> items,
    required Map<String, int> shippingFees,
    required ShippingAddress shippingAddress,
  }) async {
    final itemsTotal = items.fold<int>(0, (total, item) => total + item.lineTotal);
    final shippingTotal = shippingFees.values.fold<int>(0, (total, fee) => total + fee);
    final now = DateTime.now();
    final order = ShopOrder(
      id: '',
      uid: uid,
      status: OrderStatus.pendingPayment,
      createdAt: now,
      updatedAt: now,
      items: items,
      shippingFees: shippingFees,
      itemsTotal: itemsTotal,
      shippingTotal: shippingTotal,
      grandTotal: itemsTotal + shippingTotal,
      shippingAddress: shippingAddress,
    );
    final doc = await _orders.add(order.toFirestore());
    return ShopOrder.fromFirestore(doc.id, order.toFirestore());
  }

  @override
  Stream<List<ShopOrder>> streamMyOrders(String uid) {
    return _orders
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ShopOrder.fromFirestore(doc.id, doc.data())).toList());
  }

  @override
  Future<ShopOrder?> fetchOrder(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    final data = doc.data();
    if (data == null) return null;
    return ShopOrder.fromFirestore(doc.id, data);
  }
}
