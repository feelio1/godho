import 'package:flutter/material.dart';

import '../models/hospital_status.dart';

/// Single source of truth for every color used in the app — no hex values
/// should appear outside this file (스프린트 3 지시서: "하드코딩 색값
/// 흩어지지 않게").
///
/// "펫클 앱 디자인" 캔버스 시안(2026.10)에 맞춰 네이비 블루 팔레트로
/// 다시 잡았다. Color rule from CLAUDE.md: red is reserved for 시스템
/// 오류에만 — '폐업'은 빨강이 아니라 중립 회색이다("그 자리가 문제
/// 있어 보이지 않게"). 시안 자체는 '폐업' 칩에 빨간 톤(#F8E9E6/
/// #9A3324)을 쓰지만, 이 프로젝트에서는 그 톤을 [error](실제 시스템
/// 오류 전용)로만 옮겨오고 '폐업' 배지는 계속 회색이다 — 의도적으로
/// 시안과 다르게 적용한 지점.
class AppColors {
  const AppColors._();

  // Brand/accent — 네이비 블루.
  static const primary = Color(0xFF1B4D8C);
  static const primaryDark = Color(0xFF123A6B);

  /// 액센트를 텍스트(링크·선택 라벨 등)로 쓸 때의 톤 — 시안은 브랜드
  /// 색 하나만 쓰므로 [primary]와 같은 값이다.
  static const primaryTextTone = primary;

  /// 액센트 틴트 — 아이콘·배지 배경 등 아주 옅은 강조 영역.
  static const primarySoft = Color(0xFFE7EEF8);

  /// 진료비 최소–최대 범위 막대 틴트("펫클 앱 디자인" 캔버스 시안의
  /// `.rng`) — [primarySoft]보다 살짝 짙어 회색 트랙 위에서 구분된다.
  static const feeRangeFill = Color(0xFFC9D7EA);

  /// `ColorScheme.secondary`용 — 단일 네이비 브랜드 톤이라 별도 강조색을
  /// 쓰지 않는다. [primary]/[primaryDark]와 같은 값을 써 항상 네이비로
  /// 보이게 한다.
  static const accent = primary;
  static const accentSoft = primarySoft;

  // Status — 영업/폐업/신규(확인불가)에만 사용. 다른 용도로 재사용 금지.
  // 폐업·신규·정보부족은 빨강이 아니라 회색이다 — 평가·경고가 아니라
  // 그저 인허가 기록상 사실이라는 뜻(CLAUDE.md 평가 금지 원칙). '영업'도
  // 녹색 등 긍정적으로 읽히는 색 대신 브랜드 톤 하나로만 구분한다.
  static const openText = primary;
  static const openBg = primarySoft;
  static const openDot = primary;

  static const closedText = Color(0xFF4A5562);
  static const closedBg = Color(0xFFEEF1F4);
  static const closedDot = Color(0xFF8A94A0);

  /// 하위 호환 겸 "상태 색 하나만 필요한" 자리(타임라인 점 등)를 위한
  /// 대표값 — 배지처럼 bg/text/dot을 따로 쓸 수 있는 곳은 위 값들을
  /// 직접 쓴다.
  static const open = openText;
  static const closed = closedText;
  static const neutral = closedText;
  static const neutralBg = closedBg;

  /// 실제 시스템 오류(데이터 로드 실패 등)에만 쓰는 빨강. 폐업 배지와는
  /// 완전히 분리된 값이다 — 절대 [closed]와 같은 값으로 합치지 않는다.
  static const error = Color(0xFF9A3324);

  // Text.
  static const textPrimary = Color(0xFF111A24); // 제목
  static const textLabel = Color(0xFF34404D); // 폼 라벨 등
  static const textSecondary = Color(0xFF4A5562); // 보조
  static const textPlaceholder = Color(0xFF8A94A0); // placeholder

  // Borders — 카드/구분선/입력 필드에서 쓰임새가 조금씩 다른 세 톤.
  static const borderCard = Color(0xFFE2E6EB);
  static const borderMuted = Color(0xFFEEF1F4);
  static const borderInput = Color(0xFFD5DAE0);

  // Surfaces.
  static const backgroundLight = Color(0xFFF5F6F8); // 페이지 배경
  static const surfaceLight = Color(0xFFFFFFFF); // 카드 배경
  static const inputFill = Color(0xFFF5F6F8); // 인셋 입력 필드 배경
  static const surfaceMutedLight = Color(0xFFEEF1F4);
  /// 폐업 병원 카드 배경 — [backgroundLight]와 같은 톤이라 카드가 페이지
  /// 배경 위에서 옅게 가라앉아 보이되 완전히 묻히지는 않는다.
  static const closedCardBg = Color(0xFFF5F6F8);
  static const backgroundDark = Color(0xFF111A24);
  static const surfaceDark = Color(0xFF1E293B);
  static const surfaceMutedDark = Color(0xFF334155);

  // 광고 슬롯 — 시안의 점선 박스(흰 배경 + 회색 점선 테두리 + 회색 텍스트).
  static const adLabelBg = surfaceLight;
  static const adLabelText = Color(0xFF5B6573);
  static const adBorder = Color(0xFFB9C1CB);

  static Color forStatusText(HospitalStatus status) =>
      status == HospitalStatus.open ? openText : closedText;

  static Color forStatusBg(HospitalStatus status) =>
      status == HospitalStatus.open ? openBg : closedBg;

  static Color forStatusDot(HospitalStatus status) =>
      status == HospitalStatus.open ? openDot : closedDot;

  static Color forStatus(HospitalStatus status) => forStatusText(status);
}
