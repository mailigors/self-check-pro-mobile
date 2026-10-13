import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum AppButtonVariant { primary, secondary, dark, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expanded = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expanded;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (Color bg, Color fg, Color? border) = switch (variant) {
      AppButtonVariant.primary => (
        enabled ? AppColors.brand : AppColors.background,
        enabled ? AppColors.surface : AppColors.placeholder,
        null,
      ),
      AppButtonVariant.dark => (
        enabled ? AppColors.text : AppColors.surfaceMuted,
        enabled ? AppColors.surface : AppColors.placeholder,
        null,
      ),
      AppButtonVariant.secondary => (
        AppColors.background,
        enabled ? AppColors.text : AppColors.placeholder,
        AppColors.border,
      ),
      AppButtonVariant.danger => (
        AppColors.background,
        AppColors.error,
        AppColors.border,
      ),
    };

    final textSize = MediaQuery.textScalerOf(context).scale(16);
    final enlarged = textSize > 20;
    final child = SizedBox(
      height: enlarged ? textSize * 2.6 + 24 : 56,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(32),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: enlarged ? 2 : 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.headlineH5(color: fg),
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 10),
                          Icon(icon, color: fg, size: 20),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );

    return expanded ? child : IntrinsicWidth(child: child);
  }
}
