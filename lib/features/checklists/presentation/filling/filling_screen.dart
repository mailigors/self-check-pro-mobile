import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_sheet.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../domain/checklist_models.dart';
import 'filling_controller.dart';
import 'item_answer_card.dart';

class FillingScreen extends ConsumerStatefulWidget {
  const FillingScreen({super.key, required this.checklistId});

  final int checklistId;

  @override
  ConsumerState<FillingScreen> createState() => _FillingScreenState();
}

class _FillingScreenState extends ConsumerState<FillingScreen> {
  final _itemKeys = <int, GlobalKey>{};

  GlobalKey _keyFor(int id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  FillingController get _ctrl =>
      ref.read(fillingControllerProvider(widget.checklistId).notifier);

  Future<void> _scrollToErrors(Map<int, String> errors) async {
    if (errors.isEmpty) return;
    final key = _keyFor(errors.keys.first);
    final ctx = key.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.12,
        duration: const Duration(milliseconds: 280),
      );
    }
  }

  Future<void> _handleBack(FillingState? data) async {
    if (data == null || !data.dirty) {
      if (mounted) context.pop();
      return;
    }
    final action = await showAppConfirmSheet(
      context: context,
      title: 'Несохранённые изменения',
      message:
          'Если выйти сейчас, ответы не будут отправлены на сервер. Сохранить перед выходом?',
      cancelLabel: 'Выйти',
      confirmLabel: 'Сохранить',
    );
    if (!mounted) return;
    if (action == true) {
      try {
        await _ctrl.save();
        if (mounted) context.pop();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error is ApiException ? error.message : 'Не удалось сохранить')),
        );
      }
    } else if (action == false) {
      context.pop();
    }
  }

  Future<void> _save() async {
    try {
      final ok = await _ctrl.save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Сохранено' : 'Сохранено с ошибками валидации')),
      );
      final errors = ref.read(fillingControllerProvider(widget.checklistId)).valueOrNull?.errors;
      if (errors != null && errors.isNotEmpty) {
        await _scrollToErrors(errors);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is ApiException ? error.message : 'Не удалось сохранить')),
      );
    }
  }

  Future<void> _complete() async {
    final confirmed = await showAppConfirmSheet(
      context: context,
      title: 'Завершить работу?',
      message:
          'После завершения чек-лист станет недоступен для редактирования. Убедитесь, что все обязательные поля заполнены.',
      cancelLabel: 'Отмена',
      confirmLabel: 'Завершить',
    );
    if (confirmed != true || !mounted) return;
    try {
      final ok = await _ctrl.complete();
      if (!mounted) return;
      if (!ok) {
        final errors =
            ref.read(fillingControllerProvider(widget.checklistId)).valueOrNull?.errors ?? {};
        await _scrollToErrors(errors);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заполните обязательные поля перед завершением')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чек-лист завершён')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is ApiException ? error.message : 'Не удалось завершить')),
      );
    }
  }

  Future<void> _resume() async {
    try {
      await _ctrl.resume();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is ApiException ? error.message : 'Не удалось возобновить')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fillingControllerProvider(widget.checklistId));
    final data = async.valueOrNull;

    return PopScope(
      canPop: data == null || !data.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack(data);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: AppPage(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorBody(
                message: error is ApiException ? error.message : 'Не удалось загрузить чек-лист',
                onRetry: () => ref.invalidate(fillingControllerProvider(widget.checklistId)),
                onBack: () => context.pop(),
              ),
              data: (state) => Column(
                children: [
                  AppHeader(
                    title: state.summary.title,
                    onBack: () => _handleBack(state),
                    onProfile: () => context.go('/profile'),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _Body(checklistId: widget.checklistId, state: state, keyFor: _keyFor)),
                  const SizedBox(height: 8),
                  _Footer(
                    state: state,
                    onSave: _save,
                    onComplete: _complete,
                    onResume: _resume,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.checklistId,
    required this.state,
    required this.keyFor,
  });

  final int checklistId;
  final FillingState state;
  final GlobalKey Function(int id) keyFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(40),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Meta(state: state),
          const SizedBox(height: 16),
          for (final section in state.template.sections) ...[
            _SectionBlock(
              checklistId: checklistId,
              state: state,
              section: section,
              keyFor: keyFor,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.state});

  final FillingState state;

  @override
  Widget build(BuildContext context) {
    final ui = UiChecklistStatus.resolve(state.summary, DateTime.now());
    final meta = [
      state.summary.controlObject?.name,
      state.summary.schedule?.name ?? state.summary.template?.name,
    ].whereType<String>().where((value) => value.isNotEmpty).join('  ·  ');
    final total = state.activeItems.length;
    final answered = state.answeredCount;
    final progress = total == 0 ? 0.0 : answered / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                meta,
                style: AppText.bodyH4(),
              ),
            ),
            AppTag(label: ui.label, tone: ui.tone),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Прогресс заполнения',
              style: AppText.bodyH4(color: AppColors.text).copyWith(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '$answered из $total',
              style: AppText.bodyH4(color: AppColors.brand).copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.borderSubtle,
            color: AppColors.brand,
          ),
        ),
        if (state.dirty) ...[
          const SizedBox(height: 8),
          Text(
            'Есть несохранённые изменения',
            style: AppText.bodyH5(color: AppColors.warning),
          ),
        ],
        if (state.summary.startAt != null || state.summary.endAt != null) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (state.summary.startAt != null)
                DateFormat('d MMM, HH:mm', 'ru').format(state.summary.startAt!.toLocal()),
              if (state.summary.endAt != null)
                DateFormat('d MMM, HH:mm', 'ru').format(state.summary.endAt!.toLocal()),
            ].join(' — '),
            style: AppText.bodyH5(),
          ),
        ],
      ],
    );
  }
}

class _SectionBlock extends ConsumerWidget {
  const _SectionBlock({
    required this.checklistId,
    required this.state,
    required this.section,
    required this.keyFor,
  });

  final int checklistId;
  final FillingState state;
  final TemplateSection section;
  final GlobalKey Function(int id) keyFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = state.expandedSectionIds.contains(section.id);
    final answered = section.items.where((item) {
      final answer = state.answers[item.id];
      return answer != null && !answer.isEmpty;
    }).length;

    return Container(
      width: double.infinity,
      padding: expanded ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: expanded ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                ref.read(fillingControllerProvider(checklistId).notifier).toggleSection(section.id),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  AppIcon(
                    expanded ? AppIcon.chevronUp : AppIcon.chevronDown,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headlineH5(),
                    ),
                  ),
                  Text(
                    '$answered/${section.items.length}',
                    style: AppText.bodyH4(),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            for (final item in section.items) ...[
              KeyedSubtree(
                key: keyFor(item.id),
                child: ItemAnswerCard(
                  checklistId: checklistId,
                  item: item,
                  answer: state.answers[item.id] ?? const ItemAnswer(),
                  error: state.errors[item.id],
                  readOnly: state.readOnly,
                  uploading: state.uploadingItemId == item.id,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.onSave,
    required this.onComplete,
    required this.onResume,
  });

  final FillingState state;
  final VoidCallback onSave;
  final VoidCallback onComplete;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          if (!state.readOnly)
            Expanded(
              child: AppButton(
                label: 'Сохранить',
                variant: AppButtonVariant.secondary,
                loading: state.busy,
                onPressed: state.busy ? null : onSave,
              ),
            ),
          if (!state.readOnly) const SizedBox(width: 16),
          Expanded(
            child: AppButton(
              label: state.readOnly ? 'Возобновить' : 'Завершить',
              loading: state.busy,
              onPressed: state.busy ? null : (state.readOnly ? onResume : onComplete),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry, required this.onBack});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(label: 'Повторить', onPressed: onRetry),
            const SizedBox(height: 12),
            AppButton(
              label: 'Назад',
              variant: AppButtonVariant.secondary,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}
