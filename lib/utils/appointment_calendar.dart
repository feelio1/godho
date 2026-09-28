import '../models/appointment.dart';

/// 시각을 뺀 "그 날" — 같은 날이어도 시각이 다르면 다른 [DateTime]이라
/// [Map] 키나 `isSameDay` 비교에 그대로 쓰면 안 되므로 항상 이걸 거친다.
DateTime dateOnly(DateTime dateTime) => DateTime(dateTime.year, dateTime.month, dateTime.day);

/// 예약 목록을 날짜(시각 제외)별로 묶는다 — 캘린더 월 뷰의 날짜 마커와
/// 날짜별 목록이 이 그룹을 그대로 쓴다("예약 진료 캘린더" 지시서 1). 같은
/// 날 여러 건이면 원래 목록 순서(보통 시간 오름차순)를 그대로 유지한다.
Map<DateTime, List<Appointment>> groupAppointmentsByDate(List<Appointment> appointments) {
  final byDate = <DateTime, List<Appointment>>{};
  for (final appointment in appointments) {
    byDate.putIfAbsent(dateOnly(appointment.dateTime), () => []).add(appointment);
  }
  return byDate;
}
