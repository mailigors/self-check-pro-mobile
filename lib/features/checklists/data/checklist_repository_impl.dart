import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json_helpers.dart';
import '../domain/checklist_models.dart';
import '../domain/checklist_repository.dart';

class ChecklistRepositoryImpl implements ChecklistRepository {
  ChecklistRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<PagedChecklists> list({
    required int userId,
    String? query,
    String? status,
    int page = 0,
  }) {
    return _api.get(
      '/checklists',
      query: {
        'user_id': userId,
        'page': page,
        'size': 20,
        // 'sort': 'start_at,desc',
        'q': ?(query == null || query.isEmpty ? null : query),
        'status': ?status,
      },
      parser: (data) => PagedChecklists.fromJson(asMap(data)),
    );
  }

  @override
  Future<ChecklistDetail> getById(int id) {
    return _api.get(
      '/checklists/$id',
      parser: (data) => ChecklistDetail.fromJson(asMap(data)),
    );
  }

  @override
  Future<ChecklistTemplate> getTemplate(int templateId) {
    return _api.get(
      '/templates/$templateId',
      parser: (data) => ChecklistTemplate.fromJson(asMap(data)),
    );
  }

  @override
  Future<ChecklistDetail> save({
    required int checklistId,
    required int? controlObjectId,
    required DateTime? startAt,
    required DateTime? endAt,
    required List<TemplateItem> items,
    required Map<int, ItemAnswer> answers,
  }) {
    final payloadAnswers = [...items]
      ..sort((a, b) => a.id.compareTo(b.id));
    return _api.put(
      '/checklists/$checklistId',
      data: {
        'control_object_id': ?controlObjectId,
        if (startAt != null) 'start_at': startAt.toUtc().toIso8601String(),
        if (endAt != null) 'end_at': endAt.toUtc().toIso8601String(),
        'answers': payloadAnswers.map((item) {
          final answer = answers[item.id] ?? const ItemAnswer();
          final map = <String, dynamic>{
            'item_id': item.id,
            'photo_ids': answer.photoIds.map((e) => e.toPayload()).toList(),
            'video_ids': answer.videoIds.map((e) => e.toPayload()).toList(),
            'other_ids': answer.otherIds.map((e) => e.toPayload()).toList(),
          };
          if (answer.id != null) map['id'] = answer.id;
          if (answer.value != null && '${answer.value}'.isNotEmpty) {
            map['answer'] = answer.value;
          }
          return map;
        }).toList(),
      },
      parser: (data) => ChecklistDetail.fromJson(asMap(data)),
    );
  }

  @override
  Future<void> takeToWork(int id) {
    return _api.patch('/checklists/$id/towork', parser: (_) {});
  }

  @override
  Future<ChecklistDetail> complete(int id) {
    return _api.patch(
      '/checklists/$id/complete',
      parser: (data) => ChecklistDetail.fromJson(asMap(data)),
    );
  }

  @override
  Future<AttachmentRef> upload({
    required String filename,
    required List<int> bytes,
    required String contentType,
  }) {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    });
    return _api.post(
      '/attachments',
      data: form,
      query: {'filename': filename},
      options: Options(contentType: 'multipart/form-data'),
      parser: (data) => AttachmentRef.fromJson(asMap(data)),
    );
  }
}

final checklistRepositoryProvider = Provider<ChecklistRepository>((ref) {
  return ChecklistRepositoryImpl(ref.watch(apiClientProvider));
});
