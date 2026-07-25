import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bundle_provider.dart';
import '../providers/nav_provider.dart';
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
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

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          HomeScreen(),
          NearbyMapScreen(),
          SavedScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            ref.read(selectedTabProvider.notifier).state = index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.near_me_outlined), selectedIcon: Icon(Icons.near_me), label: '주변 병원'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: '저장'),
        ],
      ),
    );
  }
}
