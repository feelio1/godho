import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/global_banner_ad.dart';
import '../data/hospital_repository.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/region_provider.dart';
import '../providers/search_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/compare_floating_bar.dart';
import '../widgets/hospital_card.dart';
import '../widgets/mascot_image.dart';
import '../widgets/mascot_message.dart';
import '../widgets/picker_sheet_chrome.dart';
import '../widgets/search_set_card.dart';
import 'detail_screen.dart';
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
    ref.read(selectedTabProvider.notifier).state = 1;
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
    final compareIds = ref.watch(compareListProvider);
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('검색')),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [CompareFloatingBar(), GlobalBannerAd()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 0),
            child: SearchSetCard(
              hintText: '병원명 또는 주소로 검색',
              controller: _controller,
              // 진입 시 지역 목록을 바로 보여주는 것이 우선이라(스프린트 4
              // 지시서 1), 자동으로 키보드를 띄워 목록을 가리지 않는다.
              autofocus: false,
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
              region: region,
              sidoOptions: repo.sidoList,
              onSelectRegion: (filter) => ref.read(regionProvider.notifier).selectRegion(filter),
              onOpenRegionPicker: _changeRegion,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _changeSort(sort),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          sort.label,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('폐업 포함'),
                  selected: includeClosed,
                  onSelected: (value) =>
                      ref.read(includeClosedProvider.notifier).state = value,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                              trailing: OutlinedButton(
                                onPressed: _changeRegion,
                                child: const Text('지역 선택'),
                              ),
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
                                        region.sigungu != null ? '${region.sido} 전체로 넓히기' : '전국으로 넓히기',
                                      ),
                                    ),
                                  OutlinedButton(
                                    onPressed: _goToMap,
                                    child: const Text('지도에서 보기'),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  )
                : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final hospital = results[index];
                          final recordCount =
                              bundle?.sameAddressRecordCount(hospital) ?? 1;
                          final distance = HospitalRepository.distanceKm(
                            location?.latitude,
                            location?.longitude,
                            hospital.lat,
                            hospital.lng,
                          );
                          return HospitalCard(
                            hospital: hospital,
                            sameAddressRecordCount: recordCount,
                            distanceKm: distance,
                            hasUserLocation: location != null,
                            isInCompare: compareIds.contains(hospital.id),
                            onCompareToggle: () {
                              final notifier = ref.read(compareListProvider.notifier);
                              if (compareIds.contains(hospital.id)) {
                                notifier.remove(hospital.id);
                              } else {
                                final added = notifier.add(hospital.id);
                                if (!added) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('비교는 최대 3곳까지 담을 수 있습니다.')),
                                  );
                                }
                              }
                            },
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(hospitalId: hospital.id),
                              ),
                            ),
                          );
                        },
                      ),
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
