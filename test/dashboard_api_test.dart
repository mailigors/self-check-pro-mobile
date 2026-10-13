import 'dart:typed_data';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checklist_flutter/core/network/api_client.dart';
import 'package:checklist_flutter/core/storage/token_storage.dart';
import 'package:checklist_flutter/features/dashboard/data/dashboard_repository.dart';
import 'package:checklist_flutter/features/checklists/data/checklist_repository_impl.dart';

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
      '/checklists' =>
        options.queryParameters['status'] == 'IN_WORK'
            ? '{"content":[],"totalElements":2}'
            : options.queryParameters['status'] == 'COMPLETED'
            ? '{"content":[],"totalElements":17}'
            : '{"content":[{"id":9}],"totalPages":1}',
      '/dashboard/objects-rating' => '[{"name":"Объект","completedChecklists":11,"controlResult":81.5,"controlResultDynamic":4.2}]',
      '/reports/checklists/dynamics' =>
        '[{"period":"2026-10-12","createdCount":24,"controlResult":62}]',
      '/dashboard/deviations' =>
        options.queryParameters['page'] == 0
            ? '{"content":[{"checklistId":8,"inspectorId":2},{"checklistId":7}],"totalPages":2}'
            : '{"content":[{"checklistId":99,"inspectorId":1},{"checklistId":9,"inspectorId":1,"templateName":"Аудит","controlObjectName":"Объект","deviationReason":"NOT_COMPLETED"}],"totalPages":2}',
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

class _PaginationAdapter extends _Adapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!['/checklists', '/dashboard/deviations'].contains(options.path)) {
      return super.fetch(options, requestStream, cancelFuture);
    }
    requests.add(options);
    final page = options.queryParameters['page'] as int;
    final body = options.path == '/checklists'
        ? {
            'content': [
              for (var id = page * 6 + 1; id <= page * 6 + 6; id++) {'id': id},
            ],
            'totalPages': 2,
          }
        : {
            'content': [
              for (var id = page * 6 + 1; id <= page * 6 + 6; id++)
                {'checklistId': id, 'inspectorId': 1},
              {'checklistId': 99, 'inspectorId': 1},
              {'checklistId': 1, 'inspectorId': 2},
            ],
            'totalPages': 2,
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
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
      expect((await repository.summary(query)).inWork, 2);
      expect((await repository.objects(query)).single.delta, 4.2);
      expect((await repository.dynamics(query)).single.score, 62);
      expect((await repository.attention(query)).single.id, 9);
      for (final request in adapter.requests) {
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (request.path == '/checklists') {
          expect(request.queryParameters['user_id'], 1);
          continue;
        }
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
      expect(
        adapter.requests
            .singleWhere((r) => r.path == '/reports/checklists/dynamics')
            .queryParameters['groupBy'],
        'DAY',
      );
      expect(
        adapter.requests
            .where((r) => r.path == '/dashboard/deviations')
            .map((r) => r.queryParameters['page']),
        [0, 1],
      );
      await repository.summary(
        DashboardPeriod.week.query(
          DateTime(2026, 10, 12),
          userId: 1,
          organisationId: 42,
        ),
      );
      final summaryRequest = adapter.requests.lastWhere(
        (r) => r.path == '/reports/checklists/summary',
      );
      expect(summaryRequest.queryParameters['organisationId'], 42);
      expect(summaryRequest.queryParameters['inspectorIds'], 1);
    },
  );
  test('attention traverses pages, excludes unavailable IDs and keeps more than ten results', () async {
    final api = ApiClient(_Storage());
    final adapter = _PaginationAdapter();
    api.dio.httpClientAdapter = adapter;
    final repository = DashboardRepository(api);
    final query = DashboardPeriod.week.query(DateTime(2026, 10, 13), userId: 1);
    final rows = await repository.attention(query);
    expect(rows.map((r) => r.id), List.generate(12, (i) => i + 1));
    expect(
      adapter.requests
          .where((r) => r.path == '/checklists')
          .map((r) => r.queryParameters['page']),
      [0, 1],
    );
    final summary = await repository.summary(query);
    expect(summary.inWork, 12);
    expect(summary.completed, 12);
  });
  test(
    'period list sends UTC OffsetDateTime bounds covering whole local days',
    () async {
      final api = ApiClient(_Storage());
      final adapter = _Adapter();
      api.dio.httpClientAdapter = adapter;
      await ChecklistRepositoryImpl(api)
          .list(userId: 1, createdFrom: '2026-10-01', createdTo: '2026-10-13');
      final params = adapter.requests.single.queryParameters;
      expect(
        params['created_at_from'],
        DateTime(2026, 10, 1).toUtc().toIso8601String(),
      );
      expect(
        params['created_at_to'],
        DateTime(
          2026,
          10,
          14,
        ).subtract(const Duration(microseconds: 1)).toUtc().toIso8601String(),
      );
      for (final key in ['created_at_from', 'created_at_to']) {
        expect(params[key], endsWith('Z'));
        expect(DateTime.parse(params[key] as String).isUtc, isTrue);
      }
    },
  );
}
