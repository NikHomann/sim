import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_navigator.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/auth_timers.dart';
import 'package:sim_app/features/auth/shared/email_validation.dart';

/// `InviteError` of `invite.tsx:140-254`.
class InviteError extends Equatable {
  const InviteError({
    required this.code,
    required this.message,
    this.requiresAuth = false,
    this.canRetry = false,
  });

  final String code;
  final String message;
  final bool requiresAuth;
  final bool canRetry;

  InviteError withMessage(String message) => InviteError(
    code: code,
    message: message,
    requiresAuth: requiresAuth,
    canRetry: canRetry,
  );

  @override
  List<Object?> get props => [code, message, requiresAuth, canRetry];
}

const Map<String, InviteError> _inviteErrors = <String, InviteError>{
  'missing-token': InviteError(
    code: 'missing-token',
    message: 'The invitation link is invalid or missing a required parameter.',
  ),
  'invalid-token': InviteError(
    code: 'invalid-token',
    message: 'The invitation link is invalid or has already been used.',
  ),
  'expired': InviteError(
    code: 'expired',
    message: 'This invitation has expired. Please ask for a new invitation.',
  ),
  'already-processed': InviteError(
    code: 'already-processed',
    message: 'This invitation has already been accepted or declined.',
  ),
  'email-mismatch': InviteError(
    code: 'email-mismatch',
    message:
        'This invitation was sent to a different email address. Please sign in with the correct account.',
    requiresAuth: true,
  ),
  'workspace-not-found': InviteError(
    code: 'workspace-not-found',
    message:
        'The workspace associated with this invitation could not be found.',
  ),
  'disclosure-outdated': InviteError(
    code: 'disclosure-outdated',
    message:
        'Your workspaces changed since this page loaded. Review the updated notice and accept again.',
    canRetry: true,
  ),
  'user-not-found': InviteError(
    code: 'user-not-found',
    message:
        'Your user account could not be found. Please try signing out and signing back in.',
    requiresAuth: true,
  ),
  'already-member': InviteError(
    code: 'already-member',
    message: 'You are already a member of this organization or workspace.',
  ),
  'already-in-organization': InviteError(
    code: 'already-in-organization',
    message:
        'You are already a member of an organization. Leave your current organization before accepting a new invitation.',
  ),
  'no-seats-available': InviteError(
    code: 'no-seats-available',
    message:
        'This organization has reached its seat limit. Ask an admin to contact support to add seats, then try again.',
    canRetry: true,
  ),
  'upgrade-required': InviteError(
    code: 'upgrade-required',
    message:
        'The workspace owner needs an active paid plan with billing set up before you can join. Ask them to update their plan, then try again.',
    canRetry: true,
  ),
  'external-requires-paid-plan': InviteError(
    code: 'external-requires-paid-plan',
    message:
        'External collaborators need their own paid Sim plan. Upgrade your plan, or ask the organization to re-invite you as a member — that uses one of their seats instead.',
    canRetry: true,
  ),
  'invalid-invitation': InviteError(
    code: 'invalid-invitation',
    message: 'This invitation is invalid or no longer exists.',
  ),
  'not-found': InviteError(
    code: 'invalid-invitation',
    message: 'This invitation is invalid or no longer exists.',
  ),
  'server-error': InviteError(
    code: 'server-error',
    message:
        'An unexpected error occurred while processing your invitation. Please try again later.',
    canRetry: true,
  ),
  'unauthorized': InviteError(
    code: 'unauthorized',
    message: 'You need to sign in to accept this invitation.',
    requiresAuth: true,
  ),
  'forbidden': InviteError(
    code: 'forbidden',
    message:
        'You do not have permission to accept this invitation. Please check you are signed in with the correct account.',
    requiresAuth: true,
  ),
  'network-error': InviteError(
    code: 'network-error',
    message:
        'Unable to connect to the server. Please check your internet connection and try again.',
    canRetry: true,
  ),
};

const InviteError _unknownInviteError = InviteError(
  code: 'unknown',
  message:
      'An unexpected error occurred while processing your invitation. Please try again or contact support.',
  canRetry: true,
);

/// `getInviteError`.
InviteError getInviteError(String code) =>
    _inviteErrors[code] ?? _unknownInviteError;

String _codeFromStatus(int status) {
  if (status == 401) return 'unauthorized';
  if (status == 403) return 'forbidden';
  if (status == 404) return 'invalid-invitation';
  if (status == 409) return 'already-in-organization';
  if (status >= 500) return 'server-error';
  return 'unknown';
}

/// `codeFromApiClientError`: a known `code`, else a known `body.error`,
/// else by status.
String inviteErrorCode(Object error) {
  if (error is! ApiClientError) return 'network-error';
  final code = error.code;
  if (code != null && _inviteErrors.containsKey(code)) return code;
  final body = error.body;
  if (body is Map) {
    final bodyError = body['error'];
    if (bodyError is String && _inviteErrors.containsKey(bodyError)) {
      return bodyError;
    }
  }
  return _codeFromStatus(error.status);
}

/// `formatQuotedNameList` (`packages/utils/src/string.ts:221-228`).
String formatQuotedNameList(List<String> names, int maxListed) {
  final listed = names.take(maxListed).map((n) => '"$n"').join(', ');
  final overflow = names.length - maxListed;
  return overflow > 0 ? '$listed and $overflow more' : listed;
}

enum InvitePhase { loading, signedOut, error, accepted, invitation }

/// State of `/invite/[id]` (`invite-accept.md`).
class InviteState extends Equatable {
  const InviteState({
    this.phase = InvitePhase.loading,
    this.token,
    this.isNewUser = false,
    this.registrationDisabled = false,
    this.sessionEmail,
    this.invitation,
    this.joinPreview,
    this.error,
    this.accepting = false,
    this.refetching = false,
    this.signingOut = false,
  });

  final InvitePhase phase;
  final String? token;
  final bool isNewUser;
  final bool registrationDisabled;
  final String? sessionEmail;
  final InviteDetails? invitation;
  final InviteJoinPreview? joinPreview;
  final InviteError? error;
  final bool accepting;
  final bool refetching;
  final bool signingOut;

  /// `isDisclosureMissing`: an internal join without a preview.
  bool get isDisclosureMissing =>
      invitation?.membershipIntent == 'internal' && joinPreview == null;

  /// `displayName`: quoted workspace names (max 3) or the organization.
  String get displayName {
    final invitation = this.invitation;
    if (invitation == null) return 'a workspace';
    if (invitation.kind == 'workspace') {
      final names = invitation.grants
          .map((g) => g.workspaceName)
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .toList();
      return names.isEmpty ? 'a workspace' : formatQuotedNameList(names, 3);
    }
    final org = invitation.organizationName;
    return org == null || org.isEmpty ? 'an organization' : org;
  }

  InviteState copyWith({
    InvitePhase? phase,
    String? Function()? token,
    bool? isNewUser,
    bool? registrationDisabled,
    String? Function()? sessionEmail,
    InviteDetails? Function()? invitation,
    InviteJoinPreview? Function()? joinPreview,
    InviteError? Function()? error,
    bool? accepting,
    bool? refetching,
    bool? signingOut,
  }) => InviteState(
    phase: phase ?? this.phase,
    token: token == null ? this.token : token(),
    isNewUser: isNewUser ?? this.isNewUser,
    registrationDisabled: registrationDisabled ?? this.registrationDisabled,
    sessionEmail: sessionEmail == null ? this.sessionEmail : sessionEmail(),
    invitation: invitation == null ? this.invitation : invitation(),
    joinPreview: joinPreview == null ? this.joinPreview : joinPreview(),
    error: error == null ? this.error : error(),
    accepting: accepting ?? this.accepting,
    refetching: refetching ?? this.refetching,
    signingOut: signingOut ?? this.signingOut,
  );

  @override
  List<Object?> get props => [
    phase,
    token,
    isNewUser,
    registrationDisabled,
    sessionEmail,
    invitation,
    joinPreview,
    error,
    accepting,
    refetching,
    signingOut,
  ];
}

/// Port of `invite.tsx`.
class InviteCubit extends Cubit<InviteState> {
  InviteCubit({
    required AuthApi api,
    required AuthNavigator navigator,
    required AuthSessionStore sessionStore,
    required AuthTimers timers,
    required String origin,
    required this.inviteId,
    Map<String, String> query = const <String, String>{},
  }) : _api = api,
       _navigator = navigator,
       _store = sessionStore,
       _timers = timers,
       _origin = origin,
       _hasCallbackParam = query.containsKey('callbackUrl'),
       _queryToken = (query['token'] ?? '').isEmpty ? null : query['token'],
       _urlError = query['error'] == null
           ? null
           : getInviteError(query['error']!),
       super(InviteState(isNewUser: query['new'] == 'true'));

  static const Duration redirectDelay = Duration(milliseconds: 1200);

  final AuthApi _api;
  final AuthNavigator _navigator;
  final AuthSessionStore _store;
  final AuthTimers _timers;
  final String _origin;

  /// The proxy bounces a signed-out visitor to login unless the request
  /// carried `callbackUrl` (`proxy.ts:268-280`); the card shows only then.
  final bool _hasCallbackParam;
  final String inviteId;
  final String? _queryToken;
  final InviteError? _urlError;
  InviteError? _actionError;
  InviteError? _fetchError;
  bool _loaded = false;

  String get _storageKey => AuthStorageKeys.inviteToken(inviteId);

  /// `/invite/<id>[?token=…]` with the token from state, storage or query.
  String get callbackUrl {
    final token = state.token ?? _store.read(_storageKey) ?? _queryToken;
    return '/invite/$inviteId${token == null ? '' : '?token=$token'}';
  }

  String loginHref({bool isNewUser = false}) => buildAuthCrossLink(
    '/login',
    callbackUrl: callbackUrl,
    isInviteFlow: true,
    isNewUser: isNewUser,
  );

  String signupHref({bool isNewUser = false}) => buildAuthCrossLink(
    '/signup',
    callbackUrl: callbackUrl,
    isInviteFlow: true,
    isNewUser: isNewUser,
  );

  Future<void> load() async {
    final String? token;
    if (_queryToken != null) {
      _store.write(_storageKey, _queryToken);
      token = _queryToken;
    } else {
      token = _store.read(_storageKey);
    }
    var registrationDisabled = false;
    try {
      registrationDisabled = (await _api.loadOptions()).registrationDisabled;
    } on Exception {
      registrationDisabled = false;
    }
    AuthSession? session;
    try {
      session = await _api.getSession();
    } on Exception {
      session = null;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        token: () => token,
        registrationDisabled: registrationDisabled,
        sessionEmail: () => session?.user.email,
      ),
    );
    if (session == null) {
      if (!_hasCallbackParam) {
        _navigator.go(loginHref());
        return;
      }
      emit(state.copyWith(phase: InvitePhase.signedOut));
      return;
    }
    _loaded = true;
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response = await _api.getInvitation(
        id: inviteId,
        token: state.token,
      );
      if (isClosed) return;
      _fetchError = null;
      emit(
        state.copyWith(
          invitation: () => response.invitation,
          joinPreview: () => response.joinPreview,
          refetching: false,
        ),
      );
    } on Exception catch (error) {
      if (isClosed) return;
      _fetchError = getInviteError(inviteErrorCode(error));
      emit(state.copyWith(refetching: false));
    }
    _resolve();
  }

  bool get _isWrongAccount {
    final invitation = state.invitation;
    final email = state.sessionEmail;
    return invitation != null &&
        email != null &&
        normalizeEmail(email) != normalizeEmail(invitation.email);
  }

  /// Error precedence: action > fetch > wrong account > URL (until loaded).
  void _resolve() {
    if (!_loaded) return;
    final error =
        _actionError ??
        _fetchError ??
        (_isWrongAccount ? getInviteError('email-mismatch') : null) ??
        (state.invitation == null ? _urlError : null);
    if (error != null) {
      emit(state.copyWith(phase: InvitePhase.error, error: () => error));
      return;
    }
    emit(state.copyWith(phase: InvitePhase.invitation, error: () => null));
  }

  /// "Accept Invitation": `POST /api/invitations/[id]/accept`.
  Future<void> accept() async {
    final invitation = state.invitation;
    if (invitation == null ||
        _isWrongAccount ||
        state.isDisclosureMissing ||
        state.accepting) {
      return;
    }
    emit(state.copyWith(accepting: true));
    final preview = state.joinPreview;
    try {
      final result = await _api.acceptInvitation(
        id: inviteId,
        token: state.token,
        disclosedWorkspaceIds: preview?.workspaceIdsToMove,
        disclosedOutcome: preview?.outcome,
      );
      if (isClosed) return;
      emit(state.copyWith(accepting: false, phase: InvitePhase.accepted));
      _timers.schedule(redirectDelay, () {
        if (!isClosed) {
          _navigator.goToDestination(result.redirectPath, origin: _origin);
        }
      });
      try {
        await _api.getSession(disableCookieCache: true);
      } on Exception {
        // Best effort, as upstream.
      }
    } on Exception catch (error) {
      if (isClosed) return;
      final code = inviteErrorCode(error);
      final base = getInviteError(code);
      final body = error is ApiClientError ? error.body : null;
      final serverMessage = body is Map && body['message'] is String
          ? body['message']! as String
          : null;
      _actionError = code == 'server-error' && serverMessage != null
          ? base.withMessage(serverMessage)
          : base;
      emit(state.copyWith(accepting: false));
      _resolve();
    }
  }

  /// "Refresh invitation".
  Future<void> refresh() async {
    if (state.refetching) return;
    emit(state.copyWith(refetching: true));
    await _fetch();
  }

  /// "Sign in with a different account": sign out, then the login link.
  Future<void> signInWithDifferentAccount() async {
    if (state.signingOut) return;
    emit(state.copyWith(signingOut: true));
    try {
      await _api.signOut();
    } on Exception {
      // Logged only upstream; navigation proceeds.
    }
    if (isClosed) return;
    emit(state.copyWith(signingOut: false));
    _navigator.go(loginHref());
  }

  void goToLogin() => _navigator.go(loginHref());

  void goToSignup({bool isNewUser = false}) =>
      _navigator.go(signupHref(isNewUser: isNewUser));

  /// "Try Again": `window.location.reload()`.
  void tryAgain() => _navigator.reload();

  /// "Return to Home" / the logo: a document navigation to `/`.
  void returnHome() => _navigator.openTopLevel('/');

  /// "Manage Team Settings" / "Request New Invitation" → the app entry.
  void goToEntry() => _navigator.go(defaultPostAuthRoute);

  /// `brandConfig.supportEmail` default (`lib/branding/defaults.ts:12`); the
  /// whitelabel override is a known gap.
  static const String defaultSupportEmail = 'help@sim.ai';

  void contactSupport() =>
      _navigator.openTopLevel('mailto:$defaultSupportEmail');
}
