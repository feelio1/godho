import 'package:flutter/material.dart';

import '../models/hospital_status.dart';

/// Single source of truth for every color used in the app — no hex values
/// should appear outside this file (스프린트 3 지시서: "하드코딩 색값
/// 흩어지지 않게").
///
/// 스프린트 14에서 "Petcli" 디자인 시안(확정 토큰 스펙)에 맞춰 값을 다시
/// 잡았다. Color rule from CLAUDE.md: red is reserved for 시스템 오류에만
/// — '폐업'은 빨강이 아니라 중립 회색이다("그 자리가 문제 있어 보이지
/// 않게"). [error]는 폐업 배지와 완전히 분리된, 실제 시스템 오류에만 쓰는
/// 색이다.
class AppColors {
  const AppColors._();

  // Brand/accent — 진한 블루.
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);

  /// 액센트를 텍스트(링크·선택 라벨 등)로 쓸 때의 톤 — [primary]보다 살짝
  /// 짙어 흰 배경 위 대비가 더 또렷하다.
  static const primaryTextTone = Color(0xFF1E40AF);

  /// 액센트 틴트 — 아이콘·배지 배경 등 아주 옅은 강조 영역.
  static const primarySoft = Color(0xFFEAF1FE);

  /// `ColorScheme.secondary`용 — Petcli는 단일 블루 브랜드 톤이라 별도
  /// 강조색을 쓰지 않는다(스프린트 14 이전 세이지그린/코랄 시절의 잔재를
  /// 정리 — 방치하면 Material 위젯이 기본으로 `colorScheme.secondary`를
  /// 쓸 때 파란 화면 위에 낯선 색이 튀어나온다). [primary]/[primaryDark]와
  /// 같은 값을 써 항상 블루로 보이게 한다.
  static const accent = primary;
  static const accentSoft = primarySoft;

  // Status — 영업/폐업/신규(확인불가)에만 사용. 다른 용도로 재사용 금지.
  // 폐업·정보부족은 빨강이 아니라 회색이다 — 평가·경고가 아니라 그저
  // 인허가 기록상 사실이라는 뜻(CLAUDE.md 평가 금지 원칙).
  static const openText = Color(0xFF15803D);
  static const openBg = Color(0xFFDCFCE7);
  static const openDot = Color(0xFF22C55E);

  static const closedText = Color(0xFF64748B);
  static const closedBg = Color(0xFFEEF2F7);
  static const closedDot = Color(0xFF94A3B8);

  /// 하위 호환 겸 "상태 색 하나만 필요한" 자리(타임라인 점 등)를 위한
  /// 대표값 — 배지처럼 bg/text/dot을 따로 쓸 수 있는 곳은 위 값들을
  /// 직접 쓴다.
  static const open = openText;
  static const closed = closedText;
  static const neutral = closedText;
  static const neutralBg = closedBg;

  /// 실제 시스템 오류(데이터 로드 실패 등)에만 쓰는 빨강. 폐업 배지와는
  /// 완전히 분리된 값이다 — 절대 [closed]와 같은 값으로 합치지 않는다.
  static const error = Color(0xFFDC2626);

  // Text.
  static const textPrimary = Color(0xFF0F172A); // 제목
  static const textLabel = Color(0xFF475569); // 폼 라벨 등
  static const textSecondary = Color(0xFF64748B); // 보조
  static const textPlaceholder = Color(0xFF94A3B8); // placeholder

  // Borders — 카드/구분선/입력 필드에서 쓰임새가 조금씩 다른 세 톤.
  static const borderCard = Color(0xFFE7ECF3);
  static const borderMuted = Color(0xFFEEF2F7);
  static const borderInput = Color(0xFFE2E8F0);

  // Surfaces.
  static const backgroundLight = Color(0xFFF1F5F9); // 페이지 배경
  static const surfaceLight = Color(0xFFFFFFFF); // 카드 배경
  static const inputFill = Color(0xFFF1F5F9); // 인셋 입력 필드 배경
  static const surfaceMutedLight = Color(0xFFF1F5F9);
  /// 폐업 병원 카드 배경 — [backgroundLight]보다 살짝 밝아 카드가 페이지
  /// 배경 위에서 옅게 가라앉아 보이되 완전히 묻히지는 않는다.
  static const closedCardBg = Color(0xFFF8FAFC);
  static const backgroundDark = Color(0xFF0F172A);
  static const surfaceDark = Color(0xFF1E293B);
  static const surfaceMutedDark = Color(0xFF334155);

  // 광고 슬롯의 "광고" 라벨 — 배경/텍스트가 페이지 배경·placeholder
  // 텍스트와 같은 톤이라, 병원 카드와는 확실히 구분되지만 튀지 않는다.
  static const adLabelBg = backgroundLight;
  static const adLabelText = textPlaceholder;

  static Color forStatusText(HospitalStatus status) =>
      status == HospitalStatus.open ? openText : closedText;

  static Color forStatusBg(HospitalStatus status) =>
      status == HospitalStatus.open ? openBg : closedBg;

  static Color forStatusDot(HospitalStatus status) =>
      status == HospitalStatus.open ? openDot : closedDot;

  static Color forStatus(HospitalStatus status) => forStatusText(status);
}
