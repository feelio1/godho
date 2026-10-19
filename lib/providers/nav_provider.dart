import 'package:flutter_riverpod/legacy.dart';

/// 하단 탭 순서("탭 개편" 지시서 A) — 홈 / 지도 / 쇼핑 / 우리 아이(진료기록+
/// 캘린더 통합) / 내 정보. 호출부는 숫자를 직접 쓰지 않고 이 enum의
/// `.index`를 쓴다 — 탭 순서가 또 바뀌어도 호출부가 깨지지 않게 하기
/// 위해서다.
enum AppTab { home, map, shop, pet, my }

/// Index of the selected bottom-tab.
final selectedTabProvider = StateProvider<int>((ref) => AppTab.home.index);
