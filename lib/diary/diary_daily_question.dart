import '../utils/appointment_calendar.dart' show dateOnly;

/// 일기 글 입력칸의 placeholder로 쓰는 날짜별 질문 30개("일기 활성화"
/// 지시서 F) — 강요 없이 회색 안내만. `{pet}`은 반려동물 이름으로
/// 바꿔 끼운다.
const List<String> kDiaryDailyQuestions = [
  '오늘 {pet}와 산책은 어디로 갔나요?',
  '오늘 {pet}가 가장 좋아한 간식은 뭐였나요?',
  '오늘 {pet}가 가장 신났던 순간은?',
  '오늘 {pet}는 어떤 표정을 지었나요?',
  '오늘 {pet}와 함께한 가장 즐거운 순간은?',
  '오늘 {pet}가 평소와 달랐던 점이 있었나요?',
  '오늘 {pet}는 몇 시간이나 잤나요?',
  '오늘 {pet}가 새로 배운 게 있나요?',
  '오늘 {pet}와 어떤 놀이를 했나요?',
  '오늘 {pet}의 기분은 어땠나요?',
  '오늘 {pet}가 만난 친구가 있었나요?',
  '오늘 {pet}는 무엇을 보고 신기해했나요?',
  '오늘 {pet}와 특별한 추억이 생겼나요?',
  '오늘 {pet}는 어디서 가장 편안해 보였나요?',
  '오늘 {pet}가 좋아하는 소리나 장난감이 있었나요?',
  '오늘 {pet}의 식사는 어땠나요?',
  '오늘 {pet}와 산책하며 본 풍경은 어땠나요?',
  '오늘 {pet}가 짖거나 울었던 이유가 있었나요?',
  '오늘 {pet}는 누구와 가장 많은 시간을 보냈나요?',
  '오늘 {pet}의 털 상태는 어땠나요?',
  '오늘 {pet}가 호기심을 보인 것이 있었나요?',
  '오늘 {pet}와 사진을 찍었다면, 그 순간은?',
  '오늘 {pet}는 어떤 자세로 가장 많이 쉬었나요?',
  '오늘 {pet}의 걸음걸이는 어땠나요?',
  '오늘 {pet}가 평소 안 하던 행동을 했나요?',
  '오늘 {pet}와 눈을 맞춘 순간이 있었나요?',
  '오늘 {pet}는 무엇에 가장 집중했나요?',
  '오늘 {pet}와 함께 있어 좋았던 이유는?',
  '오늘 {pet}가 궁금해하는 것처럼 보인 게 있었나요?',
  '오늘 {pet}에게 하고 싶은 말이 있나요?',
];

/// [date]로 30개 중 하나를 고정적으로 고른다(같은 날짜면 언제 다시 봐도
/// 같은 질문) — 날짜만 보고 시각은 무시한다. [petName]을 끼워 넣는다.
String diaryDailyQuestionFor(DateTime date, String petName) {
  final epoch = DateTime(2020, 1, 1);
  final days = dateOnly(date).difference(epoch).inDays;
  final index = days % kDiaryDailyQuestions.length;
  return kDiaryDailyQuestions[index].replaceAll('{pet}', petName);
}
