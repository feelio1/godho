import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/cloud_migration.dart';
import 'local_store.dart';
import 'user_repository.dart';

void _log(String message) => debugPrint('[CloudMigrationService] $message');

/// [CloudMigrationService.migrateIfNeeded] 한 번 실행의 결과 — 화면이 이걸로
/// 사용자에게 짧게 알려줄 수 있다(예: "N마리는 옮기지 못했어요").
class CloudMigrationResult {
  final List<String> migratedPetNames;
  final List<String> skippedPetNames;

  const CloudMigrationResult({this.migratedPetNames = const [], this.skippedPetNames = const []});

  bool get didMigrateAnything => migratedPetNames.isNotEmpty;
  bool get hasSkipped => skippedPetNames.isNotEmpty;
}

/// 로그인 사용자의 기기 로컬 진료기록·예약을 계정(Firestore)으로 1회
/// 복사한다 — 원본 로컬 데이터는 절대 지우거나 옮기지 않는다(그대로 백업
/// 겸 유지, 비파괴). 계정당 1회만 시도하도록 SharedPreferences 플래그로
/// 막는다. 로컬 반려동물과 계정 반려동물이 이름·종류로 정확히 하나씩만
/// 짝지어질 때만 그 반려동물의 기록·예약을 복사하고, 애매하거나 일치하는
/// 계정 반려동물이 없으면 그 반려동물은 건드리지 않고 건너뛴다("진료기록·
/// 예약 Firestore 저장" 지시서 B-3).
class CloudMigrationService {
  CloudMigrationService({LocalStore? localStore, UserRepository? userRepository})
      : _localStore = localStore ?? const LocalStore(),
        _userRepository = userRepository ?? UserRepository();

  final LocalStore _localStore;
  final UserRepository _userRepository;

  static String _flagKey(String uid) => 'migratedToCloud_$uid';

  Future<bool> _hasMigrated(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_flagKey(uid)) ?? false;
  }

  Future<void> _markMigrated(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flagKey(uid), true);
  }

  /// 이미 이 계정에서 한 번 시도했으면(성공/스킵 무관) 곧바로 null을
  /// 돌려주고 아무 것도 하지 않는다 — 매번 로그인할 때마다 다시 복사
  /// 시도하지 않게.
  Future<CloudMigrationResult?> migrateIfNeeded(String uid) async {
    if (await _hasMigrated(uid)) {
      _log('이미 이관을 시도한 계정($uid) — 건너뜀');
      return null;
    }

    final localPets = await _localStore.loadPets();
    if (localPets.isEmpty) {
      _log('로컬 반려동물이 없음 — 이관할 것 없이 바로 완료 처리');
      await _markMigrated(uid);
      return null;
    }

    final accountPets = await _userRepository.fetchPets(uid);
    if (accountPets.isEmpty) {
      _log('계정 반려동물이 없음 — 이관할 대상이 없어 스킵');
      await _markMigrated(uid);
      return null;
    }

    final matches = matchLocalPetsToAccountPets(localPets, accountPets);
    final matchedPairs = matches.where((m) => m.isMatched).toList();
    final skippedNames = matches.where((m) => !m.isMatched).map((m) => m.localPet.name).toList();

    if (matchedPairs.isEmpty) {
      _log('매칭되는 반려동물이 없음(전부 애매/불일치) — 아무 것도 옮기지 않고 완료 처리');
      await _markMigrated(uid);
      return CloudMigrationResult(skippedPetNames: skippedNames);
    }

    final allRecords = await _localStore.loadMedicalRecords();
    final allAppointments = await _localStore.loadAppointments();

    final migratedNames = <String>[];
    for (final match in matchedPairs) {
      final local = match.localPet;
      final account = match.accountPet!;
      final docId = account.id;
      if (docId == null) continue; // Firestore에서 온 값이라 사실상 항상 있음.

      final records = allRecords.where((r) => r.petId == local.id);
      for (final record in records) {
        try {
          await _userRepository.addRecord(uid, docId, record);
        } catch (e) {
          _log('진료기록 이관 실패(${local.name}, ${record.id}) — 건너뜀: $e');
        }
      }

      final appointments = allAppointments.where((a) => a.petId == local.id);
      for (final appointment in appointments) {
        try {
          await _userRepository.addAppointment(uid, docId, appointment);
        } catch (e) {
          _log('예약 이관 실패(${local.name}, ${appointment.id}) — 건너뜀: $e');
        }
      }

      migratedNames.add(local.name);
      _log('${local.name} → 계정 반려동물(${account.name ?? account.species.label}) 이관 완료');
    }

    await _markMigrated(uid);
    return CloudMigrationResult(migratedPetNames: migratedNames, skippedPetNames: skippedNames);
  }
}
