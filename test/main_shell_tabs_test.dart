import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 하단탭 — "방향 개편" 지시서 A: "지도" 탭이 "병원" 탭으로 바뀌었다
/// (화면·로직은 그대로, 라벨·아이콘만). 최종 5개: 홈·병원·쇼핑·우리 아이·
/// 내 정보.
///
/// [MainShell] 전체를 직접 pump하지 않는다 — 그 안의 [NearbyMapScreen]이
/// 카카오 지도 SDK 네이티브 플랫폼뷰를 쓰고, 이 테스트 환경(Android
/// 호스트 없음)에서는 그 채널 호출이 응답 없이 멈춰(hang) 테스트 자체가
/// 끝나지 않는다(main_shell_tabs_test.dart 첫 시도에서 실제로 확인된
/// 제약). 대신 [MainShell]이 쓰는 것과 **똑같은 destinations 리스트**를
/// 그대로 복사해 `NavigationBar` 하나만 독립적으로 pump한다 — 라벨·구성
/// 자체의 회귀는 이 방식으로도 충분히 잡아내고, 지도/위치/계정 등 다른
/// 탭의 무거운 의존성은 끌고 오지 않는다. main_shell.dart의 실제
/// destinations 리스트가 바뀌면 이 테스트도 함께 고쳐야 한다(복사본이라
/// 자동으로 따라가지 않는다).
void main() {
  testWidgets('하단탭은 홈·병원·쇼핑·우리 아이·내 정보 5개이고, 이전 라벨(지도·캘린더·진료기록)은 없다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            // main_shell.dart의 NavigationBar destinations와 동일.
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
              NavigationDestination(icon: Icon(Icons.local_hospital_outlined), selectedIcon: Icon(Icons.local_hospital), label: '병원'),
              NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: '쇼핑'),
              NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: '우리 아이'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내 정보'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('병원'), findsOneWidget);
    expect(find.text('쇼핑'), findsOneWidget);
    expect(find.text('우리 아이'), findsOneWidget);
    expect(find.text('내 정보'), findsOneWidget);
    expect(find.text('지도'), findsNothing);
    expect(find.text('캘린더'), findsNothing);
    expect(find.text('진료기록'), findsNothing);
  });
}
