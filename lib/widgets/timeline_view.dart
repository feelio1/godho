import 'package:flutter/material.dart';

import '../models/timeline.dart';
import '../theme/app_colors.dart';

/// Mandatory disclaimer for any same-address timeline
/// (see CLAUDE.md 워딩 규칙 — 타임라인 하단 필수 고지). Wording must not
/// change: no operator continuity is implied.
const String timelineDisclaimer =
    '이 정보는 동일한 주소에서 확인된 병원 인허가 기록입니다. 각 병원의 운영자가 동일한 사람인지는 확인할 수 없습니다.';

/// Vertical timeline of same-address hospital registration records.
/// Merged segments start collapsed and expand on tap
/// (see CLAUDE.md 워딩 규칙: "재등록 기록 M건 포함" + 서사 추정 금지).
class TimelineView extends StatefulWidget {
  final Timeline timeline;

  const TimelineView({super.key, required this.timeline});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final segments = widget.timeline.segments;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '동일 주소 인허가 기록',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < segments.length; i++)
          _SegmentTile(
            segment: segments[i],
            isLast: i == segments.length - 1,
            expanded: _expanded.contains(i),
            onToggle: () => setState(() {
              if (_expanded.contains(i)) {
                _expanded.remove(i);
              } else {
                _expanded.add(i);
              }
            }),
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.neutralBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            timelineDisclaimer,
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.neutral, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final TimelineSegment segment;
  final bool isLast;
  final bool expanded;
  final VoidCallback onToggle;

  const _SegmentTile({
    required this.segment,
    required this.isLast,
    required this.expanded,
    required this.onToggle,
  });

  static String _formatYm(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    return '${parts[0]}.${parts[1]}';
  }

  String get _periodLabel {
    final start = _formatYm(segment.start);
    final end = segment.end == null ? '현재' : _formatYm(segment.end!);
    return '$start ~ $end';
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(segment.status);
    final textTheme = Theme.of(context).textTheme;
    final displayName =
        segment.names.isNotEmpty ? segment.names.first : '이름 확인 불가';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_periodLabel · ${segment.status.label}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.neutral),
                  ),
                  if (segment.merged) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: onToggle,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            segment.recordCount > 1
                                ? '재등록 기록 ${segment.recordCount}건 포함'
                                : '재등록 기록 포함',
                            style: textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            expanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: segment.names
                              .map((name) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '· $name',
                                      style: textTheme.bodySmall,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
