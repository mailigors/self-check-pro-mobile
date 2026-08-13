import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

Future<bool?> showAppConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Отмена',
  String confirmLabel = 'Подтвердить',
  AppButtonVariant confirmVariant = AppButtonVariant.primary,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.overlay,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DBE1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.titleH2(),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.bodyH4(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: cancelLabel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppButton(
                      label: confirmLabel,
                      variant: confirmVariant,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
