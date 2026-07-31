import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import '../models/hospital_status.dart';
import '../models/region_filter.dart';
import '../providers/bundle_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/recent_provider.dart';
import '../providers/region_provider.dart';
import '../providers/saved_provider.dart';
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
    final recentIds = ref.watch(recentHospitalsProvider).value ?? const [];
    final savedIds = ref.watch(savedHospitalsProvider).value ?? const [];
    final region = ref.watch(regionProvider).value?.filter ?? const RegionFilter.all();
    final location = ref.watch(locationProvider).value;

    final recentHospitals =
        recentIds.map(repo.byId).whereType<Hospital>().toList();
    final savedHospitals =
        savedIds.map(repo.byId).whereType<Hospital>().toList();

    final showFallback = recentHospitals.isEmpty && savedHospitals.isEmpty;
    final fallbackHospitals = showFallback
        ? repo
            .sortHospitals(
              repo
                  .filterByRegion(repo.all, region)
                  .where((h) => h.status == HospitalStatus.open)
                  .toList(),
              SortOption.recentOpen,
            )
            .take(10)
            .toList()
        : const <Hospital>[];

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
        const SizedBox(height: 12),
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
        if (recentHospitals.isNotEmpty)
          _HospitalSection(
            title: '최근 확인한 병원',
            hospitals: recentHospitals,
            location: location,
          ),
        if (savedHospitals.isNotEmpty) ...[
          if (recentHospitals.isNotEmpty) const SizedBox(height: 24),
          _HospitalSection(
            title: '저장한 병원',
            hospitals: savedHospitals,
            location: location,
          ),
        ],
        if (showFallback)
          _HospitalSection(
            title: '내 지역 최근 개원 병원',
            hospitals: fallbackHospitals,
            location: location,
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
