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

  String get label {
    if (sido == null) return '전체';
    if (sigungu == null) return '$sido 전체';
    return '$sido $sigungu';
  }

  /// Short label for compact UI (e.g. app bar region chip).
  String get shortLabel {
    if (sido == null) return '전체';
    if (sigungu == null) return sido!;
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
