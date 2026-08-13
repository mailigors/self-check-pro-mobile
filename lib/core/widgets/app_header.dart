import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onProfile,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: onBack == null
                ? null
                : GestureDetector(
                    onTap: onBack,
                    behavior: HitTestBehavior.opaque,
                    child: const AppIcon(AppIcon.back, size: 24),
                  ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.headlineH5(),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 24,
            height: 24,
            child: onProfile == null
                ? null
                : GestureDetector(
                    onTap: onProfile,
                    behavior: HitTestBehavior.opaque,
                    child: const AppIcon(AppIcon.user, size: 24),
                  ),
          ),
        ],
      ),
    );
  }
}
