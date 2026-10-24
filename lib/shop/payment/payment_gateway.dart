import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shop_order.dart';

/// 결제 1건의 결과 — 실제 PG 연동 전이라 지금은 아무 구현체도 이걸 만들지
/// 않는다(테스트용 가짜 구현만 test/ 폴더에 둔다, "쇼핑 기초" 지시서 4).
class PaymentResult {
  final bool success;
  final String? txId;
  final String? errorMessage;

  const PaymentResult({required this.success, this.txId, this.errorMessage});
}

/// 결제 게이트웨이 인터페이스 — PG가 정해지면 이 하나만 구현하면 된다.
/// 지금은 구현체가 없고(`paymentGatewayProvider`가 항상 null), 결제 버튼은
/// 그 null을 보고 "결제 준비 중" 상태로 비활성화된다("쇼핑 기초" 지시서
/// 0·4 — "결제는 인터페이스만").
abstract class PaymentGateway {
  Future<PaymentResult> pay(ShopOrder order);
}

/// 구현체가 없으면 늘 null — 결제 버튼이 이 provider 하나만 보고 켜고
/// 끌 수 있게 한다. PG가 정해지면 이 provider만 실제 구현체로 바꾼다.
final paymentGatewayProvider = Provider<PaymentGateway?>((ref) => null);
