import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 간격·모양·그림자 토큰 (스프린트 14 — Petcli 디자인 시안). 화면에
/// 하드코딩된 padding/radius/그림자 값 대신 이 상수들을 쓴다.
class AppSpacing {
  const AppSpacing._();

  /// 페이지 좌우 패딩.
  static const double page = 20;

  /// 섹션(홈의 카드 묶음 등) 사이 간격 — 스펙 범위(18–22) 중간값.
  static const double section = 20;

  /// 폼 필드 사이 간격.
  static const double formField = 16;

  /// 카드 내부 패딩 — 스펙 범위(13–18) 중간값. 더 여유가 필요한 큰
  /// 카드는 [cardLarge]를 쓴다.
  static const double card = 15;
  static const double cardLarge = 18;
}

class AppRadius {
  const AppRadius._();

  static const double card = 20;
  static const double field = 14;
  static const double pill = 999;
  static const double avatar = 14;
}

class AppShadows {
  const AppShadows._();

  /// 기본 카드 그림자: `0 1px 2px rgba(15,23,42,.04), 0 4px 14px rgba(15,23,42,.05)`.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0D0F172A), offset: Offset(0, 4), blurRadius: 14),
  ];

  /// 검색 세트 카드 전용, 조금 더 뚜렷한 그림자:
  /// `0 8px 22px rgba(15,23,42,.06)`.
  static const List<BoxShadow> searchSet = [
    BoxShadow(color: Color(0x0F0F172A), offset: Offset(0, 8), blurRadius: 22),
  ];

  /// 세그먼트 컨트롤의 활성 pill에 쓰는 옅은 그림자.
  static const List<BoxShadow> segment = [
    BoxShadow(color: Color(0x140F172A), offset: Offset(0, 1), blurRadius: 6),
  ];
}

/// 화면 전체에서 재사용하는 카드 데코레이션 — `Card` 위젯을 쓰지 않고 직접
/// `Container`로 카드를 그릴 때(예: 검색 세트 카드) 이 헬퍼를 쓴다. `Card`
/// 위젯 자체는 `AppTheme`의 `cardTheme`이 같은 톤으로 이미 처리한다.
BoxDecoration appCardDecoration({
  double radius = AppRadius.card,
  List<BoxShadow>? shadow,
  Color color = AppColors.surfaceLight,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.borderCard),
    boxShadow: shadow ?? AppShadows.card,
  );
}
