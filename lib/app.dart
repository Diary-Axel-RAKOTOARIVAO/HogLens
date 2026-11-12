import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/behavior/behavior_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/errors/errors_screen.dart';
import 'features/live/live_feed_screen.dart';
import 'features/flags/flags_screen.dart';
import 'features/projects/add_project_screen.dart';
import 'features/projects/home_screen.dart';
import 'features/projects/project_settings_screen.dart';
import 'features/widgets/placed_widgets_screen.dart';
import 'features/settings/settings_screen.dart';
import 'data/providers/settings_provider.dart';
import 'features/world/world_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const HomeScreen(),
      routes: [
        GoRoute(path: 'add', builder: (_, _) => const AddProjectScreen()),
        GoRoute(
          path: 'settings',
          builder: (_, _) => const SettingsScreen(),
          routes: [GoRoute(path: 'widgets', builder: (_, _) => const PlacedWidgetsScreen())],
        ),
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
              path: 'behavior',
              builder: (_, s) => BehaviorScreen(projectId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: 'world',
              builder: (_, s) => WorldScreen(projectId: s.pathParameters['id']!),
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

/// Opens the screen a tapped home-screen widget points at
/// (`hoglens://widget/p/<project>[/live|/errors]`), with the dashboard under it.
void openWidgetLink(Uri? uri) {
  if (uri == null || uri.host != 'widget') return;
  final seg = uri.pathSegments;
  if (seg.length < 2 || seg.first != 'p') return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _router.go('/p/${seg[1]}');
    if (seg.length > 2) _router.push('/p/${seg[1]}/${seg[2]}');
  });
}

class HogLensApp extends ConsumerWidget {
  const HogLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      key: ValueKey(settings.language),
      title: 'HogLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: settings.themeMode,
      locale: Locale(settings.language.code),
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
