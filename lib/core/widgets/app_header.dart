import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onProfile,
    this.action,
  });
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onProfile;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton.filledTonal(
              tooltip: 'Назад',
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.text,
              ),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: onBack == null ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: onBack == null ? AppText.titleH1() : AppText.titleH2(),
            ),
          ),
          ?action,
          if (onProfile != null)
            IconButton(
              tooltip: 'Профиль',
              onPressed: onProfile,
              icon: const Icon(Icons.person_outline_rounded),
            ),
        ],
      ),
    );
  }
}
