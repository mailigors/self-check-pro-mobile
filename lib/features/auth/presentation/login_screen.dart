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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

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
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Неверно указаны имя пользователя или пароль';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final loading = auth.isLoading;
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
                      'Введите логин и пароль',
                      style: AppText.bodyH4(color: AppColors.text),
                    ),
                    const SizedBox(height: 32),
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
