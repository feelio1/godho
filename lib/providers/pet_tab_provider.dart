import 'package:flutter_riverpod/legacy.dart';

/// "우리 아이" 탭 안의 [진료기록|캘린더] 세그먼트("탭 개편" 지시서 B) —
/// 기본은 진료기록이고, 선택은 앱 실행 중 유지된다(다른 탭에 갔다 돌아와도
/// 마지막에 보던 보기를 그대로 보여준다).
enum PetTabView { records, calendar }

final petTabViewProvider = StateProvider<PetTabView>((ref) => PetTabView.records);
