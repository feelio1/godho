import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/cloud_migration_service.dart';
import '../data/effective_appointment_actions.dart';
import '../data/hospital_repository.dart' show SortOption;
import '../models/appointment.dart';
import '../models/pet.dart';
import '../providers/auth_provider.dart';
import '../providers/bundle_provider.dart';
import '../providers/cloud_migration_provider.dart';
import '../providers/fee_provider.dart';
import '../providers/followup_appointment_provider.dart';
import '../providers/location_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/pet_provider.dart';
import '../providers/region_auto_detect.dart';
import '../providers/search_provider.dart';
import '../theme/app_dimens.dart';
import '../utils/appointment_calendar.dart' show dateOnly;
import '../utils/followup_appointment.dart' show shouldResetFollowUpSession;
import '../widgets/followup_check_sheet.dart';
import '../widgets/mascot_message.dart';
import 'appointment_form_screen.dart';
import 'calendar_screen.dart';
import 'health_record_screen.dart';
import 'home_screen.dart';
import 'medical_record_form_screen.dart';
import 'my_info_screen.dart';
import 'nearby_map_screen.dart';

/// Root shell holding the 5 bottom tabs: 홈 / 지도 / 캘린더 / 진료기록 /
/// 내 정보("디자인 1단계" 지시서 1 — IA 재구성. "주변" 라벨은 "지도"로,
/// "저장" 탭은 "내 정보" 탭으로 바뀌었다. 저장 화면 자체는 사라지지
/// 않고 내 정보 탭에서 진입한다). 이전엔 "저장" 탭이었다(스프린트 9
/// 지시서 1 — 건강기록을 홈 진입 카드에서 탭으로 승격, "캘린더
/// 하단탭화 + 진료 연대기" 지시서 A1 — 진료기록 화면 안에 있던 예약
/// 캘린더를 독립 탭으로 승격).
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

class _MainShellBodyState extends ConsumerState<_MainShellBody> with WidgetsBindingObserver {
  static const _exitConfirmWindow = Duration(seconds: 2);
  DateTime? _lastBackPressAt;

  // "지난 예약 확인" 지시서 3, "기준 시각 변경" 지시서 4 — 같은 세션에선
  // 한 번만 묻는다. 백그라운드에 5분 넘게 머물다 복귀하면 새 세션으로
  // 쳐서 didChangeAppLifecycleState에서 다시 false로 되돌린다("복귀 시
  // 과도한 재노출 방지" 지시서 2) — 사진 선택·로그인 창 같은 짧은 전환
  // 으로는 재질문하지 않되, 오래 비웠다 돌아오면 그사이 지났을 수 있는
  // 예약을 다시 물을 수 있어야 한다.
  bool _followUpShownThisSession = false;
  // 백그라운드 복귀 직후부터 앱 오픈 광고 흐름이 끝났다는 신호
  // (appOpenAdFlowSettledProvider)가 올 때까지는 확인 시트를 띄우지
  // 않는다(겹침 금지). 콜드 스타트에는 광고가 뜨지 않으므로(AppOpenAdGate
  // 자체 설계) 이 플래그는 항상 false로 시작한다.
  bool _awaitingAdFlowSettle = false;
  // pendingFollowUpProvider를 invalidate하면(아래) 그 provider를 보는
  // ref.listen이 다시 이 함수를 부를 수 있다 — 재진입으로 무한 루프가
  // 되지 않게 막는다("기준 시각 변경" 지시서 3).
  bool _checkingFollowUp = false;
  // paused로 들어간 시각 — resumed에서 shouldResetFollowUpSession이
  // "5분 이상 백그라운드"였는지 가릴 때 쓴다.
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 콜드 스타트 — 반려동물·예약 데이터가 아직 로딩 중이면
    // pendingFollowUpProvider의 ref.listen이 데이터가 들어온 뒤 다시
    // 알려주므로, 여기서는 이미 로딩이 끝나 있는 경우(드묾)만 바로 확인.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowFollowUpSheet());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _awaitingAdFlowSettle = true;
      final pausedAt = _pausedAt;
      _pausedAt = null;
      // 5분 넘게 백그라운드에 있었을 때만 새 세션으로 친다 — 사진
      // 선택·로그인 창 같은 짧은 전환으로는 다시 묻지 않는다("복귀 시
      // 과도한 재노출 방지" 지시서 2).
      if (shouldResetFollowUpSession(pausedAt: pausedAt, resumedAt: DateTime.now())) {
        _followUpShownThisSession = false;
      }
    }
  }

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

  /// 지난 예약 "진료 받으셨어요?" 확인 시트를 띄울 수 있는 상태인지
  /// 확인하고, 조건이 맞으면 딱 1건만 띄운다("지난 예약 확인" 지시서 1,
  /// 3) — 이미 이 세션에서 띄웠거나, 광고 흐름이 아직 안 끝났거나, 홈
  /// 탭이 보이는 중이 아니거나, MainShell 자신의 라우트가 최상단이
  /// 아니거나(기록 폼·상세·다른 시트/다이얼로그가 떠 있음), 확인할
  /// 예약이 없으면 조용히 넘어간다. "[네]로 기록 폼에 들어가 있는
  /// 동안엔 다시 묻지 않음"도 이 라우트 체크 하나로 자연히 막힌다 —
  /// 그 폼이 바로 최상단 라우트가 되기 때문에 별도 진행-중-예약 id
  /// 가드는 필요 없다("복귀 시 과도한 재노출 방지" 지시서 1, 3).
  ///
  /// pendingFollowUpProvider는 내부에서 DateTime.now()를 한 번만 계산해
  /// 캐시하므로, 호출될 때마다 먼저 invalidate해 항상 "지금" 시각
  /// 기준으로 다시 계산하게 한다 — 앱이 백그라운드에 머무는 동안 시각이
  /// 지나 새로 지난 예약이 된 건을 놓치지 않기 위해서다("기준 시각
  /// 변경" 지시서 3). invalidate가 이 provider를 보는 ref.listen을
  /// 다시 불러 이 함수가 재진입될 수 있어 `_checkingFollowUp`으로 막는다.
  void _maybeShowFollowUpSheet() {
    if (_checkingFollowUp) return;
    _checkingFollowUp = true;
    try {
      if (_followUpShownThisSession || _awaitingAdFlowSettle || !mounted) return;
      if (ref.read(selectedTabProvider) != 0) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      ref.invalidate(pendingFollowUpProvider);
      final pending = ref.read(pendingFollowUpProvider);
      if (pending == null) return;

      _followUpShownThisSession = true;
      _showFollowUpSheet(pending.pet, pending.appointment);
    } finally {
      _checkingFollowUp = false;
    }
  }

  void _showFollowUpSheet(Pet pet, Appointment appointment) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (sheetContext) => FollowUpCheckSheet(
        petName: pet.name,
        appointment: appointment,
        onRecorded: () => _handleFollowUpRecorded(sheetContext, pet, appointment),
        onSkipped: () => _handleFollowUpSkipped(sheetContext, pet, appointment),
        onLater: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  /// "네, 기록 남길게요" — 예약 내용을 미리 채운 진료기록 폼으로 넘기고,
  /// 저장에 성공했을 때만(폼이 true로 pop됐을 때만) recorded로
  /// 표시한다. 폼에서 그냥 뒤로 나가면 미처리로 남아 다음에 다시 묻는다.
  Future<void> _handleFollowUpRecorded(
    BuildContext sheetContext,
    Pet pet,
    Appointment appointment,
  ) async {
    Navigator.of(sheetContext).pop();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MedicalRecordFormScreen(
          petId: pet.id,
          initialDate: dateOnly(appointment.dateTime),
          initialHospitalId: appointment.hospitalId,
          initialHospitalName: appointment.hospitalName,
          initialCategory: appointment.reason,
          initialMemo: appointment.memo,
        ),
      ),
    );
    if (saved == true) {
      await EffectiveAppointmentActions.markFollowUp(ref, appointment, AppointmentFollowUp.recorded);
    }
  }

  /// "안 갔어요" — skipped로 표시한 뒤, 재예약 여부를 짧게 물어본다.
  Future<void> _handleFollowUpSkipped(
    BuildContext sheetContext,
    Pet pet,
    Appointment appointment,
  ) async {
    Navigator.of(sheetContext).pop();
    await EffectiveAppointmentActions.markFollowUp(ref, appointment, AppointmentFollowUp.skipped);
    if (!mounted) return;

    final rebook = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('다시 예약할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('괜찮아요'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('예약하기'),
          ),
        ],
      ),
    );
    if (rebook == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppointmentFormScreen(
            petId: pet.id,
            initialHospitalId: appointment.hospitalId,
            initialHospitalName: appointment.hospitalName,
            initialReason: appointment.reason,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedTabProvider);

    // 지난 예약 확인 — 데이터가 (뒤늦게) 들어와 확인 대상이 생기면
    // 바로, 백그라운드 복귀 뒤엔 광고 흐름이 끝났다는 신호를 받고서야
    // 띄운다("지난 예약 확인" 지시서 3).
    ref.listen<PendingFollowUp?>(pendingFollowUpProvider, (previous, next) {
      if (next != null) _maybeShowFollowUpSheet();
    });
    ref.listen<int>(appOpenAdFlowSettledProvider, (previous, next) {
      if (previous == next) return;
      _awaitingAdFlowSettle = false;
      _maybeShowFollowUpSheet();
    });

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
            MyInfoScreen(),
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
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '지도'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '캘린더'),
            NavigationDestination(icon: Icon(Icons.medical_information_outlined), selectedIcon: Icon(Icons.medical_information), label: '진료기록'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내 정보'),
          ],
        ),
      ),
    );
  }
}
