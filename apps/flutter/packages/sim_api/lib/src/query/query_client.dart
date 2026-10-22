import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:sim_api/src/client/api_client_error.dart';

/// A cache key shaped like the React Query keys (`['workflows', workspaceId]`).
typedef QueryKey = List<Object?>;

/// Loads the data of one query; cancel through [cancelToken].
typedef QueryFetcher<T> = Future<T> Function(CancelToken cancelToken);

/// A stable string for a key: JSON with map keys sorted, as React Query
/// hashes keys.
String queryHash(QueryKey key) => jsonEncode(_canonical(key));

Object? _canonical(Object? value) {
  if (value is Map) {
    final sorted = value.keys.map((k) => '$k').toList()..sort();
    return {for (final k in sorted) k: _canonical(value[k])};
  }
  if (value is List) return value.map(_canonical).toList();
  if (value is Enum) return value.name;
  return value;
}

/// Whether [key] starts with [prefix], element by element (maps and lists
/// compared structurally).
bool queryKeyMatches(QueryKey key, QueryKey prefix) {
  if (prefix.length > key.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (queryHash([key[i]]) != queryHash([prefix[i]])) return false;
  }
  return true;
}

enum QueryStatus { idle, loading, success, error }

/// A snapshot of one query.
@immutable
class QueryState<T> {
  const QueryState({
    this.status = QueryStatus.idle,
    this.data,
    this.error,
    this.updatedAt,
    this.isFetching = false,
  });

  final QueryStatus status;
  final T? data;
  final Object? error;

  /// When [data] was last set (fetch or [QueryClient.setQueryData]).
  final DateTime? updatedAt;

  /// A fetch is in flight (initial or background).
  final bool isFetching;

  bool get hasData => status == QueryStatus.success || updatedAt != null;
  bool get isLoading => status == QueryStatus.loading && updatedAt == null;

  QueryState<T> copyWith({
    QueryStatus? status,
    T? data,
    bool clearData = false,
    Object? error,
    bool clearError = false,
    DateTime? updatedAt,
    bool? isFetching,
  }) => QueryState<T>(
    status: status ?? this.status,
    data: clearData ? null : (data ?? this.data),
    error: clearError ? null : (error ?? this.error),
    updatedAt: updatedAt ?? this.updatedAt,
    isFetching: isFetching ?? this.isFetching,
  );
}

/// An observer handle on one cached query. Dispose it when the owning cubit
/// closes; the entry stays cached for the next observer.
class Query<T> {
  Query._(this._entry, this.client);

  final _Entry<T> _entry;
  final QueryClient client;

  QueryKey get key => _entry.key;
  QueryState<T> get state => _entry.state;
  Stream<QueryState<T>> get states => _entry.states;
  bool get isStale => _entry.isStale(client._now());

  /// The data, fetching when stale or absent; the in-flight fetch is shared.
  Future<T> fetch({bool force = false}) => _entry.fetch(client, force: force);

  /// Always fetches.
  Future<T> refetch() => fetch(force: true);

  /// Cancels the in-flight fetch, if any.
  void cancel() => _entry.cancel();

  void setData(T data) => _entry.setData(data, client._now());

  void dispose() => _entry.observers -= 1;
}

/// Server-data cache (plan §4.1): keyed queries with `staleTime`, in-flight
/// dedupe, invalidation by key prefix, cancellation through Dio cancel
/// tokens, focus refetch and an optimistic-update helper.
class QueryClient {
  QueryClient({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static QueryClient? _instance;

  /// The app-wide client (replaceable in tests).
  // ignore: prefer_constructors_over_static_methods
  static QueryClient get instance => _instance ??= QueryClient();
  static set instance(QueryClient client) => _instance = client;

  final DateTime Function() _now;
  final Map<String, _Entry<dynamic>> _entries = {};

  /// An observer on the query at [key]. The fetcher and [staleTime] of the
  /// first call are kept; later calls reuse the cached entry.
  Query<T> query<T>(
    QueryKey key,
    QueryFetcher<T> fetcher, {
    Duration staleTime = Duration.zero,
  }) {
    final entry = _entry<T>(key, fetcher, staleTime)..observers += 1;
    return Query._(entry, this);
  }

  /// One-shot fetch through the cache (fresh data is returned without a
  /// request; an in-flight fetch is shared).
  Future<T> fetchQuery<T>(
    QueryKey key,
    QueryFetcher<T> fetcher, {
    Duration staleTime = Duration.zero,
    bool force = false,
  }) => _entry<T>(key, fetcher, staleTime).fetch(this, force: force);

  T? getQueryData<T>(QueryKey key) {
    final entry = _entries[queryHash(key)];
    return entry?.state.data as T?;
  }

  QueryState<T>? getQueryState<T>(QueryKey key) {
    final entry = _entries[queryHash(key)];
    return entry is _Entry<T> ? entry.state : null;
  }

  void setQueryData<T>(QueryKey key, T data) {
    final entry = _entries[queryHash(key)];
    if (entry is _Entry<T>) {
      entry.setData(data, _now());
    } else if (entry == null) {
      _entries[queryHash(key)] = _Entry<T>(key, null, Duration.zero)
        ..setData(data, _now());
    } else {
      throw StateError('query ${queryHash(key)} holds another type');
    }
  }

  /// Marks every query under [prefix] stale and refetches the observed ones.
  Future<void> invalidateQueries(
    QueryKey prefix, {
    bool refetchActive = true,
  }) async {
    final futures = <Future<void>>[];
    for (final entry in _matching(prefix)) {
      entry.invalidate();
      if (refetchActive && entry.observers > 0 && entry.fetcher != null) {
        futures.add(
          entry.fetch(this, force: true).then((_) {}, onError: (_) {}),
        );
      }
    }
    await Future.wait(futures);
  }

  /// Cancels in-flight fetches under [prefix].
  void cancelQueries(QueryKey prefix) {
    for (final entry in _matching(prefix)) {
      entry.cancel();
    }
  }

  /// Drops cached entries under [prefix] (observers see an idle state).
  void removeQueries(QueryKey prefix) {
    for (final entry in _matching(prefix).toList()) {
      entry
        ..cancel()
        ..reset();
      _entries.remove(queryHash(entry.key));
    }
  }

  /// The focus hook: refetches stale observed queries, as React Query's
  /// `refetchOnWindowFocus` does. The app calls it from its lifecycle or
  /// `visibilitychange` listener.
  Future<void> onFocus() async {
    final futures = <Future<void>>[];
    for (final entry in _entries.values) {
      if (entry.observers > 0 &&
          entry.fetcher != null &&
          entry.isStale(_now()) &&
          !entry.state.isFetching) {
        futures.add(
          entry.fetch(this, force: true).then((_) {}, onError: (_) {}),
        );
      }
    }
    await Future.wait(futures);
  }

  /// Optimistic update: cancels fetches of [key], applies [update] to the
  /// cached data, runs [mutation], and rolls the data back when it throws.
  /// Pass [invalidateAfter] to refetch once the mutation settled either way.
  Future<R> optimisticUpdate<T, R>({
    required QueryKey key,
    required T Function(T? previous) update,
    required Future<R> Function() mutation,
    bool invalidateAfter = false,
  }) async {
    cancelQueries(key);
    final hash = queryHash(key);
    final entry = _entries[hash];
    final previous = entry is _Entry<T> ? entry.state : null;
    setQueryData<T>(key, update(previous?.data));
    try {
      return await mutation();
    } on Object {
      final current = _entries[hash];
      if (current is _Entry<T>) {
        if (previous != null) {
          current.restore(previous);
        } else {
          current.reset();
        }
      }
      rethrow;
    } finally {
      if (invalidateAfter) await invalidateQueries(key);
    }
  }

  /// Cancels everything and empties the cache (sign-out store reset).
  void clear() {
    for (final entry in _entries.values) {
      entry
        ..cancel()
        ..reset();
    }
    _entries.clear();
  }

  _Entry<T> _entry<T>(
    QueryKey key,
    QueryFetcher<T>? fetcher,
    Duration staleTime,
  ) {
    final hash = queryHash(key);
    final existing = _entries[hash];
    if (existing == null) {
      return _entries[hash] = _Entry<T>(key, fetcher, staleTime);
    }
    if (existing is! _Entry<T>) {
      throw StateError('query $hash holds another type');
    }
    existing.fetcher ??= fetcher;
    return existing;
  }

  Iterable<_Entry<dynamic>> _matching(QueryKey prefix) =>
      _entries.values.where((e) => queryKeyMatches(e.key, prefix));
}

class _Entry<T> {
  _Entry(this.key, this.fetcher, this.staleTime);

  final QueryKey key;
  final Duration staleTime;
  QueryFetcher<T>? fetcher;
  int observers = 0;
  QueryState<T> state = QueryState<T>();
  final _controller = StreamController<QueryState<T>>.broadcast();
  Future<T>? _inFlight;
  CancelToken? _cancelToken;
  bool _invalidated = false;

  Stream<QueryState<T>> get states => _controller.stream;

  void _emit(QueryState<T> next) {
    state = next;
    _controller.add(next);
  }

  bool isStale(DateTime now) {
    if (_invalidated) return true;
    final updatedAt = state.updatedAt;
    if (updatedAt == null) return true;
    return now.difference(updatedAt) >= staleTime;
  }

  void invalidate() => _invalidated = true;

  void setData(T data, DateTime now) {
    _invalidated = false;
    _emit(
      state.copyWith(
        status: QueryStatus.success,
        data: data,
        clearError: true,
        updatedAt: now,
      ),
    );
  }

  void restore(QueryState<T> previous) => _emit(previous);

  void reset() => _emit(QueryState<T>());

  void cancel() {
    final token = _cancelToken;
    if (token != null && !token.isCancelled) token.cancel('cancelled');
    _cancelToken = null;
    _inFlight = null;
    if (state.isFetching) _emit(state.copyWith(isFetching: false));
  }

  Future<T> fetch(QueryClient client, {required bool force}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final now = client._now();
    if (!force && !isStale(now) && state.hasData) {
      return Future.value(state.data as T);
    }
    final fetcher = this.fetcher;
    if (fetcher == null) {
      return Future.error(StateError('query ${queryHash(key)} has no fetcher'));
    }
    final token = CancelToken();
    _cancelToken = token;
    _emit(
      state.copyWith(
        status: state.updatedAt == null ? QueryStatus.loading : state.status,
        isFetching: true,
      ),
    );
    final future = fetcher(token).then(
      (data) {
        if (_cancelToken != token) {
          // Cancelled or superseded while in flight: keep the current state.
          return data;
        }
        _cancelToken = null;
        _inFlight = null;
        setData(data, client._now());
        _emit(state.copyWith(isFetching: false));
        return data;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_cancelToken == token) {
          _cancelToken = null;
          _inFlight = null;
          if (error is! ApiCancelledError) {
            _emit(
              state.copyWith(
                status: QueryStatus.error,
                error: error,
                isFetching: false,
              ),
            );
          } else {
            _emit(state.copyWith(isFetching: false));
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _inFlight = future;
    return future;
  }
}
