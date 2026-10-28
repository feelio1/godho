import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../ads/global_banner_ad.dart';
import '../diary/screens/on_this_day_diary_card.dart';
import '../diary/screens/today_diary_row.dart';
import '../models/region_filter.dart';
import '../providers/auth_provider.dart';
import '../providers/bundle_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/region_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../widgets/affiliate_fee_card.dart';
import '../widgets/brand_mark.dart';
import '../widgets/fee_summary_card.dart';
import '../widgets/guest_gate.dart';
import '../widgets/home_greeting_banner.dart';
import '../widgets/home_shop_recommendation.dart';
import '../widgets/our_pet_card.dart';
import '../widgets/region_indicator.dart';
import 'account_ui.dart';
import 'fee_overview_screen.dart';
import 'login_screen.dart';
import 'region_select_screen.dart';
import 'saved_screen.dart';
import 'search_result_screen.dart';

/// Only ever mounted once [MainShell] has confirmed the bundle is loaded.
///
/// "방향 개편" 지시서 B — 포지셔닝("병원 확인에서 시작하는 우리 아이
/// 관리 앱")에 맞춰 순서를 다시 짰다: 브랜드 헤더 → 장구름 인사 →
/// (로그인+반려동물) 우리 아이 영역 → 병원 영역(섹션 제목·타이틀·검색·
/// 3개 바로가기·지역 진료비 시세 요약) → 쇼핑 추천(쇼핑이 열려 있고
/// 판매 중 상품이 있을 때만) → 펫보험 제휴 카드 → 광고. 제휴 카드는
/// 병원 데이터 카드와 인접하지 않게 쇼핑 추천 뒤로 옮겼다. 이전("출시 전
/// 마무리" 지시서 A~C)엔 우리 아이 카드가 병원 영역 중간에 끼어 있었고,
/// 지역 진료비 시세 요약은 맨 아래였다. "내 주변 가까운 병원 / 운영 20년
/// 이상 / 최근 개원 / 최근 확인한 병원 / 저장한 병원" 세로 리스트 섹션들은
/// 그보다 전에 시안에 없어 걷어냈다(사용자 확인) — 해당 병원들은 병원
/// 탭·검색·저장 화면에서 계속 볼 수 있다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: _HomeBody()),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  Future<void> _changeRegion(BuildContext context, WidgetRef ref) async {
    final result = await showRegionPickerSheet(context);
    if (result != null) {
      await ref.read(regionProvider.notifier).selectRegion(result);
    }
  }

  Future<void> _openSaved(BuildContext context, WidgetRef ref) async {
    final ok = await requireLogin(
      context,
      ref,
      message: '로그인하면 관심 있는 병원을 저장해두고 언제든 다시 찾아볼 수 있어요.',
    );
    if (!ok || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final bundle = ref.watch(bundleProvider).value;
    final region = ref.watch(regionProvider).value?.filter ?? const RegionFilter.all();

    final generatedAt = bundle?.generatedAt;
    final dateLabel = generatedAt != null ? DateFormat('yyyy.MM.dd').format(generatedAt) : '확인 불가';

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 16),
      children: [
        Row(
          children: [
            const Expanded(child: BrandMark()),
            const _HomeAuthBadge(),
            const SizedBox(width: 8),
            RegionIndicator(region: region, onTap: () => _changeRegion(context, ref)),
          ],
        ),
        const SizedBox(height: 14),
        const HomeGreetingBanner(),
        const SizedBox(height: AppSpacing.section),
        // 우리 아이 영역 — 로그인+반려동물이 있을 때만 보인다(OurPetCard·
        // TodayDiaryRow·OnThisDayDiaryCard가 각자 스스로 가린다, "방향
        // 개편" 지시서 F, "일기 활성화" 지시서 I).
        const OurPetCard(),
        const TodayDiaryRow(),
        const OnThisDayDiaryCard(),
        const SizedBox(height: AppSpacing.section),
        // 병원 영역.
        const Text(
          '병원 찾기',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.2),
        ),
        const SizedBox(height: 10),
        Text(
          '동물병원의 기록을\n사실 그대로 확인하세요',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.35),
        ),
        const SizedBox(height: 6),
        const Text(
          '공공데이터 기반 · 평가나 순위 없이 기록만 보여드려요',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.section),
        _SearchEntry(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchResultScreen()),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '전국 ${NumberFormat('#,###').format(repo.all.length)}곳 인허가 기록 · $dateLabel 기준',
          style: AppTextStyles.src(AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.section),
        Row(
          children: [
            Expanded(
              child: _ShortcutButton(
                icon: Icons.map_outlined,
                label: '주변 병원',
                onTap: () {
                  // "주변 병원" 최초 사용 시 위치 권한을 요청한다(CLAUDE.md:
                  // 앱 시작 시 강제 요청 금지 — 탭 진입 시점에만 요청).
                  ref.read(locationProvider.notifier).requestAndFetch();
                  ref.read(selectedTabProvider.notifier).state = AppTab.map.index;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ShortcutButton(
                icon: Icons.bar_chart_outlined,
                label: '진료비 시세',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeeOverviewScreen()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ShortcutButton(
                icon: Icons.bookmark_outline,
                label: '저장한 병원',
                onTap: () => _openSaved(context, ref),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        const FeeSummaryCard(),
        const SizedBox(height: AppSpacing.section),
        const HomeShopRecommendation(),
        // 제휴 카드는 병원 데이터 카드(FeeSummaryCard)와 붙지 않게 쇼핑 추천
        // 뒤에 둔다 — 쇼핑이 꺼져 위 섹션이 비어도 위아래 간격이 두 번
        // 겹쳐 병원 영역과 충분히 떨어진다(CLAUDE.md 광고 배치 원칙).
        const SizedBox(height: AppSpacing.section),
        const AffiliateFeeCard(),
        const SizedBox(height: AppSpacing.section),
        const GlobalBannerAd(inline: true),
      ],
    );
  }
}

/// 홈 검색 진입 — 입력을 바로 받지 않고(시안: `pointer-events:none`인
/// placeholder input) 탭하면 검색 화면으로 이동한다.
class _SearchEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              '병원 이름 또는 지역 검색',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3개 바로가기(주변 병원·진료비 시세·저장한 병원) 카드 — 시안의 3열
/// 그리드 버튼.
class _ShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShortcutButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.borderCard),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 홈 상단의 로그인 표시 — 게스트는 "로그인" 버튼, 로그인하면 "○○님"으로
/// 바뀌어 탭하면 내 정보 탭으로 이동한다("홈 화면 로그인 표시" 지시서 3).
/// [authStateProvider]를 직접 구독해 로그인/로그아웃에 즉시 반응한다.
class _HomeAuthBadge extends ConsumerWidget {
  const _HomeAuthBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
        borderRadius: BorderRadius.circular(999),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '로그인',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => ref.read(selectedTabProvider.notifier).state = AppTab.my.index,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 88),
          child: Text(
            '${accountLabel(user)}님',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
