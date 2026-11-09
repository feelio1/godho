import 'models/product.dart';
import 'models/seller.dart';

/// 장바구니 한 줄 — 상품·(선택했으면) 옵션·수량. 순수 계산 입력이라
/// Firestore/Provider를 전혀 모른다.
class CartLine {
  final Product product;
  final ProductOption? option;
  final int quantity;

  const CartLine({required this.product, this.option, required this.quantity});

  /// 품절(상품 자체 soldout 상태 또는 고른 옵션이 soldOut)이면 결제 대상이
  /// 아니다("쇼핑 기초" 지시서 4 — "품절 제외").
  /// 최소 주문 수량([Product.minQty])에 못 미쳐도 결제 대상이 아니다.
  bool get isPurchasable =>
      product.isPurchasable && (option == null || !option!.soldOut) && quantity >= product.minQty;

  int get unitPrice => product.displayPrice + (option?.extraPrice ?? 0);

  int get lineTotal => unitPrice * quantity;
}

/// 판매자 한 곳 묶음의 소계·배송비·합계.
class SellerCartGroup {
  final String sellerId;
  final List<CartLine> lines;
  final int subtotal;
  final int shippingFee;

  /// [shippingFee] 중 따로 배송(bulky) 상품 몫 — 주문서 내역 표시용.
  final int bulkyFee;

  /// 따로 배송(bulky) 상품 종류 수.
  final int bulkyKinds;

  const SellerCartGroup({
    required this.sellerId,
    required this.lines,
    required this.subtotal,
    required this.shippingFee,
    this.bulkyFee = 0,
    this.bulkyKinds = 0,
  });

  /// [shippingFee] 중 일반 배송 몫(제주 추가 배송비 포함).
  int get standardFee => shippingFee - bulkyFee;

  int get total => subtotal + shippingFee;
}

/// 장바구니 전체 합계 — 브랜드별 묶음 + 상품 합계·배송비 합계·총액.
class CartSummary {
  final List<SellerCartGroup> sellerGroups;
  final int itemsTotal;
  final int shippingTotal;
  final int grandTotal;

  const CartSummary({
    required this.sellerGroups,
    required this.itemsTotal,
    required this.shippingTotal,
    required this.grandTotal,
  });

  static const empty = CartSummary(sellerGroups: [], itemsTotal: 0, shippingTotal: 0, grandTotal: 0);
}

/// 판매자 한 곳의 배송비 계산 결과.
class SellerShipping {
  final int total;
  final int bulkyFee;
  final int bulkyKinds;

  const SellerShipping({required this.total, this.bulkyFee = 0, this.bulkyKinds = 0});
}

/// 판매자 한 곳의 배송비(직판형 — 판매자 = 아깽이상점, 공급사 위탁배송):
/// - 일반(standard) 줄이 있으면: 일반 줄 소계만으로 무료배송 기준
///   ([ShippingPolicy.freeOver])을 판정해, 넘으면 0, 아니면 기본 배송비.
/// - 따로 배송(bulky) 상품: 서로 다른 상품 1종마다 [ShippingPolicy.bulkyFee]
///   (같은 상품 여러 개는 1회), 무료배송 기준과 무관하게 항상 부과.
/// - 제주면 그룹당 [ShippingPolicy.extraJejuFee]를 1회만 더한다 — 실제로는
///   따로 가는 상자마다 붙을 수 있지만, 지금은 단순화해 한 번만 받는다.
SellerShipping sellerShipping(ShippingPolicy shipping, List<CartLine> lines, {bool isJeju = false}) {
  final standardLines = lines.where((l) => !l.product.isBulky).toList();
  var standardFee = 0;
  if (standardLines.isNotEmpty) {
    final standardSubtotal = standardLines.fold<int>(0, (sum, l) => sum + l.lineTotal);
    final freeOver = shipping.freeOver;
    final isFree = freeOver != null && standardSubtotal >= freeOver;
    standardFee = isFree ? 0 : shipping.baseFee;
  }
  final bulkyKinds = lines.where((l) => l.product.isBulky).map((l) => l.product.id).toSet().length;
  final bulkyFee = bulkyKinds * shipping.bulkyFee;
  final jejuFee = isJeju ? shipping.extraJejuFee : 0;
  return SellerShipping(total: standardFee + bulkyFee + jejuFee, bulkyFee: bulkyFee, bulkyKinds: bulkyKinds);
}

/// 장바구니(또는 "바로 구매" 한 줄)를 판매자별로 묶어 소계·배송비·총액을
/// 계산한다("쇼핑 기초" 지시서 4) — 품절 줄은 조용히 제외하고, 입력에
/// 없는 판매자id는(상품의 sellerId가 [sellersById]에 없으면) 배송비 없이
/// 소계만 반영한다(판매자 문서가 아직 안 보일 뿐 주문 자체를 막을 이유는
/// 없다 — 다만 이 경우는 설정 누락이므로 호출부가 경고할 수 있게 그
/// 판매자 그룹의 shippingFee는 0으로 둔다).
CartSummary summarizeCart(
  List<CartLine> lines, {
  required Map<String, Seller> sellersById,
  bool isJeju = false,
}) {
  final purchasable = lines.where((l) => l.isPurchasable && l.quantity > 0).toList();
  if (purchasable.isEmpty) return CartSummary.empty;

  final bySeller = <String, List<CartLine>>{};
  for (final line in purchasable) {
    bySeller.putIfAbsent(line.product.sellerId, () => []).add(line);
  }

  final groups = <SellerCartGroup>[];
  var itemsTotal = 0;
  var shippingTotal = 0;
  for (final entry in bySeller.entries) {
    final sellerId = entry.key;
    final sellerLines = entry.value;
    final subtotal = sellerLines.fold<int>(0, (sum, l) => sum + l.lineTotal);
    final seller = sellersById[sellerId];
    final shipping = seller != null ? sellerShipping(seller.shipping, sellerLines, isJeju: isJeju) : null;
    final fee = shipping?.total ?? 0;

    groups.add(SellerCartGroup(
      sellerId: sellerId,
      lines: sellerLines,
      subtotal: subtotal,
      shippingFee: fee,
      bulkyFee: shipping?.bulkyFee ?? 0,
      bulkyKinds: shipping?.bulkyKinds ?? 0,
    ));
    itemsTotal += subtotal;
    shippingTotal += fee;
  }

  return CartSummary(
    sellerGroups: groups,
    itemsTotal: itemsTotal,
    shippingTotal: shippingTotal,
    grandTotal: itemsTotal + shippingTotal,
  );
}
