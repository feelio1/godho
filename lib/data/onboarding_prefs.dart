import 'package:shared_preferences/shared_preferences.dart';

/// 첫 실행 온보딩을 "봤는지" 여부 — 최초 1회만 보여주고 이후엔 건너뛴다
/// (펫클 "캘린더 하단탭화 + 진료 연대기" 지시서 B1). SharedPreferences에만
/// 저장 — 계정과 무관해 로그인 여부와 상관없이 기기 단위로 한 번만 뜬다
/// (지시서 B2 "게스트도 봄").
class OnboardingPrefs {
  const OnboardingPrefs();

  static const _seenKey = 'onboarding_seen_v1';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
