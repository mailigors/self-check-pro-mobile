import '../domain/checklist_models.dart';

abstract class ChecklistRepository {
  Future<PagedChecklists> list({
    required int userId,
    String? query,
    String? status,
    int page = 0,
  });

  Future<ChecklistDetail> getById(int id);
  Future<ChecklistTemplate> getTemplate(int templateId);
  Future<ChecklistDetail> save({
    required int checklistId,
    required int? controlObjectId,
    required DateTime? startAt,
    required DateTime? endAt,
    required List<TemplateItem> items,
    required Map<int, ItemAnswer> answers,
  });
  Future<void> takeToWork(int id);
  Future<ChecklistDetail> complete(int id);
  Future<AttachmentRef> upload({
    required String filename,
    required List<int> bytes,
    required String contentType,
  });
}
