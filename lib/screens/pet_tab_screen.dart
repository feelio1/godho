import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/calendar_focus_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../providers/pet_tab_provider.dart';
import '../theme/app_dimens.dart';
import '../widgets/guest_gate.dart';
import '../widgets/inline_error_message.dart';
import '../widgets/no_pets_message.dart';
import '../widgets/pet_switcher.dart';
import 'account_pet_actions.dart';
import 'calendar_screen.dart' show PetCalendarBody;
import 'health_record_screen.dart' show PetHealthBody;

/// "우리 아이" 탭("탭 개편" 지시서 B) — 예전엔 "캘린더"·"진료기록"이 각자
/// 독립 탭이었지만, 이제 이 하나의 탭 안에서 [진료기록|캘린더] 세그먼트로
/// 전환한다. 두 보기 모두 기존 화면의 본문(PetHealthBody/PetCalendarBody —
/// 각각 health_record_screen.dart/calendar_screen.dart에 있던 비공개
/// 본문을 공개로 옮긴 것뿐, 내부 로직은 그대로다)을 그대로 쓰고, 이 화면이
/// Scaffold/AppBar/게스트 게이팅/반려동물 선택을 한 번만 갖는다 — 예전처럼
/// 화면마다 따로 있던 걸 하나로 모았다.
class PetTabScreen extends ConsumerStatefulWidget {
  const PetTabScreen({super.key});

  @override
  ConsumerState<PetTabScreen> createState() => _PetTabScreenState();
}

class _PetTabScreenState extends ConsumerState<PetTabScreen> {
  String? _selectedPetId;
  DateTime? _pendingFocusDate;

  Future<void> _addAccountPet(String uid) async {
    final petId = await AccountPetActions.add(context, ref, uid);
    if (petId == null || !mounted) return;
    setState(() => _selectedPetId = 'account:$petId');
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 상태면 계정(Firestore) 반려동물이, 게스트면 기존 로컬
    // 반려동물이 뜬다 — 두 보기가 같은 소스(effectivePetsProvider)를 본다.
    final uid = ref.watch(authStateProvider).value?.uid;

    // 진료기록·캘린더 둘 다 로그인 필요 기능이다("로그인 게이팅" 지시서
    // 1). 게스트는 어느 세그먼트를 고르든 같은 안내 하나만 본다 — 탭 단위로
    // 1번만 보여준다는 원칙("탭 개편" 지시서 B)대로, 세그먼트별로 다른
    // 안내를 보여주지 않는다.
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('우리 아이')),
        body: const GuestFeatureNotice(
          title: '로그인하면 우리 아이 기록을 쓸 수 있어요',
          message: '로그인하면 우리 아이 진료기록·예약을 기기가 바뀌어도 이어서 볼 수 있어요.',
        ),
      );
    }

    // 홈의 "우리 아이" 카드(가장 가까운 예약)에서 넘어온 1회성 포커스
    // 요청 — 반영하자마자 비운다("출시 전 마무리" 지시서 C, "탭 개편"
    // 지시서 A). 캘린더 보기로 바꾸고 해당 반려동물·날짜를 선택한다.
    ref.listen<CalendarFocusRequest?>(calendarFocusRequestProvider, (previous, next) {
      if (next == null) return;
      setState(() {
        _selectedPetId = next.petId;
        _pendingFocusDate = next.date;
      });
      ref.read(petTabViewProvider.notifier).state = PetTabView.calendar;
      ref.read(calendarFocusRequestProvider.notifier).state = null;
    });

    final petsAsync = ref.watch(effectivePetsProvider);
    final view = ref.watch(petTabViewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('우리 아이'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '반려동물 추가',
            onPressed: () => _addAccountPet(uid),
          ),
        ],
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineErrorMessage(
          error: error,
          onRetry: () => ref.invalidate(effectivePetsProvider),
        ),
        data: (pets) {
          if (pets.isEmpty) {
            return Column(
              children: [
                _ViewSegment(value: view),
                Expanded(
                  child: NoPetsMessage(
                    isLoggedIn: true,
                    onAddAccountPet: () => _addAccountPet(uid),
                  ),
                ),
              ],
            );
          }
          final selected = pets.firstWhere(
            (p) => p.id == _selectedPetId,
            orElse: () => pets.first,
          );
          return Column(
            children: [
              _ViewSegment(value: view),
              if (pets.length > 1)
                PetSwitcher(
                  pets: pets,
                  selectedId: selected.id,
                  onSelect: (id) => setState(() => _selectedPetId = id),
                ),
              Expanded(
                child: IndexedStack(
                  index: view == PetTabView.records ? 0 : 1,
                  children: [
                    PetHealthBody(
                      key: ValueKey('records-${selected.id}'),
                      pet: selected,
                      onPetDeleted: () => setState(() => _selectedPetId = null),
                    ),
                    PetCalendarBody(
                      key: ValueKey('calendar-${selected.id}'),
                      pet: selected,
                      initialDate: _pendingFocusDate,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ViewSegment extends ConsumerWidget {
  final PetTabView value;

  const _ViewSegment({required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 4),
      child: SegmentedButton<PetTabView>(
        segments: const [
          ButtonSegment(
            value: PetTabView.records,
            label: Text('진료기록'),
            icon: Icon(Icons.medical_information_outlined),
          ),
          ButtonSegment(
            value: PetTabView.calendar,
            label: Text('캘린더'),
            icon: Icon(Icons.calendar_month_outlined),
          ),
        ],
        selected: {value},
        onSelectionChanged: (selection) =>
            ref.read(petTabViewProvider.notifier).state = selection.first,
      ),
    );
  }
}
