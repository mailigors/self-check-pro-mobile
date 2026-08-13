import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

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
    final (Color bg, Color fg, Color? border) = switch (variant) {
      AppButtonVariant.primary => (
          enabled ? AppColors.brand : AppColors.background,
          enabled ? AppColors.surface : AppColors.placeholder,
          null,
        ),
      AppButtonVariant.secondary => (
          AppColors.surface,
          enabled ? AppColors.text : AppColors.placeholder,
          AppColors.border,
        ),
      AppButtonVariant.danger => (
          const Color(0xFFFFF0F0),
          AppColors.error,
          null,
        ),
    };

    final child = SizedBox(
      height: 56,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headlineH5(color: fg),
                  ),
          ),
        ),
      ),
    );

    return expanded ? child : IntrinsicWidth(child: child);
  }
}
