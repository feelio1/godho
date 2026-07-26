import 'package:flutter/material.dart';

import '../models/hospital_status.dart';

/// Color rules from CLAUDE.md: red is reserved for 폐업/시스템 오류 only.
/// New/insufficient-data states use neutral gray, never a negative color.
class AppColors {
  static const open = Color(0xFF2E7D32);
  static const closed = Color(0xFFB3261E);
  static const neutral = Color(0xFF6B6B6B);
  static const neutralBg = Color(0xFFEDEDED);

  static Color forStatus(HospitalStatus status) {
    switch (status) {
      case HospitalStatus.open:
        return open;
      case HospitalStatus.closed:
        return closed;
      case HospitalStatus.unknown:
        return neutral;
    }
  }
}
