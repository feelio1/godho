import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';
import '../models/pet.dart';

/// 반려동물 프로필 목록. 화면상 지금은 1마리만 다루지만 저장 구조는 여러
/// 마리를 담을 수 있다(스프린트 8 지시서 2). 로컬(SharedPreferences)에만
/// 저장 — 계정·서버 없음.
class PetsNotifier extends AsyncNotifier<List<Pet>> {
  final _store = const LocalStore();

  @override
  Future<List<Pet>> build() => _store.loadPets();

  Future<void> upsert(Pet pet) async {
    final current = List<Pet>.from(state.value ?? const []);
    final index = current.indexWhere((p) => p.id == pet.id);
    if (index >= 0) {
      current[index] = pet;
    } else {
      current.add(pet);
    }
    await _store.savePets(current);
    state = AsyncValue.data(current);
  }

  Future<void> remove(String petId) async {
    final current = List<Pet>.from(state.value ?? const [])
      ..removeWhere((p) => p.id == petId);
    await _store.savePets(current);
    state = AsyncValue.data(current);
  }
}

final petsProvider = AsyncNotifierProvider<PetsNotifier, List<Pet>>(PetsNotifier.new);
