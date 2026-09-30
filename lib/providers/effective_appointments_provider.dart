import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appointment.dart';
import 'appointment_provider.dart';
import 'auth_provider.dart';
import 'effective_pets_provider.dart';

/// [petId]의 모든 예약(지난 것 포함, 이른 순) — 계정(로그인) 반려동물이면
/// Firestore를 실시간 구독하고, 게스트/로컬 반려동물이면 기존 로컬
/// [appointmentsForPetProvider]를 그대로 감싼다("진료기록·예약 Firestore
/// 저장" 지시서 B-2). [effectiveRecordsForPetProvider]와 같은 이유로
/// `.autoDispose` StreamProvider를 쓴다 — 별도 동기화 코드 없이 캘린더·
/// 진료기록 화면이 자동으로 최신 상태를 본다. 미리 알림(로컬 notification)
/// 스케줄링 자체는 이 provider가 아니라 [EffectiveAppointmentActions]가
/// 저장/삭제 시점에 맡는다(어느 저장소를 쓰든 항상 기기 로컬 알림).
final effectiveAppointmentsForPetProvider =
    StreamProvider.autoDispose.family<List<Appointment>, String>((ref, petId) {
  if (!isAccountPetId(petId)) {
    return Stream.value(ref.watch(appointmentsForPetProvider(petId)));
  }
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  final docId = accountDocIdFromPetId(petId);
  return ref.watch(userRepositoryProvider).streamAppointments(uid, docId).map(
        (list) => list..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
      );
});
