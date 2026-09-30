import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/cloud_migration_service.dart';
import '../data/hospital_repository.dart' show SortOption;
import '../models/pet.dart';
import '../providers/auth_provider.dart';
import '../providers/bundle_provider.dart';
import '../providers/cloud_migration_provider.dart';
import '../providers/fee_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/pet_provider.dart';
import '../providers/region_auto_detect.dart';
import '../providers/search_provider.dart';
import '../widgets/mascot_message.dart';
import 'calendar_screen.dart';
import 'health_record_screen.dart';
import 'home_screen.dart';
import 'nearby_map_screen.dart';
import 'saved_screen.dart';

/// Root shell holding the 5 bottom tabs: 홈 / 주변 병원 / 캘린더 / 진료기록 /
/// 저장(스프린트 9 지시서 1 — 건강기록을 홈 진입 카드에서 탭으로 승격,
/// "캘린더 하단탭화 + 진료 연대기" 지시서 A1 — 진료기록 화면 안에 있던
/// 예약 캘린더를 독립 탭으로 승격).
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

  /// 로그인 사용자의 기기 로컬 진료기록·예약을 계정(Firestore)으로 1회
  /// 옮긴다("진료기록·예약 Firestore 저장" 지시서 B-3) — 계정당 1회만
  /// 시도하도록 서비스 내부에서 플래그로 막아두므로 이 함수 자체는 로그인
  /// 때마다(재실행 포함) 불러도 안전하다. 원본 로컬 데이터는 건드리지
  /// 않고, 무엇을 옮겼는지/옮기지 못했는지만 짧게 알려준다.
  Future<void> _runCloudMigration(String uid) async {
    final service = ref.read(cloudMigrationServiceProvider);
    CloudMigrationResult? result;
    try {
      result = await service.migrateIfNeeded(uid);
    } catch (_) {
      // 이관은 어디까지나 편의 기능 — 실패해도 앱 정상 동작에는 영향 없다.
      return;
    }
    if (result == null || !mounted) return;

    final parts = <String>[];
    if (result.didMigrateAnything) {
      parts.add('${result.migratedPetNames.join(', ')}의 기기 기록을 계정으로 옮겨뒀어요.');
    }
    if (result.hasSkipped) {
      parts.add('${result.skippedPetNames.join(', ')}는 이름이 일치하는 계정 반려동물을 찾지 못해 '
          '옮기지 못했어요. 진료기록 화면에서 새로 추가해주세요.');
    }
    if (parts.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(parts.join(' ')), duration: const Duration(seconds: 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedTabProvider);

    // 로그인(또는 이미 로그인된 채 앱을 다시 시작)할 때마다 이 uid로
    // 이관을 시도한다 — 실제로 옮길 게 있는지, 이미 한 번 시도했는지는
    // 서비스 내부 플래그가 가른다.
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      final user = next.value;
      if (user == null) return;
      if (previous?.value?.uid == user.uid) return;
      unawaited(_runCloudMigration(user.uid));
    });

    // Watching locationProvider here (via listen) starts its silent,
    // non-prompting permission check as soon as the shell loads. If
    // location was already granted in an earlier session, this picks a
    // default region and sort — but never overrides an explicit user choice
    // (see RegionNotifier.applyGpsRegionIfUnset / sortManuallySetProvider).
    //
    // 지역 판정·사유 기록은 applyDetectedRegionFromPosition 한 곳에서
    // 전담한다(위치 자동감지 디버깅 지시서 A·E) — 로딩 중간 상태(next.
    // isLoading)는 무시하고, settle된 최종 상태에서만 반응한다. position이
    // null이어도 그냥 무시하지 않고 사유(위치서비스 꺼짐/권한 거부/좌표
    // 획득 실패)를 기록해야 화면 26이 "조용한 실패" 없이 안내할 수 있다.
    ref.listen<AsyncValue<Position?>>(locationProvider, (previous, next) {
      if (next.isLoading) return;
      applyDetectedRegionFromPosition(ref, next.value);
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
            CalendarScreen(),
            HealthRecordScreen(),
            SavedScreen(),
          ],
        ),
        // 스프린트 15 지시서 6: 전역 배너를 걷어내고 홈 화면 안(검색 세트
        // 카드 아래)에서만 보여준다 — 다섯 탭 전체에 항상 떠 있지 않게.
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) =>
              ref.read(selectedTabProvider.notifier).state = index,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
            NavigationDestination(icon: Icon(Icons.near_me_outlined), selectedIcon: Icon(Icons.near_me), label: '주변'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '캘린더'),
            NavigationDestination(icon: Icon(Icons.medical_information_outlined), selectedIcon: Icon(Icons.medical_information), label: '진료기록'),
            NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: '저장'),
          ],
        ),
      ),
    );
  }
}
