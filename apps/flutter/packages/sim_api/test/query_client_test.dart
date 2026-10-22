// Failure modes of Query<T> / QueryClient:
// 1. two fetches of the same key while one is in flight share it (one call);
// 2. a fetch within staleTime returns the cached data without a request,
//    one after staleTime refetches;
// 3. invalidation by prefix refetches only observed queries and marks the
//    rest stale;
// 4. cancellation cancels the Dio token and a late result is ignored;
// 5. the focus hook refetches only stale observed queries;
// 6. an optimistic update is rolled back when the mutation fails and kept
//    when it succeeds;
// 7. map keys hash independently of insertion order; a different type at the
//    same key is refused;
// 8. a failed fetch keeps the previous data and exposes the error.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

void main() {
  late DateTime now;
  late QueryClient client;

  setUp(() {
    now = DateTime(2026);
    client = QueryClient(now: () => now);
  });

  test('concurrent fetches share one request', () async {
    var calls = 0;
    final gate = Completer<int>();
    Future<int> fetcher(CancelToken _) {
      calls += 1;
      return gate.future;
    }

    final a = client.query(['workflows', 'ws1'], fetcher);
    final b = client.query(['workflows', 'ws1'], fetcher);
    final results = Future.wait([a.fetch(), b.fetch()]);
    gate.complete(7);
    expect(await results, [7, 7]);
    expect(calls, 1);
  });

  test('staleTime: fresh data is returned without a request', () async {
    var calls = 0;
    final query = client.query(
      ['session'],
      (_) async => ++calls,
      staleTime: const Duration(minutes: 5),
    );
    expect(await query.fetch(), 1);
    now = now.add(const Duration(minutes: 4));
    expect(await query.fetch(), 1);
    now = now.add(const Duration(minutes: 2));
    expect(await query.fetch(), 2);
    expect(calls, 2);
  });

  test('invalidation refetches observed queries only', () async {
    var observedCalls = 0;
    var idleCalls = 0;
    final observed = client.query(
      ['workflows', 'ws1'],
      (_) async => ++observedCalls,
      staleTime: const Duration(hours: 1),
    );
    await observed.fetch();
    await client.fetchQuery(
      ['workflows', 'ws2'],
      (_) async => ++idleCalls,
      staleTime: const Duration(hours: 1),
    );
    await client.fetchQuery(
      ['folders'],
      (_) async => 0,
      staleTime: const Duration(hours: 1),
    );

    await client.invalidateQueries(['workflows']);
    expect(observedCalls, 2);
    expect(idleCalls, 1);
    expect(client.getQueryState<int>(['folders'])?.updatedAt, isNotNull);
    await client.fetchQuery(['workflows', 'ws2'], (_) async => ++idleCalls);
    expect(idleCalls, 2);
  });

  test('cancellation cancels the token and ignores the late result', () async {
    CancelToken? seen;
    final gate = Completer<int>();
    final query = client.query(['logs'], (token) {
      seen = token;
      return gate.future;
    });
    final pending = query.fetch();
    query.cancel();
    expect(seen!.isCancelled, isTrue);
    gate.complete(99);
    expect(await pending, 99);
    expect(query.state.data, isNull);
    expect(query.state.isFetching, isFalse);
  });

  test('focus refetches only stale observed queries', () async {
    var fresh = 0;
    var stale = 0;
    final freshQuery = client.query(
      ['fresh'],
      (_) async => ++fresh,
      staleTime: const Duration(hours: 1),
    );
    final staleQuery = client.query(['stale'], (_) async => ++stale);
    await freshQuery.fetch();
    await staleQuery.fetch();
    now = now.add(const Duration(seconds: 1));
    await client.onFocus();
    expect(fresh, 1);
    expect(stale, 2);
    staleQuery.dispose();
    await client.onFocus();
    expect(stale, 2);
  });

  test(
    'optimistic update rolls back on failure and keeps on success',
    () async {
      client.setQueryData<List<String>>(['names'], ['a']);
      await expectLater(
        client.optimisticUpdate<List<String>, void>(
          key: ['names'],
          update: (previous) => [...?previous, 'b'],
          mutation: () async =>
              throw ApiClientError(status: 400, message: 'no'),
        ),
        throwsA(isA<ApiClientError>()),
      );
      expect(client.getQueryData<List<String>>(['names']), ['a']);

      await client.optimisticUpdate<List<String>, void>(
        key: ['names'],
        update: (previous) => [...?previous, 'b'],
        mutation: () async {},
      );
      expect(client.getQueryData<List<String>>(['names']), ['a', 'b']);
    },
  );

  test('map keys hash order-independently; a type mismatch is refused', () {
    expect(
      queryHash([
        'logs',
        {'a': 1, 'b': 2},
      ]),
      queryHash([
        'logs',
        {'b': 2, 'a': 1},
      ]),
    );
    client.setQueryData<int>(['x'], 1);
    expect(() => client.setQueryData<String>(['x'], 's'), throwsStateError);
  });

  test(
    'a failed fetch keeps the previous data and exposes the error',
    () async {
      var fail = false;
      final query = client.query(['env'], (_) async {
        if (fail) throw ApiClientError(status: 500, message: 'down');
        return 'ok';
      });
      await query.fetch();
      fail = true;
      await expectLater(query.refetch(), throwsA(isA<ApiClientError>()));
      expect(query.state.data, 'ok');
      expect(query.state.status, QueryStatus.error);
      expect(query.state.error, isA<ApiClientError>());
    },
  );
}
