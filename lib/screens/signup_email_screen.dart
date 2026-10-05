import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/auth_error_message.dart';
import '../widgets/signup_steps.dart';
import 'signup_age_gender_screen.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// 자체(이메일/비밀번호) 회원가입 1단계 — 자격증명 + 이름("자체
/// 회원가입·로그인·비밀번호 재설정" 지시서 1-1). 이메일 인증 없이
/// 가입 즉시 로그인 상태가 되고, 다음은 성별·연령대(필수) 화면으로
/// 이어진다(소셜 가입과 같은 공용 화면).
class SignupEmailScreen extends ConsumerStatefulWidget {
  const SignupEmailScreen({super.key});

  @override
  ConsumerState<SignupEmailScreen> createState() => _SignupEmailScreenState();
}

class _SignupEmailScreenState extends ConsumerState<SignupEmailScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      _showError('이메일 형식을 확인해주세요');
      return;
    }
    if (password.length < 6) {
      _showError('비밀번호는 6자 이상이어야 해요');
      return;
    }
    if (password != confirm) {
      _showError('비밀번호가 일치하지 않아요');
      return;
    }
    if (name.isEmpty) {
      _showError('이름을 입력해주세요');
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signUpWithEmail(email, password);
      await repo.updateDisplayName(name);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignupAgeGenderScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(authErrorMessage(e));
    } catch (e) {
      _showError('잠시 후 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            24,
          ),
          children: [
            const SignupSteps(step: 1, label: '계정 정보'),
            const SizedBox(height: 4),
            const Text(
              '이메일로 가입할게요',
              style: TextStyle(
                fontSize: 23,
                height: 1.4,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            const Text(
              '이름',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '닉네임으로 써도 괜찮아요'),
            ),
            const SizedBox(height: AppSpacing.formField),
            const Text(
              '이메일',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'example@email.com'),
            ),
            const SizedBox(height: AppSpacing.formField),
            const Text(
              '비밀번호',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '6자 이상'),
            ),
            const SizedBox(height: 4),
            const Text(
              '6자 이상',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.formField),
            const Text(
              '비밀번호 확인',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(hintText: '비밀번호를 한 번 더 입력해주세요'),
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: Listenable.merge([
                _passwordController,
                _confirmController,
              ]),
              builder: (context, _) {
                final match =
                    _confirmController.text.isNotEmpty &&
                    _confirmController.text == _passwordController.text;
                if (!match) return const SizedBox.shrink();
                return const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      '비밀번호가 일치해요',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '다음',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
