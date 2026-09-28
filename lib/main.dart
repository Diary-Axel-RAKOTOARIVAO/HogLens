import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/providers/providers.dart';
import 'data/storage/cache_store.dart';
import 'data/storage/project_store.dart';
import 'home_widget/home_widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ProjectStore.open();
  final cache = await CacheStore.open();
  await HomeWidgetService.init();
  runApp(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(store), cacheProvider.overrideWithValue(cache)],
      child: const HogLensApp(),
    ),
  );
}
