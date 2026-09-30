import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appointment.dart';
import '../notifications/notification_service.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/effective_pets_provider.dart';

/// 예약 저장/삭제 — petId가 계정(로그인) 반려동물이면 Firestore로, 게스트/
/// 로컬 반려동물이면 기존 로컬 저장소([appointmentsProvider])로 보낸다
/// ("진료기록·예약 Firestore 저장" 지시서 B-2). 예약을 어느 쪽에 저장하든
/// 미리 알림은 항상 이 기기의 로컬 notification으로 스케줄한다(서버 푸시
/// 전환은 범위 밖) — 로컬 저장 쪽은 [AppointmentsNotifier.upsert]/[remove]가
/// 이미 그 스케줄링을 맡고 있어 그대로 두고, 계정(Firestore) 쪽만 이
/// 클래스가 저장 뒤에 직접 [NotificationService]를 호출해 맞춰준다.
class EffectiveAppointmentActions {
  const EffectiveAppointmentActions._();

  static Future<void> upsert(WidgetRef ref, Appointment appointment, {required bool isNew}) async {
    if (!isAccountPetId(appointment.petId)) {
      await ref.read(appointmentsProvider.notifier).upsert(appointment);
      return;
    }
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return; // 세션이 끊긴 드문 경우 — 폼이 저장 실패로 안내.
    final docId = accountDocIdFromPetId(appointment.petId);
    final userRepo = ref.read(userRepositoryProvider);
    if (isNew) {
      await userRepo.addAppointment(uid, docId, appointment);
    } else {
      await userRepo.updateAppointment(uid, docId, appointment);
    }
    await NotificationService.instance.scheduleAppointmentReminders(appointment);
  }

  static Future<void> delete(WidgetRef ref, String petId, String appointmentId) async {
    if (!isAccountPetId(petId)) {
      await ref.read(appointmentsProvider.notifier).remove(appointmentId);
      return;
    }
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final docId = accountDocIdFromPetId(petId);
    await ref.read(userRepositoryProvider).deleteAppointment(uid, docId, appointmentId);
    await NotificationService.instance.cancelAppointmentReminders(appointmentId);
  }
}
