import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "로그아웃 버그 수정" 지시서 A의 근본 원인과 수정 방향을 검증한다.
///
/// 실제 버그: account_menu_sheet.dart의 로그아웃 onTap이 `Navigator.pop
/// (context)`로 바텀시트(ConsumerWidget)를 먼저 닫은 뒤, 그 시트 자신의
/// (이미 폐기된) `ref`로 `ref.read(authRepositoryProvider).signOut()`을
/// 호출했다 — pop된 위젯의 ref로 읽으면 예외가 나고, 그 예외는 await되지
/// 않은 Future 체인 안이라 조용히 삼켜져 signOut()이 실행되지 않았다.
///
/// 이 화면은 로그인 상태(FirebaseAuth User)에 의존해 이 테스트 환경에서
/// 직접 구동할 수 없으므로(firebase_auth_mocks가 kakao SDK와 충돌해 쓸 수
/// 없다는 제약은 이전 단계에서도 확인됨), 버그의 핵심 메커니즘 — "pop돼
/// 사라진 ConsumerWidget 자신의 ref로 나중에 읽으면 안전한가" — 을 순수
/// Riverpod 예제로 재현해 검증한다. 실제 수정(account_ui.dart의
/// confirmAndSignOut이 WidgetRef 대신 AuthRepository를 받고, 호출부가 pop
/// 전에 `ref.read(authRepositoryProvider)`로 미리 캡처하는 것)은 바로
/// 아래 두 번째 테스트의 "pop 전에 미리 읽어두기" 패턴이다.
void main() {
  final valueProvider = Provider<int>((ref) => 42);

  testWidgets('수정 전 패턴: pop돼 사라진 위젯 자신의 ref로 나중에 읽으면 예외가 난다', (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (sheetContext) => Consumer(
                    builder: (context, ref, _) {
                      capturedRef = ref;
                      return ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('닫기'),
                      );
                    },
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('닫기'));
    // 시트가 완전히 닫히고(애니메이션 포함) 위젯이 dispose될 때까지 흘려보낸다.
    await tester.pumpAndSettle();

    expect(() => capturedRef.read(valueProvider), throwsA(anything));
  });

  testWidgets('수정된 패턴: pop 전에 값을 미리 읽어두면(캡처) pop 이후에도 안전하게 쓸 수 있다', (tester) async {
    int? captured;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (sheetContext) => Consumer(
                    builder: (context, ref, _) => ElevatedButton(
                      onPressed: () {
                        // account_ui.dart 수정과 같은 순서: pop 전에 필요한
                        // 값(AuthRepository 인스턴스에 해당)을 먼저 읽어둔다.
                        final value = ref.read(valueProvider);
                        Navigator.pop(sheetContext);
                        captured = value;
                      },
                      child: const Text('닫기'),
                    ),
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    expect(captured, 42);
    expect(tester.takeException(), isNull);
  });
}
