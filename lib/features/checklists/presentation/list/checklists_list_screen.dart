import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/checklist_repository_impl.dart';
import '../../domain/checklist_models.dart';

enum ListFilter { all, inWork, done, waiting }

class ChecklistsListScreen extends ConsumerStatefulWidget {
  const ChecklistsListScreen({super.key});

  @override
  ConsumerState<ChecklistsListScreen> createState() => _ChecklistsListScreenState();
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

  @override
  void initState() {
    super.initState();
    Future.microtask(_reload);
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
      final result = await ref.read(checklistRepositoryProvider).list(
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
        _error = error is ApiException ? error.message : 'Не удалось загрузить чек-листы';
      });
    }
  }

  Future<void> _open(ChecklistSummary item) async {
    final ui = UiChecklistStatus.resolve(item, DateTime.now());
    try {
      if (item.status.code == ChecklistStatusCode.draft && ui.actionLabel == 'Взять в работу') {
        await ref.read(checklistRepositoryProvider).takeToWork(item.id);
      }
      if (!mounted) return;
      await context.push('/checklists/${item.id}');
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is ApiException ? error.message : 'Ошибка')),
      );
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
                onProfile: () => context.go('/profile'),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AppTextField(
                  controller: _search,
                  hint: 'Поиск',
                  prefix: const Padding(
                    padding: EdgeInsets.all(12),
                    child: AppIcon(AppIcon.search, size: 24, color: AppColors.textSecondary),
                  ),
                  onChanged: (_) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 400), _reload);
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: _body(),
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
        selectedColor: AppColors.brand,
        backgroundColor: AppColors.surface,
        labelStyle: AppText.bodyH4(
          color: selected ? AppColors.surface : AppColors.text,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide.none,
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
            'Назначенных чек-листов пока нет',
            textAlign: TextAlign.center,
            style: AppText.bodyH4(),
          ),
        ],
      );
    }
    final factor = formFactorOf(context);
    final columns = factor == AppFormFactor.desktop ? 2 : 1;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240 && _hasMore && !_loadingMore) {
          _loadingMore = true;
          _load(page: _page + 1, replace: false);
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 196,
          crossAxisSpacing: 16,
          mainAxisSpacing: 14,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) => _Card(
          item: _items[index],
          onOpen: () => _open(_items[index]),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.onOpen});

  final ChecklistSummary item;
  final VoidCallback onOpen;

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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headlineH5(),
                    ),
                  ),
                  AppTag(label: ui.label, tone: ui.tone),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [item.controlObject?.name, item.template?.name]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyH4(),
              ),
              const Spacer(),
              Text(date, style: AppText.bodyH4()),
              if (ui.actionLabel != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    ui.actionLabel!,
                    style: AppText.bodyH4(color: AppColors.surface),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
