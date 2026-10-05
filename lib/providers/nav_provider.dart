import 'package:flutter_riverpod/legacy.dart';

/// Index of the selected bottom-tab (홈 / 지도 / 캘린더 / 진료기록 /
/// 내 정보 — "디자인 1단계" 지시서 1).
final selectedTabProvider = StateProvider<int>((ref) => 0);
