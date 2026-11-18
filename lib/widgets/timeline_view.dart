import 'package:flutter/material.dart';

import '../models/timeline.dart';
import '../models/hospital_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Mandatory disclaimer for any same-address timeline
/// (see CLAUDE.md 워딩 규칙 — 타임라인 하단 필수 고지). Wording must not
/// change: no operator continuity is implied.
const String timelineDisclaimer = '이 정보는 동일한 주소에서 확인된 병원 인허가 기록입니다. 각 병원의 운영자가 동일한 사람인지는 확인할 수 없습니다.';

/// "이 자리의 병원 기록"("장구름의 수첩", 3차 업데이트 J-4) — 제목 + 설명
/// 한 줄 + 건수 문구, 흰 카드 안에 세로 선 + 점, 기간은 테두리 있는 날짜
/// 도장(가장 최근 구간 = 네이비, 지난 구간 = 회색). 필수 고지문은 softPanel
/// 상자에 그대로. 병합 구간은 접혀 있다가 탭하면 원 기록을 펼친다(CLAUDE.md
/// 워딩 규칙: "재등록 기록 M건 포함" + 서사 추정 금지).
class TimelineView extends StatefulWidget {
  final Timeline timeline;

  /// 같은 주소의 인허가 기록 건수(번들 계산값). null이면 구간 기록 합계.
  final int? recordCount;

  const TimelineView({super.key, required this.timeline, this.recordCount});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final segments = widget.timeline.segments;
    final count = widget.recordCount ?? widget.timeline.totalRecordCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '이 자리의 병원 기록',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          '같은 주소에 등록됐던 동물병원을 시간순으로 보여드려요. '
          '동일 주소에서 확인된 동물병원 인허가 기록 $count건.',
          style: const TextStyle(fontSize: 14, height: 1.55, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.softPanel,
                    borderRadius: BorderRadius.circular(AppRadius.panel),
                  ),
                  child: const Text(
                    timelineDisclaimer,
                    style: TextStyle(fontSize: 13.5, height: 1.55, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
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

  const _SegmentTile({required this.segment, required this.isLast, required this.expanded, required this.onToggle});

  static String _formatYm(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    return '${parts[0]}.${parts[1]}';
  }

  String get _periodLabel {
    final start = _formatYm(segment.start);
    final end = segment.end == null ? '지금' : _formatYm(segment.end!);
    return '$start ~ $end';
  }

  @override
  Widget build(BuildContext context) {
    // 색은 영업 상태가 아니라 "가장 최근 기록인지"만 나타낸다 — 폐업 여부는
    // 아래 상태 글자로만 표기해, 시간축 표시가 평가로 읽히지 않게 한다.
    final color = isLast ? AppColors.primary : AppColors.closedText;
    final displayName = segment.names.isNotEmpty ? segment.names.first : '이름 확인 불가';
    final statusLabel = segment.status == HospitalStatus.open ? '영업 중' : segment.status.label;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                const SizedBox(height: 9),
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: isLast ? AppColors.primary : AppColors.surfaceLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: AppColors.borderCard)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: color, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _periodLabel,
                      style: AppTextStyles.mono(
                        size: 14,
                        weight: FontWeight.w700,
                        color: isLast ? AppColors.textPrimary : color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isLast ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(statusLabel, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  if (segment.merged) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onToggle,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              segment.recordCount > 1 ? '재등록 기록 ${segment.recordCount}건 포함' : '재등록 기록 포함',
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final name in segment.names)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '· $name',
                                  style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                                ),
                              ),
                          ],
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
