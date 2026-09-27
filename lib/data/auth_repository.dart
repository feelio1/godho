import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void _log(String message) => debugPrint('[AuthRepository] $message');

/// 카카오 로그인 자체는 시도했지만(또는 시도조차 못 했지만) 앱 로그인으로
/// 이어갈 수 없을 때 던진다 — 원인은 항상 같다: 카카오 토큰을 Firebase
/// Custom Token으로 교환하는 Cloud Function이 아직 배포되지 않았다(Blaze
/// 미활성, 펫클 2단계 지시서 1). 호출부(로그인 화면)는 이 예외 하나만
/// 보고 "카카오 로그인 준비 중입니다"를 안전하게 보여주면 된다 — 크래시
/// 없이 항상 이 예외로 끝난다.
class KakaoLoginNotReadyException implements Exception {
  const KakaoLoginNotReadyException();

  @override
  String toString() => '카카오 로그인 준비 중입니다';
}

/// 소셜 로그인 3종(구글/카카오/애플) + 로그아웃을 한곳에 모은다. 실제
/// Firebase 세션(신규/기존 사용자 판별, Firestore 프로필)은
/// [UserRepository]가 맡고, 여기는 "Firebase에 로그인시키는 것"까지만
/// 책임진다 — 이 프로젝트의 다른 저장소 클래스([LocalStore] 등)와 같은
/// 좁은 책임 분리.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static bool _googleSignInInitialized = false;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// [GoogleSignIn.instance.initialize]는 앱 생애주기 동안 정확히 한 번만
  /// 호출돼야 한다 — 게스트는 로그인 버튼을 누를 일이 없으므로 앱 시작
  /// 시점이 아니라 최초 구글 로그인 시도 때 지연 초기화한다(게이팅 없이
  /// 게스트 그대로 두는 원칙과도 맞다).
  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleSignInInitialized = true;
  }

  /// 구글 로그인 — 이번 단계에서 유일하게 실기기 end-to-end 테스트 대상.
  /// `google-services.json`의 웹 OAuth 클라이언트를 그대로 쓰므로
  /// clientId/serverClientId를 코드에 하드코딩하지 않는다(다른 키들과
  /// 같은 "비밀값 하드코딩 금지" 원칙).
  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('구글 로그인에서 idToken을 받지 못했습니다.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  /// 카카오 로그인 — 실제 카카오 SDK 호출은 시도하되(코드가 죽어있지
  /// 않게), 성공하든 실패하든 항상 [KakaoLoginNotReadyException]으로
  /// 끝난다. Firebase Custom Token 교환 Cloud Function이 배포되기 전엔
  /// 카카오 로그인이 성공해도 앱 세션으로 이어갈 방법이 없기 때문이다 —
  /// 다른 구 시세를 대신 보여주지 않는 것과 같은 원칙으로, 여기서도 안
  /// 되는 걸 되는 것처럼 보이지 않게 한다. 어떤 경로로 실패하든(네이티브
  /// 스킴 미설정 등 포함) 크래시 없이 이 예외 하나로 수렴한다.
  Future<Never> signInWithKakao() async {
    try {
      await UserApi.instance.loginWithKakaoAccount();
      _log('카카오 로그인 성공 — 그러나 Firebase Custom Token 교환 Cloud '
          'Function이 아직 배포되지 않아 앱 로그인으로 이어갈 수 없음. 세션 정리 후 안내.');
      unawaited(() async {
        try {
          await UserApi.instance.logout();
        } catch (_) {
          // 세션 정리 실패는 무시 — 어차피 이 함수는 항상 안내로 끝난다.
        }
      }());
    } catch (e) {
      _log('카카오 로그인 실패 또는 준비 안 됨: $e');
    }
    throw const KakaoLoginNotReadyException();
  }

  /// 애플 로그인 — iOS 전용, 개발자 승인 전이라 실기기 테스트 불가(코드만
  /// 준비). FlutterFire 권장대로 재전송 공격 방지용 nonce를 sha256으로
  /// 해시해 전달한다.
  Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256(rawNonce);
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    return _auth.signInWithCredential(oauthCredential);
  }

  bool get isAppleSignInSupported => Platform.isIOS;

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      _log('GoogleSignIn signOut 실패(무시): $e');
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();
}
