import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hospital_repository.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/location_provider.dart';
import '../providers/region_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/compare_floating_bar.dart';
import '../widgets/hospital_card.dart';
import '../widgets/region_indicator.dart';
import 'detail_screen.dart';
import 'region_select_screen.dart';

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
          autofocus: widget.initialQuery == null,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '병원명 또는 주소로 검색',
            border: InputBorder.none,
          ),
          onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
        ),
      ),
      bottomNavigationBar: const CompareFloatingBar(),
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
          Expanded(
            child: query.trim().isEmpty
                ? const Center(child: Text('검색어를 입력해주세요.'))
                : results.isEmpty
                    ? const Center(child: Text('검색 결과가 없습니다.'))
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
