import 'package:flutter/material.dart';

/// "작성 중인 내용이 있어요. 나가시겠어요?" 확인 — 나가기를 고르면 true.
/// 일기 쓰기 화면과 같은 문구·버튼이다.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: const Text('작성 중인 내용이 있어요. 나가시겠어요?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('계속 쓰기')),
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('나가기')),
      ],
    ),
  );
  return discard ?? false;
}

/// 작성 화면의 뒤로가기(시스템 뒤로가기·앱바 뒤로 버튼) 확인 — [isDirty]가
/// true일 때만 묻고, 아니면 그냥 닫는다. 저장 후 코드에서 직접 부르는
/// `Navigator.pop`이나 다른 화면으로의 교체(`pushReplacement`)는 막지 않는다.
/// [isDirty]는 화면을 연 때의 값과 지금 값을 비교하는 함수라, 바뀐 게
/// 없으면(되돌린 경우 포함) 묻지 않는다.
class UnsavedChangesGuard extends StatelessWidget {
  final bool Function() isDirty;
  final Widget child;

  const UnsavedChangesGuard({super.key, required this.isDirty, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (isDirty() && !await confirmDiscardChanges(context)) return;
        if (navigator.mounted) navigator.pop(result);
      },
      child: child,
    );
  }
}
