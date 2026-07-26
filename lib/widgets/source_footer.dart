import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Mandatory source/last-updated footer for the detail screen
/// (see CLAUDE.md 원칙 4: 출처·날짜 필수).
class SourceFooter extends StatelessWidget {
  final String source;
  final DateTime? lastUpdated;

  const SourceFooter({super.key, required this.source, this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final formatted = lastUpdated != null
        ? DateFormat('yyyy.MM.dd').format(lastUpdated!)
        : '확인 불가';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '출처: $source',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '최종 갱신일: $formatted',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
