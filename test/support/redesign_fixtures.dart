import 'demo_export_files.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:checklist_flutter/features/auth/domain/user_profile.dart';
import 'package:checklist_flutter/features/auth/presentation/auth_controller.dart';
import 'package:checklist_flutter/features/checklists/domain/checklist_models.dart';
import 'package:checklist_flutter/features/checklists/domain/checklist_repository.dart';

class PreviewAuthController extends AuthController {
  PreviewAuthController({this.authenticated = true});
  final bool authenticated;
  static const user = UserProfile(
    id: 1,
    email: 'inspector@example.com',
    fullName: 'Аудитор Групп',
    roleName: 'Аудитор',
    organizationName: 'ФР Пхали-Хинкали',
    controlObjects: ['ФР Пхали-Хинкали'],
  );
  @override
  Future<AuthState> build() async =>
      AuthState(user: authenticated ? user : null);
  @override
  Future<void> login(String email, String password) async {
    state = const AsyncData(AuthState(user: user));
  }

  @override
  Future<void> logout() async {
    state = const AsyncData(AuthState());
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {}
}

class PreviewChecklistRepository implements ChecklistRepository {
  final answers = <int, ItemAnswer>{};
  final _completedIds = <int>{2};
  final _savedAnswers = <int, Map<int, ItemAnswer>>{};
  final _created =
      <int, ({String templateName, int objectId, String objectName})>{};
  int _nextId = 3;
  int? startedObject;
  int? startedTemplate;
  int saves = 0;
  int completions = 0;
  String objectName = 'ФР Пхали-Хинкали';
  String templateName = 'АТО — Оценка качества блюд ТБИЛИСИ';
  static const templates = [
    TemplateListItem(
      id: 1,
      name: 'АТО — Оценка качества блюд ТБИЛИСИ',
      description: 'Контроль качества блюд',
    ),
    TemplateListItem(
      id: 2,
      name: 'СанПиН: санитарно-эпидемиологический чек-лист',
      description: 'Плановая проверка',
    ),
    TemplateListItem(
      id: 3,
      name: 'Аудит_Кухня_Версия_5.3',
      description: 'Аудит кухни',
    ),
  ];
  static const objects = [
    ControlObject(id: 1, name: 'ФР Хачо и Пури'),
    ControlObject(id: 2, name: 'ФР Пхали-Хинкали'),
    ControlObject(id: 3, name: 'ФР Регионы'),
  ];
  ChecklistSummary summary(int id) => ChecklistSummary(
    id: id,
    template: NamedEntity(
      id: 1,
      name:
          _created[id]?.templateName ??
          (id == 2 ? 'Аудит_Кухня_Версия_5.3' : templates.first.name),
    ),
    controlObject: NamedEntity(
      id: _created[id]?.objectId ?? 2,
      name: _created[id]?.objectName ?? 'ФР Пхали-Хинкали',
    ),
    status: ChecklistStatusInfo(
      code: _completedIds.contains(id)
          ? ChecklistStatusCode.completed
          : ChecklistStatusCode.inWork,
    ),
    startAt: DateTime(2026, 9, 8, 9, 14),
    endAt: DateTime(2026, 9, 10, 9, 14),
    controlResult: _completedIds.contains(id) ? 88 : null,
  );
  @override
  Future<PagedChecklists> list({
    required int userId,
    String? query,
    String? status,
    String? createdFrom,
    String? createdTo,
    int page = 0,
  }) async => PagedChecklists(
    items: [summary(1), summary(2), ..._created.keys.map(summary)]
        .where(
          (s) =>
              (query == null ||
                  s.title.toLowerCase().contains(query.toLowerCase())) &&
              (status == null ||
                  status ==
                      (s.status.code == ChecklistStatusCode.completed
                          ? 'COMPLETED'
                          : 'IN_WORK')),
        )
        .toList(),
    page: 0,
    totalPages: 1,
  );
  @override
  Future<ChecklistDetail> getById(int id) async => ChecklistDetail(
    summary: summary(id),
    answers: Map.of(_savedAnswers[id] ?? const <int, ItemAnswer>{}),
  );
  @override
  Future<ChecklistTemplate> getTemplate(int templateId) async =>
      ChecklistTemplate(
        id: 1,
        name: templateName,
        sections: const [
          TemplateSection(
            id: 1,
            name: 'Блюдо 1',
            items: [
              TemplateItem(
                id: 1,
                name: 'Внешний вид соответствует стандарту',
                settings: ItemSettings(),
                questionType: 'boolean',
                required: true,
                description:
                    'Сверьтесь с эталонным фото из технологической карты',
              ),
              TemplateItem(
                id: 2,
                name: 'Общий выход соответствует стандарту',
                settings: ItemSettings(),
                questionType: 'boolean',
              ),
              TemplateItem(
                id: 3,
                name: 'Температура внутри блюда',
                questionType: 'number',
                settings: ItemSettings(unit: '°C', minValue: 65, maxValue: 95),
              ),
              TemplateItem(
                id: 4,
                name: 'Вес порции',
                questionType: 'number',
                settings: ItemSettings(unit: 'г'),
              ),
              TemplateItem(
                id: 5,
                name: 'Оцените чистоту рабочей зоны',
                questionType: 'slider',
                settings: ItemSettings(min: 0, max: 10),
              ),
            ],
          ),
          TemplateSection(
            id: 2,
            name: 'Блюдо 2',
            items: [
              TemplateItem(
                id: 6,
                name: 'Название блюда по меню',
                settings: ItemSettings(minLength: 3, maxLength: 80),
                questionType: 'text',
              ),
              TemplateItem(
                id: 7,
                name: 'Состояние оборудования',
                questionType: 'single_choice',
                settings: ItemSettings(
                  options: ['Исправно', 'Требует ремонта', 'Неисправно'],
                ),
              ),
              TemplateItem(
                id: 8,
                name: 'Смена',
                questionType: 'single_choice',
                settings: ItemSettings(
                  uiHint: 'dropdown',
                  options: ['Утренняя', 'Дневная', 'Вечерняя'],
                ),
              ),
              TemplateItem(
                id: 9,
                name: 'Какие нарушения обнаружены',
                questionType: 'multi_choice',
                settings: ItemSettings(
                  options: [
                    'Загрязнение',
                    'Повреждение упаковки',
                    'Нет маркировки',
                    'Просрочен срок',
                  ],
                ),
              ),
              TemplateItem(
                id: 10,
                name: 'Дата проверки',
                settings: ItemSettings(),
                questionType: 'date',
              ),
              TemplateItem(
                id: 11,
                name: 'Когда обнаружено нарушение',
                settings: ItemSettings(),
                questionType: 'datetime',
              ),
              TemplateItem(
                id: 12,
                name: 'Опишите обнаруженные нарушения',
                settings: ItemSettings(minLength: 10, maxLength: 500),
                questionType: 'long_text',
              ),
              TemplateItem(
                id: 13,
                name: 'Приложите акт проверки',
                settings: ItemSettings(),
                questionType: 'file',
              ),
            ],
          ),
        ],
      );
  @override
  Future<PagedTemplates> listTemplates({String? query, int page = 0}) async =>
      PagedTemplates(items: templates, page: 0, totalPages: 1);
  @override
  Future<PagedControlObjects> listControlObjects({
    String? query,
    int page = 0,
  }) async => PagedControlObjects(items: objects, page: 0, totalPages: 1);
  @override
  Future<ChecklistSummary> startChecklist({
    required int templateId,
    required int controlObjectId,
  }) async {
    startedObject = controlObjectId;
    startedTemplate = templateId;
    objectName = objects.firstWhere((o) => o.id == controlObjectId).name;
    templateName = templates.firstWhere((t) => t.id == templateId).name;
    final id = _nextId++;
    _created[id] = (
      templateName: templateName,
      objectId: controlObjectId,
      objectName: objectName,
    );
    return summary(id);
  }

  @override
  Future<ChecklistDetail> save({
    required int checklistId,
    required int? controlObjectId,
    required DateTime? startAt,
    required DateTime? endAt,
    required List<TemplateItem> items,
    required Map<int, ItemAnswer> answers,
  }) async {
    saves++;
    this.answers
      ..clear()
      ..addAll(answers);
    _savedAnswers[checklistId] = Map.of(answers);
    return getById(checklistId);
  }

  @override
  Future<ChecklistDetail> complete(int id) async {
    completions++;
    _completedIds.add(id);
    return getById(id);
  }

  @override
  Future<void> takeToWork(int id) async {
    _completedIds.remove(id);
  }

  @override
  Future<ChecklistExportFile> export(
    int id,
    ChecklistExportFormat format,
  ) async {
    final pdf = format == ChecklistExportFormat.pdf;
    return ChecklistExportFile(
      bytes: pdf ? demoPdfBytes() : demoExcelBytes(),
      filename: 'demo-checklist-$id.${pdf ? 'pdf' : 'xlsx'}',
      mimeType: pdf
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
