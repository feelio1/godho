import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../ads/global_banner_ad.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/region_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../widgets/brand_mark.dart';
import '../widgets/fee_summary_card.dart';
import '../widgets/region_indicator.dart';
import 'fee_overview_screen.dart';
import 'region_select_screen.dart';
import 'saved_screen.dart';
import 'search_result_screen.dart';

/// Only ever mounted once [MainShell] has confirmed the bundle is loaded.
///
/// "펫클 앱 디자인" 캔버스 시안(Main.dc.html)을 그대로 따른다 — 브랜드
/// 헤더(아이콘+펫클 · 지역 칩) → 타이틀 → 검색 진입 → 전국 기록 수 →
/// 3개 바로가기(주변 병원·진료비 시세·저장한 병원) → 지역 진료비 시세
/// 카드 → 광고. 이전의 "내 주변 가까운 병원 / 운영 20년 이상 / 최근
/// 개원 / 최근 확인한 병원 / 저장한 병원" 세로 리스트 섹션들은 시안에
/// 없어 걷어냈다(사용자 확인) — 해당 병원들은 지도·검색·저장 탭에서
/// 계속 볼 수 있다. 로그인 상태 배지도 시안엔 없다 — 내 정보 탭이
/// 그 역할을 전담한다.
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
            RegionIndicator(region: region, onTap: () => _changeRegion(context, ref)),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
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
                  ref.read(selectedTabProvider.notifier).state = 1;
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SavedScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        const FeeSummaryCard(),
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
