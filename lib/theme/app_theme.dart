import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the app's [ThemeData] from [AppColors] tokens — screens should
/// pull styling from `Theme.of(context)` rather than hardcoding values, so
/// the whole app stays visually consistent from one place.
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
          surfaceContainerHighest: AppColors.surfaceMutedLight,
          onSurfaceVariant: AppColors.textSecondary,
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

  static ThemeData _build(ColorScheme colorScheme, {required Color scaffoldBackground}) {
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final textTheme = base.textTheme.copyWith(
      // 병원명·화면 제목처럼 무게가 실려야 하는 자리.
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      // 본문.
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
      // 메타정보 — 작고 연하게.
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
        // 목업 톤: 또렷한 둥근 카드 + 옅은 그림자(스프린트 10 지시서 1).
        elevation: 1.5,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        color: colorScheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: textTheme.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          textStyle: textTheme.titleSmall,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: AppColors.primarySoft,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.primaryDark : null,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1),
      listTileTheme: ListTileThemeData(iconColor: colorScheme.onSurfaceVariant),
    );
  }
}
