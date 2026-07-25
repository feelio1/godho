import 'package:flutter_riverpod/legacy.dart';

/// Index of the selected bottom-tab (홈 / 주변 병원 / 저장).
final selectedTabProvider = StateProvider<int>((ref) => 0);
