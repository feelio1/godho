import 'package:flutter/material.dart';

import '../data/onboarding_prefs.dart';
import '../theme/app_colors.dart';
import 'onboarding_screen.dart';

/// 앱 시작 시 온보딩을 이미 봤는지 확인해, 처음이면 [OnboardingScreen]을,
/// 이미 봤으면 [child](앱 본편)를 보여준다 — 최초 1회만, 로그인 여부와
/// 무관하다("캘린더 하단탭화 + 진료 연대기" 지시서 B1·B2).
class OnboardingGate extends StatefulWidget {
  final Widget child;

  const OnboardingGate({super.key, required this.child});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  static const _prefs = OnboardingPrefs();

  bool? _hasSeen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seen = await _prefs.hasSeenOnboarding();
    if (mounted) setState(() => _hasSeen = seen);
  }

  Future<void> _complete() async {
    await _prefs.markOnboardingSeen();
    if (mounted) setState(() => _hasSeen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeen == null) {
      // SharedPreferences를 읽는 아주 짧은 순간 — 흰 화면 깜빡임 대신 앱
      // 배경색만 깔아둔다.
      return const ColoredBox(color: AppColors.backgroundLight);
    }
    if (_hasSeen == false) {
      return OnboardingScreen(onDone: _complete);
    }
    return widget.child;
  }
}
