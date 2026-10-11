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
      AppTagTone.draft => AppColors.text,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label.toLowerCase().startsWith('заверш')
                ? Icons.task_alt_rounded
                : Icons.schedule_rounded,
            size: 12,
            color: AppColors.surface,
          ),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: AppText.bodyH5(color: AppColors.surface)
                .copyWith(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
