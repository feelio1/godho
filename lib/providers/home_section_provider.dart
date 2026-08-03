import 'package:flutter_riverpod/legacy.dart';

/// Home screen's "browse" section tabs (스프린트 4 지시서 2).
///
/// [near] needs a known location to mean anything; until then it's shown
/// disabled and [recentOpen] is the default so the list never silently
/// reorders itself out from under the user.
enum HomeSectionTab {
  near('가까운 순'),
  longestOperating('오래된 순'),
  recentOpen('최근 개원 순'),
  recentlyViewed('최근 확인한 병원');

  final String label;

  const HomeSectionTab(this.label);
}

final homeSectionTabProvider =
    StateProvider<HomeSectionTab>((ref) => HomeSectionTab.recentOpen);
