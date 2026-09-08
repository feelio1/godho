import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/medical_record.dart';
import '../models/pet.dart';
import '../models/region_filter.dart';

/// Local-only persistence for saved and recently-viewed hospital ids, plus
/// (스프린트 8) 지정 병원 · 반려동물 프로필 · 진료기록. No account, no
/// server (see CLAUDE.md: 계정·서버 없음) — everything here lives only on
/// this device.
class LocalStore {
  static const _savedKey = 'saved_hospital_ids';
  static const _recentKey = 'recent_hospital_ids';
  static const _recentLimit = 10;
  static const _regionSidoKey = 'region_sido';
  static const _regionSigunguKey = 'region_sigungu';
  static const _designatedKey = 'designated_hospital_ids';
  static const _petsKey = 'pets_json_v1';
  static const _medicalRecordsKey = 'medical_records_json_v1';

  const LocalStore();

  Future<List<String>> loadSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedKey) ?? const [];
  }

  Future<List<String>> toggleSaved(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(prefs.getStringList(_savedKey) ?? const []);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    await prefs.setStringList(_savedKey, current);
    return current;
  }

  Future<List<String>> loadRecentIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? const [];
  }

  Future<List<String>> recordVisit(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(prefs.getStringList(_recentKey) ?? const []);
    current.remove(id);
    current.insert(0, id);
    final trimmed = current.take(_recentLimit).toList();
    await prefs.setStringList(_recentKey, trimmed);
    return trimmed;
  }

  /// Null means the user has never explicitly chosen a region (so a GPS-based
  /// default may still apply). A non-null value — including an explicit
  /// `RegionFilter.all()` — means the user's choice should be honored as-is.
  Future<RegionFilter?> loadRegion() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_regionSidoKey)) return null;
    final sido = prefs.getString(_regionSidoKey);
    final sigungu = prefs.getString(_regionSigunguKey);
    return RegionFilter(
      sido: (sido == null || sido.isEmpty) ? null : sido,
      sigungu: (sigungu == null || sigungu.isEmpty) ? null : sigungu,
    );
  }

  Future<void> saveRegion(RegionFilter region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regionSidoKey, region.sido ?? '');
    await prefs.setString(_regionSigunguKey, region.sigungu ?? '');
  }

  // --- 지정(단골) 병원 ---
  // "저장(관심)"과는 별개 개념 — 저장은 여러 곳을 자유롭게 담아두는 목록,
  // 지정은 홈 상단에 늘 띄워 둘 단골 병원이다. 저장 목록과 같은 방식(id
  // 배열)으로 로컬에 둔다.

  Future<List<String>> loadDesignatedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_designatedKey) ?? const [];
  }

  Future<List<String>> toggleDesignated(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(prefs.getStringList(_designatedKey) ?? const []);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    await prefs.setStringList(_designatedKey, current);
    return current;
  }

  // --- 반려동물 건강기록 (로컬 최소 버전) ---
  // Pet/MedicalRecord는 JSON 직렬화가 분리되어 있어(모델 파일 참고), 여기서는
  // "문자열 하나에 JSON 배열을 통째로 저장"하는 가장 단순한 방식만 맡는다 —
  // 후속 Firebase 이관 시 이 두 메서드 쌍만 원격 저장소 호출로 바꾸면 된다.

  Future<List<Pet>> loadPets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_petsKey);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Pet.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> savePets(List<Pet> pets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_petsKey, jsonEncode(pets.map((p) => p.toJson()).toList()));
  }

  Future<List<MedicalRecord>> loadMedicalRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_medicalRecordsKey);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveMedicalRecords(List<MedicalRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _medicalRecordsKey,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }
}
