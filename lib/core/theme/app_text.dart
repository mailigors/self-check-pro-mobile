import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppText {
  static const family = 'Poppins';

  static TextStyle titleH1({Color color = AppColors.text}) => TextStyle(
        fontFamily: family,
        fontSize: 26,
        height: 36 / 26,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle titleH2({Color color = AppColors.text}) => TextStyle(
        fontFamily: family,
        fontSize: 18,
        height: 27 / 18,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle headlineH5({Color color = AppColors.text}) => TextStyle(
        fontFamily: family,
        fontSize: 16,
        height: 20 / 16,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle bodyH3({Color color = AppColors.text}) => TextStyle(
        fontFamily: family,
        fontSize: 16,
        height: 20 / 16,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle bodyH4({Color color = AppColors.textSecondary}) => TextStyle(
        fontFamily: family,
        fontSize: 14,
        height: 18 / 14,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle bodyH5({Color color = AppColors.textSecondary}) => TextStyle(
        fontFamily: family,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0,
      );
}
