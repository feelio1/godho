import 'package:intl/intl.dart';

final _commaFormat = NumberFormat('#,###');

/// 큰 대표값(중간값) 표시용 — 만원 단위로 딱 떨어지면 "1만원"처럼 짧게,
/// 아니면 반올림하지 않고 정확한 금액을 그대로 보여준다(추정·반올림
/// 없이 정직하게, CLAUDE.md 원칙 5).
String feeWonLabel(int amount) {
  if (amount > 0 && amount % 10000 == 0) {
    return '${amount ~/ 10000}만원';
  }
  return '${_commaFormat.format(amount)}원';
}

/// 범위 표시용 — 항상 정확한 금액을 콤마와 함께("5,000~22,000원").
String feeWonRangeLabel(int min, int max) =>
    '${_commaFormat.format(min)}~${_commaFormat.format(max)}원';
