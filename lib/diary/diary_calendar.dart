import '../utils/appointment_calendar.dart' show dateOnly;
import 'models/diary.dart';

/// 일기 목록을 날짜(시각 제외)별로 묶는다 — `groupRecordsByDate`/
/// `groupAppointmentsByDate`와 같은 방식("방향 개편" 지시서 E, 캘린더
/// 일기 마커·목록에 쓴다). 하루에 여러 편 작성을 허용하므로 한 날짜에
/// 여러 일기가 묶일 수 있다.
Map<DateTime, List<Diary>> groupDiariesByDate(List<Diary> diaries) {
  final byDate = <DateTime, List<Diary>>{};
  for (final diary in diaries) {
    byDate.putIfAbsent(dateOnly(diary.date), () => []).add(diary);
  }
  return byDate;
}
