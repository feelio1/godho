/// 진료비 시세 한 칸(지역×항목×체중구간)의 값. 대표값은 [mid](중간값) —
/// 평균은 극단값에 왜곡되므로 대표로 쓰지 않는다(CLAUDE.md 진료비 원칙 3).
class FeeValue {
  final int mid;
  final int min;
  final int max;

  /// min == max인 지역·항목 — 표본이 매우 적다고 보고 "참고용" 안내를
  /// 붙인다. 표본 수 자체는 원자료에 없으므로 구체적 개수는 표기하지
  /// 않는다(CLAUDE.md 진료비 원칙 4).
  final bool sampleLow;

  const FeeValue({
    required this.mid,
    required this.min,
    required this.max,
    required this.sampleLow,
  });

  factory FeeValue.fromJson(Map<String, dynamic> json) => FeeValue(
        mid: json['mid'] as int,
        min: json['min'] as int,
        max: json['max'] as int,
        sampleLow: json['sampleLow'] as bool? ?? false,
      );
}

/// 진료비 항목 하나(예: 초진 진찰료). 이름·카테고리는 CSV 원본 값을
/// tool/build_fees.py가 그대로 옮긴 것 — 앱에서 임의로 새 라벨을 붙이지
/// 않는다.
class FeeItem {
  final String id;
  final String name;
  final String category;
  final bool weightBased;

  const FeeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.weightBased,
  });

  factory FeeItem.fromJson(Map<String, dynamic> json) => FeeItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        weightBased: json['weightBased'] as bool? ?? false,
      );
}

/// 체중 기준 3단계 — 원자료(CSV)의 체중 구분(5·10·20kg)을 그대로 옮긴
/// 구간이다. 체중 무관 항목(백신·검사 등)은 이 값을 무시하고 항상
/// 하나의 값만 갖는다.
enum FeeWeightBucket {
  u5('5kg 미만'),
  u10('5~10kg'),
  u20('10~20kg');

  final String label;

  const FeeWeightBucket(this.label);

  static FeeWeightBucket fromKg(double kg) {
    if (kg < 5) return FeeWeightBucket.u5;
    if (kg < 10) return FeeWeightBucket.u10;
    return FeeWeightBucket.u20;
  }
}
