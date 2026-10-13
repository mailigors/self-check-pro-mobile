import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_brand.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'auth_controller.dart';
import '../../../core/security/biometric_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _automaticAttempted = false;
  bool _showPassword = false;
  bool _biometricBusy = false;

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _error = null);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_email.text.trim(), _password.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Неверно указаны имя пользователя или пароль';
      });
    }
  }

  Future<void> _biometricLogin() async {
    if (_biometricBusy) return;
    setState(() {
      _error = null;
      _biometricBusy = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).loginWithBiometrics();
      if (mounted &&
          ref.read(authControllerProvider).valueOrNull?.isAuthenticated !=
              true) {
        setState(() => _showPassword = true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        // A server/network error after successful biometrics should allow a
        // retry without asking for the password again.
        _showPassword =
            error is ApiException &&
            (error.statusCode == 401 ||
                !error.offline && error.statusCode == null);
        _error = error is ApiException
            ? error.message
            : 'Не удалось войти. Попробуйте ещё раз или используйте пароль.';
      });
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final loading = auth.isLoading || _biometricBusy;
    final biometricLogin = auth.valueOrNull?.biometricLogin == true;
    final showPassword =
        auth.valueOrNull?.isAuthenticated != true &&
        (_showPassword ||
            (!auth.isLoading && !biometricLogin && !_biometricBusy));
    if (biometricLogin && !loading && !_automaticAttempted) {
      _automaticAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _biometricLogin();
      });
    }
    final biometricLabel = biometricLogin
        ? ref.watch(biometricSettingsProvider).valueOrNull?.label
        : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppPage(
          maxWidth: 480,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 56, 28, 24),
            children: [
              const AppBrand(),
              const SizedBox(height: 44),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Вход', style: AppText.titleH1()),
                    const SizedBox(height: 6),
                    Text(
                      biometricLogin || _biometricBusy
                          ? 'Подтвердите вход с Face ID'
                          : 'Введите логин и пароль',
                      style: AppText.bodyH4(color: AppColors.text),
                    ),
                    const SizedBox(height: 32),
                    if (biometricLogin || _biometricBusy) ...[
                      AppButton(
                        label:
                            'Войти с ${biometricLabel ?? 'Face ID / Touch ID'}',
                        icon: Icons.face_rounded,
                        loading: _biometricBusy,
                        onPressed: loading ? null : _biometricLogin,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null && !showPassword)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _error!,
                            style: AppText.bodyH4(color: AppColors.error),
                          ),
                        ),
                      if (!showPassword)
                        TextButton(
                          onPressed: loading
                              ? null
                              : () => setState(() => _showPassword = true),
                          child: const Text('Войти по паролю'),
                        ),
                    ],
                    if (showPassword) ...[
                      AppTextField(
                        label: 'ЛОГИН',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        fillColor: AppColors.background,
                        hint: 'Введите логин',
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        label: 'ПАРОЛЬ',
                        controller: _password,
                        obscureText: true,
                        hint: 'Введите пароль',
                        fillColor: AppColors.background,
                        errorText: _error,
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Войти',
                        icon: Icons.arrow_forward_rounded,
                        loading: loading,
                        onPressed: loading || !_canSubmit ? null : _submit,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Данные защищены',
                textAlign: TextAlign.center,
                style: AppText.bodyH5(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
