import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/auth_error_message.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// 비밀번호 재설정("자체 회원가입·로그인·비밀번호 재설정" 지시서 2) —
/// 이메일 입력 → `sendPasswordResetEmail` → 안내 후 로그인 화면으로
/// 돌아간다. 메일 템플릿은 Firebase 콘솔 기본값을 그대로 쓴다.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      _showMessage('이메일 형식을 확인해주세요');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재설정 메일을 보냈어요.')),
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(authErrorMessage(e));
    } catch (e) {
      _showMessage('잠시 후 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 찾기')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '가입할 때 쓴 이메일을 입력하면 재설정 메일을 보내드려요.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.section),
              const Text('이메일', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'example@email.com'),
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
                      : const Text('재설정 메일 보내기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
