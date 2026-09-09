import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/designated_provider.dart';
import '../providers/home_section_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/recent_provider.dart';
import '../providers/region_provider.dart';
import '../providers/saved_provider.dart';
import '../widgets/designated_hospital_card.dart';
import '../widgets/hospital_card.dart';
import '../widgets/mascot_image.dart';
import '../widgets/region_indicator.dart';
import 'detail_screen.dart';
import 'info_screens.dart';
import 'region_select_screen.dart';
import 'search_result_screen.dart';

/// Only ever mounted once [MainShell] has confirmed the bundle is loaded.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('펫병원체크'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: const _HomeBody(),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.source_outlined),
              title: const Text('출처'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SourcesScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('이용안내'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GuideScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  Future<void> _changeRegion(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<RegionFilter>(
      MaterialPageRoute(builder: (_) => const RegionSelectScreen()),
    );
    if (result != null) {
      await ref.read(regionProvider.notifier).selectRegion(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final savedIds = ref.watch(savedHospitalsProvider).value ?? const [];
    final designatedIds = ref.watch(designatedHospitalsProvider).value ?? const [];
    final region = ref.watch(regionProvider).value?.filter ?? const RegionFilter.all();
    final location = ref.watch(locationProvider).value;

    final savedHospitals = savedIds.map(repo.byId).whereType<Hospital>().toList();
    final designatedHospitals = designatedIds.map(repo.byId).whereType<Hospital>().toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const MascotImage(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '안녕하세요, 장구름이에요',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '동물병원 방문 전, 공개된 정보를 확인해보세요',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (designatedHospitals.isNotEmpty) ...[
          const SizedBox(height: 20),
          _DesignatedHospitalsSection(hospitals: designatedHospitals),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: RegionIndicator(region: region, onTap: () => _changeRegion(context, ref)),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchResultScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  '병원명 또는 주소로 검색',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () {
            // "내 주변 병원" 최초 사용 시 위치 권한을 요청한다
            // (CLAUDE.md: 앱 시작 시 강제 요청 금지).
            ref.read(locationProvider.notifier).requestAndFetch();
            ref.read(selectedTabProvider.notifier).state = 1;
          },
          icon: const Icon(Icons.near_me_outlined),
          label: const Text('내 주변 병원'),
        ),
        const SizedBox(height: 28),
        _BrowseSection(region: region, location: location),
        if (savedHospitals.isNotEmpty) ...[
          const SizedBox(height: 24),
          _HospitalSection(
            title: '저장한 병원',
            hospitals: savedHospitals,
            location: location,
          ),
        ],
      ],
    );
  }
}

/// 홈의 "병원 둘러보기" 섹션 — 보기 기준 탭으로 전환 가능
/// (스프린트 4 지시서 2). '가까운 순'은 위치가 없으면 비활성 표시되고,
/// 기본 탭은 '최근 개원 순'이라 위치 유무와 무관하게 항상 의미 있는
/// 목록을 보여준다.
class _BrowseSection extends ConsumerWidget {
  final RegionFilter region;
  final Position? location;

  const _BrowseSection({required this.region, required this.location});

  static const _maxItems = 10;

  String _emptyMessageFor(HomeSectionTab tab) {
    if (tab == HomeSectionTab.recentlyViewed) {
      return '최근 확인한 병원이 없습니다';
    }
    return '이 지역에는 표시할 병원이 없습니다';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final bundle = ref.watch(bundleProvider).value;
    final selectedTab = ref.watch(homeSectionTabProvider);
    final recentIds = ref.watch(recentHospitalsProvider).value ?? const [];
    final hasLocation = location != null;

    // 위치 없이 '가까운 순'이 선택된 상태로 남아 있으면(예: 위치 권한이
    // 나중에 거부된 경우) 안전하게 '최근 개원 순'으로 대체한다.
    final effectiveTab =
        selectedTab == HomeSectionTab.near && !hasLocation ? HomeSectionTab.recentOpen : selectedTab;

    final regionOpenHospitals = repo.filterByStatus(
      repo.filterByRegion(repo.all, region),
      includeClosed: false,
    );

    List<Hospital> hospitals;
    switch (effectiveTab) {
      case HomeSectionTab.near:
        hospitals = repo.sortHospitals(
          regionOpenHospitals,
          SortOption.distance,
          currentLat: location?.latitude,
          currentLng: location?.longitude,
        );
      case HomeSectionTab.longestOperating:
        hospitals = repo.sortHospitals(regionOpenHospitals, SortOption.operatingLength);
      case HomeSectionTab.recentOpen:
        hospitals = repo.sortHospitals(regionOpenHospitals, SortOption.recentOpen);
      case HomeSectionTab.recentlyViewed:
        hospitals = recentIds.map(repo.byId).whereType<Hospital>().toList();
    }
    hospitals = hospitals.take(_maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '병원 둘러보기',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _TabChipRow(
          selected: selectedTab,
          hasLocation: hasLocation,
          onSelected: (tab) => ref.read(homeSectionTabProvider.notifier).state = tab,
        ),
        const SizedBox(height: 10),
        if (hospitals.isEmpty)
          SizedBox(
            height: 80,
            child: Center(
              child: Text(
                _emptyMessageFor(effectiveTab),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hospitals.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final hospital = hospitals[index];
                final distance = HospitalRepository.distanceKm(
                  location?.latitude,
                  location?.longitude,
                  hospital.lat,
                  hospital.lng,
                );
                return SizedBox(
                  width: 260,
                  child: HospitalCard(
                    hospital: hospital,
                    sameAddressRecordCount: bundle?.sameAddressRecordCount(hospital) ?? 1,
                    distanceKm: distance,
                    hasUserLocation: hasLocation,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DetailScreen(hospitalId: hospital.id)),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TabChipRow extends StatelessWidget {
  final HomeSectionTab selected;
  final bool hasLocation;
  final ValueChanged<HomeSectionTab> onSelected;

  const _TabChipRow({
    required this.selected,
    required this.hasLocation,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: HomeSectionTab.values.map((tab) {
          final disabled = tab == HomeSectionTab.near && !hasLocation;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(disabled ? '${tab.label} · 준비 중' : tab.label),
              selected: selected == tab,
              onSelected: disabled ? null : (_) => onSelected(tab),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 홈 상단 "지정 병원" 섹션 — 사용자가 지정한 단골 병원을 카드로 보여주고
/// 카드에서 바로 전화·길찾기·상세로 이동할 수 있다(스프린트 8 지시서 1).
/// 영업시간·실시간 영업여부는 표시하지 않는다(데이터 없음, 추정 금지).
class _DesignatedHospitalsSection extends StatelessWidget {
  final List<Hospital> hospitals;

  const _DesignatedHospitalsSection({required this.hospitals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '지정 병원',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...hospitals.map(
          (hospital) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DesignatedHospitalCard(
              hospital: hospital,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DetailScreen(hospitalId: hospital.id)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HospitalSection extends ConsumerWidget {
  final String title;
  final List<Hospital> hospitals;
  final Position? location;

  const _HospitalSection({
    required this.title,
    required this.hospitals,
    required this.location,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(bundleProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hospitals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final hospital = hospitals[index];
              final distance = HospitalRepository.distanceKm(
                location?.latitude,
                location?.longitude,
                hospital.lat,
                hospital.lng,
              );
              return SizedBox(
                width: 260,
                child: HospitalCard(
                  hospital: hospital,
                  sameAddressRecordCount: bundle?.sameAddressRecordCount(hospital) ?? 1,
                  distanceKm: distance,
                  hasUserLocation: location != null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DetailScreen(hospitalId: hospital.id)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
