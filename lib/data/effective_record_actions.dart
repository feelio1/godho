import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medical_record.dart';
import '../providers/auth_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../providers/medical_record_provider.dart';

/// 진료기록 저장/삭제 — petId가 계정(로그인) 반려동물이면 Firestore로,
/// 게스트/로컬 반려동물이면 기존 로컬 저장소([medicalRecordsProvider])로
/// 보낸다("진료기록·예약 Firestore 저장" 지시서 B-2). 폼 화면은 이 클래스만
/// 호출하면 되고 어느 쪽으로 저장됐는지는 신경 쓰지 않아도 된다 —
/// [effectiveRecordsForPetProvider]가 같은 분기로 읽어오므로 저장 직후
/// 자동으로 화면에 반영된다.
class EffectiveRecordActions {
  const EffectiveRecordActions._();

  /// [isNew]는 호출부(폼 화면)가 이미 알고 있는 값 — "기존 항목 수정"인지
  /// "새 항목 추가"인지에 따라 Firestore 쪽에서 add(생성일 포함)/update
  /// (생성일 보존)를 가른다(SignupPet과 같은 패턴).
  static Future<void> upsert(WidgetRef ref, MedicalRecord record, {required bool isNew}) async {
    if (!isAccountPetId(record.petId)) {
      await ref.read(medicalRecordsProvider.notifier).upsert(record);
      return;
    }
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return; // 세션이 끊긴 드문 경우 — 폼이 저장 실패로 안내.
    final docId = accountDocIdFromPetId(record.petId);
    final userRepo = ref.read(userRepositoryProvider);
    if (isNew) {
      await userRepo.addRecord(uid, docId, record);
    } else {
      await userRepo.updateRecord(uid, docId, record);
    }
  }

  static Future<void> delete(WidgetRef ref, String petId, String recordId) async {
    if (!isAccountPetId(petId)) {
      await ref.read(medicalRecordsProvider.notifier).remove(recordId);
      return;
    }
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final docId = accountDocIdFromPetId(petId);
    await ref.read(userRepositoryProvider).deleteRecord(uid, docId, recordId);
  }
}
