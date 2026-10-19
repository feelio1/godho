import 'package:flutter_riverpod/legacy.dart';

/// 홈의 "우리 아이" 카드(가장 가까운 예약)에서 우리 아이 탭의 캘린더
/// 보기로 넘어갈 때 "이 반려동물·이 날짜를 보여줘"라고 전달하는 1회성
/// 요청("출시 전 마무리" 지시서 C, "탭 개편" 지시서 A). `PetTabScreen`이
/// 빌드 시점에 이 값을 읽어 자기 내부 선택 상태에 반영하고 곧바로 null로
/// 비운다 — 두 번째 진입부터는 평소처럼 사용자가 마지막으로 보던 날짜를
/// 유지한다.
class CalendarFocusRequest {
  final String petId;
  final DateTime date;

  const CalendarFocusRequest({required this.petId, required this.date});
}

final calendarFocusRequestProvider = StateProvider<CalendarFocusRequest?>((ref) => null);
