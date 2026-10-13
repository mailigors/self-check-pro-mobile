import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import 'auth_controller.dart';

/// Lives inside the authenticated navigator so routing after login cannot
/// dispose the dialog before the user answers.
class BiometricOffer extends ConsumerStatefulWidget {
  const BiometricOffer({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<BiometricOffer> createState() => _BiometricOfferState();
}

class _BiometricOfferState extends ConsumerState<BiometricOffer> {
  bool _showing = false;

  Future<void> _show(String label) async {
    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Использовать $label?'),
        content: Text(
          'В следующий раз входите с $label без ввода пароля. Настройку можно изменить в профиле.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Не сейчас'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Включить'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final controller = ref.read(authControllerProvider.notifier);
    try {
      if (enable == true) {
        final enabled = await controller.setBiometricEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                enabled
                    ? '$label включён. При следующем запуске пароль не потребуется.'
                    : '$label не включён: подтверждение отменено.',
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Не удалось включить биометрию. Попробуйте в профиле.',
            ),
          ),
        );
      }
    } finally {
      await controller.dismissBiometricOffer();
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = ref.watch(authControllerProvider).valueOrNull?.biometricOffer;
    if (label != null && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(label));
    }
    return widget.child;
  }
}
