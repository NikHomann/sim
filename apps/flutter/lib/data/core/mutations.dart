import 'dart:async';

import 'package:sim_api/sim_api.dart';

/// A `Query<T>` observed by a cubit: the subscription and the observer
/// handle, released together.
class QueryBinding<T> {
  QueryBinding(this.query, void Function(QueryState<T> state) onState)
    : _onState = onState,
      _subscription = query.states.listen((_) => onState(query.state));

  final Query<T> query;
  final void Function(QueryState<T> state) _onState;
  final StreamSubscription<QueryState<T>> _subscription;

  /// Pushes the query's current snapshot to the cubit now. `Query.states`
  /// delivers asynchronously, so a cubit calls this after an awaited fetch
  /// or a synchronous cache write to expose the result without a microtask
  /// lag (React Query notifies observers synchronously on `setQueryData`).
  /// The subscription itself also reads the current snapshot, never the
  /// event payload, so a late event can never roll the cubit back to an
  /// older state.
  void sync() => _onState(query.state);

  /// [Query.fetch] followed by [sync], whether it succeeded or threw.
  Future<T> fetch({bool force = false}) async {
    try {
      return await query.fetch(force: force);
    } finally {
      sync();
    }
  }

  Future<T> refetch() => fetch(force: true);

  void dispose() {
    unawaited(_subscription.cancel());
    query.dispose();
  }
}

/// TanStack's mutation `scope`: mutations with the same scope run one at a
/// time, in order; `onSettled` learns whether it is the last one queued
/// (spec §11.10). The optimistic update belongs *before* [run], as
/// `onMutate` runs before the scope gate upstream.
class MutationScope {
  int _pending = 0;
  Future<void> _tail = Future<void>.value();

  /// Mutations queued or in flight, the one calling [run] included.
  int get pending => _pending;

  /// Runs [mutation] after the previous one settled. [onSettled] receives
  /// `isLast` = no later mutation is queued behind this one (TanStack's
  /// `isMutating() > 1` check, which counts the settling mutation itself).
  Future<R> run<R>(
    Future<R> Function() mutation, {
    FutureOr<void> Function({required bool isLast})? onSettled,
  }) {
    _pending += 1;
    final completer = Completer<R>();
    final previous = _tail;
    _tail = previous.then((_) async {
      try {
        final result = await mutation();
        await _settle(onSettled);
        completer.complete(result);
      } on Object catch (error, stackTrace) {
        await _settle(onSettled);
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _settle(
    FutureOr<void> Function({required bool isLast})? onSettled,
  ) async {
    try {
      await onSettled?.call(isLast: _pending == 1);
    } finally {
      _pending -= 1;
    }
  }
}

/// `createOptimisticMutationHandlers` / the hand-written `onMutate` →
/// `onError` → `onSettled` triple of the React hooks, over one cached list:
/// cancel in-flight fetches of [key], snapshot, apply [update], run
/// [mutation], call [onSuccess] with the result (replace the temp row),
/// restore the snapshot on failure, and invalidate every prefix in
/// [invalidate] once settled either way.
Future<R> optimisticMutation<T, R>(
  QueryClient queryClient, {
  required QueryKey key,
  required T Function(T? previous) update,
  required Future<R> Function() mutation,
  List<QueryKey> invalidate = const [],
  void Function(R result)? onSuccess,
  void Function(T? snapshot)? onError,
  void Function()? onApplied,
}) async {
  queryClient.cancelQueries(key);
  final snapshot = queryClient.getQueryData<T>(key);
  queryClient.setQueryData<T>(key, update(snapshot));
  onApplied?.call();
  try {
    final result = await mutation();
    onSuccess?.call(result);
    onApplied?.call();
    return result;
  } on Object {
    if (onError != null) {
      onError(snapshot);
    } else if (snapshot != null) {
      queryClient.setQueryData<T>(key, snapshot);
    } else {
      queryClient.removeQueries(key);
    }
    onApplied?.call();
    rethrow;
  } finally {
    for (final prefix in invalidate) {
      await queryClient.invalidateQueries(prefix);
    }
  }
}

/// The settle step alone, for mutations without an optimistic update
/// (`onSuccess`/`onSettled` invalidation of plain mutations).
Future<R> settledMutation<R>(
  QueryClient queryClient, {
  required Future<R> Function() mutation,
  List<QueryKey> invalidate = const [],
  List<QueryKey> invalidateOnSuccess = const [],
}) async {
  try {
    final result = await mutation();
    for (final prefix in invalidateOnSuccess) {
      await queryClient.invalidateQueries(prefix);
    }
    return result;
  } finally {
    for (final prefix in invalidate) {
      await queryClient.invalidateQueries(prefix);
    }
  }
}
