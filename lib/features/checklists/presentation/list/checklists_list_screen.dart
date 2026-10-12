import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/files/downloaded_file_actions.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/checklist_repository_impl.dart';
import '../../domain/checklist_models.dart';
import '../control/control_start_sheet.dart';

enum ListFilter { all, inWork, done, waiting }

class ChecklistsListScreen extends ConsumerStatefulWidget {
  const ChecklistsListScreen({super.key, this.initialFilter = ListFilter.all});
  final ListFilter initialFilter;

  @override
  ConsumerState<ChecklistsListScreen> createState() =>
      _ChecklistsListScreenState();
}

class _ChecklistsListScreenState extends ConsumerState<ChecklistsListScreen> {
  final _search = TextEditingController();
  Timer? _searchDebounce;
  ListFilter _filter = ListFilter.all;
  List<ChecklistSummary> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 0;
  bool _hasMore = false;
  int? _exportingId;
  ChecklistExportFormat? _exportingFormat;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    Future.microtask(_reload);
  }

  @override
  void didUpdateWidget(covariant ChecklistsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      _filter = widget.initialFilter;
      _reload();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  String? get _statusParam => switch (_filter) {
    ListFilter.inWork => 'IN_WORK',
    ListFilter.done => 'COMPLETED',
    ListFilter.waiting => 'DRAFT',
    ListFilter.all => null,
  };

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
    });
    await _load(page: 0, replace: true);
  }

  Future<void> _load({required int page, required bool replace}) async {
    final user = ref.read(authControllerProvider).valueOrNull?.user;
    if (user == null) return;
    try {
      final result = await ref
          .read(checklistRepositoryProvider)
          .list(
            userId: user.id,
            query: _search.text.trim(),
            status: _statusParam,
            page: page,
          );
      if (!mounted) return;
      setState(() {
        _items = replace ? result.items : [..._items, ...result.items];
        _page = result.page;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error is ApiException
            ? error.message
            : 'Не удалось загрузить чек-листы';
      });
    }
  }

  Future<void> _open(ChecklistSummary item) async {
    final ui = UiChecklistStatus.resolve(item, DateTime.now());
    try {
      if (item.status.code == ChecklistStatusCode.draft &&
          ui.actionLabel == 'Взять в работу') {
        await ref.read(checklistRepositoryProvider).takeToWork(item.id);
      }
      if (!mounted) return;
      await context.push('/checklists/${item.id}');
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException ? error.message : 'Ошибка'),
        ),
      );
    }
  }

  Future<void> _startControl() async {
    final newId = await showControlStartSheet(context: context, ref: ref);
    if (newId == null) return;
    if (!mounted) return;
    await context.push('/checklists/$newId');
    _reload();
  }

  Future<void> _export(
    ChecklistSummary item,
    ChecklistExportFormat format,
  ) async {
    if (_exportingId != null) return;
    setState(() {
      _exportingId = item.id;
      _exportingFormat = format;
    });
    try {
      final file = await ref
          .read(checklistRepositoryProvider)
          .export(item.id, format);
      if (!mounted) return;
      await showDownloadedFileActions(
        context: context,
        bytes: file.bytes,
        filename: file.filename,
        mimeType: file.mimeType,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Не удалось подготовить ${format.label}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingId = null;
          _exportingFormat = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppPage(
          child: Column(
            children: [
              AppHeader(
                title: 'Чек-листы',
                action: IconButton.filled(
                  tooltip: 'Новый чек-лист',
                  onPressed: _startControl,
                  style: IconButton.styleFrom(backgroundColor: AppColors.text),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppTextField(
                  controller: _search,
                  hint: 'Поиск по чек-листам',
                  prefix: const Padding(
                    padding: EdgeInsets.all(12),
                    child: AppIcon(
                      AppIcon.search,
                      size: 24,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onChanged: (_) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 400),
                      _reload,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _chip('Все', ListFilter.all),
                    _chip('В работе', ListFilter.inWork),
                    _chip('Завершены', ListFilter.done),
                    _chip('Ожидание', ListFilter.waiting),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(onRefresh: _reload, child: _body()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: AppButton(
                  label: 'Начать контроль',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _startControl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, ListFilter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) {
          setState(() => _filter = value);
          _reload();
        },
        selectedColor: AppColors.text,
        backgroundColor: AppColors.background,
        labelStyle: AppText.bodyH4(
          color: selected ? AppColors.surface : AppColors.text,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: BorderSide(
          color: selected ? AppColors.text : AppColors.borderSubtle,
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Text(_error!, textAlign: TextAlign.center),
          TextButton(onPressed: _reload, child: const Text('Повторить')),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const AppIcon(AppIcon.file, size: 48, color: AppColors.border),
          const SizedBox(height: 12),
          Text(
            _search.text.isNotEmpty || _filter != ListFilter.all
                ? 'Ничего не найдено'
                : 'Назначенных чек-листов пока нет',
            textAlign: TextAlign.center,
            style: AppText.bodyH4(),
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240 &&
            _hasMore &&
            !_loadingMore) {
          _loadingMore = true;
          _load(page: _page + 1, replace: false);
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _Card(
            item: item,
            onOpen: () => _open(item),
            onExportPdf: () => _export(item, ChecklistExportFormat.pdf),
            onExportExcel: () => _export(item, ChecklistExportFormat.excel),
            exportLocked: _exportingId != null,
            exportingFormat: _exportingId == item.id ? _exportingFormat : null,
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.item,
    required this.onOpen,
    required this.onExportPdf,
    required this.onExportExcel,
    required this.exportLocked,
    this.exportingFormat,
  });

  final ChecklistSummary item;
  final VoidCallback onOpen;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;
  final bool exportLocked;
  final ChecklistExportFormat? exportingFormat;

  @override
  Widget build(BuildContext context) {
    final ui = UiChecklistStatus.resolve(item, DateTime.now());
    final start = item.startAt == null
        ? null
        : DateFormat('d MMM, HH:mm', 'ru').format(item.startAt!.toLocal());
    final end = item.endAt == null
        ? null
        : DateFormat('d MMM, HH:mm', 'ru').format(item.endAt!.toLocal());
    final date = [start, end].whereType<String>().join(' — ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            (item.controlObject?.name ?? 'Объект контроля')
                                .toUpperCase(),
                            style: AppText.bodyH5(color: AppColors.text)
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppTag(label: ui.label, tone: ui.tone),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      style: AppText.headlineH5().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (date.isNotEmpty)
                      Text(date, style: AppText.bodyH5(color: AppColors.text)),
                    const SizedBox(height: 6),
                    if (item.controlResult != null)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Оценка  ',
                              style: AppText.bodyH5(color: AppColors.text),
                            ),
                            TextSpan(
                              text: item.formattedControlResult,
                              style: AppText.bodyH4(color: AppColors.brand)
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (ui.actionLabel != null)
                    FilledButton(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.text,
                        foregroundColor: AppColors.surface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        ui.actionLabel!,
                        style: AppText.bodyH5(color: AppColors.surface)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  _ExportButton(
                    label: 'PDF',
                    loading: exportingFormat == ChecklistExportFormat.pdf,
                    onPressed: exportLocked ? null : onExportPdf,
                  ),
                  _ExportButton(
                    label: 'Excel',
                    loading: exportingFormat == ChecklistExportFormat.excel,
                    onPressed: exportLocked ? null : onExportExcel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.label,
    required this.loading,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Tooltip(
      message: 'Экспорт $label',
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 52, minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            label == 'PDF'
                                ? Icons.description_outlined
                                : Icons.grid_on_rounded,
                            size: 16,
                            color: enabled
                                ? AppColors.text
                                : AppColors.placeholder,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: AppText.bodyH5(
                              color: enabled
                                  ? AppColors.text
                                  : AppColors.placeholder,
                            ).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
