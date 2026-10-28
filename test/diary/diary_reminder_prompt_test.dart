import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/data/app_settings.dart';
import 'package:petcliniccheck/data/user_repository.dart';
import 'package:petcliniccheck/diary/diary_reminder_prompt.dart';
import 'package:petcliniccheck/models/app_user.dart';

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

  group('"물었음" 판단은 원격 필드만 본다 — 기기 로컬 옛 값은 무시한다("일기 재수정" 지시서 3-3)', () {
    test('기기 로컬에 옛 "물었음" 값이 true로 남아 있어도, 원격에 기록이 없으면 다시 물어야 한다', () async {
      // 이 기기 로컬(SharedPreferences)에는 옛 버그 버전이 남긴 "이미
      // 물음" 값이 true로 있다고 가정한다 — 새 판단 로직은 이 값을
      // 전혀 읽지 않으므로(UserRepository.diaryReminderAsked만 본다),
      // 원격에 기록이 없으면 여전히 물어야 한다는 결과가 나와야 한다.
      SharedPreferences.setMockInitialValues({'settings_diary_reminder_asked_v1': true});
      expect(await const AppSettings().diaryReminderPromptShown(), isTrue); // 옛 값은 실제로 남아 있다.

      final firestore = FakeFirebaseFirestore();
      final userRepo = UserRepository(firestore: firestore);
      final now = DateTime(2026, 1, 1);
      await userRepo.createUser(AppUser(uid: 'uid-legacy', loginType: LoginType.google, createdAt: now, updatedAt: now));

      // 판단에 쓰는 값은 오직 이것 하나다(diary_list_body.dart가 실제로
      // 넘기는 값과 같은 호출) — 로컬 값은 아예 들여다보지 않는다.
      final alreadyAsked = await userRepo.diaryReminderAsked('uid-legacy');
      expect(alreadyAsked, isFalse);
      expect(
        shouldPromptDiaryReminder(diaryCount: 5, alreadyAsked: alreadyAsked, reminderEnabled: false),
        isTrue,
      );
    });
  });
}
