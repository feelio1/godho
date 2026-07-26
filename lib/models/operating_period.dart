/// Operating-period bucket, computed from `continuousSince`.
///
/// This exists purely to describe how long a public record has been
/// continuously registered. It must never be presented as a trust or
/// quality signal (see CLAUDE.md 원칙 2).
enum OperatingPeriodCategory {
  over30,
  over20,
  over10,
  over5,
  over1,
  newHospital,
  unknown;

  String get label {
    switch (this) {
      case OperatingPeriodCategory.over30:
        return '운영 30년 이상';
      case OperatingPeriodCategory.over20:
        return '운영 20년 이상';
      case OperatingPeriodCategory.over10:
        return '운영 10년 이상';
      case OperatingPeriodCategory.over5:
        return '운영 5년 이상';
      case OperatingPeriodCategory.over1:
        return '운영 1년 이상';
      case OperatingPeriodCategory.newHospital:
        return '신규 (1년 미만)';
      case OperatingPeriodCategory.unknown:
        return '확인 불가';
    }
  }

  /// Neutral note shown alongside new/unknown hospitals so the absence of
  /// a long track record does not read as a negative signal.
  String? get neutralNote {
    switch (this) {
      case OperatingPeriodCategory.newHospital:
      case OperatingPeriodCategory.unknown:
        return '공개 데이터에서 확인할 수 있는 정보가 부족합니다.';
      default:
        return null;
    }
  }
}
