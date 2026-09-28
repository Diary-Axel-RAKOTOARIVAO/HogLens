import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/errors/errors_screen.dart';
import 'features/live/live_feed_screen.dart';
import 'features/flags/flags_screen.dart';
import 'features/projects/add_project_screen.dart';
import 'features/projects/home_screen.dart';
import 'features/projects/project_settings_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const HomeScreen(),
      routes: [
        GoRoute(path: 'add', builder: (_, _) => const AddProjectScreen()),
        GoRoute(
          path: 'p/:id',
          builder: (_, s) => DashboardScreen(projectId: s.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'flags',
              builder: (_, s) => FlagsScreen(projectId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: 'live',
              builder: (_, s) => LiveFeedScreen(projectId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: 'errors',
              builder: (_, s) => ErrorsScreen(projectId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: 'settings',
              builder: (_, s) => ProjectSettingsScreen(projectId: s.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
  ],
);

class HogLensApp extends StatelessWidget {
  const HogLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HogLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      routerConfig: _router,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: child!,
        );
      },
    );
  }
}
