import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// The cached value of the session query. `Query<T>` cannot store a bare
/// `null` (a signed-out read must replace a live session), so the session
/// is wrapped.
class SessionSnapshot extends Equatable {
  const SessionSnapshot(this.session);

  final AuthSession? session;

  @override
  List<Object?> get props => [
    session?.user.id,
    session?.user.role,
    session?.session?.impersonatedBy,
    session?.session?.activeOrganizationId,
    session?.user.email,
  ];
}

/// State of [SessionCubit]: the Better Auth session (`null` when signed
/// out), its load state and whether a live session was ever observed.
class SessionState extends Equatable {
  const SessionState({
    this.session = const LoadState(),
    this.sawSession = false,
  });

  final LoadState<SessionSnapshot> session;

  /// A live session was seen in this app instance; arms [isExpired].
  final bool sawSession;

  AuthSession? get current => session.data?.session;
  AuthUser? get user => current?.user;
  bool get isSignedIn => user != null;

  /// The query has not settled yet (`isPending`).
  bool get isPending =>
      session.status == LoadStatus.idle || session.status == LoadStatus.loading;

  /// `session.ts` error → the picker's error card; never an expiry.
  bool get hasError => session.hasError;

  /// `SessionExpired` (`session-expired.tsx:36-44`): a live session settled
  /// to `null` without an error.
  bool get isExpired =>
      sawSession && session.isReady && !hasError && current == null;

  /// Platform admin (`user.role === 'admin'`, plan §5).
  bool get isSuperuser => user?.role == 'admin';
  bool get isImpersonated => current?.isImpersonated ?? false;
  String? get activeOrganizationId => current?.session?.activeOrganizationId;

  SessionState copyWith({
    LoadState<SessionSnapshot>? session,
    bool? sawSession,
  }) => SessionState(
    session: session ?? this.session,
    sawSession: sawSession ?? this.sawSession,
  );

  @override
  List<Object?> get props => [session, sawSession];
}

/// `SessionProvider` + `useSessionQuery` (spec §4.1, §7): key
/// `['session','detail']`, stale 5 min, no retry, focus refetch through
/// [onFocus] (the only web query that refetches on focus), a 60 s poll
/// bypassing the cookie cache while impersonating, and [refresh] for the
/// post-mutation reads (invite accept, signup, verify, `?upgraded=true`).
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required AuthRepository auth,
    required QueryClient queryClient,
    Duration impersonationInterval = StaleTimes.impersonationRefetch,
  }) : _auth = auth,
       _queryClient = queryClient,
       _impersonationInterval = impersonationInterval,
       super(const SessionState());

  final AuthRepository _auth;
  final QueryClient _queryClient;
  final Duration _impersonationInterval;
  QueryBinding<SessionSnapshot>? _binding;
  Timer? _impersonationTimer;

  QueryKey get _key => SessionKeys.detail();

  Query<SessionSnapshot> _query() {
    final existing = _binding;
    if (existing != null) return existing.query;
    final query = _queryClient.query<SessionSnapshot>(
      _key,
      (token) async => SessionSnapshot(
        await _auth.getSession(
          disableCookieCache:
              _queryClient
                  .getQueryData<SessionSnapshot>(_key)
                  ?.session
                  ?.isImpersonated ??
              false,
          cancelToken: token,
        ),
      ),
      staleTime: StaleTimes.session,
    );
    _binding = QueryBinding(query, _onQueryState);
    _onQueryState(query.state);
    return query;
  }

  void _onQueryState(QueryState<SessionSnapshot> queryState) {
    if (isClosed) return;
    final load = LoadState<SessionSnapshot>.fromQuery(queryState);
    final sawSession = state.sawSession || load.data?.session?.user != null;
    emit(state.copyWith(session: load, sawSession: sawSession));
    _syncImpersonationPolling(load.data?.session?.isImpersonated ?? false);
  }

  void _syncImpersonationPolling(bool impersonated) {
    if (impersonated && _impersonationTimer == null) {
      _impersonationTimer = Timer.periodic(_impersonationInterval, (_) {
        unawaited(_binding?.refetch().then((_) {}, onError: (Object _) {}));
      });
    } else if (!impersonated) {
      _impersonationTimer?.cancel();
      _impersonationTimer = null;
    }
  }

  /// Loads the session (cached within the stale window).
  Future<AuthSession?> load() async {
    try {
      _query();
      return (await _binding!.fetch()).session;
    } on ApiClientError {
      return null;
    } on ApiNetworkError {
      return null;
    }
  }

  /// `refreshSessionQuery`: cancels, reads past the cookie cache and
  /// overwrites the cache entry. Throws on failure like upstream.
  Future<AuthSession?> refresh({bool bypassCookieCache = true}) async {
    final query = _query();
    _queryClient.cancelQueries(_key);
    final fresh = await _auth.getSession(disableCookieCache: bypassCookieCache);
    query.setData(SessionSnapshot(fresh));
    _binding?.sync();
    return fresh;
  }

  /// The window-focus hook (`refetchOnWindowFocus: true` for this query
  /// only): refetches when the 5-minute window has passed.
  Future<void> onFocus() async {
    final query = _query();
    if (!query.isStale || query.state.isFetching) return;
    try {
      await _binding!.refetch();
    } on Object {
      // The error is on the query state; focus refetches never throw.
    }
  }

  /// Seeds the cache after a sign-in/verify response carried the user.
  void setSession(AuthSession? session) {
    _query().setData(SessionSnapshot(session));
    _binding?.sync();
  }

  /// Store reset: drops the cached session and the "saw a session" arm.
  void reset() {
    _impersonationTimer?.cancel();
    _impersonationTimer = null;
    _binding?.dispose();
    _binding = null;
    _queryClient.removeQueries(_key);
    if (!isClosed) emit(const SessionState());
  }

  @override
  Future<void> close() {
    _impersonationTimer?.cancel();
    _binding?.dispose();
    return super.close();
  }
}
