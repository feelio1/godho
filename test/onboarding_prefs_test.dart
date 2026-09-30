import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:petcliniccheck/data/onboarding_prefs.dart';

void main() {
  const prefs = OnboardingPrefs();

  test('처음 설치한 기기(값 없음)는 온보딩을 아직 안 본 것으로 취급한다', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await prefs.hasSeenOnboarding(), isFalse);
  });

  test('markOnboardingSeen 이후엔 hasSeenOnboarding이 true를 돌려준다(다시 실행해도 안 뜸)', () async {
    SharedPreferences.setMockInitialValues({});
    await prefs.markOnboardingSeen();
    expect(await prefs.hasSeenOnboarding(), isTrue);
  });

  test('이미 true로 저장된 값(예: 이전 실행)이 있으면 그대로 true다', () async {
    SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});
    expect(await prefs.hasSeenOnboarding(), isTrue);
  });
}
