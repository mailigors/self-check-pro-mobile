import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg) = switch (variant) {
      AppButtonVariant.primary => (
          enabled ? AppColors.brand : AppColors.brand.withValues(alpha: 0.4),
          AppColors.surface,
        ),
      AppButtonVariant.secondary => (
          AppColors.background,
          enabled ? AppColors.text : AppColors.textSecondary,
        ),
      AppButtonVariant.danger => (
          const Color(0xFFFFF0F0),
          AppColors.error,
        ),
    };

    final child = SizedBox(
      height: 56,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                : Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      height: 20 / 16,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
          ),
        ),
      ),
    );

    return expanded ? child : IntrinsicWidth(child: child);
  }
}
