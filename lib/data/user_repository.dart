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

  // --- 회원 탈퇴 ("회원 탈퇴 구현" 지시서 E, "쇼핑 기초" 지시서 3,
  // "방향 개편" 지시서 G) ---

  CollectionReference<Map<String, dynamic>> _cart(String uid) => _users.doc(uid).collection('cart');

  CollectionReference<Map<String, dynamic>> _diaries(String uid) => _users.doc(uid).collection('diaries');

  /// 일기에 첨부된 Storage 사진을 전부 지운다 — 일기 문서마다 따로 도는
  /// 대신 `diary_photos/{uid}` 폴더 전체를 한 번에 재귀 조회해 지운다.
  /// `listAll`은 한 단계만 보여주고(`diary_photos/{uid}` 바로 아래엔
  /// 파일이 없고 일기별 하위 폴더만 있다 — 실제 사진·썸네일은 그 안에
  /// 있다), 그래서 [listed.prefixes]를 한 단계 더 내려가 지운다("일기
  /// 활성화" 지시서 A — `_t.jpg` 썸네일도 같은 하위 폴더에 있어 함께
  /// 지워진다). 폴더가 애초에 없거나 일부 삭제가 실패해도 무시하고
  /// 계속 진행한다 — 탈퇴 자체는 막지 않는다.
  Future<void> _deleteAllDiaryPhotos(String uid) async {
    try {
      await _deleteStorageFolderRecursively(FirebaseStorage.instance.ref('diary_photos/$uid'));
    } catch (e) {
      _log('일기 사진 폴더 조회 실패(애초에 없었을 수 있음, 무시): $e');
    }
  }

  Future<void> _deleteStorageFolderRecursively(Reference ref) async {
    final listed = await ref.listAll();
    for (final item in listed.items) {
      try {
        await item.delete();
      } catch (e) {
        _log('일기 사진 삭제 실패(무시하고 계속): $e');
      }
    }
    for (final prefix in listed.prefixes) {
      await _deleteStorageFolderRecursively(prefix);
    }
  }

  /// [uid]의 계정 데이터를 전부 지운다 — 반려동물마다 진료기록·예약
  /// 서브컬렉션을 먼저 지운 뒤(부모 문서를 지워도 서브컬렉션은 자동으로
  /// 지워지지 않는다) 반려동물 문서(+사진)를 지우고, 장바구니·일기(사진
  /// 먼저, 그다음 문서 — 지시서 G)도 지운 뒤 마지막으로 `users/{uid}`
  /// 문서 자체를 지운다. 호출부(설정 화면)가 Firebase Auth 계정 삭제까지
  /// 이어서 처리한다. 게스트(기기 로컬) 데이터는 이 메서드가 전혀
  /// 알지 못하므로 건드리지 않는다.
  ///
  /// `orders`는 지우지 않는다 — 전자상거래법상 거래기록 보관 의무가 있어
  /// 탈퇴 후 처리 방식(비식별화 등)은 나중에 방침·약관과 함께 확정한다.
  /// TODO(쇼핑 기초 이후): 주문 내역의 탈퇴 후 보관/비식별화 정책 확정.
  Future<void> deleteAllUserData(String uid) async {
    final pets = await fetchPets(uid);
    for (final pet in pets) {
      final petId = pet.id;
      if (petId == null) continue;
      final records = await _records(uid, petId).get();
      final appointments = await _appointments(uid, petId).get();
      final batch = _firestore.batch();
      for (final doc in records.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in appointments.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      await deletePet(uid, petId);
    }

    final cartDocs = await _cart(uid).get();
    if (cartDocs.docs.isNotEmpty) {
      final cartBatch = _firestore.batch();
      for (final doc in cartDocs.docs) {
        cartBatch.delete(doc.reference);
      }
      await cartBatch.commit();
    }

    // 사진(Storage) 먼저, 그다음 일기 문서 — DiaryRepository.deleteDiary와
    // 같은 순서.
    await _deleteAllDiaryPhotos(uid);
    final diaryDocs = await _diaries(uid).get();
    if (diaryDocs.docs.isNotEmpty) {
      final diaryBatch = _firestore.batch();
      for (final doc in diaryDocs.docs) {
        diaryBatch.delete(doc.reference);
      }
      await diaryBatch.commit();
    }

    await _users.doc(uid).delete();
  }
}
