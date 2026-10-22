import 'package:equatable/equatable.dart';
import 'package:sim_api/sim_api.dart';

/// Lifecycle of one server-data slice inside a cubit state.
enum LoadStatus { idle, loading, ready, error }

/// A `Query<T>` snapshot as cubit state: the data (kept across background
/// refetches and errors, like React Query), the status and the last error.
class LoadState<T> extends Equatable {
  const LoadState({
    this.status = LoadStatus.idle,
    this.data,
    this.error,
    this.isFetching = false,
  });

  const LoadState.ready(T data) : this(status: LoadStatus.ready, data: data);

  /// The cubit-side view of a query snapshot.
  factory LoadState.fromQuery(QueryState<T> query) => LoadState(
    status: switch (query.status) {
      QueryStatus.idle => LoadStatus.idle,
      QueryStatus.loading => LoadStatus.loading,
      QueryStatus.success => LoadStatus.ready,
      QueryStatus.error => LoadStatus.error,
    },
    data: query.data,
    error: query.error,
    isFetching: query.isFetching,
  );

  final LoadStatus status;
  final T? data;
  final Object? error;
  final bool isFetching;

  bool get hasData => status == LoadStatus.ready || data != null;

  /// The initial load (no data yet).
  bool get isLoading => status == LoadStatus.loading && data == null;
  bool get isReady => status == LoadStatus.ready;
  bool get hasError => status == LoadStatus.error;

  /// The error as an API error, when it is one.
  ApiClientError? get apiError =>
      error is ApiClientError ? error! as ApiClientError : null;

  /// A 401 after a live session: the auth cookies are stale
  /// (`isStaleSessionError`, `workspace/page.tsx`).
  bool get isUnauthorized => apiError?.status == 401;

  LoadState<T> copyWith({
    LoadStatus? status,
    T? data,
    bool clearData = false,
    Object? error,
    bool clearError = false,
    bool? isFetching,
  }) => LoadState<T>(
    status: status ?? this.status,
    data: clearData ? null : (data ?? this.data),
    error: clearError ? null : (error ?? this.error),
    isFetching: isFetching ?? this.isFetching,
  );

  @override
  List<Object?> get props => [status, data, error, isFetching];
}
