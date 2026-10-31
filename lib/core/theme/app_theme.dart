import 'package:flutter/material.dart';

import 'package:rume/core/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.ink,
      primary: AppColors.primaryLight,
      secondary: AppColors.primaryLighter,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primaryLight,
    ),
    textTheme: const TextTheme(
      titleMedium: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyMedium: TextStyle(color: AppColors.textMuted, fontSize: 14),
    ),
  );
}
