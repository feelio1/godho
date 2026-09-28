import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
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
}
