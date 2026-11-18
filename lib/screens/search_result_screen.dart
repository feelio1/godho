import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../ads/global_banner_ad.dart';
import '../data/hospital_repository.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/fee_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/region_provider.dart';
import '../providers/search_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/region_display.dart';
import '../widgets/compare_floating_bar.dart';
import '../widgets/fee_context_chip.dart' show representativeFeeItemId;
import '../widgets/fee_format.dart';
import '../widgets/hospital_card.dart';
import '../widgets/mascot_image.dart';
import '../widgets/mascot_message.dart';
import '../widgets/picker_sheet_chrome.dart';
import '../widgets/region_indicator.dart';
import 'detail_screen.dart';
import 'fee_overview_screen.dart';
import 'region_select_screen.dart';

/// Above this result count, a nationwide ("전체") scope shows a hint
/// nudging the user to narrow their region (스프린트 4 지시서 1: "과다하면
/// 상단 안내 + 지역 좁히기 유도"). The list itself is never blocked.
const int _regionHintThreshold = 200;

class SearchResultScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchResultScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends ConsumerState<SearchResultScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery ?? '';
    _controller = TextEditingController(text: initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchQueryProvider.notifier).state = initial;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _changeRegion() async {
    final result = await showRegionPickerSheet(context);
    if (result != null) {
      await ref.read(regionProvider.notifier).selectRegion(result);
    }
  }

  Future<void> _changeSort(SortOption current) async {
    final result = await showModalBottomSheet<SortOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickerSheetChrome(
        title: '정렬',
        heightFactor: 0.4,
        child: ListView(
          children: [
            for (final option in SortOption.values)
              ListTile(
                title: Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: option == current ? FontWeight.w800 : FontWeight.w600,
                    color: option == current ? AppColors.primaryTextTone : AppColors.textPrimary,
                  ),
                ),
                trailing: option == current ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (result != null) {
      ref.read(sortOptionProvider.notifier).state = result;
      ref.read(sortManuallySetProvider.notifier).state = true;
    }
  }

  /// 검색 결과가 없을 때 "OO 전체로 넓히기" — 시/군/구까지 좁혀져 있으면
  /// 시/도 전체로, 시/도만 좁혀져 있으면 전국으로 한 단계 넓힌다.
  Future<void> _widenRegion(RegionFilter region) async {
    final wider = region.sigungu != null ? RegionFilter(sido: region.sido) : const RegionFilter.all();
    await ref.read(regionProvider.notifier).selectRegion(wider);
  }

  void _goToMap() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(selectedTabProvider.notifier).state = AppTab.map.index;
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final sort = ref.watch(sortOptionProvider);
    final includeClosed = ref.watch(includeClosedProvider);
    final results = ref.watch(searchResultsProvider);
    final bundle = ref.watch(bundleProvider).value;
    final location = ref.watch(locationProvider).value;
    final region = ref.watch(regionProvider).value?.filter ?? const RegionFilter.all();

    final generatedAt = bundle?.generatedAt;
    final dateLabel = generatedAt != null ? DateFormat('yyyy.MM.dd').format(generatedAt) : '확인 불가';

    return Scaffold(
      // "장구름의 수첩"(3차 업데이트 J-3): 뒤로 + 검색창(1.5px 네이비 알약).
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 68,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.page),
          child: _SearchField(
            controller: _controller,
            onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [CompareFloatingBar(), GlobalBannerAd(inline: true)]),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(child: RegionIndicator(region: region, onTap: _changeRegion, showIcon: false)),
                      const SizedBox(width: 8),
                      _PillButton(label: sort.label, onTap: () => _changeSort(sort)),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ref.read(includeClosedProvider.notifier).state = !includeClosed,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: includeClosed,
                          visualDensity: VisualDensity.compact,
                          onChanged: (value) => ref.read(includeClosedProvider.notifier).state = value ?? false,
                        ),
                        const Text('폐업 포함', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 가까운 순인데 위치를 모를 때 — 권한 창은 이 버튼을 눌렀을 때만 뜬다.
          if (sort == SortOption.distance && location == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '위치를 켜면 가까운 순으로 볼 수 있어요',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(locationProvider.notifier).requestAndFetch(),
                    child: const Text('위치 켜기'),
                  ),
                ],
              ),
            ),
          if (region.isNationwide && results.length > _regionHintThreshold)
            _NarrowRegionHint(onTap: _changeRegion, count: results.length),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: query.trim().isEmpty
                          ? MascotMessage(
                              title: '이 지역에는 표시할 병원이 없습니다',
                              subtitle: '지역을 변경하거나 "폐업 포함"을 켜보세요',
                              assetPath: MascotImage.emptySearchAssetPath,
                              overlayIcon: Icons.location_off_outlined,
                              trailing: OutlinedButton(onPressed: _changeRegion, child: const Text('지역 선택')),
                            )
                          : MascotMessage(
                              title: "'$query' 검색 결과가 없어요",
                              subtitle: '철자를 확인하거나, 지역을 넓혀서 다시 찾아보세요.',
                              assetPath: MascotImage.emptySearchAssetPath,
                              overlayIcon: Icons.search_off,
                              trailing: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  if (!region.isNationwide)
                                    OutlinedButton(
                                      onPressed: () => _widenRegion(region),
                                      child: Text(
                                        region.sigungu != null
                                            ? '${sidoDisplayLabel(region.sido!)} 전체로 넓히기'
                                            : '전국으로 넓히기',
                                      ),
                                    ),
                                  OutlinedButton(onPressed: _goToMap, child: const Text('지도에서 보기')),
                                ],
                              ),
                            ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
                          child: _RegionFeeStrip(region: region),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.page + 2, 16, AppSpacing.page, 10),
                          child: Text.rich(
                            TextSpan(
                              text: '검색 결과 ',
                              children: [
                                TextSpan(
                                  text: '${NumberFormat('#,###').format(results.length)}곳',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      // 결과는 흰 카드 한 장 안의 목록(행 사이 1px 구분선) —
                      // 많은 결과도 보이는 행만 그린다.
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                        sliver: DecoratedSliver(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            border: Border.all(color: AppColors.borderCard),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            sliver: SliverList.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                indent: AppSpacing.cardLarge,
                                endIndent: AppSpacing.cardLarge,
                                color: AppColors.borderMuted,
                              ),
                              itemBuilder: (context, index) {
                                final hospital = results[index];
                                final recordCount = bundle?.sameAddressRecordCount(hospital) ?? 1;
                                final distance = HospitalRepository.distanceKm(
                                  location?.latitude,
                                  location?.longitude,
                                  hospital.lat,
                                  hospital.lng,
                                );
                                return HospitalCard(
                                  inList: true,
                                  hospital: hospital,
                                  sameAddressRecordCount: recordCount,
                                  distanceKm: distance,
                                  hasUserLocation: location != null,
                                  onTap: () => Navigator.of(
                                    context,
                                  ).push(MaterialPageRoute(builder: (_) => DetailScreen(hospitalId: hospital.id))),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.page + 4, 14, AppSpacing.page, 24),
                          child: Text(
                            '${bundle?.source ?? '지방행정 인허가 데이터'} · $dateLabel 기준. '
                            '리뷰와 영업시간은 병원 상세에서 네이버·카카오맵으로 확인할 수 있어요.',
                            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 검색창 — 1.5px 네이비 테두리 알약, 글자가 있으면 지우기(×).
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: '동 이름이나 병원 이름으로 검색',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(Icons.search, size: 22, color: AppColors.textPrimary),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '지우기',
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
    );
  }
}

/// 흰 바탕 알약 버튼(정렬 등) — 높이 44dp.
class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.borderCard)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 지역 시세 띠 — "{구} 초진 진찰료 가운데 값 9,500원" + [시세 보기]. 카드마다
/// 반복하던 시세 칩을 이 띠 하나로 대신한다. 구가 정해지지 않았거나 그 구
/// 자료가 없으면 그리지 않는다(대체·추정 금지).
class _RegionFeeStrip extends ConsumerWidget {
  final RegionFilter region;

  const _RegionFeeStrip({required this.region});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sigungu = region.sigungu;
    final bundle = ref.watch(feeBundleProvider).value;
    if (sigungu == null || bundle == null) return const SizedBox.shrink();
    final weight = ref.watch(feeWeightProvider).bucket;
    final item = bundle.itemById(representativeFeeItemId);
    final value = bundle.lookup(sido: region.sido!, sigungu: sigungu, itemId: representativeFeeItemId, weight: weight);
    if (item == null || value == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.panel)),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '${region.shortLabel} ${item.name} 가운데 값 ',
                children: [
                  TextSpan(
                    text: value.sampleLow ? '참고용' : feeWonLabel(value.mid),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeeOverviewScreen())),
            child: const Text('시세 보기'),
          ),
        ],
      ),
    );
  }
}

class _NarrowRegionHint extends StatelessWidget {
  final VoidCallback onTap;
  final int count;

  const _NarrowRegionHint({required this.onTap, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '전체 지역 $count곳이 표시 중이에요. 지역을 좁히면 더 빠르게 찾을 수 있어요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  '지역 선택',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
