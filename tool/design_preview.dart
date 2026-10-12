// Isolated preview with sample data. Production main.dart always uses the API.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:checklist_flutter/main.dart';
import 'package:checklist_flutter/features/auth/presentation/auth_controller.dart';
import 'package:checklist_flutter/features/checklists/data/checklist_repository_impl.dart';

import '../test/support/redesign_fixtures.dart';
import '../test/support/dashboard_fixtures.dart';

import 'package:checklist_flutter/features/dashboard/data/dashboard_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initializeDateFormatting('ru');
  runApp(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          PreviewDashboardRepository(),
        ),
        authControllerProvider.overrideWith(
          () => PreviewAuthController(
            authenticated: !const bool.fromEnvironment('PREVIEW_LOGIN'),
          ),
        ),
        checklistRepositoryProvider.overrideWithValue(
          PreviewChecklistRepository(),
        ),
      ],
      child: const SelfCheckApp(),
    ),
  );
}
