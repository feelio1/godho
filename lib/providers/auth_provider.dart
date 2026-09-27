import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/user_repository.dart';
import '../models/app_user.dart';

/// 저장소 인스턴스 — 다른 곳의 `LocalStore`처럼 노티파이어가 직접
/// 들고 있는 대신 Provider로 노출한 이유는, 로그인/Firestore 로직은
/// 백엔드 없이(`fake_cloud_firestore` 등으로) 테스트해야 할 일이 많아
/// `overrideWith`로 갈아끼울 수 있어야 하기 때문이다.
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

/// `firebase_auth`의 `authStateChanges`를 앱 전역에서 구독할 수 있게
/// 감싼 것 — 펫클 2단계 지시서 4. 로그인/로그아웃 어디서 일어나든 이
/// provider를 watch하는 모든 화면(홈 메뉴 등)이 자동으로 갱신된다.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// 로그인된 사용자의 `users/{uid}` 프로필 — 로그아웃 상태면 null, 로그인
/// 했지만 아직 가입 플로우(나이·성별·반려동물)를 마치지 않은 신규
/// 사용자도 문서가 없으므로 null이다(그 경우 로그인 화면이 가입 플로우로
/// 보낸다 — 여기서는 판단하지 않는다).
final currentUserProfileProvider = FutureProvider<AppUser?>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return null;
  return ref.watch(userRepositoryProvider).fetchUser(uid);
});
