// Failure modes (written before the code):
// - a non-loopback, https, credentialed or path-carrying base URL must be refused
// - a database whose name has no `test` segment must be refused unless explicitly allowed
// - a secret shorter than 32 characters must be refused
// - the cookie signature must be standard base64 (padded) of HMAC-SHA-256(secret, token),
//   and the cookie value must percent-encode `+`, `/`, `=`
// - fixed ids must be stable across runs and valid UUIDs (copilot tables are uuid-typed)
// - the mixed graph must have 20 blocks, every edge must join existing blocks, and each
//   subflow's `nodes` must equal the blocks whose `data.parentId` is that container
// - the benchmark graph must have 200 blocks and a single chain of 199 edges
// - the reset script must touch every table the insert script writes to
// - the whole seed must be one transaction

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sim_seed/src/better_auth.dart';
import 'package:sim_seed/src/config.dart';
import 'package:sim_seed/src/encryption.dart';
import 'package:sim_seed/src/fixtures.dart';
import 'package:sim_seed/src/ids.dart';
import 'package:test/test.dart';

void main() {
  group('guards', () {
    const secret = 'dev-secret-at-least-32-characters-long';

    test('reject non-loopback, https, credentials and paths', () {
      expect(
        () => assertGuards(
          baseUrl: 'http://example.com',
          database: 'simstudio_test',
          authSecret: secret,
        ),
        throwsA(isA<GuardError>()),
      );
      expect(
        () => assertGuards(
          baseUrl: 'https://localhost:3001',
          database: 'simstudio_test',
          authSecret: secret,
        ),
        throwsA(isA<GuardError>()),
      );
      expect(
        () => assertGuards(
          baseUrl: 'http://u:p@localhost:3001',
          database: 'simstudio_test',
          authSecret: secret,
        ),
        throwsA(isA<GuardError>()),
      );
      expect(
        () => assertGuards(
          baseUrl: 'http://localhost:3001/app',
          database: 'simstudio_test',
          authSecret: secret,
        ),
        throwsA(isA<GuardError>()),
      );
    });

    test('reject a non-test database unless allowed', () {
      expect(
        () => assertGuards(
          baseUrl: 'http://localhost:3001',
          database: 'simstudio',
          authSecret: secret,
        ),
        throwsA(isA<GuardError>()),
      );
      expect(
        () => assertGuards(
          baseUrl: 'http://localhost:3001',
          database: 'contest',
          authSecret: secret,
        ),
        throwsA(isA<GuardError>()),
      );
      assertGuards(
        baseUrl: 'http://localhost:3001',
        database: 'simstudio',
        authSecret: secret,
        allowNonTestDatabase: true,
      );
      assertGuards(
        baseUrl: 'http://127.0.0.1:3001/',
        database: 'simstudio_test',
        authSecret: secret,
      );
    });

    test('reject a short secret', () {
      expect(
        () => assertGuards(
          baseUrl: 'http://localhost:3001',
          database: 'simstudio_test',
          authSecret: 'short',
        ),
        throwsA(isA<GuardError>()),
      );
    });
  });

  group('cookie', () {
    test('signature is padded base64 of HMAC-SHA-256 (RFC 4231 case 2)', () {
      final sig = signSessionToken('what do ya want for nothing?', 'Jefe');
      final expected = base64.encode(
        fromHex(
          '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
        ),
      );
      expect(sig, expected);
      expect(sig.length, 44);
      expect(sig.endsWith('='), isTrue);
    });

    test(
      'cookie value percent-encodes the base64 alphabet like encodeURIComponent',
      () {
        final value = sessionCookieValue(
          'tok',
          'dev-secret-at-least-32-characters-long',
        );
        expect(value, startsWith('tok.'));
        expect(value, isNot(contains('=')));
        expect(value, isNot(contains('+')));
        expect(value, isNot(contains('/')));
        final decoded = Uri.decodeComponent(value);
        expect(
          decoded.split('.').last,
          signSessionToken('tok', 'dev-secret-at-least-32-characters-long'),
        );
      },
    );
  });

  group('ids', () {
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('stable and uuid-shaped', () {
      expect(fixedId('user'), fixedId('user'));
      expect(fixedId('user'), isNot(fixedId('workspace')));
      expect(fixedId('user'), matches(uuid));
      expect(fixedId('copilot_chat'), matches(uuid));
    });
  });

  group('fixture', () {
    final fixture = SeedFixture(
      authSecret: 'dev-secret-at-least-32-characters-long',
      encryptionKey: fromHex(defaultEncryptionKey),
    );

    test('mixed graph: 20 blocks, consistent edges and containers', () {
      final g = fixture.mixedGraph;
      expect(g.blocks.length, 20);
      final ids = g.blocks.map((b) => b.id).toSet();
      expect(ids.length, 20);
      for (final e in g.edges) {
        expect(ids, contains(e.source));
        expect(ids, contains(e.target));
      }
      for (final s in g.subflows) {
        final children = g.blocks
            .where((b) => b.parentId == s.id)
            .map((b) => b.id)
            .toSet();
        expect((s.config['nodes']! as List).toSet(), children);
        expect(g.blocks.singleWhere((b) => b.id == s.id).type, s.type);
      }
      expect(g.subflows.map((s) => s.type).toSet(), {'loop', 'parallel'});
    });

    test('benchmark graph: 200 blocks in one chain', () {
      final g = fixture.benchmarkGraph;
      expect(g.blocks.length, 200);
      expect(g.edges.length, 199);
      expect(g.blocks.first.type, 'start_trigger');
      expect(g.edges.map((e) => e.id).toSet().length, 199);
    });

    test(
      'reset covers every table the seed inserts into, in one transaction',
      () {
        final inserted = fixture
            .insertStatements()
            .map((s) => RegExp(r'^insert into (\S+)').firstMatch(s)!.group(1)!)
            .toSet();
        // Child rows go with their parent's ON DELETE CASCADE (schema.ts).
        const cascadedBy = {
          'workflow_blocks': 'workflow',
          'workflow_edges': 'workflow',
          'workflow_subflows': 'workflow',
          'document': 'knowledge_base',
          'copilot_messages': 'copilot_chats',
        };
        final reset = fixture.resetStatements().join('\n');
        for (final table in inserted) {
          final deleted = cascadedBy[table] ?? table;
          expect(reset, contains('delete from $deleted'), reason: table);
        }
        final script = fixture.seedScript();
        expect(script, startsWith('begin;'));
        expect(script.trim(), endsWith('commit;'));
        expect(fixture.expireSessionScript(), contains('expires_at = now()'));
      },
    );

    test('table order keys follow the fractional-indexing sequence', () {
      final keys = SeedFixture.tableOrderKeys(50);
      expect(keys.first, 'a0');
      expect(keys[9], 'a9');
      expect(keys[10], 'aA');
      expect(keys[36], 'aa');
      expect(keys.last, 'an');
      final sorted = [...keys]..sort();
      expect(sorted, keys);
    });

    test('api key hash is the sha256 hex of the plain key', () {
      final sql = fixture.insertStatements().singleWhere(
        (s) => s.startsWith('insert into api_key'),
      );
      expect(
        sql,
        contains(sha256.convert(utf8.encode(fixture.apiKey)).toString()),
      );
    });

    test('encrypted values use the iv:ciphertext:tag hex layout', () {
      final value = encryptAesGcm(
        key: fromHex(defaultEncryptionKey),
        iv: fixedBytes('iv', 12),
        plaintext: 'x',
      );
      final parts = value.split(':');
      expect(parts.length, 3);
      expect(parts[0].length, 24);
      expect(parts[2].length, 32);
    });
  });
}
