import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/checklist_repository_impl.dart';
import '../../domain/checklist_models.dart';

/// Окно запуска контроля: выбор шаблона чек-листа и объекта контроля,
/// затем вызов `POST /api/v1/checklists/start`.
///
/// Возвращает id созданного чек-листа (для перехода на форму заполнения)
/// либо `null`, если пользователь закрыл окно.
Future<int?> showControlStartSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.overlay,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _ControlStartSheet(),
  );
}

class _ControlStartSheet extends ConsumerStatefulWidget {
  const _ControlStartSheet();

  @override
  ConsumerState<_ControlStartSheet> createState() => _ControlStartSheetState();
}

class _ControlStartSheetState extends ConsumerState<_ControlStartSheet> {
  int _step = 0; // 0 — выбор объекта, 1 — выбор шаблона

  // Данные
  List<TemplateListItem> _templates = const [];
  List<ControlObject> _objects = const [];

  // Выбор
  TemplateListItem? _selectedTemplate;
  ControlObject? _selectedObject;

  // Состояние загрузки
  bool _loading = false;
  bool _starting = false;
  String? _error;

  // Поиск
  final _search = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(checklistRepositoryProvider)
          .listTemplates(query: query);
      if (!mounted) return;
      setState(() {
        _templates = result.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Не удалось загрузить шаблоны';
      });
    }
  }

  Future<void> _loadObjects({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(checklistRepositoryProvider)
          .listControlObjects(query: query);
      if (!mounted) return;
      setState(() {
        _objects = result.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Не удалось загрузить объекты';
      });
    }
  }

  Future<void> _start() async {
    final template = _selectedTemplate;
    final object = _selectedObject;
    if (template == null || object == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(checklistRepositoryProvider)
          .startChecklist(templateId: template.id, controlObjectId: object.id);
      if (!mounted) return;
      Navigator.of(context).pop(created.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = error is ApiException
            ? error.message
            : 'Не удалось создать чек-лист';
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (_step == 1) {
        _loadTemplates(query: value.trim());
      } else {
        _loadObjects(query: value.trim());
      }
    });
  }

  void _next() {
    _searchDebounce?.cancel();
    if (_step == 0 && _selectedObject != null) {
      setState(() {
        _step = 1;
        _search.clear();
      });
      _loadTemplates();
    } else if (_step == 1 && _selectedTemplate != null) {
      _start();
    }
  }

  void _back() {
    _searchDebounce?.cancel();
    if (_step == 1) {
      setState(() {
        _step = 0;
        _search.clear();
        _error = null;
      });
      _loadObjects();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        width: double.infinity,
        height: math.min(620, math.max(0, constraints.maxHeight - bottomInset)),
        margin: EdgeInsets.only(bottom: bottomInset),
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _step == 0 ? 'Объект контроля' : 'Шаблон чек-листа',
                      style: AppText.titleH2(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: _starting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _search,
                hint: 'Поиск',
                prefix: const Padding(
                  padding: EdgeInsets.all(12),
                  child: AppIcon(
                    AppIcon.search,
                    size: 24,
                    color: AppColors.textSecondary,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: math.min(260, constraints.maxHeight * .4),
                child: _list(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: AppText.bodyH5(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_step == 1) ...[
                    Expanded(
                      child: AppButton(
                        label: 'Назад',
                        variant: AppButtonVariant.secondary,
                        onPressed: _starting ? null : _back,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: AppButton(
                      label: _step == 0 ? 'Далее' : 'Начать',
                      loading: _starting,
                      onPressed: _canProceed && !_loading && !_starting
                          ? _next
                          : null,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canProceed =>
      _step == 1 ? _selectedTemplate != null : _selectedObject != null;

  Widget _list() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _step == 1 ? _templates : _objects;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            _step == 1 ? 'Шаблоны не найдены' : 'Объекты не найдены',
            style: AppText.bodyH4(),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (_step == 1) {
          final item = _templates[index];
          return _templateTile(item);
        }
        final item = _objects[index];
        return _objectTile(item);
      },
    );
  }

  Widget _templateTile(TemplateListItem item) {
    final selected = _selectedTemplate?.id == item.id;
    return _SelectableTile(
      selected: selected,
      title: item.name,
      subtitle: item.description,
      onTap: () => setState(() => _selectedTemplate = item),
    );
  }

  Widget _objectTile(ControlObject item) {
    final selected = _selectedObject?.id == item.id;
    final meta = [
      item.address,
      item.phone,
      item.email,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return _SelectableTile(
      selected: selected,
      title: item.name,
      subtitle: meta.isEmpty ? null : meta,
      onTap: () => setState(() => _selectedObject = item),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.surface,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected
                  ? AppColors.brand
                  : AppColors.surfaceMuted,
              child: Icon(
                Icons.fact_check_outlined,
                size: 20,
                color: selected ? AppColors.surface : AppColors.text,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headlineH5(),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyH4(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 24,
              color: selected ? AppColors.brand : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}
