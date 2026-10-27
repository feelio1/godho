import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/diary/diary_draft.dart';
import 'package:petcliniccheck/diary/models/diary.dart';

/// 일기 작성 중 자동 임시저장("일기 활성화" 지시서 G) — 저장·복원이
/// 값을 그대로 보존하는지, 저장값이 없거나 깨졌을 때 안전하게 null로
/// 떨어지는지 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = DiaryDraftStore();

  test('저장값이 없으면 null이다', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await store.load(), isNull);
  });

  test('저장한 임시본을 그대로 복원한다', () async {
    SharedPreferences.setMockInitialValues({});
    final draft = DiaryDraft(
      date: DateTime(2026, 5, 1),
      petIds: const ['account:p1', 'p2'],
      weather: DiaryWeather.cloudy,
      activities: const [DiaryActivity.walk, DiaryActivity.treat],
      text: '산책하고 간식 먹었다',
      photoPaths: const ['/tmp/a.jpg', '/tmp/b.jpg'],
    );

    await store.save(draft);
    final restored = await store.load();

    expect(restored, isNotNull);
    expect(restored!.date, DateTime(2026, 5, 1));
    expect(restored.petIds, ['account:p1', 'p2']);
    expect(restored.weather, DiaryWeather.cloudy);
    expect(restored.activities, [DiaryActivity.walk, DiaryActivity.treat]);
    expect(restored.text, '산책하고 간식 먹었다');
    expect(restored.photoPaths, ['/tmp/a.jpg', '/tmp/b.jpg']);
  });

  test('clear 후에는 다시 null이다', () async {
    SharedPreferences.setMockInitialValues({});
    await store.save(DiaryDraft(date: DateTime(2026, 1, 1), petIds: const ['p1']));
    await store.clear();
    expect(await store.load(), isNull);
  });

  test('저장값이 깨졌으면(JSON 아님) null이다(하위호환 — 안전한 기본값)', () async {
    SharedPreferences.setMockInitialValues({'diary_draft_v1': 'not json at all {'});
    expect(await store.load(), isNull);
  });
}
