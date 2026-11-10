/// 전화번호를 지역번호 기준 하이픈 형식으로 — 화면 표시용이다. 저장값·전화
/// 걸기에는 원래 값을 그대로 쓴다. 알아볼 수 없는 형식이면 원래 값을 돌려준다
/// (추정해서 바꾸지 않는다).
///
/// - 02(서울): 02-XXX-XXXX / 02-XXXX-XXXX
/// - 050X(평생번호): 0505-XXX-XXXX / 0505-XXXX-XXXX
/// - 그 밖의 0XX(지역번호·010 등 휴대전화·070): 031-XXX-XXXX / 010-XXXX-XXXX
/// - 15XX·16XX·18XX(전국 대표번호, 8자리): 1588-XXXX
/// - 지역번호 없는 7·8자리(번들에 그런 값이 있다): XXX-XXXX / XXXX-XXXX
String formatPhoneNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return raw;

  String splitRest(String prefix, String rest) {
    if (rest.length == 7) return '$prefix-${rest.substring(0, 3)}-${rest.substring(3)}';
    if (rest.length == 8) return '$prefix-${rest.substring(0, 4)}-${rest.substring(4)}';
    return raw;
  }

  if (digits.startsWith('02')) return splitRest('02', digits.substring(2));
  if (RegExp(r'^050[2-8]').hasMatch(digits)) return splitRest(digits.substring(0, 4), digits.substring(4));
  if (digits.startsWith('0') && digits.length >= 10) return splitRest(digits.substring(0, 3), digits.substring(3));
  if (digits.length == 8 && RegExp(r'^1[568]').hasMatch(digits)) {
    return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }
  if (!digits.startsWith('0')) {
    if (digits.length == 7) return '${digits.substring(0, 3)}-${digits.substring(3)}';
    if (digits.length == 8) return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }
  return raw;
}
