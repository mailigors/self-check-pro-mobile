import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json_helpers.dart';
import '../../auth/presentation/auth_controller.dart';

enum DashboardPeriod {
  week('Неделя', 7, 'DAY'),
  month('Месяц', 30, 'DAY'),
  quarter('Квартал', 90, 'WEEK');

  const DashboardPeriod(this.label, this.days, this.groupBy);
  final String label;
  final int days;
  final String groupBy;

  DashboardQuery query(
    DateTime now, {
    required int userId,
    int? organisationId,
  }) {
    if (userId <= 0) throw ArgumentError.value(userId, 'userId');
    final end = DateTime(now.year, now.month, now.day);
    final start = DateTime(end.year, end.month, end.day - days + 1);
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return (
      fromDate: date(start),
      toDate: date(end),
      groupBy: groupBy,
      organisationId: organisationId,
      userId: userId,
    );
  }
}

typedef DashboardQuery = ({
  String fromDate,
  String toDate,
  String groupBy,
  int? organisationId,
  int userId,
});

class DashboardSummary {
  const DashboardSummary({
    required this.inWork,
    required this.completed,
    this.score,
  });
  final int inWork;
  final int completed;
  final double? score;
  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        inWork: asInt(json['inWorkCount']) ?? 0,
        completed: asInt(json['completedCount']) ?? 0,
        score: asDouble(json['controlResult']),
      );
}

class DashboardObject {
  const DashboardObject({
    required this.name,
    required this.completed,
    this.score,
    this.delta,
  });
  final String name;
  final int completed;
  final double? score;
  final double? delta;
  factory DashboardObject.fromJson(Map<String, dynamic> json) =>
      DashboardObject(
        name: asString(json['name']) ?? 'Объект',
        completed: asInt(json['completedChecklists']) ?? 0,
        score: asDouble(json['controlResult']),
        delta: asDouble(json['controlResultDynamic']),
      );
}

class DashboardPoint {
  const DashboardPoint({
    required this.period,
    required this.created,
    this.score,
  });
  final String period;
  final int created;
  final double? score;
  factory DashboardPoint.fromJson(Map<String, dynamic> json) => DashboardPoint(
    period: asString(json['period']) ?? '',
    created: asInt(json['createdCount']) ?? 0,
    score: asDouble(json['controlResult']),
  );
}

class DashboardAttention {
  const DashboardAttention({
    required this.id,
    required this.template,
    required this.object,
    required this.reason,
  });
  final int id;
  final String template;
  final String object;
  final String reason;
  factory DashboardAttention.fromJson(Map<String, dynamic> json) =>
      DashboardAttention(
        id: asInt(json['checklistId']) ?? 0,
        template: asString(json['templateName']) ?? 'Чек-лист',
        object: asString(json['controlObjectName']) ?? 'Объект',
        reason: switch (json['deviationReason']) {
          'LATE_COMPLETION' => 'Завершён с опозданием',
          'NOT_COMPLETED' => 'Не завершён в срок',
          _ => 'Нарушение срока',
        },
      );
}

class DashboardOrganization {
  const DashboardOrganization(this.id, this.name);
  final int id;
  final String name;
}

class DashboardRepository {
  DashboardRepository(this.api);
  final ApiClient api;
  Map<String, dynamic> params(DashboardQuery q) => {
    'fromDate': q.fromDate,
    'toDate': q.toDate,
    // A single scalar serializes as inspectorIds=ID, as in the web app.
    'inspectorIds': q.userId,
    if (q.organisationId != null) 'organisationId': q.organisationId,
  };

  Future<DashboardSummary> summary(DashboardQuery q) => api.get(
    '/reports/checklists/summary',
    query: params(q),
    parser: (data) => DashboardSummary.fromJson(asMap(data)),
  );
  Future<List<DashboardObject>> objects(DashboardQuery q) => api.get(
    '/dashboard/objects-rating',
    query: params(q),
    parser: (data) =>
        asList(data).map((e) => DashboardObject.fromJson(asMap(e))).toList(),
  );
  Future<List<DashboardPoint>> dynamics(DashboardQuery q) => api.get(
    '/reports/checklists/dynamics',
    query: {...params(q), 'groupBy': q.groupBy},
    parser: (data) =>
        asList(data).map((e) => DashboardPoint.fromJson(asMap(e))).toList(),
  );
  Future<List<DashboardAttention>> attention(DashboardQuery q) async {
    // This endpoint has no inspector filter. Filter before taking the first
    // ten results, continuing through pages containing other inspectors.
    final result = <DashboardAttention>[];
    for (var page = 0; ; page++) {
      final data = await api.get<Map<String, dynamic>>(
        '/dashboard/deviations',
        query: {
          'fromDate': q.fromDate,
          'toDate': q.toDate,
          if (q.organisationId != null) 'organisationId': q.organisationId,
          'page': page,
          'size': 100,
          'sort': 'startAt,desc',
        },
        parser: asMap,
      );
      final content = asList(data['content']);
      for (final raw in content) {
        final json = asMap(raw);
        if (asInt(json['inspectorId']) != q.userId) continue;
        final item = DashboardAttention.fromJson(json);
        if (item.id > 0) result.add(item);
        if (result.length == 10) return result;
      }
      final totalPages = asInt(data['totalPages']);
      if (content.isEmpty ||
          asBool(data['last']) == true ||
          (totalPages != null && page + 1 >= totalPages) ||
          (totalPages == null &&
              content.length < (asInt(data['size']) ?? 100))) {
        return result;
      }
    }
  }

  Future<List<DashboardOrganization>> organizations() => api.get(
    '/organizations',
    query: {'size': 200},
    parser: (data) => asList(data is List ? data : asMap(data)['content'])
        .map(
          (e) => DashboardOrganization(
            asInt(asMap(e)['id']) ?? 0,
            asString(asMap(e)['name']) ?? 'Организация',
          ),
        )
        .where((e) => e.id > 0)
        .toList(),
  );
}

final dashboardRepositoryProvider = Provider(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);
void _requireCurrentUser(Ref ref, DashboardQuery q) {
  final user = ref.watch(authControllerProvider).valueOrNull?.user;
  if (user == null || user.id <= 0 || user.id != q.userId) {
    throw const ApiException(
      message: 'Сессия пользователя изменилась',
      statusCode: 401,
    );
  }
}

// Depend on the session so cached analytics are discarded when the user changes.
final dashboardSummaryProvider = FutureProvider.autoDispose
    .family<DashboardSummary, DashboardQuery>((ref, q) {
      _requireCurrentUser(ref, q);
      return ref.watch(dashboardRepositoryProvider).summary(q);
    });
final dashboardObjectsProvider = FutureProvider.autoDispose
    .family<List<DashboardObject>, DashboardQuery>((ref, q) {
      _requireCurrentUser(ref, q);
      return ref.watch(dashboardRepositoryProvider).objects(q);
    });
final dashboardDynamicsProvider = FutureProvider.autoDispose
    .family<List<DashboardPoint>, DashboardQuery>((ref, q) {
      _requireCurrentUser(ref, q);
      return ref.watch(dashboardRepositoryProvider).dynamics(q);
    });
final dashboardAttentionProvider = FutureProvider.autoDispose
    .family<List<DashboardAttention>, DashboardQuery>((ref, q) {
      _requireCurrentUser(ref, q);
      return ref.watch(dashboardRepositoryProvider).attention(q);
    });
final dashboardOrganizationsProvider = FutureProvider.autoDispose((ref) {
  ref.watch(authControllerProvider);
  return ref.watch(dashboardRepositoryProvider).organizations();
});
