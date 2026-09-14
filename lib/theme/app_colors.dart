import 'package:flutter/material.dart';

import '../models/hospital_status.dart';

/// Single source of truth for every color used in the app — no hex values
/// should appear outside this file (스프린트 3 지시서: "하드코딩 색값
/// 흩어지지 않게").
///
/// 스프린트 13에서 파스텔 민트 → 또렷한 딥블루 기반으로 톤을 다시 잡았다
/// (마스코트 "장구름"의 구름과 어울리는, 의료·신뢰의 색 — 마스코트 이미지
/// 자체는 그대로, UI 크롬 색만 블루). Color rule from CLAUDE.md: red is
/// reserved for 시스템 오류에만 — '폐업'은 빨강이 아니라 중립 회색이다("그
/// 자리가 문제 있어 보이지 않게"). [error]는 폐업 배지와 완전히 분리된,
/// 실제 시스템 오류에만 쓰는 색이다.
class AppColors {
  const AppColors._();

  // Brand — 또렷한 딥블루. 파스텔로 흐리지 않는다(스프린트 13 지시서 1).
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primarySoft = Color(0xFFDBEAFE);
  static const accent = Color(0xFFFF6F59);
  static const accentSoft = Color(0xFFFFE6E1);

  // Status — 영업/폐업/신규(확인불가)에만 사용. 다른 용도로 재사용 금지.
  // 폐업은 빨강이 아니라 회색이다 — 평가·경고가 아니라 그저 인허가 기록상
  // 사실이라는 뜻(CLAUDE.md 평가 금지 원칙). 영업중은 블루 브랜드와 구분되게
  // 차분한 그린을 그대로 쓴다(스프린트 13 지시서 1 — "영업중을 굳이
  // 블루로 안 해도 됨, 상태 구분이 명확하면 됨").
  static const open = Color(0xFF16A34A);
  static const closed = Color(0xFF6B7280);
  static const neutral = Color(0xFF6B7280);
  static const neutralBg = Color(0xFFF1F5F9);

  /// 실제 시스템 오류(데이터 로드 실패 등)에만 쓰는 빨강. 폐업 배지와는
  /// 완전히 분리된 값이다 — 절대 [closed]와 같은 값으로 합치지 않는다.
  static const error = Color(0xFFDC2626);

  // Text — 진한 회색/네이비 계열로 가독성 확보.
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const textCaption = Color(0xFF9CA3AF);

  // Surfaces — 흰 배경 + 카드가 또렷이 도드라지도록.
  static const backgroundLight = Color(0xFFF8FAFC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceMutedLight = Color(0xFFF1F5F9);
  static const backgroundDark = Color(0xFF0F172A);
  static const surfaceDark = Color(0xFF1E293B);
  static const surfaceMutedDark = Color(0xFF334155);

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
