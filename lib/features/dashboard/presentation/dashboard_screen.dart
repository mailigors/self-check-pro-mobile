import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/dashboard_repository.dart';

String _percent(double? value) =>
    value == null ? '—' : '${NumberFormat('0.#', 'ru').format(value)}%';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.week;
  int? _organization;
  late DashboardQuery _query;

  @override
  void initState() {
    super.initState();
    _query = _period.query(DateTime.now());
  }

  void _select(DashboardPeriod period, int? organization) {
    setState(() {
      _period = period;
      _organization = organization;
      _query = period.query(DateTime.now(), organisationId: organization);
    });
  }

  Future<void> _refresh() async {
    final next = _period.query(DateTime.now(), organisationId: _organization);
    if (next != _query) setState(() => _query = next);
    ref.invalidate(dashboardSummaryProvider(_query));
    ref.invalidate(dashboardDynamicsProvider(_query));
    ref.invalidate(dashboardObjectsProvider(_query));
    ref.invalidate(dashboardAttentionProvider(_query));
    // Each block owns its error state; refreshing still completes on an error.
    await Future.wait([
      ref
          .read(dashboardSummaryProvider(_query).future)
          .then<void>((_) {}, onError: (Object e) {}),
      ref
          .read(dashboardDynamicsProvider(_query).future)
          .then<void>((_) {}, onError: (Object e) {}),
      ref
          .read(dashboardObjectsProvider(_query).future)
          .then<void>((_) {}, onError: (Object e) {}),
      ref
          .read(dashboardAttentionProvider(_query).future)
          .then<void>((_) {}, onError: (Object e) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final system =
        ref
            .watch(authControllerProvider)
            .valueOrNull
            ?.user
            ?.isSystemAdministrator ??
        false;
    final blocked = system && _organization == null;
    final summary = blocked
        ? null
        : ref.watch(dashboardSummaryProvider(_query));
    final dynamics = blocked
        ? null
        : ref.watch(dashboardDynamicsProvider(_query));
    final objects = blocked
        ? null
        : ref.watch(dashboardObjectsProvider(_query));
    final attention = blocked
        ? null
        : ref.watch(dashboardAttentionProvider(_query));
    final start = DateFormat(
      'd MMM',
      'ru',
    ).format(DateTime.parse(_query.fromDate));
    final end = DateFormat('d MMM', 'ru').format(DateTime.parse(_query.toDate));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: blocked
              ? () async {
                  ref.invalidate(dashboardOrganizationsProvider);
                }
              : _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Дашборд', style: AppText.titleH1()),
                          ),
                          IconButton(
                            tooltip: 'Обновить дашборд',
                            onPressed: blocked ? null : _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      Text(
                        '$start — $end · все объекты',
                        style: AppText.bodyH4(),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DashboardPeriod.values
                            .map(
                              (p) => ChoiceChip(
                                label: Text(p.label),
                                selected: _period == p,
                                showCheckmark: false,
                                onSelected: (_) => _select(p, _organization),
                                selectedColor: AppColors.text,
                                labelStyle: TextStyle(
                                  color: _period == p
                                      ? Colors.white
                                      : AppColors.text,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (system) ...[
                        const SizedBox(height: 16),
                        _AsyncBlock(
                          value: ref.watch(dashboardOrganizationsProvider),
                          onRetry: () =>
                              ref.invalidate(dashboardOrganizationsProvider),
                          builder: (items) => DropdownButtonFormField<int>(
                            initialValue: _organization,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Организация',
                            ),
                            hint: const Text('Выберите организацию'),
                            items: items
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text(
                                      e.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (id) => _select(_period, id),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (blocked)
                        const Text(
                          'Выберите организацию для просмотра дашборда.',
                        ),
                      if (!blocked) ...[
                        _AsyncBlock(
                          value: summary!,
                          onRetry: () =>
                              ref.invalidate(dashboardSummaryProvider(_query)),
                          builder: (s) => Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _Metric(
                                      value: '${s.inWork}',
                                      label: 'В работе',
                                      icon: Icons.schedule_rounded,
                                      color: AppColors.warning,
                                      action: 'Открыть список',
                                      onTap: () => context.go(
                                        '/checklists?status=IN_WORK',
                                        extra: DateTime.now()
                                            .microsecondsSinceEpoch,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _Metric(
                                      value: '${s.completed}',
                                      label: 'Завершено',
                                      icon: Icons.task_alt_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _AsyncBlock(
                                      value: dynamics!,
                                      onRetry: () => ref.invalidate(
                                        dashboardDynamicsProvider(_query),
                                      ),
                                      builder: (rows) => _Metric(
                                        value:
                                            '${rows.fold<int>(0, (sum, row) => sum + row.created)}',
                                        label: 'Проверок за период',
                                        icon: Icons.fact_check_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _Metric(
                                      value: _percent(s.score),
                                      label: 'Средняя оценка',
                                      icon: Icons.speed_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'В работе, завершено и средняя оценка — на $end.',
                                style: AppText.bodyH5(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _period == DashboardPeriod.quarter
                                    ? 'Оценки по неделям'
                                    : 'Оценки по дням',
                                style: AppText.titleH2(),
                              ),
                              Text('Норматив 70%', style: AppText.bodyH5()),
                              const SizedBox(height: 16),
                              _AsyncBlock(
                                value: dynamics!,
                                onRetry: () => ref.invalidate(
                                  dashboardDynamicsProvider(_query),
                                ),
                                builder: (rows) => rows.isEmpty
                                    ? const Text('За этот период нет проверок.')
                                    : _ScoreChart(points: rows),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('По объектам', style: AppText.titleH2()),
                              const SizedBox(height: 12),
                              _AsyncBlock(
                                value: objects!,
                                onRetry: () => ref.invalidate(
                                  dashboardObjectsProvider(_query),
                                ),
                                builder: (rows) => rows.isEmpty
                                    ? const Text('Нет данных по объектам.')
                                    : Column(
                                        children: rows
                                            .map(
                                              (o) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            o.name,
                                                            style:
                                                                AppText.headlineH5(),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            'Завершено: ${o.completed}',
                                                            style:
                                                                AppText.bodyH5(),
                                                          ),
                                                          if (o.delta != null)
                                                            Text(
                                                              '${o.delta! > 0 ? '+' : ''}${NumberFormat('0.#', 'ru').format(o.delta)} п.п.',
                                                              style: AppText.bodyH5(
                                                                color:
                                                                    o.delta! >=
                                                                        0
                                                                    ? AppColors
                                                                          .success
                                                                    : AppColors
                                                                          .error,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      _percent(o.score),
                                                      style: AppText.titleH2(
                                                        color: o.score == null
                                                            ? AppColors
                                                                  .textSecondary
                                                            : o.score! >= 70
                                                            ? AppColors.success
                                                            : AppColors.warning,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Требуют внимания',
                                style: AppText.titleH2(),
                              ),
                              Text(
                                'Отклонения по срокам · последние 10',
                                style: AppText.bodyH5(),
                              ),
                              const SizedBox(height: 12),
                              _AsyncBlock(
                                value: attention!,
                                onRetry: () => ref.invalidate(
                                  dashboardAttentionProvider(_query),
                                ),
                                builder: (rows) => rows.isEmpty
                                    ? const Text('Отклонений по срокам нет.')
                                    : Column(
                                        children: rows
                                            .map(
                                              (a) => ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                  a.template,
                                                  style: AppText.headlineH5(),
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      a.object,
                                                      style: AppText.bodyH5(),
                                                    ),
                                                    Text(
                                                      a.reason,
                                                      style: AppText.bodyH5(
                                                        color:
                                                            AppColors.warning,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                trailing: const Icon(
                                                  Icons.chevron_right_rounded,
                                                ),
                                                onTap: () async {
                                                  await context.push(
                                                    '/checklists/${a.id}',
                                                  );
                                                  if (mounted) await _refresh();
                                                },
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AsyncBlock<T> extends StatelessWidget {
  const _AsyncBlock({
    required this.value,
    required this.builder,
    required this.onRetry,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: false,
    data: builder,
    loading: () => const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (error, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          error is ApiException ? error.message : 'Не удалось загрузить данные',
          style: AppText.bodyH4(color: AppColors.error),
        ),
        TextButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(28),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
    this.color = AppColors.brand,
    this.action,
    this.onTap,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(28),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        constraints: const BoxConstraints(minHeight: 152),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color.withValues(alpha: .1),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(value, style: AppText.titleH1()),
            Text(
              label.toUpperCase(),
              style: AppText.bodyH5(color: AppColors.text),
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              Text('$action ›', style: AppText.bodyH5(color: color)),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ScoreChart extends StatelessWidget {
  const _ScoreChart({required this.points});
  final List<DashboardPoint> points;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth / points.length).clamp(
        42.0,
        double.infinity,
      );
      final labelHeight = MediaQuery.textScalerOf(context).scale(12) * 16 / 12;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width * points.length,
          height: 130 + labelHeight * 2,
          child: Stack(
            children: [
              Positioned(
                bottom: labelHeight + 8 + 77,
                left: 0,
                right: 0,
                child: Container(height: 1, color: AppColors.border),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((p) {
                  final date = DateTime.tryParse(p.period);
                  final label = date == null
                      ? p.period
                      : DateFormat('dd.MM').format(date);
                  return SizedBox(
                    width: width,
                    child: Semantics(
                      label: '$label: ${_percent(p.score)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            p.score == null
                                ? '—'
                                : NumberFormat('0.#', 'ru').format(p.score),
                            style: AppText.bodyH5(color: AppColors.text),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 26,
                            height: p.score == null
                                ? 2
                                : (p.score!.clamp(0, 100) * 1.1)
                                      .clamp(2, 110)
                                      .toDouble(),
                            decoration: BoxDecoration(
                              color: p.score == null
                                  ? AppColors.border
                                  : p.score! >= 70
                                  ? AppColors.success
                                  : AppColors.warning,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            style: AppText.bodyH5(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
