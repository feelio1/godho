import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diary/screens/diary_list_body.dart';
import '../models/pet.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_focus_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../providers/pet_tab_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/guest_gate.dart';
import '../widgets/inline_error_message.dart';
import '../widgets/mascot_image.dart';
import '../widgets/mascot_message.dart';
import 'account_pet_actions.dart';
import 'pet_profile_form_screen.dart';
import 'calendar_screen.dart' show PetCalendarBody;
import 'health_record_screen.dart' show PetHealthBody;

/// "우리 아이" 탭("탭 개편" 지시서 B, "방향 개편" 지시서 D에서 일기
/// 추가, "일기를 기본 보기로" 지시서에서 기본값·순서 변경) — [일기|
/// 캘린더|진료기록] 세그먼트로 전환하고, 마지막으로 본 세그먼트를 기기에
/// 저장해 앱을 다시 켜도 이어본다. 세 보기 모두 기존 화면의 본문
/// (PetHealthBody/PetCalendarBody — 각각 health_record_screen.dart/
/// calendar_screen.dart에 있던 비공개 본문을 공개로 옮긴 것뿐, 내부
/// 로직은 그대로다 / DiaryListBody — 일기 전용 새 본문)을 그대로 쓰고,
/// 이 화면이 Scaffold/AppBar/게스트 게이팅/반려동물 선택을 한 번만
/// 갖는다 — 예전처럼 화면마다 따로 있던 걸 하나로 모았다. AppBar의 "+"
/// 버튼은 반려동물이 선택된 동안은 지금 세그먼트에 맞는 입력(일기 작성/
/// 캘린더 날짜/오늘 기록)을 열고, 반려동물이 없을 때만 반려동물 추가로
/// 돌아간다.
class PetTabScreen extends ConsumerStatefulWidget {
  const PetTabScreen({super.key});

  @override
  ConsumerState<PetTabScreen> createState() => _PetTabScreenState();
}

class _PetTabScreenState extends ConsumerState<PetTabScreen> {
  String? _selectedPetId;
  DateTime? _pendingFocusDate;

  @override
  void initState() {
    super.initState();
    restorePersistedPetTabView(ref.read(petTabViewProvider.notifier));
  }

  /// 반려동물 등록 — 등록하면 그 반려동물을 고르고 일기 보기로 바로 간다
  /// (2차 업데이트 C: 0마리 회원이 처음 등록한 뒤 일기부터 쓰게).
  Future<void> _addAccountPet(String uid) async {
    final petId = await AccountPetActions.add(context, ref, uid);
    if (petId == null || !mounted) return;
    setState(() => _selectedPetId = 'account:$petId');
    ref.read(petTabViewProvider.notifier).state = PetTabView.diary;
  }

  /// 반려동물 알약 → 아래 시트: 다른 아이로 바꾸기, 이 아이 정보 수정,
  /// 반려동물 추가.
  Future<void> _openPetSheet(String uid, List<Pet> pets, Pet selected) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final pet in pets)
              ListTile(
                leading: _PetFace(pet: pet, size: 40),
                title: Text(pet.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: pet.id == selected.id ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.of(sheetContext).pop('select:${pet.id}'),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('${selected.name} 정보 수정'),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('반려동물 추가'),
              onTap: () => Navigator.of(sheetContext).pop('add'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action.startsWith('select:')) {
      setState(() => _selectedPetId = action.substring('select:'.length));
    } else if (action == 'add') {
      await _addAccountPet(uid);
    } else if (action == 'edit') {
      await _editPet(uid, selected);
    }
  }

  /// 반려동물 정보 수정 — 계정 반려동물은 사진까지 온전한 원본([SignupPet])을
  /// 다시 찾아 공용 수정 화면으로, 로컬 반려동물은 기존 로컬 폼으로.
  Future<void> _editPet(String uid, Pet pet) async {
    if (!isAccountPetId(pet.id)) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PetProfileFormScreen(existing: pet)));
      return;
    }
    final docId = accountDocIdFromPetId(pet.id);
    final accountPets = await ref.read(accountSignupPetsProvider.future);
    final existing = accountPets.where((p) => p.id == docId).firstOrNull;
    if (existing == null || !mounted) return;
    final deleted = await AccountPetActions.editOrDelete(context, ref, uid, existing);
    if (deleted && mounted) setState(() => _selectedPetId = null);
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
          message: '로그인하면 우리 아이 진료기록·예약·일기를 기기가 바뀌어도 이어서 볼 수 있어요.',
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

    // 가입 완료 화면 등 이미 닫힌 화면이 "등록 화면을 열어 달라"고 요청한
    // 경우(2차 업데이트 C) — 이 탭이 대신 연다.
    ref.listen<int>(petRegistrationRequestProvider, (previous, next) {
      if (next != previous) _addAccountPet(uid);
    });

    // 세그먼트가 바뀔 때마다 기기에 저장해 다음 실행에서도 이어본다
    // ("일기를 기본 보기로" 지시서).
    ref.listen<PetTabView>(petTabViewProvider, (previous, next) {
      persistPetTabView(next);
    });

    final petsAsync = ref.watch(effectivePetsProvider);
    final view = ref.watch(petTabViewProvider);
    final pets = petsAsync.value;
    final selectedPet = (pets == null || pets.isEmpty)
        ? null
        : pets.firstWhere((p) => p.id == _selectedPetId, orElse: () => pets.first);

    return Scaffold(
      // "장구름의 수첩"(3차 업데이트 J-5): 큰 제목 + 오른쪽 반려동물 선택 알약.
      // 새 기록은 각 보기의 [일기 쓰기]/[진료기록 추가] 플로팅 버튼과 캘린더의
      // [이 날짜로 … 추가]에서 연다.
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text('우리 아이', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        actions: [
          if (selectedPet != null && pets != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.page),
              child: _PetPill(pet: selectedPet, onTap: () => _openPetSheet(uid, pets, selectedPet)),
            )
          else
            IconButton(icon: const Icon(Icons.add), tooltip: '반려동물 추가', onPressed: () => _addAccountPet(uid)),
        ],
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineErrorMessage(error: error, onRetry: () => ref.invalidate(effectivePetsProvider)),
        data: (pets) {
          if (pets.isEmpty) {
            // 반려동물 0마리 회원(가입 때 등록이 선택이 됨) — 세그먼트 없이
            // 등록 안내 하나만 보여 준다. 등록하면 바로 일기 보기로 간다.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: MascotMessage(
                  title: '우리 아이를 등록하면 일기와 진료기록을 남길 수 있어요',
                  assetPath: MascotImage.emptyRecordAssetPath,
                  overlayIcon: Icons.pets,
                  trailing: FilledButton.icon(
                    key: const ValueKey('pet_tab_register'),
                    onPressed: () => _addAccountPet(uid),
                    icon: const Icon(Icons.add),
                    label: const Text('반려동물 등록'),
                  ),
                ),
              ),
            );
          }
          final selected = pets.firstWhere((p) => p.id == _selectedPetId, orElse: () => pets.first);
          return Column(
            children: [
              _ViewSegment(value: view),
              Expanded(
                child: IndexedStack(
                  index: switch (view) {
                    PetTabView.records => 0,
                    PetTabView.calendar => 1,
                    PetTabView.diary => 2,
                  },
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
                    DiaryListBody(key: ValueKey('diary-${selected.id}'), selectedPet: selected, allPets: pets),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 4),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<PetTabView>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: PetTabView.diary, label: Text('일기')),
            ButtonSegment(value: PetTabView.calendar, label: Text('캘린더')),
            ButtonSegment(value: PetTabView.records, label: Text('진료기록')),
          ],
          selected: {value},
          onSelectionChanged: (selection) => ref.read(petTabViewProvider.notifier).state = selection.first,
        ),
      ),
    );
  }
}

/// 앱바 오른쪽 반려동물 선택 알약 — 사진(없으면 구름이 얼굴) + 이름 + ▾.
class _PetPill extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;

  const _PetPill({required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '반려동물 ${pet.name} 선택',
      child: Material(
        color: AppColors.surfaceLight,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.borderCard)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PetFace(pet: pet, size: 38),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 반려동물 얼굴 — 구름 같은 옅은 하늘색 동그라미 속 사진, 사진이 없으면
/// 구름이 얼굴. 계정 반려동물 사진은 원본([SignupPet.photoUrl])에서 찾는다.
class _PetFace extends ConsumerWidget {
  final Pet pet;
  final double size;

  const _PetFace({required this.pet, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? photoUrl;
    if (isAccountPetId(pet.id)) {
      final docId = accountDocIdFromPetId(pet.id);
      final accountPets = ref.watch(accountSignupPetsProvider).value ?? const [];
      photoUrl = accountPets.where((p) => p.id == docId).firstOrNull?.photoUrl;
    }
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: AppColors.feeRangeFill, shape: BoxShape.circle),
      child: ClipOval(
        child: photoUrl != null
            ? CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover)
            : pet.photoPath != null
            ? Image.file(File(pet.photoPath!), fit: BoxFit.cover)
            : Container(
                color: AppColors.warmBackground,
                child: MascotImage(size: size - 6, semanticLabel: pet.name),
              ),
      ),
    );
  }
}
