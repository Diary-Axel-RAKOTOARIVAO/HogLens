import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoglens/data/storage/cache_store.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('hoglens_cache'));
  tearDown(() async => dir.delete(recursive: true));

  test('writes, reads back with a timestamp, and clears per project', () async {
    final store = CacheStore(dir);
    expect(await store.read('stats_p1_week'), isNull);
    await store.write('stats_p1_week', {'events': 42});
    await store.write('flags_p2', {'v': []});
    final got = await store.read('stats_p1_week');
    expect(got, isNotNull);
    expect(got!.$1['events'], 42);
    expect(DateTime.now().difference(got.$2).inSeconds, lessThan(5));
    await store.removeProject('p1');
    expect(await store.read('stats_p1_week'), isNull);
    expect(await store.read('flags_p2'), isNotNull);
  });

  test('ignores corrupt files', () async {
    final store = CacheStore(dir);
    await File('${dir.path}/broken.json').writeAsString('{not json');
    expect(await store.read('broken'), isNull);
  });
}
