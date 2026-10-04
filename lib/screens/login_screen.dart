import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/feature_flags.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/auth_error_message.dart';
import 'password_reset_screen.dart';
import 'signup_age_gender_screen.dart';
import 'signup_email_screen.dart';

/// 로그인/회원가입 진입 화면(펫클 2단계 지시서 1, 4) — 홈 메뉴에서 진입.
/// 게이팅이 아니라 "테스트 가능한 진입점"이라, 로그인하지 않고 뒤로
/// 가도 게스트 기능은 그대로다.
///
/// v1 출시 범위는 구글 + 이메일 + 게스트다("v1 출시 준비" 지시서 1) —
/// 카카오·애플 버튼은 [kEnableKakaoLogin]/[kEnableAppleLogin] 플래그로
/// 숨겨져 있을 뿐, `signInWithKakao`/`signInWithApple`과 그 호출
/// 코드는 그대로 남아 있어 플래그만 true로 바꾸면 다시 노출된다(마켓
/// URL 확보 후 적용할 카카오 실연결은 별도 지시서).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Provider { google, kakao, apple, email }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Provider? _loading;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요');
      return;
    }
    setState(() => _loading = _Provider.email);
    try {
      final repo = ref.read(authRepositoryProvider);
      final credential = await repo.signInWithEmail(email, password);
      await _afterSignedIn(credential.user);
    } on FirebaseAuthException catch (e) {
      _showError(authErrorMessage(e));
    } catch (e) {
      _showError('잠시 후 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  void _openSignupEmail() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupEmailScreen()),
    );
  }

  void _openPasswordReset() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PasswordResetScreen()),
    );
  }

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
        child: SingleChildScrollView(
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
              const Text('이메일', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: _loading == null,
                decoration: const InputDecoration(hintText: 'example@email.com'),
              ),
              const SizedBox(height: AppSpacing.formField),
              const Text('비밀번호', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                enabled: _loading == null,
                onSubmitted: (_) => _handleEmailLogin(),
                decoration: const InputDecoration(hintText: '비밀번호'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading == null ? _handleEmailLogin : null,
                  child: _loading == _Provider.email
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('로그인'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _loading == null ? _openSignupEmail : null,
                    child: const Text('회원가입'),
                  ),
                  const Text('·', style: TextStyle(color: AppColors.textPlaceholder)),
                  TextButton(
                    onPressed: _loading == null ? _openPasswordReset : null,
                    child: const Text('비밀번호 찾기'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('또는', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              _ProviderButton(
                label: 'Google로 계속하기',
                icon: Icons.g_mobiledata,
                loading: _loading == _Provider.google,
                enabled: _loading == null,
                onPressed: _handleGoogle,
              ),
              if (kEnableKakaoLogin) ...[
                const SizedBox(height: 12),
                _ProviderButton(
                  label: '카카오로 계속하기',
                  icon: Icons.chat_bubble,
                  loading: _loading == _Provider.kakao,
                  enabled: _loading == null,
                  onPressed: _handleKakao,
                ),
              ],
              if (isIOS && kEnableAppleLogin) ...[
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
