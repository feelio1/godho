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

/// "그날의 기록" 카드가 찾아볼 날짜를 우선순위대로 돌려준다 — 1년 전
/// 오늘, 그다음 한 달 전 오늘("일기 활성화" 지시서 I). 호출부가 순서대로
/// 찾아보다 먼저 걸리는 일기를 쓴다(둘 다 없으면 카드 없음). `DateTime`의
/// 월/일 보정(예: 2월 29일의 1년 전이 2월이 없는 해면 3월 1일로 밀림)을
/// 그대로 따른다 — 추정해서 다른 날로 바꾸지 않는다.
List<DateTime> onThisDayCandidates(DateTime today) {
  final day = dateOnly(today);
  return [
    DateTime(day.year - 1, day.month, day.day),
    DateTime(day.year, day.month - 1, day.day),
  ];
}

/// 이번 달에 일기를 쓴 날(중복 없이) — "이달의 기록" 집계·점줄에 쓴다
/// ("일기 활성화" 지시서 J). 연속·끊김 여부는 보지 않는다.
Set<DateTime> diaryRecordedDays(List<Diary> diaries) =>
    diaries.map((d) => dateOnly(d.date)).toSet();
