import 'package:checklist_flutter/core/network/api_client.dart';
import 'package:checklist_flutter/core/storage/token_storage.dart';
import 'package:checklist_flutter/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PreviewDashboardRepository extends DashboardRepository {
  PreviewDashboardRepository()
    : super(ApiClient(TokenStorage(const FlutterSecureStorage())));
  final queries = <DashboardQuery>[];
  bool failObjects = false;
  @override
  Future<List<DashboardOrganization>> organizations() async => const [
    DashboardOrganization(42, 'Тестовая организация'),
  ];
  @override
  Future<DashboardSummary> summary(DashboardQuery q) async {
    queries.add(q);
    return const DashboardSummary(inWork: 7, completed: 17, score: 78.4);
  }

  @override
  Future<List<DashboardPoint>> dynamics(DashboardQuery q) async => [
    DashboardPoint(period: q.fromDate, created: 24, score: 62),
    DashboardPoint(period: q.toDate, created: 0, score: 85),
  ];
  @override
  Future<List<DashboardObject>> objects(DashboardQuery q) async {
    if (failObjects) throw Exception('unavailable');
    return const [
      DashboardObject(
        name: 'ФР Пхали-Хинкали',
        completed: 11,
        score: 81.5,
        delta: 4.2,
      ),
    ];
  }

  @override
  Future<List<DashboardAttention>> attention(DashboardQuery q) async => const [
    DashboardAttention(
      id: 1,
      template: 'Проверка с отклонением',
      object: 'ФР Пхали-Хинкали',
      reason: 'Не завершён в срок',
    ),
  ];
}
