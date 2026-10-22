// Failure modes of KeyValueStore implementations and KeyValueNamespace:
// 1. a write over quota throws KeyValueQuotaExceededError and keeps the
//    previous value (in-memory and file);
// 2. a corrupt value reads as null and a corrupt file starts the store
//    empty while keeping a `.corrupt` copy;
// 3. concurrent writers never lose a write or interleave the file;
// 4. a write never leaves a half-written file (temp + rename);
// 5. a namespace drops a value its decoder rejects and returns null;
// 6. keys(prefix) only lists that prefix, and a namespace strips it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sim_api_kv');
  });

  tearDown(() => dir.delete(recursive: true));

  test('a write over quota throws and keeps the previous value', () async {
    final memory = InMemoryKeyValueStore(maxBytes: 20);
    await memory.write('k', 'short');
    await expectLater(
      memory.write('k', 'a value that is far too long'),
      throwsA(isA<KeyValueQuotaExceededError>()),
    );
    expect(await memory.read('k'), 'short');

    final file = FileKeyValueStore('${dir.path}/kv.json', maxBytes: 40);
    await file.write('k', 'short');
    await expectLater(
      file.write('k', 'a value that is far too long for the file'),
      throwsA(isA<KeyValueQuotaExceededError>()),
    );
    expect(await file.read('k'), 'short');
    expect(await FileKeyValueStore('${dir.path}/kv.json').read('k'), 'short');
  });

  test(
    'corrupt values read as null; a corrupt file starts empty with a backup',
    () async {
      final memory = InMemoryKeyValueStore()..plantRaw('bad', '{not json');
      expect(await memory.read('bad'), isNull);

      final path = '${dir.path}/kv.json';
      await File(path).writeAsString('{"a": 1, oops');
      final store = FileKeyValueStore(path);
      expect(await store.read('a'), isNull);
      await store.write('b', 2);
      expect(File('$path.corrupt').existsSync(), isTrue);
      expect(jsonDecode(await File(path).readAsString()), {'b': 2});
    },
  );

  test('concurrent writers never lose a write', () async {
    final store = FileKeyValueStore('${dir.path}/kv.json');
    await Future.wait([for (var i = 0; i < 50; i++) store.write('k$i', i)]);
    final reopened = FileKeyValueStore('${dir.path}/kv.json');
    expect(await reopened.keys(), hasLength(50));
    expect(await reopened.read('k49'), 49);
  });

  test(
    'a write leaves no temp file behind and the file stays valid JSON',
    () async {
      final path = '${dir.path}/nested/kv.json';
      final store = FileKeyValueStore(path);
      await store.write('k', {'x': 1});
      expect(File('$path.tmp').existsSync(), isFalse);
      expect(jsonDecode(await File(path).readAsString()), {
        'k': {'x': 1},
      });
    },
  );

  test('a namespace drops a value its decoder rejects', () async {
    final store = InMemoryKeyValueStore();
    final numbers = KeyValueNamespace<int>(
      store: store,
      prefix: 'console:',
      encode: (v) => v,
      decode: (json) => json! as int,
    );
    await numbers.write('a', 1);
    await store.write('console:b', 'not a number');
    expect(await numbers.read('a'), 1);
    expect(await numbers.read('b'), isNull);
    expect(await store.read('console:b'), isNull);
  });

  test(
    'keys(prefix) lists only that prefix and a namespace strips it',
    () async {
      final store = InMemoryKeyValueStore();
      await store.write('console:a', 1);
      await store.write('undo:b', 2);
      expect(await store.keys(prefix: 'console:'), ['console:a']);
      final namespace = KeyValueNamespace<int>(
        store: store,
        prefix: 'console:',
        encode: (v) => v,
        decode: (json) => json! as int,
      );
      expect(await namespace.keys(), ['a']);
      await namespace.clear();
      expect(await store.keys(), ['undo:b']);
    },
  );

  test('shared web state helpers read the React shapes strictly', () {
    expect(
      sidebarWidthFromEnvelope({
        'state': {'sidebarWidth': 240},
        'version': 0,
      }),
      240,
    );
    expect(sidebarWidthFromEnvelope({'sidebarWidth': 240}), isNull);
    expect(sidebarCollapsedFromCookie('a=1; sidebar_collapsed=1'), isTrue);
    expect(sidebarCollapsedFromCookie('sidebar_collapsed=10'), isFalse);
    expect(sidebarCollapsedFromCookie('x_sidebar_collapsed=1'), isFalse);
  });

  test('legacy isCollapsed migrates only when the cookie is absent', () {
    expect(hasSidebarCollapsedCookie('a=1; sidebar_collapsed=0'), isTrue);
    expect(hasSidebarCollapsedCookie('x_sidebar_collapsed=1'), isFalse);
    expect(
      legacyCollapsedFromEnvelope({
        'state': {'sidebarWidth': 240, 'isCollapsed': true},
        'version': 0,
      }),
      isTrue,
    );
    expect(
      legacyCollapsedFromEnvelope({
        'state': {'sidebarWidth': 240},
      }),
      isNull,
    );
  });
}
