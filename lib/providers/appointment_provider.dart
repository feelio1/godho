import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';
import '../models/appointment.dart';
import '../notifications/notification_service.dart';

/// 진료 예약 전체 목록(모든 반려동물 통합). 화면에서는
/// [upcomingAppointmentsForPetProvider]로 특정 반려동물의 다가오는 예약만
/// 걸러 본다. 저장·수정·삭제할 때마다 로컬 알림도 함께 갱신한다 — 알림
/// 예약/취소가 실패해도(권한 없음 등) [NotificationService]가 조용히
/// 무시하므로 여기서는 별도 방어가 필요 없다.
class AppointmentsNotifier extends AsyncNotifier<List<Appointment>> {
  final _store = const LocalStore();

  @override
  Future<List<Appointment>> build() => _store.loadAppointments();

  Future<void> upsert(Appointment appointment) async {
    final current = List<Appointment>.from(state.value ?? const []);
    final index = current.indexWhere((a) => a.id == appointment.id);
    if (index >= 0) {
      current[index] = appointment;
    } else {
      current.add(appointment);
    }
    await _store.saveAppointments(current);
    state = AsyncValue.data(current);
    await NotificationService.instance.scheduleAppointmentReminders(appointment);
  }

  Future<void> remove(String appointmentId) async {
    final current = List<Appointment>.from(state.value ?? const [])
      ..removeWhere((a) => a.id == appointmentId);
    await _store.saveAppointments(current);
    state = AsyncValue.data(current);
    await NotificationService.instance.cancelAppointmentReminders(appointmentId);
  }
}

final appointmentsProvider =
    AsyncNotifierProvider<AppointmentsNotifier, List<Appointment>>(
  AppointmentsNotifier.new,
);

/// [petId]의 다가오는(아직 지나지 않은) 예약만 이른 순으로 정렬해 반환한다.
/// 지난 예약은 자동 삭제하지 않고 저장소에는 남지만, 이 화면 목록에는
/// 더는 노출하지 않는다(스프린트 9 지시서 3).
final upcomingAppointmentsForPetProvider = Provider.family<List<Appointment>, String>((ref, petId) {
  final all = ref.watch(appointmentsProvider).value ?? const [];
  final filtered = all.where((a) => a.petId == petId && a.isUpcoming).toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return filtered;
});
