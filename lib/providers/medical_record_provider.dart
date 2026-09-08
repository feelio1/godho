import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';
import '../models/medical_record.dart';

/// 반려동물 진료/방문 기록 전체 목록(모든 반려동물 통합). 화면에서는
/// [recordsForPetProvider]로 특정 반려동물 것만 최신순으로 걸러 본다.
/// 로컬(SharedPreferences)에만 저장 — 계정·서버 없음(스프린트 8 지시서 3).
class MedicalRecordsNotifier extends AsyncNotifier<List<MedicalRecord>> {
  final _store = const LocalStore();

  @override
  Future<List<MedicalRecord>> build() => _store.loadMedicalRecords();

  Future<void> upsert(MedicalRecord record) async {
    final current = List<MedicalRecord>.from(state.value ?? const []);
    final index = current.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      current[index] = record;
    } else {
      current.add(record);
    }
    await _store.saveMedicalRecords(current);
    state = AsyncValue.data(current);
  }

  Future<void> remove(String recordId) async {
    final current = List<MedicalRecord>.from(state.value ?? const [])
      ..removeWhere((r) => r.id == recordId);
    await _store.saveMedicalRecords(current);
    state = AsyncValue.data(current);
  }
}

final medicalRecordsProvider =
    AsyncNotifierProvider<MedicalRecordsNotifier, List<MedicalRecord>>(
  MedicalRecordsNotifier.new,
);

/// [petId]의 기록만 최신 날짜순으로 정렬해 반환한다.
final recordsForPetProvider = Provider.family<List<MedicalRecord>, String>((ref, petId) {
  final all = ref.watch(medicalRecordsProvider).value ?? const [];
  final filtered = all.where((r) => r.petId == petId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return filtered;
});
