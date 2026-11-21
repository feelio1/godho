import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diary_book/providers/diary_book_switch.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
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
class OnboardingScreen extends ConsumerWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  Future<void> _login(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (context.mounted) onDone();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 그림일기 스위치가 열렸을 때만 두 번째 줄을 그림일기로(4차 업데이트 K-8) —
    // 닫혔거나 아직 모르면(로딩·오류) 지금 문구. 진료기록은 세 번째 줄에 남긴다.
    final book = ref.watch(diaryBookVisibleProvider);
    // "장구름의 수첩"(3차 업데이트 J-7): 위 300dp 버터색 바탕(아래쪽 둥근
    // 모서리)에 구름이와 고양이 그림, 제목·설명, 할 수 있는 것 3줄, 맨 아래
    // 공공데이터 안내 + [시작하기] + 로그인.
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 300 + MediaQuery.paddingOf(context).top,
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 16, bottom: 12),
              decoration: const BoxDecoration(
                color: AppColors.warmBackground,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Image.asset(
                'assets/mascot/home_banner.png',
                fit: BoxFit.contain,
                semanticLabel: '구름이와 고양이',
                errorBuilder: (context, error, stackTrace) => const Center(child: MascotImage(size: 140)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 28, AppSpacing.page, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '동물병원 가기 전에\n확인하세요',
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '언제 문 열었는지, 영업 중으로 등록돼 있는지, 이 동네 진료비는 얼마쯤인지 정부 공공데이터로 보여드려요.',
                    style: TextStyle(fontSize: 15, height: 1.6, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  const _OnboardingStep(icon: Icons.search, title: '병원 기록 · 동네 진료비', subtitle: '로그인 없이 바로 볼 수 있어요'),
                  const SizedBox(height: 14),
                  _OnboardingStep(
                    icon: book ? Icons.menu_book_outlined : Icons.edit_outlined,
                    title: book ? '우리 아이 일기 · 그림일기' : '우리 아이 일기 · 진료기록',
                    subtitle: book ? '쓴 일기가 그림일기 공책이 돼요' : '로그인하면 계정에 저장돼요',
                  ),
                  const SizedBox(height: 14),
                  _OnboardingStep(
                    icon: Icons.calendar_today_outlined,
                    title: '예약 알림 · 캘린더',
                    subtitle: book ? '진료기록 · 예약 일정을 한곳에서' : '다니는 병원 일정을 한곳에서',
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: double.infinity,
                    child: Text(
                      '공공데이터 기반 · 병원으로부터 비용을 받지 않아요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: onDone, child: const Text('시작하기')),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => _login(context),
                      child: const Text(
                        '이미 계정이 있어요 · 로그인',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingStep({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, size: 22, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
