import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/providers/nav_provider.dart';

/// 하단 탭 순서("탭 개편" 지시서 A) — 숫자 하드코딩 대신 [AppTab] enum의
/// index를 쓰므로, 그 순서 자체가 호출부들이 기대하는 계약이다. 여기서
/// 고정해두면 나중에 탭 순서가 또 바뀔 때 실수로 깨지는 호출부를 바로
/// 잡아낼 수 있다.
void main() {
  test('AppTab 순서는 홈·지도·쇼핑·우리 아이·내 정보다', () {
    expect(AppTab.values, [AppTab.home, AppTab.map, AppTab.shop, AppTab.pet, AppTab.my]);
    expect(AppTab.home.index, 0);
    expect(AppTab.map.index, 1);
    expect(AppTab.shop.index, 2);
    expect(AppTab.pet.index, 3);
    expect(AppTab.my.index, 4);
  });

  test('selectedTabProvider의 초기값은 홈 탭이다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(selectedTabProvider), AppTab.home.index);
  });
}
