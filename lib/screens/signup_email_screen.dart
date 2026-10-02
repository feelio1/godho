import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/auth_error_message.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text(
              '이메일과 비밀번호로 가입할 수 있어요',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.section),
            const Text('이메일', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'example@email.com'),
            ),
            const SizedBox(height: AppSpacing.formField),
            const Text('비밀번호', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '6자 이상'),
            ),
            const SizedBox(height: AppSpacing.formField),
            const Text('비밀번호 확인', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '비밀번호를 한 번 더 입력해주세요'),
            ),
            const SizedBox(height: AppSpacing.formField),
            const Text('이름', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: '닉네임으로 써도 괜찮아요'),
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('가입하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
