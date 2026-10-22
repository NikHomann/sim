import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_navigator.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';

/// `SIM_CLI_CLIENT_ID`.
const String simCliClientId = 'sim-cli';

/// `OAUTH_SCOPES` in declaration order with `OAUTH_SCOPE_DESCRIPTIONS`
/// (`lib/auth/oauth-provider.ts`).
const Map<String, String> oauthScopeDescriptions = <String, String>{
  'offline_access': 'Stay signed in without asking again',
  'api:read': 'Read your workspaces, workflows, files, tables, and logs',
  'api:write':
      'Read, create, change, run, and delete resources in your workspaces',
  'search:read':
      'Search and read documents you can access, and start private Sim Search conversations',
};

bool _satisfies(List<String> granted, String required) {
  if (granted.contains(required)) return true;
  if (required == 'search:read') {
    return granted.contains('api:read') || granted.contains('api:write');
  }
  return required == 'api:read' && granted.contains('api:write');
}

/// `visibleOAuthScopes`: `api:read` hidden under `api:write`; `search:read`
/// hidden when `api:read` is satisfied; declaration order.
List<String> visibleOAuthScopes(List<String> granted) {
  final implied = granted.contains('api:write') ? 'api:read' : null;
  return oauthScopeDescriptions.keys
      .where(
        (scope) =>
            scope != implied &&
            !(scope == 'search:read' && _satisfies(granted, 'api:read')) &&
            granted.contains(scope),
      )
      .toList();
}

/// `describeDestination`: the redirect host, loopback hosts as "this
/// computer"; null when unparsable.
String? describeConsentDestination(String? redirectUri) {
  if (redirectUri == null || redirectUri.isEmpty) return null;
  final uri = Uri.tryParse(redirectUri);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  final host = uri.host;
  if (host == '127.0.0.1' || host == '[::1]' || host == '::1') {
    return 'this computer';
  }
  return host;
}

/// `REFUSAL_MESSAGES`.
const Map<String, String> consentRefusalMessages = <String, String>{
  'expired':
      'This authorization request has expired. Start sign-in again from the app.',
  'missing': 'The authorization request is missing its client identifier.',
  'tampered': 'This authorization request was altered on its way here.',
  'unsigned': 'This authorization request did not come from Sim.',
};

enum ConsentPhase { loading, refusal, ready }

/// State of `/oauth/consent` (`auth-oauth-pages.md` B).
class ConsentState extends Equatable {
  const ConsentState({
    this.phase = ConsentPhase.loading,
    this.refusalMessage,
    this.appName = '',
    this.isCli = false,
    this.scopes = const <String>[],
    this.destination,
    this.email = '',
    this.deciding,
    this.switching = false,
    this.errorMessage,
  });

  final ConsentPhase phase;
  final String? refusalMessage;
  final String appName;
  final bool isCli;
  final List<String> scopes;
  final String? destination;
  final String email;

  /// `true` while Allow is in flight, `false` for Deny, null otherwise.
  final bool? deciding;
  final bool switching;
  final String? errorMessage;

  bool get isPending => deciding != null || switching;

  ConsentState copyWith({
    ConsentPhase? phase,
    String? Function()? refusalMessage,
    String? appName,
    bool? isCli,
    List<String>? scopes,
    String? Function()? destination,
    String? email,
    bool? Function()? deciding,
    bool? switching,
    String? Function()? errorMessage,
  }) => ConsentState(
    phase: phase ?? this.phase,
    refusalMessage: refusalMessage == null
        ? this.refusalMessage
        : refusalMessage(),
    appName: appName ?? this.appName,
    isCli: isCli ?? this.isCli,
    scopes: scopes ?? this.scopes,
    destination: destination == null ? this.destination : destination(),
    email: email ?? this.email,
    deciding: deciding == null ? this.deciding : deciding(),
    switching: switching ?? this.switching,
    errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
  );

  @override
  List<Object?> get props => [
    phase,
    refusalMessage,
    appName,
    isCli,
    scopes,
    destination,
    email,
    deciding,
    switching,
    errorMessage,
  ];
}

/// Port of `consent/page.tsx` (checks) + `consent-view.tsx` (behaviour).
class ConsentCubit extends Cubit<ConsentState> {
  ConsentCubit({
    required AuthApi api,
    required AuthNavigator navigator,
    required Map<String, List<String>> queryAll,
    required String rawQuery,
    DateTime Function()? now,
  }) : _api = api,
       _navigator = navigator,
       _queryAll = queryAll,
       _rawQuery = rawQuery,
       _now = now ?? DateTime.now,
       super(const ConsentState());

  final AuthApi _api;
  final AuthNavigator _navigator;

  /// Every query value (repeats included), for the tamper check.
  final Map<String, List<String>> _queryAll;

  /// The signed authorize query as it arrived, forwarded as `oauth_query`.
  final String _rawQuery;
  final DateTime Function() _now;

  String? _single(String key) {
    final values = _queryAll[key];
    return values == null || values.isEmpty ? null : values.first;
  }

  /// `URLSearchParams` of every single-valued string param.
  String get _signInQuery => encodeSearchParams(<String, String>{
    for (final entry in _queryAll.entries)
      if (entry.value.length == 1) entry.key: entry.value.first,
  });

  /// `tampered` → `unsigned` → `expired`, else null.
  String? _refusal() {
    final tampered = _queryAll.entries.any(
      (entry) => entry.key != 'ba_param' && entry.value.length > 1,
    );
    if (tampered) return 'tampered';
    if (_single('sig') == null) return 'unsigned';
    final exp = double.tryParse(_single('exp') ?? '');
    if (exp == null || !exp.isFinite) return 'expired';
    if (exp * 1000 < _now().millisecondsSinceEpoch) return 'expired';
    return null;
  }

  Future<void> load() async {
    AuthSession? session;
    try {
      session = await _api.getSession();
    } on Exception {
      session = null;
    }
    if (isClosed) return;
    if (session == null) {
      _navigator.openTopLevel('/oauth/sign-in?$_signInQuery');
      return;
    }
    emit(state.copyWith(email: session.user.email));
    final refusal = _refusal();
    final clientId = _single('client_id');
    if (refusal != null || clientId == null || clientId.isEmpty) {
      emit(
        state.copyWith(
          phase: ConsentPhase.refusal,
          refusalMessage: () => consentRefusalMessages[refusal ?? 'missing'],
        ),
      );
      return;
    }
    OAuthPublicClient client;
    try {
      client = await _api.oauthPublicClient(clientId: clientId);
    } on Exception catch (error) {
      if (isClosed) return;
      final message = error is ApiClientError && error.message.isNotEmpty
          ? error.message
          : 'Sim could not identify the app. Start again from the app.';
      emit(
        state.copyWith(
          phase: ConsentPhase.refusal,
          refusalMessage: () => message,
        ),
      );
      return;
    }
    if (isClosed) return;
    final name = client.name?.trim() ?? '';
    if (name.isEmpty) {
      emit(
        state.copyWith(
          phase: ConsentPhase.refusal,
          refusalMessage: () =>
              'Sim could not identify the app. Start again from the app asking for access.',
        ),
      );
      return;
    }
    final granted = (_single('scope') ?? '')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();
    emit(
      state.copyWith(
        phase: ConsentPhase.ready,
        appName: name,
        isCli: clientId == simCliClientId,
        scopes: visibleOAuthScopes(granted),
        destination: () => describeConsentDestination(_single('redirect_uri')),
      ),
    );
  }

  /// Allow / Deny: `POST /api/auth/oauth2/consent`, then leave for the
  /// client's `redirect_uri`.
  Future<void> decide({required bool accept}) async {
    if (state.isPending) return;
    emit(state.copyWith(deciding: () => accept, errorMessage: () => null));
    try {
      final url = await _api.oauthConsent(
        accept: accept,
        oauthQuery: _rawQuery,
      );
      if (isClosed) return;
      _navigator.openTopLevel(url);
    } on Exception catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          deciding: () => null,
          errorMessage: () =>
              error is ApiClientError && error.message.isNotEmpty
              ? error.message
              : 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  /// "Use another account": sign out, then restart at the login bridge with
  /// `prompt=login consent`.
  Future<void> switchAccount() async {
    if (state.isPending) return;
    emit(state.copyWith(switching: true, errorMessage: () => null));
    try {
      await _api.signOut();
      if (isClosed) return;
      final query = encodeSearchParams(<String, String>{
        for (final entry in _queryAll.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.first,
        'prompt': 'login consent',
      });
      _navigator.openTopLevel('/oauth/sign-in?$query');
    } on Exception catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          switching: false,
          errorMessage: () =>
              error is ApiClientError && error.message.isNotEmpty
              ? error.message
              : 'Could not sign out. Please try again.',
        ),
      );
    }
  }

  void goHome() => _navigator.openTopLevel('/');
}
