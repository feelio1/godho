import 'package:shared_preferences/shared_preferences.dart';

import '../models/region_filter.dart';

/// Local-only persistence for saved and recently-viewed hospital ids.
/// No account, no server (see CLAUDE.md: 계정·서버 없음).
class LocalStore {
  static const _savedKey = 'saved_hospital_ids';
  static const _recentKey = 'recent_hospital_ids';
  static const _recentLimit = 10;
  static const _regionSidoKey = 'region_sido';
  static const _regionSigunguKey = 'region_sigungu';

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
}
