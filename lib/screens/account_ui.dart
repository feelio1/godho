import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

/// 로그인 사용자를 부르는 이름 — 닉네임(displayName)이 있으면 그걸,
/// 없으면(예: 애플 로그인에서 이름 비공개) 이메일 앞부분을 쓴다. 홈 상단
/// 배지와 계정 메뉴가 같은 이름을 보여주도록 한곳에 모아둔다(펫클 3단계
/// 지시서 1, "계정 메뉴에 반려동물 관리 통합" 지시서에서 공용으로 뺌).
String accountLabel(User user) {
  final displayName = user.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final email = user.email;
  if (email != null && email.isNotEmpty) return email.split('@').first;
  return '회원';
}

/// 로그아웃 확인 다이얼로그 — 탭 한 번으로 바로 로그아웃되지 않도록 확인을
/// 한 번 거친다(펫클 "계정 반려동물 추가/수정" 지시서 3 "명확하게"). 로컬
/// (게스트) 반려동물·진료기록은 로그인 여부와 무관하게 기기에 그대로
/// 남는다는 점을 안내해 혼선을 막는다(CLAUDE.md 원칙과 같은 맥락: 데이터가
/// 사라진다는 오해를 만들지 않는다).
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('로그아웃'),
      content: const Text('로그아웃하시겠어요?\n이 기기에 남아 있는 반려동물·진료기록은 지워지지 않습니다.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('로그아웃')),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(authRepositoryProvider).signOut();
  }
}
