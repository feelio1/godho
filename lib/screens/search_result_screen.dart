import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/global_banner_ad.dart';
import '../data/hospital_repository.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/location_provider.dart';
import '../providers/region_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/compare_floating_bar.dart';
import '../widgets/hospital_card.dart';
import '../widgets/mascot_image.dart';
import '../widgets/mascot_message.dart';
import '../widgets/region_indicator.dart';
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
    final result = await Navigator.of(context).push<RegionFilter>(
      MaterialPageRoute(builder: (_) => const RegionSelectScreen()),
    );
    if (result != null) {
      await ref.read(regionProvider.notifier).selectRegion(result);
    }
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

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          // 진입 시 지역 목록을 바로 보여주는 것이 우선이라(스프린트 4
          // 지시서 1), 자동으로 키보드를 띄워 목록을 가리지 않는다.
          autofocus: false,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '병원명 또는 주소로 검색',
            border: InputBorder.none,
          ),
          onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
        ),
      ),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [CompareFloatingBar(), GlobalBannerAd()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                RegionIndicator(region: region, onTap: _changeRegion),
                const Spacer(),
                FilterChip(
                  label: const Text('폐업 병원도 보기'),
                  selected: includeClosed,
                  onSelected: (value) =>
                      ref.read(includeClosedProvider.notifier).state = value,
                ),
              ],
            ),
          ),
          _SortBar(sort: sort),
          if (region.isNationwide && results.length > _regionHintThreshold)
            _NarrowRegionHint(onTap: _changeRegion, count: results.length),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: query.trim().isEmpty
                          ? const MascotMessage(
                              title: '이 지역에는 표시할 병원이 없습니다',
                              subtitle: '지역을 변경하거나 "폐업 병원도 보기"를 켜보세요',
                              assetPath: MascotImage.emptySearchAssetPath,
                            )
                          : const MascotMessage(
                              title: '검색 결과가 없습니다',
                              subtitle: '다른 이름이나 주소로 다시 검색해보세요',
                              assetPath: MascotImage.emptySearchAssetPath,
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

class _SortBar extends ConsumerWidget {
  final SortOption sort;

  const _SortBar({required this.sort});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: SortOption.values
            .map((option) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(option.label),
                    selected: sort == option,
                    onSelected: (_) {
                      ref.read(sortOptionProvider.notifier).state = option;
                      ref.read(sortManuallySetProvider.notifier).state = true;
                    },
                  ),
                ))
            .toList(),
      ),
    );
  }
}
