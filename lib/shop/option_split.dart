import 'models/product.dart';

/// 상품 옵션을 화면에서만 색상 → 사이즈로 나눠 고르게 하는 도우미("장구름의
/// 수첩", 3차 업데이트 J-6). 데이터 구조는 바꾸지 않는다 — 모든 옵션 이름이
/// "색 / 사이즈" 꼴이고 색·사이즈가 각각 2가지 이상일 때만 나눈다.
class OptionAxes {
  final List<String> colors;
  final List<String> sizes;

  const OptionAxes(this.colors, this.sizes);

  /// 나눌 수 없으면 null(지금처럼 한 줄 칩).
  static OptionAxes? of(List<ProductOption> options) {
    if (options.length < 2) return null;
    final colors = <String>[];
    final sizes = <String>[];
    for (final o in options) {
      final parts = splitName(o.name);
      if (parts == null) return null;
      if (!colors.contains(parts.$1)) colors.add(parts.$1);
      if (!sizes.contains(parts.$2)) sizes.add(parts.$2);
    }
    if (colors.length < 2 && sizes.length < 2) return null;
    return OptionAxes(colors, sizes);
  }

  static (String, String)? splitName(String name) {
    final parts = name.split('/');
    if (parts.length != 2) return null;
    final color = parts[0].trim();
    final size = parts[1].trim();
    if (color.isEmpty || size.isEmpty) return null;
    return (color, size);
  }

  /// 색·사이즈 조합의 옵션(없으면 null).
  static ProductOption? find(List<ProductOption> options, String color, String size) {
    for (final o in options) {
      final parts = splitName(o.name);
      if (parts != null && parts.$1 == color && parts.$2 == size) return o;
    }
    return null;
  }
}

/// 상품정보제공고시 '치수' 값에서 한 사이즈의 치수를 한 줄로 —
/// "등길이/가슴둘레 XS 20/28 · S 25/34 · M 30/38 cm (±3cm)" →
/// "M 사이즈는 등길이 30cm, 가슴둘레 38cm예요. 재는 방법에 따라 3cm쯤 다를 수 있어요."
/// 꼴이 다르거나 그 사이즈가 없으면 null(추정하지 않는다).
String? sizeMeasureLine(String? notice, String size) {
  if (notice == null) return null;
  final match = RegExp(r'^\s*([^\s/]+)/([^\s/]+)\s+(.+?)\s*cm\s*(?:\(±\s*([\d.]+)\s*cm\))?\s*$').firstMatch(notice);
  if (match == null) return null;
  final labelA = match.group(1)!;
  final labelB = match.group(2)!;
  final tolerance = match.group(4);
  for (final entry in match.group(3)!.split('·')) {
    final m = RegExp(r'^\s*(\S+)\s+([\d.]+)/([\d.]+)\s*$').firstMatch(entry);
    if (m == null) return null;
    if (m.group(1) != size) continue;
    final base = '$size 사이즈는 $labelA ${m.group(2)}cm, $labelB ${m.group(3)}cm예요.';
    return tolerance == null ? base : '$base 재는 방법에 따라 ${tolerance}cm쯤 다를 수 있어요.';
  }
  return null;
}
