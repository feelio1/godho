import 'hospital_status.dart';
import 'operating_period.dart';

class Hospital {
  final String id;
  final String name;
  final HospitalStatus status;
  final String sido;
  final String sigungu;
  final String roadAddr;
  final String jibunAddr;
  final double? lat;
  final double? lng;
  final String? phone;
  final DateTime? openDate;
  final DateTime? closeDate;
  final DateTime? continuousSince;
  final bool merged;
  final String? timelineId;

  const Hospital({
    required this.id,
    required this.name,
    required this.status,
    required this.sido,
    required this.sigungu,
    required this.roadAddr,
    required this.jibunAddr,
    this.lat,
    this.lng,
    this.phone,
    this.openDate,
    this.closeDate,
    this.continuousSince,
    this.merged = false,
    this.timelineId,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'] as String,
      name: json['name'] as String,
      status: HospitalStatus.fromJson(json['status'] as String?),
      sido: json['sido'] as String? ?? '',
      sigungu: json['sigungu'] as String? ?? '',
      roadAddr: json['roadAddr'] as String? ?? '',
      jibunAddr: json['jibunAddr'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      openDate: _parseDate(json['openDate']),
      closeDate: _parseDate(json['closeDate']),
      continuousSince: _parseDate(json['continuousSince']),
      merged: json['merged'] as bool? ?? false,
      timelineId: json['timelineId'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  bool get hasCoordinates => lat != null && lng != null;

  /// Full years of continuous registration, ending at `closeDate` for
  /// closed hospitals or today for open ones. Null when `continuousSince`
  /// is not available in the public data — never estimated.
  int? get operatingYears {
    final since = continuousSince;
    if (since == null) return null;
    final end = status == HospitalStatus.closed
        ? (closeDate ?? DateTime.now())
        : DateTime.now();
    if (end.isBefore(since)) return 0;
    var years = end.year - since.year;
    final anniversaryPassed = (end.month > since.month) ||
        (end.month == since.month && end.day >= since.day);
    if (!anniversaryPassed) years -= 1;
    return years < 0 ? 0 : years;
  }

  OperatingPeriodCategory get operatingPeriodCategory {
    final years = operatingYears;
    if (years == null) return OperatingPeriodCategory.unknown;
    if (years >= 30) return OperatingPeriodCategory.over30;
    if (years >= 20) return OperatingPeriodCategory.over20;
    if (years >= 10) return OperatingPeriodCategory.over10;
    if (years >= 5) return OperatingPeriodCategory.over5;
    if (years >= 1) return OperatingPeriodCategory.over1;
    return OperatingPeriodCategory.newHospital;
  }

  String get operatingPeriodLabel => operatingPeriodCategory.label;
}
