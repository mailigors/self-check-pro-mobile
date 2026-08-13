import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final textTheme = GoogleFonts.poppinsTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brand,
        onPrimary: AppColors.surface,
        secondary: AppColors.brandSoft,
        onSecondary: AppColors.brand,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.error,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      dividerColor: AppColors.borderSubtle,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: GoogleFonts.poppins(
          color: AppColors.surface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      ),
    );
  }

  static ThemeData dark() {
    final textTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121417),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brand,
        onPrimary: AppColors.surface,
        secondary: Color(0xFF1B2A3A),
        onSecondary: AppColors.brand,
        surface: Color(0xFF1C2128),
        onSurface: Color(0xFFF2F4F6),
        error: AppColors.error,
      ),
      textTheme: textTheme,
    );
  }
}
