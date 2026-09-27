import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'signup_age_gender_screen.dart';

/// 로그인/회원가입 진입 화면(펫클 2단계 지시서 1, 4) — 홈 메뉴에서 진입.
/// 게이팅이 아니라 "테스트 가능한 진입점"이라, 로그인하지 않고 뒤로
/// 가도 게스트 기능은 그대로다.
///
/// 안드로이드: 구글+카카오, iOS: 구글+카카오+애플. 구글만 이번 단계에서
/// 실제로 끝까지 동작한다 — 카카오는 Firebase Custom Token 교환 Cloud
/// Function이 아직 배포되지 않아(Blaze 비활성) 항상 안내로 끝나고,
/// 애플은 개발자 승인 전이라 iOS에서만 노출될 뿐 실기기 검증 대상이
/// 아니다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Provider { google, kakao, apple }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Provider? _loading;

  Future<void> _handleGoogle() async {
    setState(() => _loading = _Provider.google);
    try {
      final repo = ref.read(authRepositoryProvider);
      final credential = await repo.signInWithGoogle();
      await _afterSignedIn(credential.user);
    } on FirebaseAuthException catch (e) {
      _showError('구글 로그인에 실패했어요. (${e.code})');
    } catch (e) {
      // 사용자가 계정 선택 창을 닫은 경우 등 — 조용히 무시한다.
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  Future<void> _handleKakao() async {
    setState(() => _loading = _Provider.kakao);
    try {
      await ref.read(authRepositoryProvider).signInWithKakao();
    } on KakaoLoginNotReadyException {
      _showPreparing('카카오 로그인 준비 중입니다.');
    } catch (e) {
      _showPreparing('카카오 로그인 준비 중입니다.');
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  Future<void> _handleApple() async {
    setState(() => _loading = _Provider.apple);
    try {
      final repo = ref.read(authRepositoryProvider);
      final credential = await repo.signInWithApple();
      await _afterSignedIn(credential.user);
    } on FirebaseAuthException catch (e) {
      _showError('애플 로그인에 실패했어요. (${e.code})');
    } catch (e) {
      // 취소 등 — 조용히 무시한다.
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  Future<void> _afterSignedIn(User? user) async {
    if (user == null || !mounted) return;
    final exists = await ref.read(userRepositoryProvider).userExists(user.uid);
    if (!mounted) return;
    if (exists) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인됐어요.')),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignupAgeGenderScreen()),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPreparing(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('준비 중'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    return Scaffold(
      appBar: AppBar(title: const Text('로그인 / 회원가입')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.section),
              const Icon(Icons.pets, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                '로그인하면 반려동물 정보를 계정에 담아둘 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                '로그인하지 않아도 검색·시세·지도·진료기록은 지금처럼 그대로 쓸 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.section * 2),
              _ProviderButton(
                label: 'Google로 계속하기',
                icon: Icons.g_mobiledata,
                loading: _loading == _Provider.google,
                enabled: _loading == null,
                onPressed: _handleGoogle,
              ),
              const SizedBox(height: 12),
              _ProviderButton(
                label: '카카오로 계속하기',
                icon: Icons.chat_bubble,
                loading: _loading == _Provider.kakao,
                enabled: _loading == null,
                onPressed: _handleKakao,
              ),
              if (isIOS) ...[
                const SizedBox(height: 12),
                _ProviderButton(
                  label: 'Apple로 계속하기',
                  icon: Icons.apple,
                  loading: _loading == _Provider.apple,
                  enabled: _loading == null,
                  onPressed: _handleApple,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.borderCard),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
        ),
      ),
    );
  }
}
