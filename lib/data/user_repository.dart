import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/appointment.dart';
import '../models/medical_record.dart';
import '../models/signup_pet.dart';

void _log(String message) => debugPrint('[UserRepository] $message');

/// `users/{uid}` 컬렉션(및 `pets` 서브컬렉션) 읽기/쓰기 — 펫클 2단계
/// 지시서 2. 생성자 주입으로 [FirebaseFirestore] 인스턴스를 바꿔 끼울 수
/// 있어(`fake_cloud_firestore` 등) 실제 백엔드 없이도 테스트할 수 있다.
///
/// `users/{uid}`는 본인(uid 일치)만 read/write — 실제 규칙은
/// `firestore.rules`에 있고, 이 클래스는 그 규칙을 전제로 호출된다.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  Future<bool> userExists(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists;
  }

  Future<AppUser?> fetchUser(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return AppUser.fromFirestore(uid, data);
  }

  Future<void> createUser(AppUser user) async {
    await _users.doc(user.uid).set(user.toFirestore());
  }

  /// 나이대·성별·통계 동의를 갱신한다 — 가입 플로우 3-1(선택 입력)에서
  /// "건너뛰기"를 눌러도 문서 자체는 [createUser]로 이미 만들어져 있어야
  /// 하므로, 이 메서드는 항상 기존 문서에 대한 부분 업데이트다.
  Future<void> updateProfile(
    String uid, {
    AgeGroup? ageGroup,
    Gender? gender,
    required bool agreedStats,
  }) async {
    await _users.doc(uid).update({
      if (ageGroup != null) 'ageGroup': ageGroup.name,
      if (gender != null) 'gender': gender.name,
      'agreedStats': agreedStats,
      'agreedStatsAt': agreedStats ? Timestamp.now() : null,
      'updatedAt': Timestamp.now(),
    });
  }

  CollectionReference<Map<String, dynamic>> _pets(String uid) => _users.doc(uid).collection('pets');

  /// 생성된 문서 id를 돌려준다 — 사진이 있으면 이 id로 저장 경로를 정하고
  /// [updatePet]으로 photoUrl을 마저 채운다(문서가 있어야 id를 알 수
  /// 있어 사진 업로드는 항상 문서 생성 다음 순서다).
  Future<String> addPet(String uid, SignupPet pet) async {
    final doc = await _pets(uid).add(pet.toFirestore());
    return doc.id;
  }

  Future<List<SignupPet>> fetchPets(String uid) async {
    final snapshot = await _pets(uid).get();
    return snapshot.docs.map((doc) => SignupPet.fromFirestore(doc.id, doc.data())).toList();
  }

  /// [pet]의 `createdAt`은 무시한다(수정 때마다 생성일이 갱신되면 안 됨) —
  /// [SignupPet.toFirestoreUpdate]가 그 키를 뺀 맵을 준다.
  Future<void> updatePet(String uid, String petId, SignupPet pet) async {
    await _pets(uid).doc(petId).update(pet.toFirestoreUpdate());
  }

  Future<void> deletePet(String uid, String petId) async {
    await _pets(uid).doc(petId).delete();
    // 사진도 함께 지운다 — 실패해도(애초에 사진이 없었을 수도 있음) 문서
    // 삭제 자체는 이미 끝났으니 계속 진행한다.
    await deletePetPhoto(uid, petId);
  }

  Reference _petPhotoRef(String uid, String petId) =>
      FirebaseStorage.instance.ref('pet_photos/$uid/$petId.jpg');

  /// 실패하면(Storage 버킷 미설정 등) null을 돌려줄 뿐 예외를 던지지
  /// 않는다 — 사진 업로드가 안 돼도 반려동물 정보 저장 자체는 항상
  /// 성공해야 한다(크래시·전체 실패 금지).
  Future<String?> uploadPetPhoto(String uid, String petId, File file) async {
    try {
      final ref = _petPhotoRef(uid, petId);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      _log('사진 업로드 실패(반려동물 정보는 사진 없이 저장됨): $e');
      return null;
    }
  }

  Future<void> deletePetPhoto(String uid, String petId) async {
    try {
      await _petPhotoRef(uid, petId).delete();
    } catch (e) {
      _log('사진 삭제 실패(무시 — 애초에 없었을 수 있음): $e');
    }
  }

  // --- 진료기록/예약 ("진료기록·예약 Firestore 저장" 지시서 B-1) ---
  // pets/{petId} 아래 records/appointments 서브컬렉션. 문서 id는 로컬에서
  // 이미 쓰던 id(SignupPet과 달리 Firestore가 새로 만들어주지 않아도 됨 —
  // 로컬 [MedicalRecord]/[Appointment]가 저장 시점에 이미 고유 id를 들고
  // 있으므로 그 id를 그대로 Firestore 문서 id로 쓴다)를 그대로 쓴다 —
  // add(수정 전 비파괴 이관 포함)는 항상 `.doc(id).set(...)`이라 같은
  // id로 두 번 호출해도 안전(idempotent)하다.

  CollectionReference<Map<String, dynamic>> _records(String uid, String petId) =>
      _pets(uid).doc(petId).collection('records');

  CollectionReference<Map<String, dynamic>> _appointments(String uid, String petId) =>
      _pets(uid).doc(petId).collection('appointments');

  Future<void> addRecord(String uid, String petId, MedicalRecord record) async {
    await _records(uid, petId).doc(record.id).set(record.toFirestore());
  }

  Future<void> updateRecord(String uid, String petId, MedicalRecord record) async {
    await _records(uid, petId).doc(record.id).update(record.toFirestoreUpdate());
  }

  Future<void> deleteRecord(String uid, String petId, String recordId) async {
    await _records(uid, petId).doc(recordId).delete();
  }

  Future<List<MedicalRecord>> fetchRecords(String uid, String petId) async {
    final snapshot = await _records(uid, petId).get();
    return snapshot.docs.map((doc) => MedicalRecord.fromFirestore(petId, doc.id, doc.data())).toList();
  }

  /// 실시간 구독 — 이 스트림을 보는 모든 화면(진료기록 리스트·캘린더 등)이
  /// 한 군데의 쓰기만으로 자동 반영된다(지시서 B-2 "하나의 데이터, 여러
  /// 뷰", 별도 invalidate 불필요).
  Stream<List<MedicalRecord>> streamRecords(String uid, String petId) {
    return _records(uid, petId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => MedicalRecord.fromFirestore(petId, doc.id, doc.data())).toList());
  }

  Future<void> addAppointment(String uid, String petId, Appointment appointment) async {
    await _appointments(uid, petId).doc(appointment.id).set(appointment.toFirestore());
  }

  Future<void> updateAppointment(String uid, String petId, Appointment appointment) async {
    await _appointments(uid, petId).doc(appointment.id).update(appointment.toFirestoreUpdate());
  }

  Future<void> deleteAppointment(String uid, String petId, String appointmentId) async {
    await _appointments(uid, petId).doc(appointmentId).delete();
  }

  Future<List<Appointment>> fetchAppointments(String uid, String petId) async {
    final snapshot = await _appointments(uid, petId).get();
    return snapshot.docs.map((doc) => Appointment.fromFirestore(petId, doc.id, doc.data())).toList();
  }

  Stream<List<Appointment>> streamAppointments(String uid, String petId) {
    return _appointments(uid, petId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Appointment.fromFirestore(petId, doc.id, doc.data())).toList());
  }
}
