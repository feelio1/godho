import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/signup_pet.dart';

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

  Future<void> addPet(String uid, SignupPet pet) async {
    await _pets(uid).add(pet.toFirestore());
  }

  Future<List<SignupPet>> fetchPets(String uid) async {
    final snapshot = await _pets(uid).get();
    return snapshot.docs.map((doc) => SignupPet.fromFirestore(doc.id, doc.data())).toList();
  }
}
