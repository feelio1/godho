import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../models/appointment.dart';
import '../models/pet.dart';
import '../utils/followup_appointment.dart';
import 'auth_provider.dart';
import 'effective_appointments_provider.dart';
import 'effective_pets_provider.dart';

/// 지난 예약 "진료 받으셨어요?" 확인 대상 1건 + 그 반려동물("지난 예약
/// 확인" 지시서 1, 3).
class PendingFollowUp {
  final Appointment appointment;
  final Pet pet;

  const PendingFollowUp({required this.appointment, required this.pet});
}

/// 로그인 사용자의 계정 반려동물 전체 예약을 모아 확인이 필요한 1건을
/// 고른다 — 게스트는 항상 null(이 기능은 로그인 전용이다, 하지 말 것).
/// 기존 [effectiveAppointmentsForPetProvider]/[effectivePetsProvider]를
/// 그대로 watch하므로 새 저장소 없이, 예약이 바뀌면 자동으로 다시
/// 계산된다.
final pendingFollowUpProvider = Provider<PendingFollowUp?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return null;

  final pets = ref.watch(effectivePetsProvider).value ?? const <Pet>[];
  final appointments = <Appointment>[];
  final petById = <String, Pet>{};
  for (final pet in pets) {
    petById[pet.id] = pet;
    appointments.addAll(ref.watch(effectiveAppointmentsForPetProvider(pet.id)).value ?? const []);
  }

  final target = selectFollowUpAppointment(appointments);
  if (target == null) return null;
  final pet = petById[target.petId];
  if (pet == null) return null;
  return PendingFollowUp(appointment: target, pet: pet);
});

/// 앱 오픈 광고 흐름이 끝났음을 알리는 신호 — 값 자체는 의미 없고 증가
/// 횟수만 본다. 광고가 전혀 안 뜨거나(쿨다운/로딩 중) 뜬 뒤 닫히면
/// 오른다. 홈의 "진료 받으셨어요?" 확인 시트가 광고와 겹치지 않게 이
/// 신호를 기다린다("지난 예약 확인" 지시서 3).
final appOpenAdFlowSettledProvider = StateProvider<int>((ref) => 0);
