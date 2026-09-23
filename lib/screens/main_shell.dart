import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/hospital_repository.dart';
import '../models/pet.dart';
import '../providers/bundle_provider.dart';
import '../providers/fee_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/pet_provider.dart';
import '../providers/region_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/mascot_message.dart';
import 'health_record_screen.dart';
import 'home_screen.dart';
import 'nearby_map_screen.dart';
import 'saved_screen.dart';

/// Root shell holding the 4 bottom tabs: 홈 / 주변 병원 / 진료기록 / 저장
/// (스프린트 9 지시서 1 — 건강기록을 홈 진입 카드에서 탭으로 승격).
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

class _MainShellBody extends ConsumerStatefulWidget {
  const _MainShellBody();

  @override
  ConsumerState<_MainShellBody> createState() => _MainShellBodyState();
}

class _MainShellBodyState extends ConsumerState<_MainShellBody> {
  static const _exitConfirmWindow = Duration(seconds: 2);
  DateTime? _lastBackPressAt;

  /// 뒤로가기 처리(스프린트 13 지시서 3): 탭 화면 위에 더 push된 화면이
  /// 없는(=이 Scaffold가 곧 최상단 라우트인) 상태에서 시스템 뒤로가기를
  /// 눌렀을 때만 호출된다 — 상세 등 push된 화면 위에서는 그 화면이 먼저
  /// pop되므로 건드릴 필요가 없다.
  /// - 홈이 아닌 탭이면: 홈 탭으로 이동(바로 앱 종료 금지).
  /// - 홈 탭이면: 처음 누르면 "한 번 더 누르면 종료됩니다" 안내, 일정
  ///   시간 안에 한 번 더 누르면 그때 앱을 종료한다.
  void _handleBackPress() {
    final selectedIndex = ref.read(selectedTabProvider);
    if (selectedIndex != 0) {
      ref.read(selectedTabProvider.notifier).state = 0;
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPressAt;
    if (last != null && now.difference(last) < _exitConfirmWindow) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('한 번 더 누르면 종료됩니다'), duration: _exitConfirmWindow),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    // 반려동물이 등록되어 있고 체중이 입력돼 있으면, 진료비 시세 조회의
    // 체중 기준 기본값을 그 값으로 맞춘다 — 사용자가 이미 직접 고른
    // 체중 기준은 덮어쓰지 않는다(FeeWeightNotifier.applyPetWeightIfUnset).
    ref.listen<AsyncValue<List<Pet>>>(petsProvider, (previous, next) {
      final pets = next.value;
      if (pets == null || pets.isEmpty) return;
      final weightKg = pets.first.weightKg;
      if (weightKg == null) return;
      ref.read(feeWeightProvider.notifier).applyPetWeightIfUnset(weightKg);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: const [
            HomeScreen(),
            NearbyMapScreen(),
            HealthRecordScreen(),
            SavedScreen(),
          ],
        ),
        // 스프린트 15 지시서 6: 전역 배너를 걷어내고 홈 화면 안(검색 세트
        // 카드 아래)에서만 보여준다 — 네 탭 전체에 항상 떠 있지 않게.
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) =>
              ref.read(selectedTabProvider.notifier).state = index,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
            NavigationDestination(icon: Icon(Icons.near_me_outlined), selectedIcon: Icon(Icons.near_me), label: '주변 병원'),
            NavigationDestination(icon: Icon(Icons.medical_information_outlined), selectedIcon: Icon(Icons.medical_information), label: '진료기록'),
            NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: '저장'),
          ],
        ),
      ),
    );
  }
}
