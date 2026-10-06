import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'mascot_message.dart';

/// 게스트가 로그인 필요 기능(반려동물·진료기록·예약·캘린더·저장)에
/// 접근할 때 쓰는 공용 게이트("로그인 게이팅" 지시서 1). 검색·시세·지도·
/// 상세처럼 게스트에게 그대로 열려 있는 기능은 이 함수를 쓰지 않는다.
///
/// 이미 로그인 상태면 다이얼로그 없이 바로 true. 게스트면 "막는" 벽이
/// 아니라 혜택 톤의 바텀시트로 안내하고, 동의하면 로그인 화면으로
/// 보낸다. 기존 회원 로그인은 성공하면 그 화면이 스스로 pop되어 돌아오므로
/// true를 돌려줘 호출부가 원래 하려던 동작(저장 등)을 그 자리에서 이어갈
/// 수 있다. 신규 가입은 가입 플로우 전체가 끝나면 홈까지 pop하므로
/// (SignupDoneScreen "시작하기"), 그 경우 호출부 화면 자체가 이미 사라져
/// 있을 수 있어 돌아온 뒤 `context.mounted`를 반드시 먼저 확인한다.
Future<bool> requireLogin(
  BuildContext context,
  WidgetRef ref, {
  required String message,
  String title = '로그인하면 이 기능을 쓸 수 있어요',
}) async {
  if (ref.read(authStateProvider).value != null) return true;

  final proceed = await showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('로그인 · 가입'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: const Text('나중에 할게요'),
            ),
          ],
        ),
      ),
    ),
  );
  if (proceed != true || !context.mounted) return false;

  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  if (!context.mounted) return false;
  return ref.read(authStateProvider).value != null;
}

/// 캘린더·진료기록 탭처럼, 화면 전체를 대신하는 안내 상태 — 게스트에게
/// "이 기능은 없다"가 아니라 "로그인하면 이렇게 좋다"를 보여준다.
class GuestFeatureNotice extends StatelessWidget {
  final String title;
  final String message;

  const GuestFeatureNotice({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MascotMessage(
          title: title,
          subtitle: message,
          overlayIcon: Icons.login,
          trailing: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: const Text('로그인 · 가입'),
          ),
        ),
      ),
    );
  }
}
