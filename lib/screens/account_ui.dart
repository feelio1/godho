import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/auth_repository.dart';

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
///
/// [WidgetRef] 대신 [AuthRepository] 인스턴스를 직접 받는다 — 호출부가
/// 바텀시트처럼 이 함수가 끝나기 전에 스스로 pop되어 사라지는 위젯이면,
/// 그 위젯의 ref는 pop되는 순간 폐기(dispose)돼 이후 `ref.read(...)`가
/// 예외를 던진다. 그 예외가 이 함수 안의 await 체인에서 나면 어디서도
/// await되지 않은 Future라 조용히 삼켜지고, signOut()은 실행되지 않은 채
/// 로그인 상태가 그대로 남는 버그로 이어진다("로그아웃 버그 수정" 지시서
/// A). AuthRepository는 [authRepositoryProvider]가 앱 생애주기 내내 하나만
/// 만드는 평범한 객체라 어떤 위젯이 사라지든 계속 유효하다 — 호출부가
/// pop하기 전에 `ref.read(authRepositoryProvider)`로 미리 꺼내 넘기면 된다.
Future<void> confirmAndSignOut(BuildContext context, AuthRepository authRepository) async {
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
  if (confirmed != true) return;
  try {
    await authRepository.signOut();
  } catch (e) {
    debugPrint('[confirmAndSignOut] signOut 실패: $e');
  }
}
