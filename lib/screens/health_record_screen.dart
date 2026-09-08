import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/medical_record.dart';
import '../models/pet.dart';
import '../providers/medical_record_provider.dart';
import '../providers/pet_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mascot_message.dart';
import 'medical_record_form_screen.dart';
import 'pet_profile_form_screen.dart';

/// "우리 아이" 반려동물 건강기록 — 로컬 최소 버전(스프린트 8 지시서 2).
/// 하단 탭이 아니라 홈의 진입점 카드에서 들어오는 별도 화면이다(CLAUDE.md
/// 하단 탭 3개 원칙 유지). 지금은 반려동물 1마리만 다루지만, 데이터 구조는
/// 여러 마리를 담을 수 있다.
class HealthRecordScreen extends ConsumerWidget {
  const HealthRecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('우리 아이')),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('불러오지 못했습니다: $error')),
        data: (pets) {
          if (pets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: MascotMessage(
                  title: '아직 등록된 반려동물이 없어요',
                  subtitle: '프로필을 등록하면 진료 기록과 몸무게를 기기에 남길 수 있어요',
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
          final pet = pets.first;
          return _PetHealthBody(pet: pet);
        },
      ),
    );
  }
}

class _PetHealthBody extends ConsumerWidget {
  final Pet pet;

  const _PetHealthBody({required this.pet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsForPetProvider(pet.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PetProfileCard(pet: pet),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SummaryRow(records: records),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '진료 기록',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MedicalRecordFormScreen(petId: pet.id)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('기록 추가'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '아직 등록된 진료 기록이 없습니다',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
        else
          ...records.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecordTile(record: r, petId: pet.id),
            ),
          ),
      ],
    );
  }
}

class _PetProfileCard extends StatelessWidget {
  final Pet pet;

  const _PetProfileCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleParts = <String>[
      pet.species.label,
      if (pet.breed != null && pet.breed!.isNotEmpty) pet.breed!,
      if (pet.birthday != null) '생일 ${DateFormat('yyyy.MM.dd').format(pet.birthday!)}',
    ];
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PetProfileFormScreen(existing: pet)),
              ),
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
  final String petId;

  const _RecordTile({required this.record, required this.petId});

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
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MedicalRecordFormScreen(petId: petId, existing: record),
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
                    DateFormat('yyyy.MM.dd').format(record.date),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.hospitalName,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (record.memo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(record.memo, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
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
      ),
    );
  }
}
