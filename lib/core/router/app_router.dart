import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/checklists/presentation/filling/filling_screen.dart';
import '../../features/checklists/presentation/list/checklists_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/app_icon.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final loggedIn = auth.valueOrNull?.isAuthenticated ?? false;
      if (auth.isLoading) {
        if (location == '/login' || location == '/splash') return null;
        return '/splash';
      }
      if (!loggedIn) {
        return location == '/login' ? null : '/login';
      }
      if (location == '/login' || location == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const ChecklistsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/checklists/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return FillingScreen(checklistId: id);
        },
      ),
    ],
  );
});

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final desktop = formFactorOf(context) == AppFormFactor.desktop;
    if (desktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              selectedIconTheme: const IconThemeData(color: AppColors.brand),
              selectedLabelTextStyle: AppText.bodyH5(color: AppColors.brand),
              destinations: const [
                NavigationRailDestination(
                  icon: AppIcon(AppIcon.file, size: 24),
                  selectedIcon: AppIcon(AppIcon.file, size: 24, color: AppColors.brand),
                  label: Text('Чек-листы'),
                ),
                NavigationRailDestination(
                  icon: AppIcon(AppIcon.user, size: 24),
                  selectedIcon: AppIcon(AppIcon.user, size: 24, color: AppColors.brand),
                  label: Text('Профиль'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.borderSubtle),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brandSoft,
        destinations: const [
          NavigationDestination(
            icon: AppIcon(AppIcon.file, size: 24),
            selectedIcon: AppIcon(AppIcon.file, size: 24, color: AppColors.brand),
            label: 'Чек-листы',
          ),
          NavigationDestination(
            icon: AppIcon(AppIcon.user, size: 24),
            selectedIcon: AppIcon(AppIcon.user, size: 24, color: AppColors.brand),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
