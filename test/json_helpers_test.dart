import 'dart:convert';
import 'dart:typed_data';

import 'package:checklist_flutter/core/utils/json_helpers.dart';
import 'package:checklist_flutter/features/checklists/domain/checklist_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseContentDispositionFilename', () {
    test('читает обычный filename', () {
      expect(
        parseContentDispositionFilename('attachment; filename="report.pdf"'),
        'report.pdf',
      );
    });

    test('читает filename* в UTF-8', () {
      expect(
        parseContentDispositionFilename(
          "attachment; filename*=UTF-8''%D1%87%D0%B5%D0%BA%D0%BB%D0%B8%D1%81%D1%82.xlsx",
        ),
        'чеклист.xlsx',
      );
    });

    test('возвращает null без заголовка', () {
      expect(parseContentDispositionFilename(null), isNull);
      expect(parseContentDispositionFilename(''), isNull);
    });
  });

  group('sanitizeFilename', () {
    test('убирает запрещённые символы', () {
      expect(sanitizeFilename('a/b:c.pdf'), 'a_b_c.pdf');
    });
  });

  group('extractMessage', () {
    test('разбирает JSON в байтах', () {
      final bytes = Uint8List.fromList(utf8.encode('{"message":"Нет доступа"}'));
      expect(extractMessage(bytes), 'Нет доступа');
    });
  });

  group('ChecklistSummary.controlResult', () {
    test('форматирует процент с запятой', () {
      const item = ChecklistSummary(
        id: 1,
        status: ChecklistStatusInfo(code: ChecklistStatusCode.completed),
        controlResult: 89.3,
      );
      expect(item.formattedControlResult, '89,3%');
    });

    test('читает control_result из JSON', () {
      final item = ChecklistSummary.fromJson({
        'id': 1,
        'status': {'code': 'COMPLETED'},
        'control_result': 89.3,
      });
      expect(item.controlResult, 89.3);
      expect(item.formattedControlResult, '89,3%');
    });

    test('без оценки показывает тире', () {
      final item = ChecklistSummary.fromJson({
        'id': 1,
        'status': {'code': 'DRAFT'},
      });
      expect(item.formattedControlResult, '—');
    });
  });

  group('ItemAnswer.comment', () {
    test('читает comment из JSON', () {
      final answer = ItemAnswer.fromJson({
        'id': 1,
        'item_id': 10,
        'answer': true,
        'comment': 'Замечание по пункту',
      });
      expect(answer.comment, 'Замечание по пункту');
      expect(answer.hasComment, isTrue);
    });

    test('без комментария чекбокс выключен', () {
      final answer = ItemAnswer.fromJson({
        'item_id': 10,
        'answer': 'ok',
      });
      expect(answer.comment, isNull);
      expect(answer.hasComment, isFalse);
    });
  });
}
