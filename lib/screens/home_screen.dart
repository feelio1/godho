import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../ads/global_banner_ad.dart';
import '../config/feature_flags.dart';
import '../diary/screens/on_this_day_diary_card.dart';
import '../diary/screens/today_diary_row.dart';
import '../models/region_filter.dart';
import '../providers/auth_provider.dart';
import '../providers/bundle_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/region_auto_detect.dart';
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
import '../widgets/mascot_image.dart';
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
    return const Scaffold(body: SafeArea(child: _HomeBody()));
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
    final ok = await requireLogin(context, ref, message: '로그인하면 관심 있는 병원을 저장해두고 언제든 다시 찾아볼 수 있어요.');
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

    final user = ref.watch(authStateProvider).value;
    final hasPets = user != null && (ref.watch(effectivePetsProvider).value?.isNotEmpty ?? false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Align(alignment: Alignment.centerLeft, child: BrandMark(fontSize: 26, showIcon: false)),
            ),
            const _HomeAuthBadge(),
            const SizedBox(width: 6),
            RegionIndicator(region: region, onTap: () => _changeRegion(context, ref)),
          ],
        ),
        const SizedBox(height: 16),
        // "평가하지 않아요" 류 문구는 홈에서 한 곳에만 둔다(2차 업데이트 F) —
        // 게스트·반려동물 0마리는 이 인사 배너, 반려동물이 있는 회원은 버터색
        // 일기 띠가 이 자리에 오므로 검색 카드 아래 기준일 줄에 붙인다.
        const HomeGreetingBanner(),
        // 지역이 "전체"일 때만 — 우리 동네를 정하면 사라진다.
        if (region.isNationwide) ...[const SizedBox(height: 14), const _NeighborhoodCard()],
        // 우리 아이 영역 — 버터색 일기 띠(로그인 + 반려동물, 0마리면 등록
        // 안내) + 다가오는 예약·최근 진료기록 카드 + 1년 전 오늘 일기. 각자
        // 조건이 안 맞으면 스스로 숨는다.
        const _GapIfVisible(child: TodayDiaryRow()),
        const _GapIfVisible(child: OurPetCard()),
        const OnThisDayDiaryCard(),
        const SizedBox(height: 12),
        // 병원 영역 — 검색 → 진료비 시세 → 바로가기 순(2차 업데이트 F).
        _SearchHeroCard(
          totalLabel: NumberFormat('#,###').format(repo.all.length),
          dateLabel: dateLabel,
          showNoRatingLine: hasPets,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchResultScreen())),
        ),
        const SizedBox(height: 28),
        const FeeSummaryCard(),
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
            const SizedBox(width: 10),
            Expanded(
              child: _ShortcutButton(
                icon: Icons.bar_chart_outlined,
                label: '진료비 시세',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeeOverviewScreen())),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ShortcutButton(
                icon: Icons.bookmark_outline,
                label: '저장한 병원',
                onTap: () => _openSaved(context, ref),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const HomeShopRecommendation(),
        // 제휴 카드는 병원 데이터 카드(FeeSummaryCard)와 붙지 않게 쇼핑 추천
        // 뒤에 둔다 — 쇼핑이 꺼져 위 섹션이 비어도 위아래 간격이 두 번
        // 겹쳐 병원 영역과 충분히 떨어진다(CLAUDE.md 광고 배치 원칙).
        // v1에서는 펫보험 카드를 숨긴다(kEnableInsuranceCard) — 코드는 그대로.
        if (kEnableInsuranceCard) ...[const SizedBox(height: AppSpacing.section), const AffiliateFeeCard()],
        const SizedBox(height: AppSpacing.section),
        const GlobalBannerAd(inline: true),
      ],
    );
  }
}

/// 우리 아이 영역 카드 위 간격(카드가 스스로 숨어도 14dp만 남는다).
class _GapIfVisible extends StatelessWidget {
  final Widget child;

  const _GapIfVisible({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(top: 14), child: child);
  }
}

/// 홈 검색 카드("장구름의 수첩", 3차 업데이트 J-2) — 네이비 바탕 큰 둥근
/// 카드(반지름 28): 흰 제목, 흰 검색창 + 버터색 화살표 버튼, `navyTint`
/// 칩 3개(버터색 체크), 맨 아래 기준일. 오른쪽 위에 돋보기 든 구름이가
/// 카드 밖으로 살짝 걸친다. 입력을 바로 받지 않고 탭하면 검색 화면으로.
class _SearchHeroCard extends StatelessWidget {
  final String totalLabel;
  final String dateLabel;
  final bool showNoRatingLine;
  final VoidCallback onTap;

  const _SearchHeroCard({
    required this.totalLabel,
    required this.dateLabel,
    required this.showNoRatingLine,
    required this.onTap,
  });

  static const _mascot = 104.0;
  static const _overhang = 30.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _overhang),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.button)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: _mascot - 20),
                  child: Text(
                    '동물병원 가기 전에\n확인하세요',
                    style: TextStyle(
                      fontSize: 25,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  button: true,
                  label: '병원 검색',
                  child: Material(
                    color: Colors.white,
                    shape: const StadiumBorder(side: BorderSide(color: Colors.white, width: 1.5)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: onTap,
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            const SizedBox(width: 18),
                            const Icon(Icons.search, size: 22, color: AppColors.textPrimary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '동 이름이나 병원 이름으로 검색',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 15, color: AppColors.textPlaceholder),
                              ),
                            ),
                            Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(color: AppColors.butter, shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward, color: AppColors.textPrimary, size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: [_NavyCheckChip('문 연 날'), _NavyCheckChip('영업 등록 상태'), _NavyCheckChip('동네 진료비')],
                ),
                const SizedBox(height: 14),
                Text(
                  '전국 $totalLabel곳 인허가 기록 · $dateLabel 기준',
                  style: AppTextStyles.mono(size: 13, color: AppColors.onNavyCaption),
                ),
                if (showNoRatingLine) ...[
                  const SizedBox(height: 2),
                  const Text(
                    '병원을 평가하지 않아요. 공개된 사실만 보여드려요.',
                    style: TextStyle(fontSize: 13, color: AppColors.onNavyCaption),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Positioned(
          right: 6,
          top: 0,
          child: ExcludeSemantics(
            child: MascotImage(size: _mascot, assetPath: MascotImage.emptySearchAssetPath),
          ),
        ),
      ],
    );
  }
}

class _NavyCheckChip extends StatelessWidget {
  final String label;

  const _NavyCheckChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: AppColors.navyTint, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 14, color: AppColors.butter),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 3개 바로가기(주변 병원·진료비 시세·저장한 병원) — 흰 카드 3칸, 아이콘 +
/// 글자, 높이 84dp.
class _ShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShortcutButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderCard),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        child: SizedBox(
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
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
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
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

/// "우리 동네를 알려주세요" — 지역이 "전체"일 때만 홈에 보인다(2차 업데이트
/// F). [현재 위치로 찾기]는 이 버튼을 눌렀을 때만 위치 권한을 묻고(앱 시작 시
/// 강제 요청 금지), 좌표로 지역을 판정해 고른다. [직접 선택]은 지역 선택 시트.
/// 지역이 정해지면 홈이 이 카드를 더는 그리지 않는다.
class _NeighborhoodCard extends ConsumerStatefulWidget {
  const _NeighborhoodCard();

  @override
  ConsumerState<_NeighborhoodCard> createState() => _NeighborhoodCardState();
}

class _NeighborhoodCardState extends ConsumerState<_NeighborhoodCard> {
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      await ref.read(locationProvider.notifier).requestAndFetch();
      final position = ref.read(locationProvider).value;
      if (position == null) {
        _showMessage('위치를 확인할 수 없어요. 위치 권한을 확인하거나 직접 선택해 주세요.');
        return;
      }
      final normalized = await detectNormalizedRegion(ref, position.latitude, position.longitude);
      if (normalized == null) {
        _showMessage('현재 위치의 지역을 찾지 못했어요. 직접 선택해 주세요.');
        return;
      }
      await ref
          .read(regionProvider.notifier)
          .selectRegion(RegionFilter(sido: normalized.sido, sigungu: normalized.sigungu));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickRegion() async {
    final result = await showRegionPickerSheet(context);
    if (result != null) await ref.read(regionProvider.notifier).selectRegion(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.borderCard),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '우리 동네를 알려주세요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text('진료비 시세와 가까운 병원을 보여드려요', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          // 좁은 폭에서도 글자가 줄바꿈되지 않게 두 버튼을 위아래로 둔다.
          FilledButton.icon(
            key: const ValueKey('neighborhood_locate'),
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 18),
            label: const Text('현재 위치로 찾기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('neighborhood_pick'),
            onPressed: _locating ? null : _pickRegion,
            child: const Text('직접 선택'),
          ),
        ],
      ),
    );
  }
}
