import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/compare_provider.dart';
import '../screens/compare_screen.dart';

/// Persistent bottom bar shown from search results and detail screens once
/// at least one hospital is in the compare list (max 3).
class CompareFloatingBar extends ConsumerWidget {
  const CompareFloatingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compareIds = ref.watch(compareListProvider);
    if (compareIds.isEmpty) return const SizedBox.shrink();

    // 바깥 호출부(detail_screen.dart/search_result_screen.dart)가
    // bottomNavigationBar 전체를 SafeArea(top: false)로 한 번만 감싼다 —
    // 여기서도 감싸면 뒤따르는 GlobalBannerAd와 겹쳐 하단 안전영역
    // 패딩이 두 번 들어간다.
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: Text('비교 목록 ${compareIds.length}/3')),
          TextButton(
            onPressed: () => ref.read(compareListProvider.notifier).clear(),
            child: const Text('비우기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CompareScreen()),
            ),
            child: const Text('비교하기'),
          ),
        ],
      ),
    );
  }
}
