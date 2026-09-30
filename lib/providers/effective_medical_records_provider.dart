import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medical_record.dart';
import 'auth_provider.dart';
import 'effective_pets_provider.dart';
import 'medical_record_provider.dart';

/// [petId]의 진료기록 — 계정(로그인) 반려동물이면 Firestore를 실시간
/// 구독하고, 게스트/로컬 반려동물이면 기존 로컬 [recordsForPetProvider]를
/// 그대로 감싼다("진료기록·예약 Firestore 저장" 지시서 B-2). 계정 쪽은
/// [UserRepository.streamRecords]가 실시간 스트림이라, 이 provider를 보는
/// 화면(진료기록 리스트·캘린더 등) 모두가 한 군데의 쓰기만으로 자동
/// 반영된다 — 별도 invalidate/동기화 코드가 필요 없다(하나의 데이터, 여러
/// 뷰). `.autoDispose`라 더 이상 보고 있지 않은 반려동물의 Firestore
/// 리스너는 자동으로 끊긴다(지시서 B-4 "리스너는 보이는 펫 기준 최소화").
final effectiveRecordsForPetProvider =
    StreamProvider.autoDispose.family<List<MedicalRecord>, String>((ref, petId) {
  if (!isAccountPetId(petId)) {
    return Stream.value(ref.watch(recordsForPetProvider(petId)));
  }
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  final docId = accountDocIdFromPetId(petId);
  return ref.watch(userRepositoryProvider).streamRecords(uid, docId);
});
