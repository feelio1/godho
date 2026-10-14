import '../models/appointment.dart';

/// 지난 예약 중 "진료 받으셨어요?" 확인이 필요한 1건을 고른다("지난
/// 예약 확인" 지시서 1) — 예약 시각+1시간이 지났고, 최근 30일 이내이며,
/// 아직 처리되지 않은(followUp이 null인) 예약 중 가장 오래된 것. 여러
/// 반려동물의 예약을 한 리스트로 모아 넘겨도 된다(각 [Appointment]가
/// 이미 petId를 들고 있다).
Appointment? selectFollowUpAppointment(List<Appointment> appointments, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  Appointment? oldest;
  for (final appointment in appointments) {
    if (appointment.followUp != null) continue;
    final dueAt = appointment.dateTime.add(const Duration(hours: 1));
    if (!clock.isAfter(dueAt)) continue;
    if (clock.difference(appointment.dateTime) > const Duration(days: 30)) continue;
    if (oldest == null || appointment.dateTime.isBefore(oldest.dateTime)) {
      oldest = appointment;
    }
  }
  return oldest;
}
