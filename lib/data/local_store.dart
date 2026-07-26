import 'package:shared_preferences/shared_preferences.dart';

/// Local-only persistence for saved and recently-viewed hospital ids.
/// No account, no server (see CLAUDE.md: 계정·서버 없음).
class LocalStore {
  static const _savedKey = 'saved_hospital_ids';
  static const _recentKey = 'recent_hospital_ids';
  static const _recentLimit = 10;

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
}
