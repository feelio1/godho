import 'package:flutter/material.dart';

import '../models/fee.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/fee_item_card.dart';

/// 첫 실행 온보딩(3장) — 사용법 + 가격 읽는 법(중간값·지역 시세)을 짧게
/// 안내한다("캘린더 하단탭화 + 진료 연대기" 지시서 B). 로그인 여부와
/// 무관하게 항상 보여주고, 과장·평가·추천·"싸다/비싸다" 표현은 어디에도
/// 쓰지 않는다(CLAUDE.md 원칙 1, 지시서 B4 — 사실·안내 톤만).
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pageCount - 1;
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('건너뛰기', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _UsageSlide(),
                  _MedianSlide(),
                  _RegionSlide(),
                ],
              ),
            ),
            _PageDots(count: _pageCount, index: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(isLast ? '시작하기' : '다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 슬라이드 공통 레이아웃 — 원형 아이콘 + 제목 + 설명, 선택적으로 예시
/// 위젯(2번째 장의 진료비 카드 등)을 아래에 붙인다.
class _OnboardingSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? example;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    this.example,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 32, AppSpacing.page, 16),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 44, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
          if (example != null) ...[
            const SizedBox(height: 24),
            example!,
          ],
        ],
      ),
    );
  }
}

class _UsageSlide extends StatelessWidget {
  const _UsageSlide();

  @override
  Widget build(BuildContext context) {
    return const _OnboardingSlide(
      icon: Icons.fact_check_outlined,
      title: '공개 정보를 확인하고,\n우리 아이 기록도 함께 관리해요',
      description:
          '동물병원의 공개된 행정 정보와 진료비 시세를 확인하고,\n우리 아이의 진료기록과 예약을 캘린더로 관리할 수 있어요.',
    );
  }
}

/// 대표값이 "중간값"인 이유를 실제 진료비 카드([FeeItemCard])와 같은
/// 모양의 예시로 보여준다 — 실제 화면에서 볼 카드와 다르게 생기면 오히려
/// 헷갈리므로 같은 위젯을 그대로 재사용한다.
class _MedianSlide extends StatelessWidget {
  const _MedianSlide();

  @override
  Widget build(BuildContext context) {
    return const _OnboardingSlide(
      icon: Icons.bar_chart_outlined,
      title: '대표 가격은 평균이 아니라\n중간값이에요',
      description: '유난히 비싸거나 저렴한 병원 하나에 휘둘리지 않도록,\n중간값과 범위(최저~최고)를 함께 보여드려요.',
      example: FeeItemCard(
        item: FeeItem(id: 'onboarding-example', name: '예시 진료 항목', category: '', weightBased: false),
        value: FeeValue(mid: 10000, min: 5000, max: 22000, sampleLow: false),
      ),
    );
  }
}

class _RegionSlide extends StatelessWidget {
  const _RegionSlide();

  @override
  Widget build(BuildContext context) {
    return const _OnboardingSlide(
      icon: Icons.location_city_outlined,
      title: '시세는 특정 병원이 아니라\n지역(구) 시세예요',
      description: '보여드리는 가격은 한 병원의 가격이 아니라,\n같은 지역(구) 안 병원들의 가격을 모은 참고 정보예요.',
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int index;

  const _PageDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == index ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == index ? AppColors.primary : AppColors.borderCard,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
