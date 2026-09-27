import 'package:cloud_firestore/cloud_firestore.dart';

/// 소셜 로그인에 실제로 쓰인 제공자 — 어떤 값으로 로그인했는지는 계정
/// 복구·문의 대응에 필요해 저장해 둔다.
enum LoginType {
  google,
  kakao,
  apple;

  static LoginType fromFirestore(String? value) => LoginType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => LoginType.google,
      );
}

/// 가입 플로우에서 선택 입력하는 나이대. 과장·유도 없이 "또래 반려인
/// 기준" 문구에만 쓰이는 순수 통계용 구간이다(펫클 2단계 지시서 3-1).
enum AgeGroup {
  teens('10대'),
  twenties('20대'),
  thirties('30대'),
  forties('40대'),
  fiftiesPlus('50대 이상');

  final String label;

  const AgeGroup(this.label);

  static AgeGroup? fromFirestore(String? value) {
    if (value == null) return null;
    for (final e in AgeGroup.values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

/// 가입 플로우에서 선택 입력하는 성별 — "선택 안 함"을 동등한 선택지로
/// 둔다(입력 강요 금지).
enum Gender {
  male('남'),
  female('여'),
  unspecified('선택 안 함');

  final String label;

  const Gender(this.label);

  static Gender? fromFirestore(String? value) {
    if (value == null) return null;
    for (final e in Gender.values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

/// `users/{uid}` 문서 — 펫클 2단계(로그인·회원가입) 지시서의 스키마 그대로.
/// 순수 데이터 + Firestore 직렬화만 갖고, 저장/조회 방식은 [UserRepository]가
/// 맡는다(로컬 [Pet]/[LocalStore] 모델과 같은 관례).
class AppUser {
  final String uid;
  final LoginType loginType;
  final String? email;
  final String? displayName;
  final AgeGroup? ageGroup;
  final Gender? gender;
  final bool agreedStats;
  final DateTime? agreedStatsAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.uid,
    required this.loginType,
    this.email,
    this.displayName,
    this.ageGroup,
    this.gender,
    this.agreedStats = false,
    this.agreedStatsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      loginType: LoginType.fromFirestore(data['loginType'] as String?),
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      ageGroup: AgeGroup.fromFirestore(data['ageGroup'] as String?),
      gender: Gender.fromFirestore(data['gender'] as String?),
      agreedStats: data['agreedStats'] as bool? ?? false,
      agreedStatsAt: (data['agreedStatsAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'loginType': loginType.name,
        'email': email,
        'displayName': displayName,
        'ageGroup': ageGroup?.name,
        'gender': gender?.name,
        'agreedStats': agreedStats,
        'agreedStatsAt': agreedStatsAt != null ? Timestamp.fromDate(agreedStatsAt!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
