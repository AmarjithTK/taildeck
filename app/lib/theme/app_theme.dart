import 'package:flutter/material.dart';

/// Colour tokens from `docs/UI_SPEC.md` §1.
abstract final class AppColors {
  static const Color bg = Color(0xFF0A0E13);
  static const Color surface = Color(0xFF151A21);
  static const Color surfaceHigh = Color(0xFF1C232C);
  static const Color border = Color(0xFF232B36);
  static const Color borderDashed = Color(0xFF2E3846);

  static const Color textPrimary = Color(0xFFF2F5F8);
  static const Color textSecondary = Color(0xFF8B95A5);
  static const Color textDisabled = Color(0xFF5A6472);

  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryPressed = Color(0xFF5B4BD6);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF5A524);
  static const Color danger = Color(0xFFEF4444);

  /// Colour for a status dot. `checking` has no colour — it renders a spinner.
  static Color forState(ProbeDotState state) => switch (state) {
    ProbeDotState.online => success,
    ProbeDotState.offline => danger,
    ProbeDotState.warning => warning,
    ProbeDotState.checking ||
    ProbeDotState.disabled ||
    ProbeDotState.unknown => textDisabled,
  };
}

/// Minimal enum so the dot does not have to import the domain layer.
enum ProbeDotState { unknown, checking, online, offline, disabled, warning }

/// Type styles. Addresses use a monospace face so digits line up down the grid.
abstract final class AppText {
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Roboto Mono', 'Courier New'],
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

ThemeData buildTailDeckTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.primary,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    dividerColor: AppColors.border,
    splashColor: Colors.white10,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: Color(0x556C5CE7),
      selectionHandleColor: AppColors.primary,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      labelSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
