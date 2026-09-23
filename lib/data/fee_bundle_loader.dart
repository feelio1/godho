import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/fee_bundle.dart';

/// Loads the static fee bundle from assets. Called once at app start and
/// kept in memory — same pattern as [BundleLoader] for hospitals.json
/// (CLAUDE.md: Firestore 사용 안 함).
class FeeBundleLoader {
  const FeeBundleLoader();

  Future<FeeBundle> load() async {
    final raw = await rootBundle.loadString('assets/fees.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return FeeBundle.fromJson(json);
  }
}
