import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_text_styles.dart';

/// Builds the app's [ThemeData] from [AppColors]/[AppSpacing]/[AppRadius]
/// tokens — screens should pull styling from `Theme.of(context)` rather
/// than hardcoding values, so the whole app stays visually consistent
/// from one place.
///
/// "장구름의 수첩"(3차 업데이트 J-1) — IBM Plex Sans KR 하나(숫자는
/// tabular figures, [AppTextStyles.mono]), 네이비 블루 액센트, 그림자 없는
/// 흰 카드(1px 테두리) + 옅은 회색 페이지 배경, 알약 모양 버튼.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.accent,
          onSecondary: Colors.white,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.inputFill,
          onSurfaceVariant: AppColors.textSecondary,
          outlineVariant: AppColors.borderCard,
          error: AppColors.error,
        ),
        scaffoldBackground: AppColors.backgroundLight,
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surfaceDark,
          surfaceContainerHighest: AppColors.surfaceMutedDark,
          error: AppColors.error,
        ),
        scaffoldBackground: AppColors.backgroundDark,
      );

  static TextTheme _textTheme(Color titleColor, Color bodyColor, Color mutedColor) {
    TextStyle f({
      required double size,
      required FontWeight weight,
      double letterSpacing = 0,
      Color? color,
      double? height,
    }) =>
        TextStyle(
          fontFamily: 'IBM Plex Sans KR',
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          color: color,
          height: height,
          fontFeatures: AppTextStyles.tabular,
        );

    // IBM Plex Sans KR은 400/500/600/700 네 굵기만 번들링돼 있다(시안
    // CSS도 그 넷만 불러온다) — 이전 Gothic A1의 800/900(w900 포함)은
    // 더 못 쓴다. 가장 굵은 Bold(700)로 눌러 쓴다.
    return TextTheme(
      // 화면/브랜드 제목: 22–25 / w700, 자간 -0.03em.
      headlineSmall: f(size: 25, weight: FontWeight.w700, letterSpacing: -0.75, color: titleColor),
      titleLarge: f(size: 22, weight: FontWeight.w700, letterSpacing: -0.66, color: titleColor),
      // 카드·섹션 제목: 15–16 / w600.
      titleMedium: f(size: 16, weight: FontWeight.w600, color: titleColor),
      titleSmall: f(size: 15, weight: FontWeight.w600, color: titleColor),
      // 본문.
      bodyLarge: f(size: 15, weight: FontWeight.w500, color: bodyColor, height: 1.4),
      bodyMedium: f(size: 14, weight: FontWeight.w400, color: bodyColor, height: 1.4),
      bodySmall: f(size: 12.5, weight: FontWeight.w400, color: mutedColor, height: 1.45),
      // 버튼/라벨.
      labelLarge: f(size: 15, weight: FontWeight.w600, color: titleColor),
      labelMedium: f(size: 13, weight: FontWeight.w600, color: bodyColor),
      labelSmall: f(size: 11, weight: FontWeight.w500, color: mutedColor),
    );
  }

  static ThemeData _build(ColorScheme colorScheme, {required Color scaffoldBackground}) {
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final isDark = colorScheme.brightness == Brightness.dark;
    final textTheme = _textTheme(
      isDark ? Colors.white : AppColors.textPrimary,
      isDark ? Colors.white70 : AppColors.textLabel,
      isDark ? Colors.white60 : AppColors.textSecondary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        // "장구름의 수첩"(3차 업데이트 J-1): 그림자 없이 흰 바탕 + 1px
        // borderCard + 반지름 22.
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        color: colorScheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.borderCard),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        // 선택 칩: 선택됨 = 2px 네이비 테두리 + primarySoft + 굵은 글자,
        // 안 선택 = 1px borderInput + 흰 바탕. 정보만 보여 주는 칩(상태·
        // 건수)은 각 화면에서 회색 바탕을 직접 준다.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const BorderSide(color: AppColors.primary, width: 2)
              : const BorderSide(color: AppColors.borderInput),
        ),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.primarySoft : AppColors.surfaceLight,
        ),
        checkmarkColor: AppColors.primary,
        // 칩 라벨도 앱 기본 글꼴로(지정하지 않으면 기기 시스템 글꼴로 대체된다).
        // 칩 글자는 굵게(w600) 두고, 선택되면 네이비 글자 — Chip은 글자 굵기를
        // 상태별로 바꿔 주지 않아 색으로 구분한다(테두리·바탕도 함께 바뀜).
        labelStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextTone,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // 흰 바탕 + 1px borderInput(대비 3:1 이상), 반지름 14, 높이 약 52dp.
        fillColor: isDark ? AppColors.inputFill : AppColors.surfaceLight,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textPlaceholder),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.borderInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.borderInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        // 주요 버튼: 높이 56dp, 알약(반지름 28), 네이비 바탕 흰 글자.
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderCard,
          disabledForegroundColor: AppColors.textPlaceholder,
          minimumSize: const Size(64, 56),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // 보조 버튼: 높이 48dp, 알약, 1.5px 네이비 테두리 + 네이비 글자.
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        // 텍스트 버튼도 터치 높이 44dp 이상.
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        extendedSizeConstraints: BoxConstraints.tightFor(height: 56),
        shape: StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        // 세그먼트: closedBg 둥근 막대 안에 선택 칸만 흰색·굵게.
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.surfaceLight : AppColors.closedBg,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.closedBg, width: 3)),
          textStyle: WidgetStateProperty.resolveWith(
            (states) => textTheme.labelMedium?.copyWith(
              fontSize: 14,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // 하단 탭: 선택 = feeRangeFill 알약 + 네이비 아이콘·굵은 글자,
        // 안 선택 = textSecondary(옅은 회색 아님). 라벨 12sp.
        backgroundColor: colorScheme.surface,
        indicatorColor: AppColors.feeRangeFill,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderMuted, space: 1),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.textSecondary),
      iconTheme: const IconThemeData(color: AppColors.textLabel),
      // 날짜/시간 피커(캘린더·시계)는 커스텀 바텀시트로 새로 만들지 않고,
      // Flutter 기본 피커를 Petcli 톤으로 다시 입혔다 — 선택 로직은 각
      // 화면의 showDatePicker/showTimePicker 그대로다.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: Colors.white,
        todayForegroundColor: WidgetStateProperty.all(AppColors.primary),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textPrimary,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        dialBackgroundColor: AppColors.inputFill,
        dialHandColor: AppColors.primary,
        hourMinuteColor: AppColors.inputFill,
        hourMinuteTextColor: AppColors.textPrimary,
      ),
    );
  }
}
