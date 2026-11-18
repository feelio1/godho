
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/medical_record.dart';
import '../models/pet.dart';
import '../providers/effective_medical_records_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../utils/record_appointment_flow.dart';
import '../widgets/mascot_image.dart';
import '../widgets/mascot_message.dart';
import 'medical_record_form_screen.dart';

/// 진료기록 보기의 반려동물별 본문 — 원래 독립 탭이던 `HealthRecordScreen`의
/// 내용이다("탭 개편" 지시서 B). 그 화면의 Scaffold/AppBar/게스트 게이팅/
/// 반려동물 선택은 이제 `PetTabScreen`(우리 아이 탭)이 한 번만 가지므로,
/// 여기서는 선택된 반려동물 하나에 대한 본문만 그대로 맡는다(내부 로직
/// 변경 없음 — 비공개였던 이 위젯을 공개로 옮긴 것뿐).
class PetHealthBody extends ConsumerWidget {
  final Pet pet;
  final VoidCallback onPetDeleted;

  const PetHealthBody({super.key, required this.pet, required this.onPetDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 계정(로그인) 반려동물이면 Firestore를, 게스트/로컬이면 기존 로컬
    // 저장소를 실시간으로 본다 — 진료기록 화면에서 기록하든 캘린더에서
    // 기록하든 같은 provider라 자동으로 반영된다("진료기록·예약 Firestore
    // 저장" 지시서 B-2).
    final records = ref.watch(effectiveRecordsForPetProvider(pet.id)).value ?? const [];
    final isAccountPet = isAccountPetId(pet.id);

    // "장구름의 수첩"(3차 업데이트 J-5): 네이비 요약 띠 → 월별 묶음(흰 카드
    // 목록, 날짜 도장) → 저장 위치 안내, [진료기록 추가] 플로팅 버튼. 반려동물
    // 정보 수정은 앱바의 반려동물 알약에서 연다.
    final groups = <DateTime, List<MedicalRecord>>{};
    for (final r in records) {
      groups.putIfAbsent(DateTime(r.date.year, r.date.month), () => []).add(r);
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 100),
          children: [
            _SummaryRow(records: records),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: MascotMessage(
                  title: '아직 진료기록이 없어요',
                  subtitle: '다녀온 날짜와 진료 내용, 비용을 남겨두면 다음 진료 때 꺼내 볼 수 있어요.',
                  assetPath: MascotImage.emptyRecordAssetPath,
                  overlayIcon: Icons.description_outlined,
                  trailing: FilledButton.icon(
                    onPressed: () => openRecordOrAppointmentEntry(context, petId: pet.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('첫 기록 남기기'),
                  ),
                ),
              ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 22, 0, 10),
                child: Text(
                  DateFormat('yyyy년 M월').format(entry.key),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: AppSpacing.cardLarge,
                          endIndent: AppSpacing.cardLarge,
                          color: AppColors.borderMuted,
                        ),
                      _RecordTile(record: entry.value[i], pet: pet),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 1),
                  child: Icon(
                    isAccountPet ? Icons.cloud_outlined : Icons.smartphone_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAccountPet
                        ? '이 기록은 계정에 저장됩니다. 다른 기기에서도 로그인하면 볼 수 있어요.'
                        : '이 기록은 현재 기기에만 저장됩니다. 앱 삭제/기기 변경 시 사라질 수 있습니다.',
                    style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          right: AppSpacing.page,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'record_add_fab',
            onPressed: () => openRecordOrAppointmentEntry(context, petId: pet.id),
            icon: const Icon(Icons.add),
            label: const Text('진료기록 추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
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
          orElse: () =>
              MedicalRecord(id: '', petId: '', date: DateTime.fromMillisecondsSinceEpoch(0), hospitalName: ''),
        )
        .weightKg;

    // 네이비 띠 요약 3칸(보조 글자 onNavyCaption) — 그래프·판정 없음.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _SummaryItem(label: '기록', value: '${records.length}건'),
            const VerticalDivider(width: 1, color: AppColors.navyTint),
            _SummaryItem(
              label: '총 진료비',
              value: totalCost > 0 ? '${NumberFormat('#,###').format(totalCost)}원' : '기록 없음',
            ),
            const VerticalDivider(width: 1, color: AppColors.navyTint),
            _SummaryItem(label: '최근 몸무게', value: latestWeight != null ? '${latestWeight}kg' : '기록 없음'),
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
          Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.onNavyCaption)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.mono(size: 19, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// 진료기록 한 줄 — 왼쪽 날짜 도장(1.5px 네이비 테두리 "11.05 / 목") + 진료
/// 내용·병원 + 오른쪽 금액·몸무게.
class _RecordTile extends StatelessWidget {
  final MedicalRecord record;
  final Pet pet;

  const _RecordTile({required this.record, required this.pet});

  @override
  Widget build(BuildContext context) {
    final title = record.category.isNotEmpty ? record.category : (record.memo.isNotEmpty ? record.memo : '진료');
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MedicalRecordFormScreen(petId: pet.id, existing: record),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardLarge),
        child: Row(
          children: [
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MM.dd').format(record.date),
                    style: AppTextStyles.mono(size: 14, weight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('E', 'ko_KR').format(record.date),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.hospitalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (record.costWon != null)
                  Text(
                    '${NumberFormat('#,###').format(record.costWon)}원',
                    style: AppTextStyles.mono(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                if (record.weightKg != null) ...[
                  const SizedBox(height: 4),
                  Text('${record.weightKg}kg', style: AppTextStyles.mono(size: 13.5, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
