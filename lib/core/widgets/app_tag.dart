import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum AppTagTone { success, brand, warning, error, draft }

class AppTag extends StatelessWidget {
  const AppTag({super.key, required this.label, required this.tone});

  final String label;
  final AppTagTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AppTagTone.success => AppColors.success,
      AppTagTone.brand => AppColors.brand,
      AppTagTone.warning => AppColors.warning,
      AppTagTone.error => AppColors.error,
      AppTagTone.draft => AppColors.draft,
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone == AppTagTone.warning ? const Color(0xFFFFD54F) : color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: AppText.bodyH5(
          color: tone == AppTagTone.warning
              ? AppColors.text
              : AppColors.surface,
        ),
      ),
    );
  }
}
