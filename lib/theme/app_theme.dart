import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Builds the app's [ThemeData] from [AppColors]/[AppSpacing]/[AppRadius]
/// tokens — screens should pull styling from `Theme.of(context)` rather
/// than hardcoding values, so the whole app stays visually consistent
/// from one place.
///
/// 스프린트 14: "Petcli" 디자인 시안 — Gothic A1 폰트, 딥블루 액센트,
/// 흰 카드 + 옅은 회색 페이지 배경.
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
          fontFamily: 'Gothic A1',
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          color: color,
          height: height,
        );

    return TextTheme(
      // 화면/브랜드 제목: 22–27 / w900, 자간 타이트.
      headlineSmall: f(size: 26, weight: FontWeight.w900, letterSpacing: -0.7, color: titleColor),
      titleLarge: f(size: 22, weight: FontWeight.w900, letterSpacing: -0.5, color: titleColor),
      // 카드·섹션 제목: 15–17 / w800.
      titleMedium: f(size: 16, weight: FontWeight.w800, letterSpacing: -0.3, color: titleColor),
      titleSmall: f(size: 15, weight: FontWeight.w800, letterSpacing: -0.2, color: titleColor),
      // 본문: 13–15 / w600–700.
      bodyLarge: f(size: 15, weight: FontWeight.w600, color: bodyColor, height: 1.4),
      bodyMedium: f(size: 14, weight: FontWeight.w600, color: bodyColor, height: 1.4),
      bodySmall: f(size: 12.5, weight: FontWeight.w500, color: mutedColor, height: 1.4),
      // 버튼/라벨.
      labelLarge: f(size: 15, weight: FontWeight.w700, color: titleColor),
      labelMedium: f(size: 13, weight: FontWeight.w700, color: bodyColor),
      labelSmall: f(size: 11, weight: FontWeight.w600, color: mutedColor),
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
        // Petcli 카드: 흰 배경 + 또렷한 둥근 모서리 + 옅은 2단 그림자.
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
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: AppColors.inputFill,
        selectedColor: AppColors.primarySoft,
        labelStyle: textTheme.labelSmall?.copyWith(color: AppColors.textLabel),
        secondaryLabelStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.primaryTextTone,
          fontWeight: FontWeight.w800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textPlaceholder),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
          side: const BorderSide(color: AppColors.borderInput),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          foregroundColor: AppColors.textLabel,
          textStyle: textTheme.labelMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.inputFill,
          selectedBackgroundColor: AppColors.surfaceLight,
          selectedForegroundColor: AppColors.primaryTextTone,
          foregroundColor: AppColors.textSecondary,
          side: BorderSide.none,
          textStyle: textTheme.labelMedium,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field - 2)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textPlaceholder,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textPlaceholder,
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
