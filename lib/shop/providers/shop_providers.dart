import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../config/feature_flags.dart';
import '../../providers/auth_provider.dart';
import '../../providers/effective_pets_provider.dart';
import '../data/firestore_shop_repository.dart';
import '../data/shop_repository.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/seller.dart';
import '../models/shop_order.dart';
import '../recommend.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) => FirestoreShopRepository());

/// `config/shop` 문서를 읽을 [FirebaseFirestore] 인스턴스 — 테스트가
/// `fake_cloud_firestore`로 바꿔 끼울 수 있게 별도 provider로 뺐다.
final shopFirestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// 런타임 스위치("쇼핑 기초" 지시서 1) — 컴파일 플래그 [kEnableShopCode]가
/// false면 Firestore를 아예 조회하지 않고 늘 false. true여도 `config/shop`
/// 문서가 없거나, `enabled` 필드가 없거나, 읽기 자체가 실패하면(오프라인·
/// 권한 등) false다 — 기본값은 항상 닫힘(fail-closed)이라 설정이 아직
/// 없는 상태에서 실수로 열리는 일이 없다.
final shopEnabledProvider = StreamProvider<bool>((ref) {
  if (!kEnableShopCode) return Stream.value(false);
  return _watchShopEnabled(ref.watch(shopFirestoreProvider));
});

Stream<bool> _watchShopEnabled(FirebaseFirestore firestore) async* {
  try {
    yield* firestore.collection('config').doc('shop').snapshots().map((doc) {
      final data = doc.data();
      return data?['enabled'] as bool? ?? false;
    });
  } catch (_) {
    yield false;
  }
}

/// 스토어 홈의 카테고리 칩 선택 상태.
final shopCategoryFilterProvider = StateProvider<ProductCategory?>((ref) => null);

/// 스토어 홈 첫 페이지(20개, 카테고리 필터 적용) — 더 보기(페이지네이션)는
/// 화면이 직접 [ShopRepository.fetchProducts]를 커서와 함께 다시 불러
/// 처리한다(이 provider는 "처음 진입/필터 바뀜" 경로만 맡는다).
final productsProvider = FutureProvider.autoDispose<ProductPage>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  final category = ref.watch(shopCategoryFilterProvider);
  return repo.fetchProducts(category: category);
});

final productProvider = FutureProvider.autoDispose.family<Product?, String>((ref, productId) {
  return ref.watch(shopRepositoryProvider).fetchProduct(productId);
});

final sellerProvider = FutureProvider.autoDispose.family<Seller?, String>((ref, sellerId) {
  return ref.watch(shopRepositoryProvider).fetchSeller(sellerId);
});

/// 장바구니 — 비로그인(게스트)이면 항상 빈 목록(구매 관련 동작은 로그인
/// 필요, "쇼핑 기초" 지시서 5).
final cartProvider = StreamProvider.autoDispose<List<CartItem>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(shopRepositoryProvider).streamCart(uid);
});

final cartItemCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(cartProvider).value ?? const [];
  return items.fold<int>(0, (total, item) => total + item.quantity);
});

/// "우리 아이에게 맞는" 추천 — 로그인 + 반려동물이 있을 때만. 종·체중·
/// 생애주기 태그로만 거른다(CLAUDE.md: 진료기록·예약 데이터 기반 추천
/// 금지 — [filterRecommendedProducts]는 [Pet] 프로필만 본다).
final recommendedProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const [];

  final pets = await ref.watch(effectivePetsProvider.future);
  if (pets.isEmpty) return const [];

  final page = await ref.watch(productsProvider.future);
  return filterRecommendedProducts(page.products, pets);
});

final myOrdersProvider = StreamProvider.autoDispose<List<ShopOrder>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(shopRepositoryProvider).streamMyOrders(uid);
});

final orderProvider = FutureProvider.autoDispose.family<ShopOrder?, String>((ref, orderId) {
  return ref.watch(shopRepositoryProvider).fetchOrder(orderId);
});
