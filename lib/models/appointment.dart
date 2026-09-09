import 'reminder_offset.dart';

/// 진료 예약 한 건(스프린트 9 지시서 3). `MedicalRecord`와 마찬가지로 병원은
/// 우리 DB에서 고른 병원(`hospitalId`)일 수도, 직접 입력한 이름일 수도
/// 있다. 순수 데이터 + JSON 직렬화만 갖고 저장 방식에는 관여하지 않는다.
class Appointment {
  final String id;
  final String petId;
  final DateTime dateTime;
  final String? hospitalId;
  final String hospitalName;

  /// 진료 내용(예: 발치, 중성화) — 자유 입력, 판정 문구 아님.
  final String reason;
  final String memo;
  final List<ReminderOffset> reminders;

  const Appointment({
    required this.id,
    required this.petId,
    required this.dateTime,
    this.hospitalId,
    required this.hospitalName,
    this.reason = '',
    this.memo = '',
    this.reminders = const [],
  });

  bool get isUpcoming => dateTime.isAfter(DateTime.now());

  Appointment copyWith({
    DateTime? dateTime,
    String? hospitalId,
    String? hospitalName,
    String? reason,
    String? memo,
    List<ReminderOffset>? reminders,
    bool clearHospitalId = false,
  }) {
    return Appointment(
      id: id,
      petId: petId,
      dateTime: dateTime ?? this.dateTime,
      hospitalId: clearHospitalId ? null : (hospitalId ?? this.hospitalId),
      hospitalName: hospitalName ?? this.hospitalName,
      reason: reason ?? this.reason,
      memo: memo ?? this.memo,
      reminders: reminders ?? this.reminders,
    );
  }

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        petId: json['petId'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        hospitalId: json['hospitalId'] as String?,
        hospitalName: json['hospitalName'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        memo: json['memo'] as String? ?? '',
        reminders: (json['reminders'] as List<dynamic>? ?? const [])
            .map((e) => ReminderOffset.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'dateTime': dateTime.toIso8601String(),
        'hospitalId': hospitalId,
        'hospitalName': hospitalName,
        'reason': reason,
        'memo': memo,
        'reminders': reminders.map((r) => r.toJson()).toList(),
      };
}
