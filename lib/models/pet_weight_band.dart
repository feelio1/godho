import 'fee.dart';

/// 반려동물 프로필 체중 구간 — 숫자 대신 구간 4개 중 하나를 고른다(2차
/// 업데이트 결정 6). 진료비 시세 체중 구간([FeeWeightBucket] u5/u10/u20)과
/// 맞췄고, 20kg 이상은 시세 자료에 따로 없어 10~20kg 시세로 본다.
/// 구간만 저장하고 가짜 kg 값을 만들어 넣지 않는다. 진료기록의 몸무게(진료
/// 때 잰 실제 kg)와는 별개다.
enum PetWeightBand {
  u5('5kg 미만', null, 5),
  u10('5~10kg', 5, 10),
  u20('10~20kg', 10, 20),
  o20('20kg 이상', 20, null);

  final String label;

  /// 구간 아래 끝(포함, kg) — null이면 0.
  final double? minKg;

  /// 구간 위 끝(미포함, kg) — null이면 상한 없음.
  final double? maxKg;

  const PetWeightBand(this.label, this.minKg, this.maxKg);

  /// 옛 데이터의 실제 체중(kg)이 속한 구간.
  static PetWeightBand fromKg(double kg) {
    if (kg < 5) return PetWeightBand.u5;
    if (kg < 10) return PetWeightBand.u10;
    if (kg < 20) return PetWeightBand.u20;
    return PetWeightBand.o20;
  }

  static PetWeightBand? fromName(String? value) {
    for (final band in PetWeightBand.values) {
      if (band.name == value) return band;
    }
    return null;
  }

  /// 진료비 시세 체중 구간 — 20kg 이상은 10~20kg 시세.
  FeeWeightBucket get feeBucket => switch (this) {
        PetWeightBand.u5 => FeeWeightBucket.u5,
        PetWeightBand.u10 => FeeWeightBucket.u10,
        PetWeightBand.u20 || PetWeightBand.o20 => FeeWeightBucket.u20,
      };

  /// 상품 체중 범위([minKg]~[maxKg], 양 끝 포함, null이면 열림)와 겹치는가.
  bool overlaps({double? minKg, double? maxKg}) {
    final lo = this.minKg ?? 0;
    final hi = this.maxKg ?? double.infinity;
    final productLo = minKg ?? 0;
    final productHi = maxKg ?? double.infinity;
    return lo <= productHi && productLo < hi;
  }
}

/// 실제로 쓸 체중 구간 — 고른 구간이 있으면 그것, 없으면 옛 kg 값으로 계산,
/// 둘 다 없으면 null(모름).
PetWeightBand? effectiveWeightBand({PetWeightBand? band, double? weightKg}) {
  if (band != null) return band;
  if (weightKg != null && weightKg > 0) return PetWeightBand.fromKg(weightKg);
  return null;
}
