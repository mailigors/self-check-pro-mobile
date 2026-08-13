import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

abstract final class AppTheme {
  static const _textTheme = TextTheme(
    displayLarge: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    displayMedium: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    displaySmall: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    headlineLarge: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    headlineMedium: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    headlineSmall: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    titleLarge: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    titleMedium: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    titleSmall: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    bodyLarge: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    bodyMedium: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    bodySmall: TextStyle(fontFamily: AppText.family, color: AppColors.textSecondary),
    labelLarge: TextStyle(fontFamily: AppText.family, color: AppColors.text),
    labelMedium: TextStyle(fontFamily: AppText.family, color: AppColors.textSecondary),
    labelSmall: TextStyle(fontFamily: AppText.family, color: AppColors.textSecondary),
  );

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: 1),
      );

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppText.family,
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
      textTheme: _textTheme,
      dividerColor: AppColors.borderSubtle,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.brand,
        selectionColor: AppColors.brandSoft,
        selectionHandleColor: AppColors.brand,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppText.bodyH3(color: AppColors.placeholder),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.brand),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error),
        disabledBorder: _border(AppColors.borderSubtle),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.brandSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppText.bodyH5(color: selected ? AppColors.brand : AppColors.textSecondary);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: const IconThemeData(color: AppColors.brand),
        unselectedIconTheme: const IconThemeData(color: AppColors.text),
        selectedLabelTextStyle: AppText.bodyH5(color: AppColors.brand),
        unselectedLabelTextStyle: AppText.bodyH5(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: AppText.bodyH4(color: AppColors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      ),
    );
  }
}
