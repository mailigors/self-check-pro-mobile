import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/checklist_repository_impl.dart';
import '../../domain/checklist_models.dart';

class FillingState {
  const FillingState({
    required this.detail,
    required this.template,
    required this.answers,
    this.expandedSectionIds = const {},
    this.errors = const {},
    this.dirty = false,
    this.busy = false,
    this.uploadingItemId,
  });

  final ChecklistDetail detail;
  final ChecklistTemplate template;
  final Map<int, ItemAnswer> answers;
  final Set<int> expandedSectionIds;
  final Map<int, String> errors;
  final bool dirty;
  final bool busy;
  final int? uploadingItemId;

  ChecklistSummary get summary => detail.summary;
  bool get readOnly => summary.status.code == ChecklistStatusCode.completed;

  List<TemplateItem> get activeItems => [
        for (final section in template.sections)
          if (section.active) ...section.items.where((item) => item.active),
      ];

  int get answeredCount => activeItems.where((item) {
        final answer = answers[item.id];
        return answer != null && !answer.isEmpty;
      }).length;

  FillingState copyWith({
    ChecklistDetail? detail,
    ChecklistTemplate? template,
    Map<int, ItemAnswer>? answers,
    Set<int>? expandedSectionIds,
    Map<int, String>? errors,
    bool? dirty,
    bool? busy,
    int? uploadingItemId,
    bool clearUpload = false,
  }) {
    return FillingState(
      detail: detail ?? this.detail,
      template: template ?? this.template,
      answers: answers ?? this.answers,
      expandedSectionIds: expandedSectionIds ?? this.expandedSectionIds,
      errors: errors ?? this.errors,
      dirty: dirty ?? this.dirty,
      busy: busy ?? this.busy,
      uploadingItemId: clearUpload ? null : uploadingItemId ?? this.uploadingItemId,
    );
  }
}

class FillingController extends AutoDisposeFamilyAsyncNotifier<FillingState, int> {
  @override
  Future<FillingState> build(int arg) async {
    final repo = ref.read(checklistRepositoryProvider);
    final detail = await repo.getById(arg);
    final templateId = detail.summary.template?.id;
    if (templateId == null) {
      throw Exception('У чек-листа нет шаблона');
    }
    final template = await repo.getTemplate(templateId);
    final expanded = template.sections.isEmpty
        ? <int>{}
        : {template.sections.first.id};
    return FillingState(
      detail: detail,
      template: template,
      answers: Map.of(detail.answers),
      expandedSectionIds: expanded,
      errors: {
        for (final error in detail.validationErrors)
          if (error.errors.isNotEmpty) error.itemId: error.errors.first,
      },
    );
  }

  FillingState get _require => state.valueOrNull!;

  void toggleSection(int id) {
    final current = _require;
    final next = {...current.expandedSectionIds};
    if (!next.add(id)) next.remove(id);
    state = AsyncData(current.copyWith(expandedSectionIds: next));
  }

  void setAnswer(int itemId, dynamic value, {bool clear = false}) {
    final current = _require;
    if (current.readOnly) return;
    final prev = current.answers[itemId] ?? const ItemAnswer();
    final answers = Map<int, ItemAnswer>.from(current.answers)
      ..[itemId] = prev.copyWith(value: value, clearValue: clear);
    final errors = Map<int, String>.from(current.errors)..remove(itemId);
    state = AsyncData(current.copyWith(answers: answers, errors: errors, dirty: true));
  }

  void expandSectionsForItems(Iterable<int> itemIds) {
    final current = _require;
    final next = {...current.expandedSectionIds};
    for (final section in current.template.sections) {
      if (section.items.any((item) => itemIds.contains(item.id))) {
        next.add(section.id);
      }
    }
    state = AsyncData(current.copyWith(expandedSectionIds: next));
  }

  Future<void> addAttachment({
    required TemplateItem item,
    required String filename,
    required List<int> bytes,
    required String contentType,
    required String kind,
  }) async {
    final current = _require;
    if (current.readOnly) return;
    if (bytes.length > ApiConfig.maxUploadBytes) {
      throw const ApiException(message: 'Файл слишком большой', statusCode: 413);
    }
    state = AsyncData(current.copyWith(busy: true, uploadingItemId: item.id));
    try {
      final uploaded = await ref.read(checklistRepositoryProvider).upload(
            filename: filename,
            bytes: bytes,
            contentType: contentType,
          );
      final latest = _require;
      final prev = latest.answers[item.id] ?? const ItemAnswer();
      final next = switch (kind) {
        'photo' => prev.copyWith(photoIds: [...prev.photoIds, uploaded]),
        'video' => prev.copyWith(videoIds: [...prev.videoIds, uploaded]),
        _ => prev.copyWith(otherIds: [...prev.otherIds, uploaded]),
      };
      final answers = Map<int, ItemAnswer>.from(latest.answers)..[item.id] = next;
      state = AsyncData(
        latest.copyWith(answers: answers, dirty: true, busy: false, clearUpload: true),
      );
    } catch (error, stack) {
      state = AsyncData(_require.copyWith(busy: false, clearUpload: true));
      Error.throwWithStackTrace(error, stack);
    }
  }

  void removeAttachment(int itemId, int attachmentId) {
    final current = _require;
    if (current.readOnly) return;
    final prev = current.answers[itemId] ?? const ItemAnswer();
    final answers = Map<int, ItemAnswer>.from(current.answers)
      ..[itemId] = prev.copyWith(
        photoIds: prev.photoIds.where((e) => e.attachmentId != attachmentId).toList(),
        videoIds: prev.videoIds.where((e) => e.attachmentId != attachmentId).toList(),
        otherIds: prev.otherIds.where((e) => e.attachmentId != attachmentId).toList(),
      );
    state = AsyncData(current.copyWith(answers: answers, dirty: true));
  }

  Map<int, String> _clientValidate(FillingState current) {
    final errors = <int, String>{};
    for (final item in current.activeItems) {
      final answer = current.answers[item.id];
      if (item.required && (answer == null || answer.isEmpty)) {
        errors[item.id] = 'Обязательный вопрос';
      }
      if (item.photoRequired && (answer?.photoIds.isEmpty ?? true)) {
        errors[item.id] = 'Требуется фото';
      }
      if (item.videoRequired && (answer?.videoIds.isEmpty ?? true)) {
        errors[item.id] = 'Требуется видео';
      }
      if (['number', 'numeric', 'double'].contains(item.questionType)) {
        final raw = answer?.value;
        if (raw == null) continue;
        final number = raw is num ? raw : num.tryParse('$raw'.replaceAll(',', '.'));
        if (number != null) {
          if (item.settings.minValue != null && number < item.settings.minValue!) {
            errors[item.id] = 'Значение меньше минимума';
          }
          if (item.settings.maxValue != null && number > item.settings.maxValue!) {
            errors[item.id] = 'Значение больше максимума';
          }
        }
      }
    }
    return errors;
  }

  Future<bool> save() async {
    final current = _require;
    state = AsyncData(current.copyWith(busy: true));
    try {
      final saved = await ref.read(checklistRepositoryProvider).save(
            checklistId: current.summary.id,
            controlObjectId: current.summary.controlObject?.id,
            startAt: current.summary.startAt,
            endAt: current.summary.endAt,
            items: current.activeItems,
            answers: current.answers,
          );
      final errors = {
        for (final error in saved.validationErrors)
          if (error.errors.isNotEmpty) error.itemId: error.errors.first,
      };
      state = AsyncData(
        current.copyWith(
          detail: saved,
          answers: saved.answers.isEmpty ? current.answers : saved.answers,
          errors: errors,
          dirty: false,
          busy: false,
        ),
      );
      return errors.isEmpty;
    } catch (error, stack) {
      state = AsyncData(_require.copyWith(busy: false));
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<bool> complete() async {
    final current = _require;
    final clientErrors = _clientValidate(current);
    if (clientErrors.isNotEmpty) {
      expandSectionsForItems(clientErrors.keys);
      state = AsyncData(_require.copyWith(errors: clientErrors));
      return false;
    }
    await save();
    final afterSave = _require;
    if (afterSave.errors.isNotEmpty) {
      expandSectionsForItems(afterSave.errors.keys);
      return false;
    }
    state = AsyncData(afterSave.copyWith(busy: true));
    try {
      final completed = await ref.read(checklistRepositoryProvider).complete(afterSave.summary.id);
      state = AsyncData(
        afterSave.copyWith(
          detail: completed,
          answers: completed.answers.isEmpty ? afterSave.answers : completed.answers,
          dirty: false,
          busy: false,
        ),
      );
      return true;
    } on ApiException catch (error, stack) {
      state = AsyncData(_require.copyWith(busy: false));
      if (error.statusCode == 400) {
        throw const ApiException(
          message:
              'Заполненный лист имеет ошибки, перед отправкой необходимо заполнить все данные',
          statusCode: 400,
        );
      }
      Error.throwWithStackTrace(error, stack);
    } catch (error, stack) {
      state = AsyncData(_require.copyWith(busy: false));
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> resume() async {
    final current = _require;
    await ref.read(checklistRepositoryProvider).takeToWork(current.summary.id);
    ref.invalidateSelf();
  }
}

final fillingControllerProvider = AsyncNotifierProvider.autoDispose
    .family<FillingController, FillingState, int>(FillingController.new);
