/// 그림일기에 찍는 날짜·기간 문구 — 엔진을 순수 Dart로 두려고 `intl`
/// 로케일 데이터 없이 직접 만든다.
library;

const _weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

/// "2026년 10월 28일 수요일"
String bookDateLabel(DateTime date) => '${date.year}년 ${date.month}월 ${date.day}일 ${_weekdays[date.weekday - 1]}';

/// "2026. 10 — 2026. 12" (같은 달이면 "2026. 10")
String bookPeriodLabel(DateTime start, DateTime end) {
  String ym(DateTime d) => '${d.year}. ${d.month.toString().padLeft(2, '0')}';
  final a = ym(start);
  final b = ym(end);
  return a == b ? a : '$a — $b';
}
