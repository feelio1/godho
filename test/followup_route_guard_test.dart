import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// MainShell의 _maybeShowFollowUpSheet는 `ModalRoute.of(context)?.isCurrent`
// 로 "내 라우트가 최상단인지"를 가린다 — 기록 폼·상세·다른 시트/다이얼로그가
// 위에 떠 있으면 확인 시트를 띄우지 않기 위해서다("복귀 시 과도한 재노출
// 방지" 지시서 1, 3). MainShell 자체는 Firebase/bundle 등 무거운 의존성
// 때문에 이 환경에서 직접 렌더링해 검증하기 어려워, 여기서는 그 메커니즘
// 자체(Navigator.push 위에 다른 라우트가 뜨면 아래 라우트의 isCurrent가
// false로 바뀌고, pop하면 다시 true로 돌아오는지)를 최소 재현으로 검증한다.
void main() {
  testWidgets(
    'ModalRoute.of(context)?.isCurrent는 다른 화면이 push되면 false, pop하면 다시 true가 된다',
    (tester) async {
      late BuildContext baseRouteContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              baseRouteContext = context;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (popContext) => Scaffold(
                        body: ElevatedButton(
                          onPressed: () => Navigator.of(popContext).pop(),
                          child: const Text('위에 뜬 화면'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('열기'),
                ),
              );
            },
          ),
        ),
      );

      expect(ModalRoute.of(baseRouteContext)?.isCurrent, isTrue);

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(ModalRoute.of(baseRouteContext)?.isCurrent, isFalse);

      await tester.tap(find.text('위에 뜬 화면'));
      await tester.pumpAndSettle();
      expect(ModalRoute.of(baseRouteContext)?.isCurrent, isTrue);
    },
  );

  testWidgets(
    '바텀시트가 떠 있는 동안에도 아래 라우트의 isCurrent는 false다',
    (tester) async {
      late BuildContext baseRouteContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              baseRouteContext = context;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(height: 100, child: Text('시트')),
                  ),
                  child: const Text('시트 열기'),
                ),
              );
            },
          ),
        ),
      );

      expect(ModalRoute.of(baseRouteContext)?.isCurrent, isTrue);

      await tester.tap(find.text('시트 열기'));
      await tester.pumpAndSettle();
      expect(ModalRoute.of(baseRouteContext)?.isCurrent, isFalse);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(ModalRoute.of(baseRouteContext)?.isCurrent, isTrue);
    },
  );
}
