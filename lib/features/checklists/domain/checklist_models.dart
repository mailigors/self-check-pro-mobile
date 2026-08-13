import '../../../core/utils/json_helpers.dart';
import '../../../core/widgets/app_tag.dart';

class NamedEntity {
  const NamedEntity({this.id, required this.name});

  final int? id;
  final String name;

  factory NamedEntity.fromJson(dynamic raw) {
    final json = asMap(raw);
    return NamedEntity(
      id: asInt(json['id']),
      name: asString(json['name']) ?? '',
    );
  }
}

enum ChecklistStatusCode { draft, inWork, completed, unknown }

class ChecklistStatusInfo {
  const ChecklistStatusInfo({
    required this.code,
    this.description,
    this.descriptionEn,
  });

  final ChecklistStatusCode code;
  final String? description;
  final String? descriptionEn;

  factory ChecklistStatusInfo.fromJson(dynamic raw) {
    final json = asMap(raw);
    final value = (asString(json['code']) ?? '').toUpperCase();
    final code = switch (value) {
      'DRAFT' => ChecklistStatusCode.draft,
      'IN_WORK' => ChecklistStatusCode.inWork,
      'COMPLETED' => ChecklistStatusCode.completed,
      _ => ChecklistStatusCode.unknown,
    };
    return ChecklistStatusInfo(
      code: code,
      description: asString(json['description']),
      descriptionEn: asString(json['descriptionEn']),
    );
  }
}

class ChecklistSummary {
  const ChecklistSummary({
    required this.id,
    this.schedule,
    this.template,
    this.controlObject,
    this.user,
    required this.status,
    this.startAt,
    this.endAt,
  });

  final int id;
  final NamedEntity? schedule;
  final NamedEntity? template;
  final NamedEntity? controlObject;
  final NamedEntity? user;
  final ChecklistStatusInfo status;
  final DateTime? startAt;
  final DateTime? endAt;

  String get title =>
      schedule?.name.isNotEmpty == true ? schedule!.name : (template?.name ?? 'Чек-лист');

  factory ChecklistSummary.fromJson(Map<String, dynamic> json) {
    return ChecklistSummary(
      id: asInt(json['id']) ?? 0,
      schedule: json['inspectionSchedule'] == null
          ? null
          : NamedEntity.fromJson(json['inspectionSchedule']),
      template: json['template'] == null ? null : NamedEntity.fromJson(json['template']),
      controlObject:
          json['controlObject'] == null ? null : NamedEntity.fromJson(json['controlObject']),
      user: json['user'] == null ? null : NamedEntity.fromJson(json['user']),
      status: ChecklistStatusInfo.fromJson(json['status']),
      startAt: DateTime.tryParse(asString(json['start_at']) ?? ''),
      endAt: DateTime.tryParse(asString(json['end_at']) ?? ''),
    );
  }
}

class UiChecklistStatus {
  const UiChecklistStatus({
    required this.label,
    required this.tone,
    required this.actionLabel,
  });

  final String label;
  final AppTagTone tone;
  final String? actionLabel;

  static UiChecklistStatus resolve(ChecklistSummary item, DateTime now) {
    switch (item.status.code) {
      case ChecklistStatusCode.inWork:
        return const UiChecklistStatus(
          label: 'В работе',
          tone: AppTagTone.success,
          actionLabel: 'Продолжить',
        );
      case ChecklistStatusCode.completed:
        return const UiChecklistStatus(
          label: 'Завершен',
          tone: AppTagTone.draft,
          actionLabel: 'Возобновить',
        );
      case ChecklistStatusCode.draft:
        final waiting = item.startAt != null && item.startAt!.isAfter(now);
        return UiChecklistStatus(
          label: waiting ? 'Ожидание' : 'В работу',
          tone: waiting ? AppTagTone.warning : AppTagTone.brand,
          actionLabel: waiting ? null : 'Взять в работу',
        );
      case ChecklistStatusCode.unknown:
        return UiChecklistStatus(
          label: item.status.description ?? 'Статус',
          tone: AppTagTone.draft,
          actionLabel: 'Открыть',
        );
    }
  }
}

class AttachmentRef {
  const AttachmentRef({required this.attachmentId, this.filename, this.contentType});

  final int attachmentId;
  final String? filename;
  final String? contentType;

  factory AttachmentRef.fromJson(dynamic raw) {
    if (raw is num) {
      return AttachmentRef(attachmentId: raw.toInt());
    }
    final json = asMap(raw);
    return AttachmentRef(
      attachmentId: asInt(pick(json, ['attachmentId', 'id'])) ?? 0,
      filename: asString(json['filename']),
      contentType: asString(json['contentType']),
    );
  }

  Map<String, dynamic> toPayload() => {'attachmentId': attachmentId};
}

class ItemSettings {
  const ItemSettings({
    this.placeholder,
    this.minLength,
    this.maxLength,
    this.minValue,
    this.maxValue,
    this.unit,
    this.precision,
    this.min,
    this.max,
    this.step,
    this.labelStart,
    this.labelEnd,
    this.options = const [],
    this.uiHint,
    this.minSelections,
    this.maxSelections,
    this.minDate,
    this.maxDate,
    this.minDatetime,
    this.maxDatetime,
  });

  final String? placeholder;
  final int? minLength;
  final int? maxLength;
  final num? minValue;
  final num? maxValue;
  final String? unit;
  final int? precision;
  final int? min;
  final int? max;
  final int? step;
  final String? labelStart;
  final String? labelEnd;
  final List<String> options;
  final String? uiHint;
  final int? minSelections;
  final int? maxSelections;
  final String? minDate;
  final String? maxDate;
  final String? minDatetime;
  final String? maxDatetime;

  factory ItemSettings.fromJson(dynamic raw) {
    final json = asMap(raw);
    final optionsRaw = asList(pick(json, ['options']));
    final options = optionsRaw.map((item) {
      if (item is String) return item;
      final map = asMap(item);
      return asString(pick(map, ['label', 'name', 'value'])) ?? '$item';
    }).toList();
    return ItemSettings(
      placeholder: asString(json['placeholder']),
      minLength: asInt(json['min_length']),
      maxLength: asInt(json['max_length']),
      minValue: asDouble(json['min_value']),
      maxValue: asDouble(json['max_value']),
      unit: asString(json['unit']),
      precision: asInt(json['precision']),
      min: asInt(json['min']),
      max: asInt(json['max']),
      step: asInt(json['step']),
      labelStart: asString(json['label_start']),
      labelEnd: asString(json['label_end']),
      options: options,
      uiHint: asString(json['ui_hint']),
      minSelections: asInt(json['min_selections']),
      maxSelections: asInt(json['max_selections']),
      minDate: asString(json['min_date']),
      maxDate: asString(json['max_date']),
      minDatetime: asString(json['min_datetime']),
      maxDatetime: asString(json['max_datetime']),
    );
  }
}

class TemplateItem {
  const TemplateItem({
    required this.id,
    required this.name,
    this.description,
    required this.questionType,
    required this.settings,
    this.required = false,
    this.photoRequired = false,
    this.videoRequired = false,
    this.active = true,
    this.order = 0,
  });

  final int id;
  final String name;
  final String? description;
  final String questionType;
  final ItemSettings settings;
  final bool required;
  final bool photoRequired;
  final bool videoRequired;
  final bool active;
  final int order;

  factory TemplateItem.fromJson(Map<String, dynamic> json) {
    return TemplateItem(
      id: asInt(json['id']) ?? 0,
      name: asString(json['name']) ?? '',
      description: asString(json['description']),
      questionType: (asString(json['question_type']) ?? 'text').toLowerCase(),
      settings: ItemSettings.fromJson(json['settings']),
      required: asBool(json['required']) ?? false,
      photoRequired: asBool(json['photo_required']) ?? false,
      videoRequired: asBool(json['video_required']) ?? false,
      active: asBool(json['active']) ?? true,
      order: asInt(json['order']) ?? 0,
    );
  }
}

class TemplateSection {
  const TemplateSection({
    required this.id,
    required this.name,
    this.description,
    this.active = true,
    this.order = 0,
    this.items = const [],
  });

  final int id;
  final String name;
  final String? description;
  final bool active;
  final int order;
  final List<TemplateItem> items;

  factory TemplateSection.fromJson(Map<String, dynamic> json) {
    final items = asList(json['items'])
        .map((item) => TemplateItem.fromJson(asMap(item)))
        .where((item) => item.active)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return TemplateSection(
      id: asInt(json['id']) ?? 0,
      name: asString(json['name']) ?? '',
      description: asString(json['description']),
      active: asBool(json['active']) ?? true,
      order: asInt(json['order']) ?? 0,
      items: items,
    );
  }
}

class ChecklistTemplate {
  const ChecklistTemplate({
    required this.id,
    required this.name,
    this.sections = const [],
  });

  final int id;
  final String name;
  final List<TemplateSection> sections;

  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) {
    final sections = asList(json['sections'])
        .map((item) => TemplateSection.fromJson(asMap(item)))
        .where((section) => section.active)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return ChecklistTemplate(
      id: asInt(json['id']) ?? 0,
      name: asString(json['name']) ?? '',
      sections: sections,
    );
  }
}

class ItemAnswer {
  const ItemAnswer({
    this.id,
    this.value,
    this.photoIds = const [],
    this.videoIds = const [],
    this.otherIds = const [],
  });

  final int? id;
  final dynamic value;
  final List<AttachmentRef> photoIds;
  final List<AttachmentRef> videoIds;
  final List<AttachmentRef> otherIds;

  bool get isEmpty {
    final hasValue = switch (value) {
      null => false,
      String text => text.trim().isNotEmpty,
      List list => list.isNotEmpty,
      _ => true,
    };
    return !hasValue && photoIds.isEmpty && videoIds.isEmpty && otherIds.isEmpty;
  }

  ItemAnswer copyWith({
    int? id,
    dynamic value,
    bool clearValue = false,
    List<AttachmentRef>? photoIds,
    List<AttachmentRef>? videoIds,
    List<AttachmentRef>? otherIds,
  }) {
    return ItemAnswer(
      id: id ?? this.id,
      value: clearValue ? null : (value ?? this.value),
      photoIds: photoIds ?? this.photoIds,
      videoIds: videoIds ?? this.videoIds,
      otherIds: otherIds ?? this.otherIds,
    );
  }

  factory ItemAnswer.fromJson(Map<String, dynamic> json) {
    List<AttachmentRef> parseFiles(dynamic raw) =>
        asList(raw).map(AttachmentRef.fromJson).where((item) => item.attachmentId != 0).toList();
    return ItemAnswer(
      id: asInt(json['id']),
      value: json['answer'],
      photoIds: parseFiles(json['photo_ids']),
      videoIds: parseFiles(json['video_ids']),
      otherIds: parseFiles(json['other_ids']),
    );
  }
}

class AnswerValidationError {
  const AnswerValidationError({
    required this.itemId,
    this.itemName,
    required this.errors,
  });

  final int itemId;
  final String? itemName;
  final List<String> errors;

  factory AnswerValidationError.fromJson(Map<String, dynamic> json) {
    return AnswerValidationError(
      itemId: asInt(pick(json, ['itemId', 'item_id'])) ?? 0,
      itemName: asString(json['itemName']),
      errors: asList(json['errors']).map((item) => '$item').toList(),
    );
  }
}

class ChecklistDetail {
  const ChecklistDetail({
    required this.summary,
    this.answers = const {},
    this.validationErrors = const [],
  });

  final ChecklistSummary summary;
  final Map<int, ItemAnswer> answers;
  final List<AnswerValidationError> validationErrors;

  factory ChecklistDetail.fromJson(Map<String, dynamic> json) {
    final answers = <int, ItemAnswer>{};
    for (final raw in asList(json['answers'])) {
      final map = asMap(raw);
      final itemId = asInt(map['item_id']);
      if (itemId == null) continue;
      answers[itemId] = ItemAnswer.fromJson(map);
    }
    return ChecklistDetail(
      summary: ChecklistSummary.fromJson(json),
      answers: answers,
      validationErrors: asList(json['answerValidationErrors'])
          .map((item) => AnswerValidationError.fromJson(asMap(item)))
          .toList(),
    );
  }
}

class PagedChecklists {
  const PagedChecklists({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<ChecklistSummary> items;
  final int page;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;

  factory PagedChecklists.fromJson(Map<String, dynamic> json) {
    return PagedChecklists(
      items: asList(json['content']).map((item) => ChecklistSummary.fromJson(asMap(item))).toList(),
      page: asInt(json['number']) ?? 0,
      totalPages: asInt(json['totalPages']) ?? 1,
    );
  }
}
