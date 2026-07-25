import 'hospital_status.dart';

class TimelineSegment {
  final List<String> names;
  final String start; // "YYYY-MM"
  final String? end; // "YYYY-MM" or null (ongoing)
  final HospitalStatus status;
  final bool merged;

  const TimelineSegment({
    required this.names,
    required this.start,
    this.end,
    required this.status,
    this.merged = false,
  });

  factory TimelineSegment.fromJson(Map<String, dynamic> json) {
    return TimelineSegment(
      names: (json['names'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      start: json['start'] as String,
      end: json['end'] as String?,
      status: HospitalStatus.fromJson(json['status'] as String?),
      merged: json['merged'] as bool? ?? false,
    );
  }

  /// Best-available count of registration names folded into this display
  /// segment. Only shown when it is actually informative (>1) — a merged
  /// segment with a single known name is described without a fabricated
  /// number (see CLAUDE.md 원칙 5).
  int get recordCount => names.isEmpty ? 1 : names.length;
}

class Timeline {
  final String id;
  final String addrKey;
  final List<TimelineSegment> segments;

  const Timeline({
    required this.id,
    required this.addrKey,
    required this.segments,
  });

  factory Timeline.fromJson(String id, Map<String, dynamic> json) {
    return Timeline(
      id: id,
      addrKey: json['addrKey'] as String? ?? '',
      segments: (json['segments'] as List<dynamic>? ?? const [])
          .map((e) => TimelineSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Total number of registration records known at this address, summed
  /// across all segments. This is the figure shown as "동일 주소에서
  /// 확인된 동물병원 인허가 기록 N건" — a plain count of public records,
  /// never an implication about the operator.
  int get totalRecordCount =>
      segments.fold(0, (sum, seg) => sum + seg.recordCount);
}
