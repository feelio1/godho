import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global compare list (max 3 hospitals), session-only.
class CompareListNotifier extends Notifier<List<String>> {
  static const maxCompare = 3;

  @override
  List<String> build() => [];

  bool get isFull => state.length >= maxCompare;

  bool contains(String id) => state.contains(id);

  /// Adds [id] to the compare list. Returns false without changing state
  /// if the list is already full.
  bool add(String id) {
    if (state.contains(id)) return true;
    if (state.length >= maxCompare) return false;
    state = [...state, id];
    return true;
  }

  void remove(String id) {
    state = state.where((e) => e != id).toList();
  }

  void toggle(String id) {
    if (state.contains(id)) {
      remove(id);
    } else {
      add(id);
    }
  }

  void clear() {
    state = [];
  }
}

final compareListProvider =
    NotifierProvider<CompareListNotifier, List<String>>(
  CompareListNotifier.new,
);
