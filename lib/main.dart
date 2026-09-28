import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/providers/providers.dart';
import 'data/storage/project_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ProjectStore.open();
  runApp(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(store)],
      child: const HogLensApp(),
    ),
  );
}
