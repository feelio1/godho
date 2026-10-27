import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/diary.dart';

/// 일기 작성 중 자동 임시 저장("일기 활성화" 지시서 G) — 기기에만 둔다
/// (서버에 올리지 않고, 저장에 성공하면 곧바로 지운다). 새 일기 작성에만
/// 쓴다 — 수정 화면은 이미 저장된 내용이 있어 대상이 아니다. [photoPaths]는
/// 아직 올리지 않은 로컬 사진 파일 경로만 들고 있는다.
class DiaryDraft {
  final DateTime date;
  final List<String> petIds;
  final DiaryWeather? weather;
  final List<DiaryActivity> activities;
  final String text;
  final List<String> photoPaths;

  const DiaryDraft({
    required this.date,
    required this.petIds,
    this.weather,
    this.activities = const [],
    this.text = '',
    this.photoPaths = const [],
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'petIds': petIds,
        'weather': weather?.name,
        'activities': activities.map((a) => a.name).toList(),
        'text': text,
        'photoPaths': photoPaths,
      };

  factory DiaryDraft.fromJson(Map<String, dynamic> json) => DiaryDraft(
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        petIds: (json['petIds'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
        weather: DiaryWeather.fromFirestore(json['weather'] as String?),
        activities: (json['activities'] as List<dynamic>? ?? const [])
            .map((e) => DiaryActivity.fromFirestore(e as String?))
            .whereType<DiaryActivity>()
            .toList(),
        text: json['text'] as String? ?? '',
        photoPaths: (json['photoPaths'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
      );
}

/// SharedPreferences에 임시 일기를 1개만 둔다 — "다시 +를 누르면 이어쓰기
/// / 새로 쓰기"가 가리키는 임시본은 늘 하나뿐이다.
class DiaryDraftStore {
  static const _key = 'diary_draft_v1';

  const DiaryDraftStore();

  /// 저장값이 없거나 깨졌으면(알 수 없는 JSON) null — 호출부는 임시본이
  /// 없는 것처럼 취급한다.
  Future<DiaryDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return DiaryDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(DiaryDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
