import '../utils/region_display.dart';

/// A region scope for filtering search/nearby results.
///
/// `sido == null` means nationwide ("전체"). `sido` set with
/// `sigungu == null` means "that whole 시/도" ("전체" within a 시/도).
/// Both set narrows to a single 시/군/구.
class RegionFilter {
  final String? sido;
  final String? sigungu;

  const RegionFilter({this.sido, this.sigungu});

  const RegionFilter.all() : sido = null, sigungu = null;

  bool get isNationwide => sido == null;

  /// 화면에 보여줄 문자열 — [sido]는 표시 직전에만 [sidoDisplayLabel]로
  /// 축약한다. 조인·필터 등 내부 로직에 쓰이는 [sido] 값 자체는 그대로다.
  String get label {
    if (sido == null) return '전체';
    final sidoLabel = sidoDisplayLabel(sido!);
    if (sigungu == null) return '$sidoLabel 전체';
    return '$sidoLabel $sigungu';
  }

  /// Short label for compact UI (e.g. app bar region chip).
  String get shortLabel {
    if (sido == null) return '전체';
    if (sigungu == null) return sidoDisplayLabel(sido!);
    return sigungu!;
  }

  bool matches(String hospitalSido, String hospitalSigungu) {
    if (sido == null) return true;
    if (sido != hospitalSido) return false;
    if (sigungu == null) return true;
    return sigungu == hospitalSigungu;
  }

  Map<String, dynamic> toJson() => {'sido': sido, 'sigungu': sigungu};

  factory RegionFilter.fromJson(Map<String, dynamic> json) => RegionFilter(
        sido: json['sido'] as String?,
        sigungu: json['sigungu'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is RegionFilter && other.sido == sido && other.sigungu == sigungu;

  @override
  int get hashCode => Object.hash(sido, sigungu);

  @override
  String toString() => 'RegionFilter($label)';
}
