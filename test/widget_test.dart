import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checklist_flutter/main.dart';

void main() {
  testWidgets('приложение запускается', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SelfCheckApp()));
    await tester.pump();
    expect(find.byType(SelfCheckApp), findsOneWidget);
  });
}
