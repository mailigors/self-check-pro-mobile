import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  bool get _canSubmit => _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

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
      await ref.read(authControllerProvider.notifier).login(
            _email.text.trim(),
            _password.text,
          );
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
      body: AppPage(
        maxWidth: 480,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  height: 36,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: SafeArea(
                  top: false,
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('Вход', style: AppText.titleH1()),
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        label: 'Логин',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        hint: 'Введите логин',
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Пароль',
                        controller: _password,
                        obscureText: true,
                        hint: 'Введите пароль',
                        errorText: _error,
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Войти',
                        loading: loading,
                        onPressed: loading || !_canSubmit ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
