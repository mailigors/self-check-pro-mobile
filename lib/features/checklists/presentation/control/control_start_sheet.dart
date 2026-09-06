import 'dart:async';

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
  int _step = 0; // 0 — выбор шаблона, 1 — выбор объекта

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
    _loadTemplates();
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
      final result = await ref.read(checklistRepositoryProvider).listTemplates(query: query);
      if (!mounted) return;
      setState(() {
        _templates = result.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : 'Не удалось загрузить шаблоны';
      });
    }
  }

  Future<void> _loadObjects({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(checklistRepositoryProvider).listControlObjects(query: query);
      if (!mounted) return;
      setState(() {
        _objects = result.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : 'Не удалось загрузить объекты';
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
      final created = await ref.read(checklistRepositoryProvider).startChecklist(
            templateId: template.id,
            controlObjectId: object.id,
          );
      if (!mounted) return;
      Navigator.of(context).pop(created.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = error is ApiException ? error.message : 'Не удалось создать чек-лист';
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (_step == 0) {
        _loadTemplates(query: value.trim());
      } else {
        _loadObjects(query: value.trim());
      }
    });
  }

  void _next() {
    if (_step == 0 && _selectedTemplate != null) {
      setState(() {
        _step = 1;
        _search.clear();
      });
      _loadObjects();
    } else if (_step == 1 && _selectedObject != null) {
      _start();
    }
  }

  void _back() {
    if (_step == 1) {
      setState(() {
        _step = 0;
        _search.clear();
        _selectedObject = null;
        _error = null;
      });
      _loadTemplates();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: bottomInset),
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
            Row(
              children: [
                GestureDetector(
                  onTap: _back,
                  behavior: HitTestBehavior.opaque,
                  child: const AppIcon(AppIcon.back, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _step == 0 ? 'Шаблон чек-листа' : 'Объект контроля',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleH2(),
                  ),
                ),
                const SizedBox(width: 24),
                const SizedBox(width: 24),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _search,
              hint: 'Поиск',
              prefix: const Padding(
                padding: EdgeInsets.all(12),
                child: AppIcon(AppIcon.search, size: 24, color: AppColors.textSecondary),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: _list(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppText.bodyH5(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: _step == 0 ? 'Далее' : 'Начать',
              loading: _starting,
              onPressed: _canProceed ? _next : null,
            ),
          ],
        ),
      ),
    );
  }

  bool get _canProceed => _step == 0 ? _selectedTemplate != null : _selectedObject != null;

  Widget _list() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _step == 0 ? _templates : _objects;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            _step == 0 ? 'Шаблоны не найдены' : 'Объекты не найдены',
            style: AppText.bodyH4(),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderSubtle),
      itemBuilder: (context, index) {
        if (_step == 0) {
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
    final meta = [item.address, item.phone, item.email]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' · ');
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyH3(),
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
            if (selected)
              const Icon(Icons.check_circle, size: 24, color: AppColors.brand),
          ],
        ),
      ),
    );
  }
}
