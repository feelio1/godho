import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../models/medical_record.dart';
import '../models/pet.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_focus_provider.dart';
import '../providers/effective_appointments_provider.dart';
import '../providers/effective_medical_records_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../providers/nav_provider.dart';
import '../screens/medical_record_form_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/appointment_calendar.dart';
import '../utils/record_appointment_flow.dart';

/// 홈의 "우리 아이" 카드("출시 전 마무리" 지시서 C) — 로그인하고 계정
/// 반려동물이 1마리 이상일 때만 보인다(게스트에겐 노출 안 함). 모든
/// 반려동물을 통틀어 가장 가까운 미래 예약 → 없으면 가장 최근 진료기록
/// → 둘 다 없으면 "아직 기록이 없어요"를 우선순위대로 1장만 보여준다.
/// 기존 provider(계정 예약/기록 스트림)를 그대로 보므로 새 저장소를 만들지
/// 않고, 로그인·로그아웃이나 기록 추가에 자동으로 반응한다.
class OurPetCard extends ConsumerWidget {
  const OurPetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final pets = ref.watch(effectivePetsProvider).value ?? const [];
    if (pets.isEmpty) return const SizedBox.shrink();

    Appointment? nearestAppointment;
    Pet? appointmentPet;
    MedicalRecord? latestRecord;
    Pet? recordPet;

    for (final pet in pets) {
      final appointments = ref.watch(effectiveAppointmentsForPetProvider(pet.id)).value ?? const [];
      for (final appointment in appointments) {
        if (!appointment.isUpcoming) continue;
        if (nearestAppointment == null || appointment.dateTime.isBefore(nearestAppointment.dateTime)) {
          nearestAppointment = appointment;
          appointmentPet = pet;
        }
      }

      final records = ref.watch(effectiveRecordsForPetProvider(pet.id)).value ?? const [];
      for (final record in records) {
        if (latestRecord == null || record.date.isAfter(latestRecord.date)) {
          latestRecord = record;
          recordPet = pet;
        }
      }
    }

    if (nearestAppointment != null && appointmentPet != null) {
      return _OurPetCardShell(
        onTap: () {
          ref.read(calendarFocusRequestProvider.notifier).state = CalendarFocusRequest(
            petId: appointmentPet!.id,
            date: dateOnly(nearestAppointment!.dateTime),
          );
          ref.read(selectedTabProvider.notifier).state = AppTab.pet.index;
        },
        icon: Icons.event_available_outlined,
        child: _AppointmentContent(pet: appointmentPet, appointment: nearestAppointment),
      );
    }

    if (latestRecord != null && recordPet != null) {
      return _OurPetCardShell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MedicalRecordFormScreen(petId: recordPet!.id, existing: latestRecord),
          ),
        ),
        icon: Icons.description_outlined,
        child: _RecordContent(pet: recordPet, record: latestRecord),
      );
    }

    final firstPet = pets.first;
    return _OurPetCardShell(
      onTap: () => openRecordOrAppointmentEntry(context, petId: firstPet.id),
      icon: Icons.pets_outlined,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '아직 기록이 없어요',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
            ),
          ),
          const _CardButton(label: '첫 기록 남기기'),
        ],
      ),
    );
  }
}

class _OurPetCardShell extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Widget child;

  const _OurPetCardShell({required this.onTap, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.card),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.borderCard),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _AppointmentContent extends StatelessWidget {
  final Pet? pet;
  final Appointment? appointment;

  const _AppointmentContent({required this.pet, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final petName = pet?.name ?? '반려동물';
    final dateLabel = DateFormat('M월 d일 (E) a h:mm', 'ko_KR').format(appointment!.dateTime);
    final reason = appointment!.reason.trim();
    final parts = [
      petName,
      dateLabel,
      if (reason.isNotEmpty) reason,
      appointment!.hospitalName,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '다가오는 예약',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 3),
        Text(
          parts.join(' · '),
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RecordContent extends StatelessWidget {
  final Pet? pet;
  final MedicalRecord? record;

  const _RecordContent({required this.pet, required this.record});

  @override
  Widget build(BuildContext context) {
    final petName = pet?.name ?? '반려동물';
    final dateLabel = DateFormat('M월 d일', 'ko_KR').format(record!.date);
    final memo = record!.memo.trim();
    final descriptor = record!.category.isNotEmpty
        ? record!.category
        : (memo.isNotEmpty ? memo : '진료 기록');
    final parts = [petName, '$dateLabel $descriptor', record!.hospitalName];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최근 진료기록',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 3),
        Text(
          parts.join(' · '),
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  final String label;

  const _CardButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
      ),
    );
  }
}
