import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/diary/diary_reminder_prompt.dart';

/// 일기 알림 동의를 물어야 하는지 판단하는 순수 로직("일기 수정"
/// 지시서 3) — "정확히 3"이 아니라 "3편 이상"이고, 이미 물었거나
/// 알림이 이미 켜져 있으면 묻지 않는다.
void main() {
  group('shouldPromptDiaryReminder', () {
    test('일기 2편이면 묻지 않는다', () {
      expect(
        shouldPromptDiaryReminder(diaryCount: 2, alreadyAsked: false, reminderEnabled: false),
        isFalse,
      );
    });

    test('일기 3편 이상이고 아직 안 물었으면 한 번 묻는다', () {
      expect(
        shouldPromptDiaryReminder(diaryCount: 3, alreadyAsked: false, reminderEnabled: false),
        isTrue,
      );
      expect(
        shouldPromptDiaryReminder(diaryCount: 10, alreadyAsked: false, reminderEnabled: false),
        isTrue,
      );
    });

    test('이미 물었으면 일기 수가 많아도 묻지 않는다', () {
      expect(
        shouldPromptDiaryReminder(diaryCount: 10, alreadyAsked: true, reminderEnabled: false),
        isFalse,
      );
    });

    test('알림이 이미 켜져 있으면 묻지 않는다', () {
      expect(
        shouldPromptDiaryReminder(diaryCount: 10, alreadyAsked: false, reminderEnabled: true),
        isFalse,
      );
    });
  });
}
