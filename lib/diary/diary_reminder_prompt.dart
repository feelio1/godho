/// 일기 알림 동의를 물어야 하는지("일기 수정" 지시서 3) — 기기 로컬
/// 누적 저장 횟수가 "정확히 3"일 때만 묻던 예전 조건을 없애고, 실제
/// 일기 수(Firestore)가 3편 이상이면 늦게라도(4편째든 10편째든) 아직
/// 안 물었을 때 한 번 묻는다. 알림이 이미 켜져 있으면 다시 물을 필요가
/// 없고, 이미 물었으면(수락·거절 상관없이) 다시 묻지 않는다.
bool shouldPromptDiaryReminder({
  required int diaryCount,
  required bool alreadyAsked,
  required bool reminderEnabled,
}) {
  if (reminderEnabled) return false;
  if (alreadyAsked) return false;
  return diaryCount >= 3;
}
