import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/hospital_bundle.dart';

/// Loads the static hospital data bundle from assets. Called once at app
/// start and kept in memory (see CLAUDE.md: Firestore 사용 안 함).
class BundleLoader {
  const BundleLoader();

  Future<HospitalBundle> load() async {
    final raw = await rootBundle.loadString('assets/hospitals.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return HospitalBundle.fromJson(json);
  }
}
