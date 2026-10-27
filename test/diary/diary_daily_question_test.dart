import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/diary_daily_question.dart';

/// 글 입력칸의 placeholder로 쓰는 "오늘의 질문"("일기 활성화" 지시서 F) —
/// 날짜로 30개를 순환하고, 같은 날짜면 항상 같은 질문을 돌려준다(강요
/// 없이 회색 안내만이라 매번 바뀌면 오히려 혼란스럽다).
void main() {
  group('diaryDailyQuestionFor', () {
    test('30개 질문은 전부 다르다', () {
      expect(kDiaryDailyQuestions.toSet(), hasLength(30));
    });

    test('모든 질문에 {pet} 자리가 있다', () {
      for (final q in kDiaryDailyQuestions) {
        expect(q.contains('{pet}'), isTrue, reason: q);
      }
    });

    test('같은 날짜면 언제 다시 봐도 같은 질문이다', () {
      final a = diaryDailyQuestionFor(DateTime(2026, 5, 1, 9), '몽이');
      final b = diaryDailyQuestionFor(DateTime(2026, 5, 1, 21), '몽이');
      expect(a, b);
    });

    test('30일 뒤는 같은 질문으로 돌아온다(순환)', () {
      final a = diaryDailyQuestionFor(DateTime(2026, 5, 1), '몽이');
      final b = diaryDailyQuestionFor(DateTime(2026, 5, 31), '몽이');
      expect(a, b);
    });

    test('반려동물 이름이 {pet} 자리에 들어간다', () {
      final q = diaryDailyQuestionFor(DateTime(2026, 5, 1), '몽이');
      expect(q.contains('몽이'), isTrue);
      expect(q.contains('{pet}'), isFalse);
    });

    test('기준일(2020-01-01) 이전 날짜도 범위 안의 질문을 돌려준다', () {
      final q = diaryDailyQuestionFor(DateTime(2019, 1, 1), '몽이');
      expect(kDiaryDailyQuestions.any((t) => q == t.replaceAll('{pet}', '몽이')), isTrue);
    });
  });
}
