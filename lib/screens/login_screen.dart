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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupEmailScreen()));
  }

  void _openPasswordReset() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PasswordResetScreen()));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인됐어요.')));
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignupAgeGenderScreen()),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPreparing(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('준비 중'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // "펫클 앱 디자인" 캔버스 시안(Login.dc.html) — 아이콘+헤드라인,
              // 로그인 시 할 수 있는 일 3가지를 체크리스트로.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add, size: 26, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '우리 아이 기록은\n로그인 후 저장돼요',
                      style: TextStyle(
                        fontSize: 23,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _LoginBenefit('진료기록 작성과 보관'),
                    SizedBox(height: 12),
                    _LoginBenefit('다니는 병원 저장 · 비교'),
                    SizedBox(height: 12),
                    _LoginBenefit('예약 알림과 캘린더'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              if (isIOS && kEnableAppleLogin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProviderButton(
                    label: 'Apple로 계속하기',
                    icon: Icons.apple,
                    background: Colors.black,
                    foreground: Colors.white,
                    loading: _loading == _Provider.apple,
                    enabled: _loading == null,
                    onPressed: _handleApple,
                  ),
                ),
              if (kEnableKakaoLogin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProviderButton(
                    label: '카카오로 계속하기',
                    icon: Icons.chat_bubble,
                    background: const Color(0xFFFEE500),
                    foreground: const Color(0xD9000000),
                    loading: _loading == _Provider.kakao,
                    enabled: _loading == null,
                    onPressed: _handleKakao,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProviderButton(
                  label: 'Google로 계속하기',
                  icon: Icons.g_mobiledata,
                  background: AppColors.surfaceLight,
                  foreground: AppColors.textPrimary,
                  border: AppColors.borderInput,
                  loading: _loading == _Provider.google,
                  enabled: _loading == null,
                  onPressed: _handleGoogle,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '또는',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              const Text(
                '이메일',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textLabel,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: _loading == null,
                decoration: const InputDecoration(
                  hintText: 'example@email.com',
                ),
              ),
              const SizedBox(height: AppSpacing.formField),
              const Text(
                '비밀번호',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textLabel,
                ),
              ),
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
                height: 54,
                child: FilledButton(
                  onPressed: _loading == null ? _handleEmailLogin : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                  ),
                  child: _loading == _Provider.email
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                  const Text(
                    '·',
                    style: TextStyle(color: AppColors.textPlaceholder),
                  ),
                  TextButton(
                    onPressed: _loading == null ? _openPasswordReset : null,
                    child: const Text('비밀번호 찾기'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '로그인 없이 둘러보기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textLabel,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '만 14세 이상만 가입할 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textPlaceholder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginBenefit extends StatelessWidget {
  final String label;

  const _LoginBenefit(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textLabel),
        ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.border,
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
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(icon, color: foreground),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background,
          side: border != null ? BorderSide(color: border!) : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
        ),
      ),
    );
  }
}
