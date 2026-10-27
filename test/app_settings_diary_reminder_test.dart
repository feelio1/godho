import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/data/app_settings.dart';

/// 일기 알림 설정("일기 활성화" 지시서 K) — 기본은 꺼짐·기본 시간이고,
/// 예약 알림(settings_notifications_enabled_v1)과 완전히 다른 키를 쓴다
/// (서로 영향을 주지 않는다).
void main() {
  const settings = AppSettings();

  test('기본값은 꺼짐, 기본 시간은 21:00이다', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await settings.diaryReminderEnabled(), isFalse);
    final time = await settings.diaryReminderTime();
    expect(time.hour, AppSettings.diaryReminderDefaultHour);
    expect(time.minute, AppSettings.diaryReminderDefaultMinute);
  });

  test('켜고/시간을 바꾸면 그대로 저장된다', () async {
    SharedPreferences.setMockInitialValues({});
    await settings.setDiaryReminderEnabled(true);
    await settings.setDiaryReminderTime(hour: 7, minute: 30);

    expect(await settings.diaryReminderEnabled(), isTrue);
    final time = await settings.diaryReminderTime();
    expect(time.hour, 7);
    expect(time.minute, 30);
  });

  test('3번째 저장 직후 묻는 기준 — 1씩 늘어난다', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await settings.incrementDiarySaveCount(), 1);
    expect(await settings.incrementDiarySaveCount(), 2);
    expect(await settings.incrementDiarySaveCount(), 3);
  });

  test('알림 동의를 한 번 물었다고 표시하면 다시 물을 필요가 없다고 나온다', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await settings.diaryReminderPromptShown(), isFalse);
    await settings.setDiaryReminderPromptShown();
    expect(await settings.diaryReminderPromptShown(), isTrue);
  });

  test('예약 알림 설정과는 별개 키라 서로 영향을 주지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    await settings.setNotificationsEnabled(false);
    await settings.setDiaryReminderEnabled(true);

    expect(await settings.notificationsEnabled(), isFalse);
    expect(await settings.diaryReminderEnabled(), isTrue);
  });
}
