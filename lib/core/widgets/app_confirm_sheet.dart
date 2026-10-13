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
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.overlay,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cancel = AppButton(
                      label: cancelLabel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context, false),
                    );
                    final confirm = AppButton(
                      label: confirmLabel,
                      variant: confirmVariant,
                      onPressed: () => Navigator.pop(context, true),
                    );
                    if (constraints.maxWidth < 280 &&
                        MediaQuery.textScalerOf(context).scale(16) > 20) {
                      return Column(
                        children: [cancel, const SizedBox(height: 12), confirm],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: cancel),
                        const SizedBox(width: 16),
                        Expanded(child: confirm),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
