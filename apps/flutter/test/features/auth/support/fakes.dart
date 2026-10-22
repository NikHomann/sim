import 'dart:async';

import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_navigator.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/auth_timers.dart';

/// The origin the fake pages run under.
const String testOrigin = 'http://localhost:3001';

AuthUser testUser({String email = 'ada@example.com'}) =>
    AuthUser(id: 'user-1', email: email, emailVerified: true);

AuthSession testSession({String email = 'ada@example.com'}) =>
    AuthSession(user: testUser(email: email));

ApiClientError apiError(
  int status, {
  String message = 'Request failed',
  String? code,
  Object? body,
}) => ApiClientError(status: status, message: message, code: code, body: body);

/// One recorded call of [FakeAuthApi].
class ApiCall {
  const ApiCall(this.name, this.args);

  final String name;
  final Map<String, Object?> args;

  @override
  String toString() => '$name $args';
}

/// Scripted [AuthApi]: each method returns its configured result or throws
/// its configured error, recording the call either way.
class FakeAuthApi implements AuthApi {
  final List<ApiCall> calls = <ApiCall>[];

  /// When set, every answer waits for it (to observe loading states).
  Completer<void>? gate;

  AuthPageOptions options = const AuthPageOptions();
  Object? optionsError;
  AuthSession? session;
  Object? sessionError;
  AuthUser? signInResult;
  Object? signInError;
  SignUpResult signUpResult = SignUpResult(user: testUser());
  Object? signUpError;
  String socialUrl = 'https://accounts.example.com/oauth';
  Object? socialError;
  Object? forgetPasswordError;
  Object? resetPasswordError;
  Object? verifyOtpError;
  Object? resendError;
  Object? signOutError;
  String ssoProviderId = 'okta-1';
  Object? resolveSsoError;
  String ssoUrl = 'https://idp.example.com/saml';
  Object? ssoSignInError;
  OAuthPublicClient publicClient = const OAuthPublicClient(
    clientId: 'app-1',
    name: 'Acme CLI',
  );
  Object? publicClientError;
  String consentUrl = 'http://127.0.0.1:8123/callback?code=abc';
  Object? consentError;
  InviteResponse inviteResponse = const InviteResponse(
    invitation: null,
    joinPreview: null,
  );
  Object? inviteError;
  InviteAcceptResult acceptResult = const InviteAcceptResult(
    redirectPath: '/workspace/ws-1/home',
  );
  Object? acceptError;

  /// Sessions returned by successive [getSession] calls (the last repeats).
  List<AuthSession?>? sessionSequence;
  int _sessionCalls = 0;

  List<ApiCall> callsNamed(String name) =>
      calls.where((c) => c.name == name).toList();

  Future<T> _answer<T>(
    String name,
    Map<String, Object?> args,
    Object? error,
    T value,
  ) {
    calls.add(ApiCall(name, args));
    final pending = gate?.future ?? Future<void>.value();
    return pending.then(
      (_) => error != null ? Future<T>.error(error) : Future<T>.value(value),
    );
  }

  @override
  Future<AuthPageOptions> loadOptions() =>
      _answer('loadOptions', const {}, optionsError, options);

  @override
  Future<AuthSession?> getSession({bool disableCookieCache = false}) {
    final sequence = sessionSequence;
    var value = session;
    if (sequence != null && sequence.isNotEmpty) {
      value = sequence[_sessionCalls.clamp(0, sequence.length - 1)];
    }
    _sessionCalls++;
    return _answer(
      'getSession',
      {'disableCookieCache': disableCookieCache},
      sessionError,
      value,
    );
  }

  @override
  Future<AuthUser?> signInEmail({
    required String email,
    required String password,
    required String callbackUrl,
  }) => _answer(
    'signInEmail',
    {'email': email, 'password': password, 'callbackUrl': callbackUrl},
    signInError,
    signInResult ?? testUser(email: email),
  );

  @override
  Future<SignUpResult> signUpEmail({
    required String email,
    required String password,
    required String name,
    String? captchaToken,
  }) => _answer(
    'signUpEmail',
    {
      'email': email,
      'password': password,
      'name': name,
      'captchaToken': captchaToken,
    },
    signUpError,
    signUpResult,
  );

  @override
  Future<String> startSocialSignIn({
    required String provider,
    required String callbackUrl,
  }) => _answer(
    'startSocialSignIn',
    {'provider': provider, 'callbackUrl': callbackUrl},
    socialError,
    socialUrl,
  );

  @override
  Future<void> forgetPassword({
    required String email,
    required String redirectTo,
  }) => _answer(
    'forgetPassword',
    {'email': email, 'redirectTo': redirectTo},
    forgetPasswordError,
    null,
  );

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _answer(
    'resetPassword',
    {'token': token, 'newPassword': newPassword},
    resetPasswordError,
    null,
  );

  @override
  Future<AuthUser?> verifyEmailOtp({
    required String email,
    required String otp,
  }) => _answer(
    'verifyEmailOtp',
    {'email': email, 'otp': otp},
    verifyOtpError,
    testUser(email: email),
  );

  @override
  Future<void> sendVerificationOtp({required String email}) =>
      _answer('sendVerificationOtp', {'email': email}, resendError, null);

  @override
  Future<void> signOut() => _answer('signOut', const {}, signOutError, null);

  @override
  Future<String> resolveSsoProvider({
    required String email,
    String? providerId,
  }) => _answer(
    'resolveSsoProvider',
    {'email': email, 'providerId': providerId},
    resolveSsoError,
    ssoProviderId,
  );

  @override
  Future<String> startSsoSignIn({
    required String email,
    required String providerId,
    required String callbackUrl,
    required String errorCallbackUrl,
  }) => _answer(
    'startSsoSignIn',
    {
      'email': email,
      'providerId': providerId,
      'callbackUrl': callbackUrl,
      'errorCallbackUrl': errorCallbackUrl,
    },
    ssoSignInError,
    ssoUrl,
  );

  @override
  Future<OAuthPublicClient> oauthPublicClient({required String clientId}) =>
      _answer(
        'oauthPublicClient',
        {'clientId': clientId},
        publicClientError,
        publicClient,
      );

  @override
  Future<String> oauthConsent({
    required bool accept,
    required String oauthQuery,
  }) => _answer(
    'oauthConsent',
    {'accept': accept, 'oauthQuery': oauthQuery},
    consentError,
    consentUrl,
  );

  @override
  Future<InviteResponse> getInvitation({required String id, String? token}) =>
      _answer(
        'getInvitation',
        {'id': id, 'token': token},
        inviteError,
        inviteResponse,
      );

  @override
  Future<InviteAcceptResult> acceptInvitation({
    required String id,
    String? token,
    List<String>? disclosedWorkspaceIds,
    String? disclosedOutcome,
  }) => _answer(
    'acceptInvitation',
    {
      'id': id,
      'token': token,
      'disclosedWorkspaceIds': disclosedWorkspaceIds,
      'disclosedOutcome': disclosedOutcome,
    },
    acceptError,
    acceptResult,
  );

  @override
  String absoluteUrl(String path) => '$testOrigin$path';
}

/// Records every navigation.
class FakeAuthNavigator extends AuthNavigator {
  final List<String> gone = <String>[];
  final List<String> topLevel = <String>[];
  final List<String> replaced = <String>[];
  final List<String> newTabs = <String>[];
  int reloads = 0;
  int closes = 0;

  @override
  void go(String location) => gone.add(location);

  @override
  void openTopLevel(String url) => topLevel.add(url);

  @override
  void replaceTopLevel(String url) => replaced.add(url);

  @override
  void openNewTab(String url) => newTabs.add(url);

  @override
  void reload() => reloads++;

  @override
  void closeWindow() => closes++;
}

class _FakeTimer implements Timer {
  _FakeTimer(this.due, this.period, this.callback);

  Duration due;
  final Duration? period;
  final void Function(Timer) callback;
  bool _active = true;
  int _tick = 0;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

/// Hand-driven [AuthTimers]: nothing fires until [elapse] moves the clock.
class FakeAuthTimers implements AuthTimers {
  final List<_FakeTimer> _timers = <_FakeTimer>[];
  Duration _now = Duration.zero;

  Duration get now => _now;

  int get pendingCount => _timers.where((t) => t.isActive).length;

  @override
  Timer schedule(Duration duration, void Function() callback) {
    final timer = _FakeTimer(_now + duration, null, (_) => callback());
    _timers.add(timer);
    return timer;
  }

  @override
  Timer periodic(Duration period, void Function(Timer timer) callback) {
    final timer = _FakeTimer(_now + period, period, callback);
    _timers.add(timer);
    return timer;
  }

  /// Advances the clock, firing due timers in order.
  void elapse(Duration duration) {
    final target = _now + duration;
    while (true) {
      _FakeTimer? next;
      for (final timer in _timers) {
        if (!timer.isActive || timer.due > target) continue;
        if (next == null || timer.due < next.due) next = timer;
      }
      if (next == null) break;
      _now = next.due;
      next._tick++;
      final period = next.period;
      if (period == null) {
        next._active = false;
      } else {
        next.due = next.due + period;
      }
      next.callback(next);
    }
    _now = target;
    _timers.removeWhere((t) => !t.isActive);
  }
}

/// The fake dependency set a page under test receives.
class FakeAuthDeps {
  FakeAuthDeps({
    FakeAuthApi? api,
    FakeAuthNavigator? navigator,
    MemoryAuthSessionStore? sessionStore,
    MemoryAuthSessionStore? localStore,
    FakeAuthTimers? timers,
  }) : api = api ?? FakeAuthApi(),
       navigator = navigator ?? FakeAuthNavigator(),
       sessionStore = sessionStore ?? MemoryAuthSessionStore(),
       localStore = localStore ?? MemoryAuthSessionStore(),
       timers = timers ?? FakeAuthTimers();

  final FakeAuthApi api;
  final FakeAuthNavigator navigator;
  final MemoryAuthSessionStore sessionStore;
  final MemoryAuthSessionStore localStore;
  final FakeAuthTimers timers;

  AuthDependencies get deps => AuthDependencies(
    api: api,
    navigator: navigator,
    sessionStore: sessionStore,
    localStore: localStore,
    timers: timers,
    origin: testOrigin,
  );
}
