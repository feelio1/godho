import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../models/medical_record.dart';
import '../models/pet.dart';
import '../models/signup_pet.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../providers/medical_record_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mascot_image.dart';
import '../widgets/mascot_message.dart';
import 'account_pet_form_screen.dart';
import 'appointment_form_screen.dart';
import 'medical_record_form_screen.dart';
import 'pet_profile_form_screen.dart';

/// "진료기록" 탭의 메인 화면 — 반려동물 건강기록(스프린트 8) + 다가오는
/// 예약(스프린트 9), 목업에 맞춘 "진료 기록/예약 알림" 탭 레이아웃(스프린트
/// 10). 스프린트 8에서는 홈의 진입 카드로만 들어올 수 있어 찾기 어렵다는
/// 문제가 있었고, 스프린트 9에서 하단 탭으로 승격했다(하단 탭 4개:
/// 홈/주변 병원/진료기록/저장). 로그인 상태에선 계정(Firestore) 반려동물을
/// 여러 마리 추가·전환할 수 있다(펫클 "계정 반려동물 추가/수정" 지시서 1) —
/// 게스트(로컬)는 여전히 1마리만 다루는 기존 흐름 그대로다.
class HealthRecordScreen extends ConsumerStatefulWidget {
  const HealthRecordScreen({super.key});

  @override
  ConsumerState<HealthRecordScreen> createState() => _HealthRecordScreenState();
}

class _HealthRecordScreenState extends ConsumerState<HealthRecordScreen> {
  String? _selectedPetId;

  Future<void> _addAccountPet(String uid) async {
    final result = await Navigator.of(context).push<AccountPetFormResult>(
      MaterialPageRoute(builder: (_) => const AccountPetFormScreen()),
    );
    if (result == null || result.isDelete || result.pet == null) return;

    final userRepo = ref.read(userRepositoryProvider);
    try {
      final petId = await userRepo.addPet(uid, result.pet!);
      if (result.newPhotoFile != null) {
        final url = await userRepo.uploadPetPhoto(uid, petId, result.newPhotoFile!);
        if (url != null) {
          await userRepo.updatePet(uid, petId, result.pet!.copyWith(photoUrl: url));
        }
      }
      ref.invalidate(accountSignupPetsProvider);
      if (!mounted) return;
      setState(() => _selectedPetId = 'account:$petId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('반려동물 추가에 실패했어요. 잠시 후 다시 시도해주세요. ($e)')),
      );
    }
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: isLoggedIn
                    ? MascotMessage(
                        title: '아직 등록된 반려동물이 없어요',
                        subtitle: '반려동물을 추가하면 진료 기록과 몸무게를 남길 수 있어요',
                        assetPath: MascotImage.emptyRecordAssetPath,
                        overlayIcon: Icons.pets,
                        trailing: FilledButton.icon(
                          onPressed: () => _addAccountPet(uid),
                          icon: const Icon(Icons.add),
                          label: const Text('반려동물 추가'),
                        ),
                      )
                    : MascotMessage(
                        title: '아직 등록된 반려동물이 없어요',
                        subtitle: '프로필을 등록하면 진료 기록과 몸무게를 기기에 남길 수 있어요',
                        assetPath: MascotImage.emptyRecordAssetPath,
                        overlayIcon: Icons.pets,
                        trailing: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PetProfileFormScreen()),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('반려동물 등록하기'),
                        ),
                      ),
              ),
            );
          }
          final selected = pets.firstWhere(
            (p) => p.id == _selectedPetId,
            orElse: () => pets.first,
          );
          return Column(
            children: [
              if (pets.length > 1)
                _PetSwitcher(
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

/// 계정 반려동물이 2마리 이상일 때만 뜨는 전환 칩(펫클 "계정 반려동물
/// 추가/수정" 지시서 1 "여러 마리 등록·전환 가능"). 게스트는 항상 1마리라
/// 이 위젯 자체가 그려지지 않는다.
class _PetSwitcher extends StatelessWidget {
  final List<Pet> pets;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _PetSwitcher({required this.pets, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: pets.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final pet = pets[i];
          return ChoiceChip(
            label: Text(pet.name),
            selected: pet.id == selectedId,
            onSelected: (_) => onSelect(pet.id),
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
    final records = ref.watch(recordsForPetProvider(pet.id));
    final upcoming = ref.watch(upcomingAppointmentsForPetProvider(pet.id));

    return DefaultTabController(
      length: 2,
      child: Column(
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
                      const Icon(Icons.smartphone_outlined, size: 18, color: AppColors.neutral),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '이 기록은 현재 기기에만 저장됩니다. 앱 삭제/기기 변경 시 사라질 수 있습니다.',
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
          const SizedBox(height: 8),
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [Tab(text: '진료 기록'), Tab(text: '예약 알림')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RecordsTab(pet: pet, records: records),
                _AppointmentsTab(pet: pet, upcoming: upcoming),
              ],
            ),
          ),
        ],
      ),
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

class _AppointmentsTab extends StatelessWidget {
  final Pet pet;
  final List<Appointment> upcoming;

  const _AppointmentsTab({required this.pet, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AppointmentFormScreen(petId: pet.id)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('예약 추가'),
          ),
        ),
        const SizedBox(height: 14),
        if (upcoming.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '다가오는 예약이 없습니다',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
        else
          ...upcoming.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AppointmentTile(appointment: a, petId: pet.id),
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
  /// 추가/수정" 지시서 2).
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

    final result = await Navigator.of(context).push<AccountPetFormResult>(
      MaterialPageRoute(builder: (_) => AccountPetFormScreen(existing: existing)),
    );
    if (result == null) return;

    final userRepo = ref.read(userRepositoryProvider);
    try {
      if (result.isDelete) {
        await userRepo.deletePet(uid, docId);
        ref.invalidate(accountSignupPetsProvider);
        onDeleted();
        return;
      }
      if (result.pet == null) return;
      var updated = result.pet!;
      if (result.newPhotoFile != null) {
        final url = await userRepo.uploadPetPhoto(uid, docId, result.newPhotoFile!);
        if (url != null) updated = updated.copyWith(photoUrl: url);
      } else if (result.removePhoto) {
        await userRepo.deletePetPhoto(uid, docId);
        updated = updated.copyWith(clearPhotoUrl: true);
      }
      await userRepo.updatePet(uid, docId, updated);
      ref.invalidate(accountSignupPetsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장에 실패했어요. 잠시 후 다시 시도해주세요. ($e)')),
      );
    }
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

/// "다가오는 예약" 한 건 — 병원·날짜시간·진료 내용과, 설정해 둔 알림
/// 시각들을 칩으로 보여준다. 판정 문구는 없다(건강·안전 원칙).
class _AppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final String petId;

  const _AppointmentTile({required this.appointment, required this.petId});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primarySoft,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentFormScreen(petId: petId, existing: appointment),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm').format(appointment.dateTime),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                appointment.hospitalName,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              if (appointment.reason.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(appointment.reason, style: textTheme.bodyMedium),
              ],
              if (appointment.reminders.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: appointment.reminders
                      .map((r) => Chip(
                            avatar: const Icon(Icons.notifications_outlined, size: 14),
                            label: Text(r.label, style: const TextStyle(fontSize: 11)),
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
