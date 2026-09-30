import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/medical_record.dart';
import '../models/pet.dart';
import '../models/signup_pet.dart';
import '../providers/auth_provider.dart';
import '../providers/effective_medical_records_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mascot_image.dart';
import '../widgets/mascot_message.dart';
import '../widgets/no_pets_message.dart';
import '../widgets/pet_switcher.dart';
import 'account_pet_actions.dart';
import 'medical_record_form_screen.dart';
import 'pet_profile_form_screen.dart';

/// "진료기록" 탭의 메인 화면 — 반려동물 건강기록 리스트(스프린트 8). 예약은
/// 더 이상 여기 탭으로 두지 않는다 — "캘린더" 탭으로 독립해서(하단 탭 5개:
/// 홈/주변 병원/캘린더/진료기록/저장) 과거 진료기록과 함께 보여주므로,
/// 여기서 또 보여주면 같은 정보가 두 곳에 중복된다("캘린더 하단탭화 + 진료
/// 연대기" 지시서 A5). 로그인 상태에선 계정(Firestore) 반려동물을 여러
/// 마리 추가·전환할 수 있다(펫클 "계정 반려동물 추가/수정" 지시서 1) —
/// 게스트(로컬)는 여전히 1마리만 다루는 기존 흐름 그대로다.
class HealthRecordScreen extends ConsumerStatefulWidget {
  const HealthRecordScreen({super.key});

  @override
  ConsumerState<HealthRecordScreen> createState() => _HealthRecordScreenState();
}

class _HealthRecordScreenState extends ConsumerState<HealthRecordScreen> {
  String? _selectedPetId;

  Future<void> _addAccountPet(String uid) async {
    final petId = await AccountPetActions.add(context, ref, uid);
    if (petId == null || !mounted) return;
    setState(() => _selectedPetId = 'account:$petId');
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 상태면 계정(Firestore) 반려동물이, 게스트면 기존 로컬
    // 반려동물이 뜬다 — effectivePetsProvider가 그 전환을 맡는다(펫클
    // 3단계 지시서 2). 로컬 데이터 자체는 이 화면이 무엇을 보여주든 절대
    // 건드리지 않는다.
    final petsAsync = ref.watch(effectivePetsProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final isLoggedIn = uid != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('진료기록'),
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '반려동물 추가',
              onPressed: () => _addAccountPet(uid),
            ),
        ],
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('불러오지 못했습니다: $error')),
        data: (pets) {
          if (pets.isEmpty) {
            return NoPetsMessage(
              isLoggedIn: isLoggedIn,
              onAddAccountPet: () => _addAccountPet(uid!),
            );
          }
          final selected = pets.firstWhere(
            (p) => p.id == _selectedPetId,
            orElse: () => pets.first,
          );
          return Column(
            children: [
              if (pets.length > 1)
                PetSwitcher(
                  pets: pets,
                  selectedId: selected.id,
                  onSelect: (id) => setState(() => _selectedPetId = id),
                ),
              Expanded(
                child: _PetHealthBody(
                  pet: selected,
                  onPetDeleted: () => setState(() => _selectedPetId = null),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PetHealthBody extends ConsumerWidget {
  final Pet pet;
  final VoidCallback onPetDeleted;

  const _PetHealthBody({required this.pet, required this.onPetDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 계정(로그인) 반려동물이면 Firestore를, 게스트/로컬이면 기존 로컬
    // 저장소를 실시간으로 본다 — 진료기록 화면에서 기록하든 캘린더에서
    // 기록하든 같은 provider라 자동으로 반영된다("진료기록·예약 Firestore
    // 저장" 지시서 B-2).
    final records = ref.watch(effectiveRecordsForPetProvider(pet.id)).value ?? const [];
    final isAccountPet = isAccountPetId(pet.id);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              _PetProfileCard(pet: pet, onDeleted: onPetDeleted),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.neutralBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAccountPet ? Icons.cloud_outlined : Icons.smartphone_outlined,
                      size: 18,
                      color: AppColors.neutral,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAccountPet
                            ? '이 기록은 계정에 저장됩니다. 다른 기기에서도 로그인하면 볼 수 있어요.'
                            : '이 기록은 현재 기기에만 저장됩니다. 앱 삭제/기기 변경 시 사라질 수 있습니다.',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SummaryRow(records: records),
            ],
          ),
        ),
        Expanded(child: _RecordsTab(pet: pet, records: records)),
      ],
    );
  }
}

class _RecordsTab extends StatelessWidget {
  final Pet pet;
  final List<MedicalRecord> records;

  const _RecordsTab({required this.pet, required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: MascotMessage(
            title: '아직 진료기록이 없어요',
            subtitle: '병원 방문·접종·몸무게를 기록해두면 여기에서 한눈에 볼 수 있어요.',
            assetPath: MascotImage.emptyRecordAssetPath,
            overlayIcon: Icons.description_outlined,
            trailing: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MedicalRecordFormScreen(petId: pet.id)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('첫 기록 남기기'),
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MedicalRecordFormScreen(petId: pet.id)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('진료 기록 추가'),
          ),
        ),
        const SizedBox(height: 14),
        ...records.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RecordTile(record: r, pet: pet),
          ),
        ),
      ],
    );
  }
}

class _PetProfileCard extends ConsumerWidget {
  final Pet pet;
  final VoidCallback onDeleted;

  const _PetProfileCard({required this.pet, required this.onDeleted});

  /// 계정 반려동물 수정 — 사진 미리보기까지 온전한 원본([SignupPet])을
  /// [accountSignupPetsProvider]에서 다시 찾아 폼에 넘긴다([Pet]으로
  /// 변환하는 과정에서 photoUrl이 손실되기 때문이다, 펫클 "계정 반려동물
  /// 추가/수정" 지시서 2). 실제 추가/수정/삭제 로직은 [AccountPetActions]
  /// 공용 헬퍼가 맡는다(홈의 계정 메뉴와 동일한 코드 경로, "계정 메뉴에
  /// 반려동물 관리 통합" 지시서).
  Future<void> _editAccountPet(BuildContext context, WidgetRef ref, String uid) async {
    final docId = accountDocIdFromPetId(pet.id);
    final accountPets = await ref.read(accountSignupPetsProvider.future);
    SignupPet existing;
    try {
      existing = accountPets.firstWhere((p) => p.id == docId);
    } catch (_) {
      // 목록에서 이미 사라진 반려동물(다른 화면/기기에서 먼저 삭제됨 등) —
      // 수정할 대상이 없으니 조용히 무시한다.
      return;
    }
    if (!context.mounted) return;

    final deleted = await AccountPetActions.editOrDelete(context, ref, uid, existing);
    if (deleted) onDeleted();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleParts = <String>[
      if (pet.breed != null && pet.breed!.isNotEmpty) pet.breed! else pet.species.label,
      if (pet.ageLabel != null) pet.ageLabel!,
      if (pet.weightKg != null) '${pet.weightKg}kg',
    ];
    final isAccountPet = isAccountPetId(pet.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primarySoft,
              backgroundImage: pet.photoPath != null ? FileImage(File(pet.photoPath!)) : null,
              child: pet.photoPath == null
                  ? const Icon(Icons.pets, size: 28, color: AppColors.primaryDark)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(pet.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(subtitleParts.join(' · '), style: textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                if (isAccountPet) {
                  final uid = ref.read(authStateProvider).value?.uid;
                  if (uid != null) _editAccountPet(context, ref, uid);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PetProfileFormScreen(existing: pet)),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 기록 개수·진료비 합계·최근 몸무게만 보여주는 최소 요약(스프린트 8 지시서
/// 2). 그래프·통계·판정은 이번 범위가 아니다.
class _SummaryRow extends StatelessWidget {
  final List<MedicalRecord> records;

  const _SummaryRow({required this.records});

  @override
  Widget build(BuildContext context) {
    final totalCost = records.fold<int>(0, (sum, r) => sum + (r.costWon ?? 0));
    final latestWeight = records
        .firstWhere(
          (r) => r.weightKg != null,
          orElse: () => MedicalRecord(id: '', petId: '', date: DateTime.fromMillisecondsSinceEpoch(0), hospitalName: ''),
        )
        .weightKg;

    return Card(
      color: AppColors.primarySoft,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            _SummaryItem(label: '기록', value: '${records.length}건'),
            _SummaryItem(
              label: '총 진료비',
              value: totalCost > 0 ? '${NumberFormat('#,###').format(totalCost)}원' : '기록 없음',
            ),
            _SummaryItem(
              label: '최근 몸무게',
              value: latestWeight != null ? '${latestWeight}kg' : '기록 없음',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral)),
        ],
      ),
    );
  }
}


class _RecordTile extends StatelessWidget {
  final MedicalRecord record;
  final Pet pet;

  const _RecordTile({required this.record, required this.pet});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chips = <String>[
      if (record.weightKg != null) '${record.weightKg}kg',
      if (record.costWon != null) '${NumberFormat('#,###').format(record.costWon)}원',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MedicalRecordFormScreen(petId: pet.id, existing: record),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy.MM.dd').format(record.date),
                      style: textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.hospitalName,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (record.memo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(record.memo,
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: chips
                            .map((c) => Chip(
                                  label: Text(c, style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: pet.photoPath != null ? FileImage(File(pet.photoPath!)) : null,
                child: pet.photoPath == null
                    ? const Icon(Icons.pets, size: 18, color: AppColors.primaryDark)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
