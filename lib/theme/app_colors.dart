import 'package:flutter/material.dart';

import '../models/hospital_status.dart';

/// Single source of truth for every color used in the app — no hex values
/// should appear outside this file (스프린트 3 지시서: "하드코딩 색값
/// 흩어지지 않게").
///
/// Color rule from CLAUDE.md: red is reserved for 폐업/시스템 오류 only.
/// New/insufficient-data states use neutral gray, never a negative color.
/// The coral accent below is a distinct hue from [closed] specifically so
/// it never reads as an error/closed signal.
class AppColors {
  const AppColors._();

  // Brand — 민트/청록 베이스 + 코랄 포인트.
  static const primary = Color(0xFF0FA88B);
  static const primaryDark = Color(0xFF0B7F69);
  static const primarySoft = Color(0xFFDFF5F0);
  static const accent = Color(0xFFFF6F59);
  static const accentSoft = Color(0xFFFFE6E1);

  // Status — 영업/폐업/신규(확인불가)에만 사용. 다른 용도로 재사용 금지.
  static const open = Color(0xFF2F9E44);
  static const closed = Color(0xFFB3261E);
  static const neutral = Color(0xFF6E6E6E);
  static const neutralBg = Color(0xFFF0F0EE);

  // Text.
  static const textPrimary = Color(0xFF1B1D1C);
  static const textSecondary = Color(0xFF6E6E6E);
  static const textCaption = Color(0xFF9A9A98);

  // Surfaces.
  static const backgroundLight = Color(0xFFF7FBFA);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceMutedLight = Color(0xFFF0F5F4);
  static const backgroundDark = Color(0xFF0F1513);
  static const surfaceDark = Color(0xFF17201D);
  static const surfaceMutedDark = Color(0xFF1F2A26);

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
