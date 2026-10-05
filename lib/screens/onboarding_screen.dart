import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../widgets/mascot_image.dart';
import 'login_screen.dart';

/// 첫 실행 온보딩 — "펫클 앱 디자인" 캔버스 시안(Onboarding.dc.html)
/// 그대로, 슬라이드 없이 한 화면으로 보여준다("디자인 2단계" 지시서,
/// 사용자 확인하에 적용). 이전 3장 슬라이드의 "중간값 vs 평균" 설명은
/// 삭제했지만, 그 정보 자체는 진료비가 나오는 모든 화면의 "중간값"
/// 배지([FeeItemCard])에 항상 붙어 있어 없어지지 않는다.
///
/// 로그인 여부와 무관하게 항상 보여주고, 과장·평가·추천·"싸다/비싸다"
/// 표현은 어디에도 쓰지 않는다(CLAUDE.md 원칙 1).
class OnboardingScreen extends StatelessWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  Future<void> _login(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (context.mounted) onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            24,
            AppSpacing.page,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                alignment: Alignment.center,
                child: const MascotImage(size: 120),
              ),
              const SizedBox(height: AppSpacing.section),
              const Text(
                '동물병원,\n사실부터 확인하세요',
                style: TextStyle(
                  fontSize: 27,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '펫클은 정부 공공데이터로 병원의 개원 시기와 같은 주소의 인허가 기록, 지역 진료비 시세를 보여드려요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const _OnboardingStep(
                number: '01',
                title: '병원 행정 기록 · 지역 시세 확인',
                subtitle: '로그인 없이 바로 검색할 수 있어요',
              ),
              const SizedBox(height: 16),
              const _OnboardingStep(
                number: '02',
                title: '우리 아이 진료기록 · 예약 알림',
                subtitle: '로그인하면 계정에 저장돼요',
              ),
              const SizedBox(height: 16),
              const _OnboardingStep(
                number: '03',
                title: '병원 저장 · 캘린더',
                subtitle: '다니는 병원과 일정을 한곳에서',
              ),
              const SizedBox(height: AppSpacing.section),
              Text(
                '공공데이터 기반 · 병원으로부터 비용을 받지 않습니다',
                textAlign: TextAlign.center,
                style: AppTextStyles.src(AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                  ),
                  child: const Text(
                    '시작하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => _login(context),
                  child: const Text(
                    '이미 계정이 있어요 · 로그인',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _OnboardingStep({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: AppTextStyles.mono(
              size: 13,
              weight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
