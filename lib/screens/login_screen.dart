import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../ads/app_open_ad_suppression.dart';
import '../config/feature_flags.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/mascot_image.dart';
import '../utils/keep_words.dart';
import '../utils/auth_error_message.dart';
import '../utils/network_error.dart';
import 'password_reset_screen.dart';
import 'signup_age_gender_screen.dart';
import 'signup_email_screen.dart';

/// 로그인/회원가입 진입 화면(펫클 2단계 지시서 1, 4) — 홈 메뉴에서 진입.
/// 게이팅이 아니라 "테스트 가능한 진입점"이라, 로그인하지 않고 뒤로
/// 가도 게스트 기능은 그대로다.
///
/// v1 출시 범위는 구글 + 이메일 + 게스트다("v1 출시 준비" 지시서 1) —
/// 카카오 버튼은 [kEnableKakaoLogin] 플래그로 숨겨져 있을 뿐,
/// `signInWithKakao`와 그 호출 코드는 그대로 남아 있어 플래그만 true로
/// 바꾸면 다시 노출된다(마켓 URL 확보 후 적용할 카카오 실연결은 별도
/// 지시서). 애플 로그인은 iOS 출시 준비(L-3)에서 켰고 iOS에서만 보인다
/// ([showAppleSignIn]).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// 애플 로그인 버튼을 보일지 — iOS에서만, [kEnableAppleLogin]이 켜졌을 때만.
/// 안드로이드는 플래그와 무관하게 보이지 않는다(iOS 출시 준비 L-3).
bool showAppleSignIn(TargetPlatform platform) => platform == TargetPlatform.iOS && kEnableAppleLogin;

enum _Provider { google, kakao, apple, email }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Provider? _loading;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

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
      _showError(actionFailureMessage(e, '로그인'));
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  void _openSignupEmail() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupEmailScreen()));
  }

  void _openPasswordReset() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PasswordResetScreen()));
  }

  Future<void> _handleGoogle() async {
    setState(() => _loading = _Provider.google);
    try {
      final repo = ref.read(authRepositoryProvider);
      final credential = await repo.signInWithGoogle();
      await _afterSignedIn(credential.user);
    } on FirebaseAuthException catch (e) {
      _showError(authErrorMessage(e));
    } catch (e) {
      // 사용자가 계정 선택 창을 닫은 경우 등은 조용히 무시하지만, 네트워크
      // 오류(가입 여부 확인용 Firestore 조회 실패 등)는 안내한다.
      if (isNetworkError(e)) {
        _showError(actionFailureMessage(e, '로그인'));
      }
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
      _showError(authErrorMessage(e));
    } catch (e) {
      // 취소 등은 조용히 무시하지만, 네트워크 오류는 안내한다.
      if (isNetworkError(e)) {
        _showError(actionFailureMessage(e, '로그인'));
      }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인됐어요.')));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SignupAgeGenderScreen()));
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
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인'))],
      ),
    );
  }

  // 로그인 중에는 앱 오프닝 광고를 띄우지 않는다 — 화면이 사라지면
  // (어떤 경로든) 억제도 같이 풀린다.
  @override
  Widget build(BuildContext context) => AppOpenAdSuppressor(child: _buildScreen(context));

  Widget _buildScreen(BuildContext context) {
    final showApple = showAppleSignIn(defaultTargetPlatform);
    // "장구름의 수첩"(3차 업데이트 J-7): 오른쪽 위 닫기, 제목 + 손 흔드는 구름이,
    // 구글 버튼 → "또는 이메일로" → 라벨 있는 이메일·비밀번호(보기 버튼,
    // 자동완성) → [로그인] → 회원가입 | 비밀번호 찾기 → 둘러보기·14세 안내.
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(tooltip: '닫기', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 24),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '우리 아이 기록은\n로그인 후 저장돼요',
                            style: TextStyle(
                              fontSize: 25,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            keepWords('일기 · 진료기록 · 예약 알림 · 병원 저장'),
                            style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const MascotImage(size: 88, assetPath: MascotImage.emptyRecordAssetPath),
                  ],
                ),
                const SizedBox(height: 22),
                if (showApple)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AppleSignInButton(
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
                _GoogleSignInButton(
                  loading: _loading == _Provider.google,
                  enabled: _loading == null,
                  onPressed: _handleGoogle,
                ),
                const SizedBox(height: 22),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.borderCard)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('또는 이메일로', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ),
                    Expanded(child: Divider(color: AppColors.borderCard)),
                  ],
                ),
                const SizedBox(height: 18),
                const _LoginLabel('이메일'),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  enabled: _loading == null,
                  decoration: const InputDecoration(hintText: 'name@example.com'),
                ),
                const SizedBox(height: AppSpacing.formField),
                const _LoginLabel('비밀번호'),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: _loading == null,
                  onSubmitted: (_) => _handleEmailLogin(),
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? '비밀번호 가리기' : '비밀번호 보기',
                      icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _loading == null ? _handleEmailLogin : null,
                  child: _loading == _Provider.email
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('로그인'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(onPressed: _loading == null ? _openSignupEmail : null, child: const Text('회원가입')),
                    Container(width: 1, height: 16, color: AppColors.borderCard),
                    TextButton(onPressed: _loading == null ? _openPasswordReset : null, child: const Text('비밀번호 찾기')),
                  ],
                ),
                const SizedBox(height: 28),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                    child: const Text(
                      '로그인 없이 둘러보기',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '만 14세 이상만 가입할 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginLabel extends StatelessWidget {
  final String text;

  const _LoginLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    ),
  );
}

/// 구글 로그인 버튼 — Google 브랜드 가이드(라이트 테마)대로: 흰 바탕,
/// 1px #747775 테두리, 알약 모양, 왼쪽에 공식 G 로고(`assets/brand/
/// google_g.png`, 다시 그리지 않음) 20dp, "Google로 계속하기". 높이 54dp로
/// 다른 로그인 수단보다 덜 눈에 띄지 않게 한다(2차 업데이트 I).
class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.loading, required this.enabled, required this.onPressed});

  static const _border = Color(0xFF747775);
  static const _text = Color(0xFF1F1F1F);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('login_google'),
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white,
          side: const BorderSide(color: _border, width: 1),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _text))
                : Image.asset('assets/brand/google_g.png', width: 20, height: 20),
            const SizedBox(width: 12),
            const Text(
              'Google로 계속하기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _text),
            ),
          ],
        ),
      ),
    );
  }
}

/// 애플 로그인 버튼 — 애플 가이드(Sign in with Apple 버튼)대로 검정 바탕,
/// 흰 애플 로고(패키지의 공식 로고 [AppleLogoPainter], 다시 그리지 않음)와
/// 시스템 글꼴의 "Apple로 계속하기". 크기·높이·모양은 구글 버튼과 같다
/// (54dp 알약, 전체 너비) — 다른 로그인 수단보다 작거나 덜 눈에 띄지
/// 않게(iOS 출시 준비 L-3).
class _AppleSignInButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _AppleSignInButton({required this.loading, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('login_apple'),
      height: 54,
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      // 로고가 글자 높이와 같아 보이게 살짝 줄이고 위로 올린다.
                      padding: EdgeInsets.fromLTRB(2, 0, 2, 2),
                      child: CustomPaint(painter: AppleLogoPainter(color: Colors.white)),
                    ),
                  ),
            const SizedBox(width: 12),
            const Text(
              'Apple로 계속하기',
              style: TextStyle(
                // iOS 시스템 글꼴(애플 가이드). 다른 플랫폼에서는 기본 글꼴로 떨어진다.
                fontFamily: 'CupertinoSystemText',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
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
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: foreground))
            : Icon(icon, color: foreground),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
        ),
      ),
    );
  }
}
