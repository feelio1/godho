import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../utils/auth_error_message.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// 비밀번호 재설정("자체 회원가입·로그인·비밀번호 재설정" 지시서 2) —
/// 이메일 입력 → `sendPasswordResetEmail` → "펫클 앱 디자인" 캔버스
/// 시안(PwReset.dc.html/PwSent.dc.html)대로 발송 확인 화면으로 넘어간다.
/// 메일 템플릿은 Firebase 콘솔 기본값을 그대로 쓴다.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _send(String email) async {
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _showMessage(authErrorMessage(e));
    } catch (e) {
      _showMessage('잠시 후 다시 시도해주세요');
    }
    return false;
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      _showMessage('이메일 형식을 확인해주세요');
      return;
    }

    setState(() => _loading = true);
    final sent = await _send(email);
    if (mounted) setState(() => _loading = false);
    if (sent && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PasswordResetSentScreen(email: email),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '가입한 이메일을\n입력해 주세요',
                style: TextStyle(
                  fontSize: 23,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '비밀번호를 다시 설정할 수 있는 링크를 메일로 보내드려요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
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
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'example@email.com',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '구글·카카오·Apple로 가입했다면 비밀번호 없이 해당 버튼으로 로그인해 주세요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textPlaceholder,
                ),
              ),
              const Spacer(),
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
                          '재설정 메일 보내기',
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
      ),
    );
  }
}

/// 재설정 메일 발송 확인("펫클 앱 디자인" 캔버스 시안 PwSent.dc.html) —
/// 로그인 화면까지 한 번에 돌아가고, 다시 보내기는 이 화면에서 바로.
class _PasswordResetSentScreen extends ConsumerStatefulWidget {
  final String email;

  const _PasswordResetSentScreen({required this.email});

  @override
  ConsumerState<_PasswordResetSentScreen> createState() =>
      _PasswordResetSentScreenState();
}

class _PasswordResetSentScreenState
    extends ConsumerState<_PasswordResetSentScreen> {
  bool _resending = false;

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('재설정 메일을 다시 보냈어요.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('잠시 후 다시 시도해주세요')));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            56,
            AppSpacing.page,
            24,
          ),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.mail_outline,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '재설정 메일을 보냈어요',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: widget.email,
                            style: AppTextStyles.mono(
                              size: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const TextSpan(
                            text:
                                '\n가입된 이메일이라면 곧 메일이 도착해요.\n보이지 않으면 스팸함도 확인해 주세요.',
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    // 로그인 화면까지 두 단계(이 화면 → 비밀번호 찾기 화면)를
                    // 한 번에 돌아간다 — Login.dc.html에서 PwReset.dc.html →
                    // PwSent.dc.html로 이어진 경로를 그대로 되짚는다.
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.pop();
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                  ),
                  child: const Text(
                    '로그인으로 돌아가기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: _resending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '메일 다시 보내기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLabel,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
