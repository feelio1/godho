import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../ads/global_banner_ad.dart';
import '../data/hospital_repository.dart';
import '../providers/bundle_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/region_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/mascot_message.dart';
import 'home_screen.dart';
import 'nearby_map_screen.dart';
import 'saved_screen.dart';

/// Root shell holding the 3 bottom tabs: 홈 / 주변 병원 / 저장.
///
/// Every tab reads from [repositoryProvider], which requires the bundle to
/// already be loaded — so the whole shell waits for it here rather than
/// each tab guarding individually. [IndexedStack] builds all three tabs up
/// front (to preserve their state across switches), so without this gate a
/// non-visible tab could still crash on the still-loading bundle.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(bundleProvider);

    return bundleAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: MascotMessage(
            title: '정보를 불러오고 있어요',
            subtitle: '공개된 동물병원 인허가 정보를 준비 중입니다',
            trailing: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      ),
      error: (error, _) =>
          Scaffold(body: Center(child: Text('데이터를 불러오지 못했습니다: $error'))),
      data: (_) => const _MainShellBody(),
    );
  }
}

class _MainShellBody extends ConsumerWidget {
  const _MainShellBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);

    // Watching locationProvider here (via listen) starts its silent,
    // non-prompting permission check as soon as the shell loads. If
    // location was already granted in an earlier session, this picks a
    // default region and sort — but never overrides an explicit user choice
    // (see RegionNotifier.applyGpsRegionIfUnset / sortManuallySetProvider).
    ref.listen<AsyncValue<Position?>>(locationProvider, (previous, next) {
      final position = next.value;
      if (position == null) return;
      final repo = ref.read(repositoryProvider);
      final nearest = repo.nearestRegion(position.latitude, position.longitude);
      if (nearest != null) {
        ref.read(regionProvider.notifier).applyGpsRegionIfUnset(nearest);
      }
      if (!ref.read(sortManuallySetProvider)) {
        ref.read(sortOptionProvider.notifier).state = SortOption.distance;
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          HomeScreen(),
          NearbyMapScreen(),
          SavedScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 하단 탭 바 위에 전역 배너 광고 (스프린트 5 지시서 2). 홈/주변
          // 병원/저장 세 탭 모두 이 한 곳에서 커버된다.
          const GlobalBannerAd(),
          NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                ref.read(selectedTabProvider.notifier).state = index,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
              NavigationDestination(icon: Icon(Icons.near_me_outlined), selectedIcon: Icon(Icons.near_me), label: '주변 병원'),
              NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: '저장'),
            ],
          ),
        ],
      ),
    );
  }
}
