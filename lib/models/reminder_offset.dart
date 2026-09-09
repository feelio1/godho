/// 예약 알림을 "며칠 전 + 몇 시"로 사용자가 직접 지정할 수 있게 하는 값
/// (스프린트 9 지시서 3 — 핵심). 한 예약에 여러 개를 둘 수 있다(예: 전날
/// 저녁 + 당일 아침).
class ReminderOffset {
  /// 0이면 예약 당일.
  final int daysBefore;
  final int hour;
  final int minute;

  const ReminderOffset({required this.daysBefore, required this.hour, required this.minute});

  /// 예약 [appointmentDateTime] 기준으로 이 알림이 실제로 울릴 시각.
  DateTime fireTimeFor(DateTime appointmentDateTime) {
    final day = DateTime(
      appointmentDateTime.year,
      appointmentDateTime.month,
      appointmentDateTime.day,
    ).subtract(Duration(days: daysBefore));
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  String get label {
    final time = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return daysBefore == 0 ? '당일 $time' : '$daysBefore일 전 $time';
  }

  factory ReminderOffset.fromJson(Map<String, dynamic> json) => ReminderOffset(
        daysBefore: json['daysBefore'] as int,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );

  Map<String, dynamic> toJson() => {
        'daysBefore': daysBefore,
        'hour': hour,
        'minute': minute,
      };

  @override
  bool operator ==(Object other) =>
      other is ReminderOffset &&
      other.daysBefore == daysBefore &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(daysBefore, hour, minute);
}
