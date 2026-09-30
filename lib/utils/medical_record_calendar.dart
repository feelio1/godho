import '../models/medical_record.dart';
import 'appointment_calendar.dart' show dateOnly;

/// 진료기록 목록을 날짜(시각 제외)별로 묶는다 — [dateOnly]/
/// `groupAppointmentsByDate`(appointment_calendar.dart)와 같은 방식으로,
/// 캘린더 화면이 진료기록·예약 두 데이터를 같은 날짜 키로 합쳐 보여줄 수
/// 있게 한다("캘린더 하단탭화 + 진료 연대기" 지시서 2, 4 — 새 저장소 없이
/// 기존 두 로컬 저장소를 그대로 읽어 합치기만 한다).
Map<DateTime, List<MedicalRecord>> groupRecordsByDate(List<MedicalRecord> records) {
  final byDate = <DateTime, List<MedicalRecord>>{};
  for (final record in records) {
    byDate.putIfAbsent(dateOnly(record.date), () => []).add(record);
  }
  return byDate;
}
