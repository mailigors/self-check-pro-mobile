import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checklist_flutter/core/network/api_client.dart';
import 'package:checklist_flutter/core/storage/token_storage.dart';
import 'package:checklist_flutter/features/dashboard/data/dashboard_repository.dart';

class _Storage extends TokenStorage {
  _Storage() : super(const FlutterSecureStorage());
  @override
  Future<String?> readAccessToken() async => 'test-token';
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = switch (options.path) {
      '/reports/checklists/summary' =>
        '{"inWorkCount":7,"completedCount":17,"controlResult":78.4}',
      '/dashboard/objects-rating' => '[{"name":"Объект","completedChecklists":11,"controlResult":81.5,"controlResultDynamic":4.2}]',
      '/reports/checklists/dynamics' =>
        '[{"period":"2026-10-12","createdCount":24,"controlResult":62}]',
      '/dashboard/deviations' =>
        options.queryParameters['page'] == 0
            ? '{"content":[{"checklistId":8,"inspectorId":2},{"checklistId":7}],"totalPages":2}'
            : '{"content":[{"checklistId":9,"inspectorId":1,"templateName":"Аудит","controlObjectName":"Объект","deviationReason":"NOT_COMPLETED"}],"totalPages":2}',
      _ => '[]',
    };
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'repository uses web API contracts, period parameters and bearer token',
    () async {
      final api = ApiClient(_Storage());
      final adapter = _Adapter();
      api.dio.httpClientAdapter = adapter;
      final repository = DashboardRepository(api);
      final query = DashboardPeriod.week.query(
        DateTime(2026, 10, 12),
        userId: 1,
      );
      expect((await repository.summary(query)).inWork, 7);
      expect((await repository.objects(query)).single.delta, 4.2);
      expect((await repository.dynamics(query)).single.score, 62);
      expect((await repository.attention(query)).single.id, 9);
      for (final request in adapter.requests) {
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.queryParameters['fromDate'], '2026-10-06');
        expect(request.queryParameters['toDate'], '2026-10-12');
        expect(request.queryParameters.containsKey('organisationId'), isFalse);
        if (request.path != '/dashboard/deviations') {
          expect(request.queryParameters['inspectorIds'], 1);
          expect(request.uri.queryParameters['inspectorIds'], '1');
          expect(
            request.uri.queryParameters.containsKey('inspectorIds[]'),
            isFalse,
          );
        }
      }
      expect(adapter.requests[2].queryParameters['groupBy'], 'DAY');
      expect(adapter.requests[3].queryParameters['page'], 0);
      expect(adapter.requests[4].queryParameters['page'], 1);
      await repository.summary(
        DashboardPeriod.week.query(
          DateTime(2026, 10, 12),
          userId: 1,
          organisationId: 42,
        ),
      );
      expect(adapter.requests.last.queryParameters['organisationId'], 42);
      expect(adapter.requests.last.queryParameters['inspectorIds'], 1);
    },
  );
}
