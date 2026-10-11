import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _securityOpen = false;
  String? _formError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _current.text;
    final next = _next.text;
    final confirm = _confirm.text;
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() => _formError = 'Заполните все поля');
      return;
    }
    if (next != confirm) {
      setState(() => _formError = 'Новый пароль и подтверждение не совпадают');
      return;
    }
    if (next.length < 8) {
      setState(
        () => _formError = 'Новый пароль должен содержать минимум 8 символов',
      );
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: current,
            newPassword: next,
            confirmPassword: confirm,
          );
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Пароль изменён')));
    } catch (error) {
      setState(() {
        _formError = error is ApiException
            ? error.message
            : 'Не удалось изменить пароль';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull?.user;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppPage(
          maxWidth: 640,
          child: Column(
            children: [
              const AppHeader(title: 'Профиль'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: AppColors.brand,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  user?.initials ?? 'U',
                                  style: AppText.titleH2(
                                    color: AppColors.surface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.fullName ?? 'Пользователь',
                                      style: AppText.headlineH5().copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [user?.email, user?.roleName]
                                          .whereType<String>()
                                          .where((v) => v.isNotEmpty)
                                          .join(' · '),
                                      style: AppText.bodyH5(
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.transparent,
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                'Данные профиля',
                                style: AppText.bodyH4(color: AppColors.text),
                              ),
                              children: [
                                _info('Организация', user?.organizationName),
                                _info('Должность', user?.positionName),
                                _info('Роль', user?.roleName),
                                _info(
                                  'Объекты контроля',
                                  user?.controlObjects.isEmpty == true
                                      ? '—'
                                      : user?.controlObjects.join(', '),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.shield_outlined,
                              color: AppColors.brand,
                            ),
                            title: Text(
                              'Безопасность',
                              style: AppText.headlineH5(),
                            ),
                            trailing: Icon(
                              _securityOpen
                                  ? Icons.expand_less
                                  : Icons.chevron_right,
                            ),
                            onTap: () =>
                                setState(() => _securityOpen = !_securityOpen),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.brand,
                            ),
                            title: Text(
                              'О приложении',
                              style: AppText.headlineH5(),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showAboutDialog(
                              context: context,
                              applicationName: 'SelfCheckPro',
                              applicationVersion: '1.0.0',
                              children: [
                                Text(
                                  'Контроль качества · аудиты · чек-листы',
                                  style: AppText.bodyH4(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_securityOpen)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Смена пароля', style: AppText.headlineH5()),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Текущий пароль',
                              controller: _current,
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              label: 'Новый пароль',
                              controller: _next,
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              label: 'Подтверждение',
                              controller: _confirm,
                              obscureText: true,
                              errorText: _formError,
                            ),
                            const SizedBox(height: 20),
                            AppButton(
                              label: 'Изменить пароль',
                              loading: _busy,
                              onPressed: _busy ? null : _changePassword,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Выйти',
                      variant: AppButtonVariant.danger,
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.bodyH4()),
          const SizedBox(height: 4),
          Text(
            (value == null || value.isEmpty) ? '—' : value,
            style: AppText.headlineH5(),
          ),
        ],
      ),
    );
  }
}
