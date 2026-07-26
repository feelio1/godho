import 'hospital.dart';
import 'timeline.dart';

/// The full static data bundle loaded once at app start
/// (see CLAUDE.md: 정적 JSON 번들, Firestore 사용 안 함).
class HospitalBundle {
  final DateTime? generatedAt;
  final String source;
  final String region;
  final List<Hospital> hospitals;
  final Map<String, Timeline> timelines;

  const HospitalBundle({
    required this.generatedAt,
    required this.source,
    required this.region,
    required this.hospitals,
    required this.timelines,
  });

  factory HospitalBundle.fromJson(Map<String, dynamic> json) {
    final timelinesJson =
        json['timelines'] as Map<String, dynamic>? ?? const {};
    return HospitalBundle(
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? ''),
      source: json['source'] as String? ?? '',
      region: json['region'] as String? ?? '',
      hospitals: (json['hospitals'] as List<dynamic>? ?? const [])
          .map((e) => Hospital.fromJson(e as Map<String, dynamic>))
          .toList(),
      timelines: timelinesJson.map(
        (key, value) =>
            MapEntry(key, Timeline.fromJson(key, value as Map<String, dynamic>)),
      ),
    );
  }

  Timeline? timelineFor(Hospital hospital) {
    final id = hospital.timelineId;
    if (id == null) return null;
    return timelines[id];
  }

  /// Records known at the same address as [hospital]: from the timeline
  /// when one exists, otherwise just the hospital itself.
  int sameAddressRecordCount(Hospital hospital) {
    final timeline = timelineFor(hospital);
    if (timeline == null) return 1;
    return timeline.totalRecordCount;
  }
}
