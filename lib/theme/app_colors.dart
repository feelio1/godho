import 'package:flutter/material.dart';

import '../models/hospital_status.dart';

/// Single source of truth for every color used in the app — no hex values
/// should appear outside this file (스프린트 3 지시서: "하드코딩 색값
/// 흩어지지 않게").
///
/// 스프린트 10에서 목업(장구름 브랜드: 민트/세이지 그린 + 따뜻한 회갈색)에
/// 맞춰 토큰을 다시 잡았다. Color rule from CLAUDE.md: red is reserved for
/// 시스템 오류에만 — '폐업'은 더 이상 빨강이 아니라 중립 회색이다("그 자리가
/// 문제 있어 보이지 않게"). [error]는 폐업 배지와 완전히 분리된, 실제
/// 시스템 오류에만 쓰는 색이다.
class AppColors {
  const AppColors._();

  // Brand — 세이지/민트 그린 베이스 + 코랄 포인트.
  static const primary = Color(0xFF6FA98A);
  static const primaryDark = Color(0xFF4C8267);
  static const primarySoft = Color(0xFFE3F1E7);
  static const accent = Color(0xFFFF6F59);
  static const accentSoft = Color(0xFFFFE6E1);

  // Status — 영업/폐업/신규(확인불가)에만 사용. 다른 용도로 재사용 금지.
  // 폐업은 빨강이 아니라 회색이다 — 평가·경고가 아니라 그저 인허가 기록상
  // 사실이라는 뜻(CLAUDE.md 평가 금지 원칙, 스프린트 10 지시서 2).
  static const open = Color(0xFF4C8F68);
  static const closed = Color(0xFF8A8072);
  static const neutral = Color(0xFF8A8072);
  static const neutralBg = Color(0xFFF1EFEA);

  /// 실제 시스템 오류(데이터 로드 실패 등)에만 쓰는 빨강. 폐업 배지와는
  /// 완전히 분리된 값이다 — 절대 [closed]와 같은 값으로 합치지 않는다.
  static const error = Color(0xFFB3261E);

  // Text — 따뜻한 회갈색 계열.
  static const textPrimary = Color(0xFF4A3F35);
  static const textSecondary = Color(0xFF8A7A6C);
  static const textCaption = Color(0xFFB4A79A);

  // Surfaces.
  static const backgroundLight = Color(0xFFFAFBF6);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceMutedLight = Color(0xFFF1F4EC);
  static const backgroundDark = Color(0xFF14180F);
  static const surfaceDark = Color(0xFF1C231A);
  static const surfaceMutedDark = Color(0xFF242C20);

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
