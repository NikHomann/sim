import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';

/// Everything the auth pages learn before they render, assembled from
/// `GET /api/public-env` and `GET /api/auth/providers` (the React server
/// props, `auth-login.md` States). Missing optional fields are permissive.
class AuthPageOptions {
  const AuthPageOptions({
    this.githubAvailable = false,
    this.googleAvailable = false,
    this.microsoftAvailable = false,
    this.registrationDisabled = false,
    this.emailEnabled = true,
    this.ssoEnabled = false,
    this.emailVerificationEnabled = true,
    this.emailServiceConfigured = true,
    this.isProduction = false,
    this.turnstileSiteKey,
  });

  /// Merges the raw `public-env` map and the `providers` response.
  factory AuthPageOptions.fromResponses({
    required Object? publicEnv,
    required AuthProviders providers,
  }) {
    final env = publicEnv is Map ? publicEnv : const <Object?, Object?>{};
    final publicEmailEnabled = !_isFalsy(
      env['NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED'],
    );
    final siteKey = env['NEXT_PUBLIC_TURNSTILE_SITE_KEY'];
    return AuthPageOptions(
      githubAvailable: providers.githubAvailable,
      googleAvailable: providers.googleAvailable,
      microsoftAvailable: providers.microsoftAvailable,
      registrationDisabled: providers.registrationDisabled,
      emailEnabled:
          publicEmailEnabled && (providers.emailSignupEnabled ?? true),
      ssoEnabled:
          providers.ssoEnabled ?? _isTruthy(env['NEXT_PUBLIC_SSO_ENABLED']),
      // Absent server flags take the spec's defaults (`auth-verify.md`,
      // `auth-signup.md` States): no verification, no mail service, prod.
      emailVerificationEnabled: providers.emailVerificationEnabled ?? false,
      emailServiceConfigured: providers.emailServiceConfigured ?? false,
      isProduction: providers.isProd ?? true,
      turnstileSiteKey: siteKey is String && siteKey.isNotEmpty
          ? siteKey
          : null,
    );
  }

  final bool githubAvailable;
  final bool googleAvailable;
  final bool microsoftAvailable;

  /// `DISABLE_REGISTRATION`.
  final bool registrationDisabled;

  /// `NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED` not falsy and
  /// `DISABLE_EMAIL_SIGNUP` not set.
  final bool emailEnabled;
  final bool ssoEnabled;

  /// `EMAIL_VERIFICATION_ENABLED && hasEmailService()` (absent on the wire
  /// means false).
  final bool emailVerificationEnabled;

  /// `hasEmailService()` (absent on the wire means false).
  final bool emailServiceConfigured;

  /// `isProd` (decides the no-mail-service copy on `/verify`).
  final bool isProduction;

  /// `NEXT_PUBLIC_TURNSTILE_SITE_KEY` (hosted only).
  final String? turnstileSiteKey;

  bool get hasSocial =>
      githubAvailable || googleAvailable || microsoftAvailable;

  /// `hasOnlySSO = sso && !email && !hasSocial`.
  bool get hasOnlySso => ssoEnabled && !emailEnabled && !hasSocial;

  /// `showBottomSection = hasSocial || (sso && !hasOnlySSO)`.
  bool get showBottomSection => hasSocial || (ssoEnabled && !hasOnlySso);

  /// `showDivider = (email || showTopSSO) && showBottomSection`.
  bool get showDivider => (emailEnabled || hasOnlySso) && showBottomSection;

  AuthPageOptions copyWith({
    bool? githubAvailable,
    bool? googleAvailable,
    bool? microsoftAvailable,
    bool? registrationDisabled,
    bool? emailEnabled,
    bool? ssoEnabled,
    bool? emailVerificationEnabled,
    bool? emailServiceConfigured,
    bool? isProduction,
    String? turnstileSiteKey,
  }) => AuthPageOptions(
    githubAvailable: githubAvailable ?? this.githubAvailable,
    googleAvailable: googleAvailable ?? this.googleAvailable,
    microsoftAvailable: microsoftAvailable ?? this.microsoftAvailable,
    registrationDisabled: registrationDisabled ?? this.registrationDisabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    ssoEnabled: ssoEnabled ?? this.ssoEnabled,
    emailVerificationEnabled:
        emailVerificationEnabled ?? this.emailVerificationEnabled,
    emailServiceConfigured:
        emailServiceConfigured ?? this.emailServiceConfigured,
    isProduction: isProduction ?? this.isProduction,
    turnstileSiteKey: turnstileSiteKey ?? this.turnstileSiteKey,
  );

  /// `isFalsy` (`lib/core/config/env.ts:839`): only an explicit `'false'`,
  /// `'0'` or `false` counts; unset is not falsy.
  static bool _isFalsy(Object? value) {
    if (value is String) return value.toLowerCase() == 'false' || value == '0';
    return value == false;
  }

  static bool _isTruthy(Object? value) {
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return value == true;
  }
}

/// `POST /api/auth/sign-up/email` result: the created user.
class SignUpResult {
  const SignUpResult({required this.user});

  final AuthUser? user;
}

/// `publicClientPrelogin`: the registered name of an OAuth client.
class OAuthPublicClient {
  const OAuthPublicClient({required this.clientId, required this.name});

  final String clientId;
  final String? name;
}

/// One workspace grant of an invitation.
class InviteGrant {
  const InviteGrant({
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceLogoUrl,
    required this.permission,
  });

  factory InviteGrant.fromJson(Map<Object?, Object?> json) => InviteGrant(
    workspaceId: '${json['workspaceId'] ?? ''}',
    workspaceName: json['workspaceName'] as String?,
    workspaceLogoUrl: json['workspaceLogoUrl'] as String?,
    permission: '${json['permission'] ?? 'read'}',
  );

  final String workspaceId;
  final String? workspaceName;
  final String? workspaceLogoUrl;
  final String permission;
}

/// `GET /api/invitations/[id]` → `invitation`.
class InviteDetails {
  const InviteDetails({
    required this.id,
    required this.kind,
    required this.email,
    required this.organizationName,
    required this.membershipIntent,
    required this.role,
    required this.grants,
  });

  factory InviteDetails.fromJson(Map<Object?, Object?> json) {
    final grants = json['grants'];
    return InviteDetails(
      id: '${json['id'] ?? ''}',
      kind: '${json['kind'] ?? 'workspace'}',
      email: '${json['email'] ?? ''}',
      organizationName: json['organizationName'] as String?,
      membershipIntent: '${json['membershipIntent'] ?? 'internal'}',
      role: json['role'] as String?,
      grants: grants is List
          ? grants
                .whereType<Map<Object?, Object?>>()
                .map(InviteGrant.fromJson)
                .toList()
          : const <InviteGrant>[],
    );
  }

  final String id;

  /// `organization` | `workspace`.
  final String kind;
  final String email;
  final String? organizationName;

  /// `internal` | `external`.
  final String membershipIntent;
  final String? role;
  final List<InviteGrant> grants;
}

/// `GET /api/invitations/[id]` → `joinPreview`.
class InviteJoinPreview {
  const InviteJoinPreview({
    required this.outcome,
    required this.organizationName,
    required this.workspacesToMove,
    required this.workspaceIdsToMove,
  });

  factory InviteJoinPreview.fromJson(Map<Object?, Object?> json) {
    final names = json['workspacesToMove'];
    final ids = json['workspaceIdsToMove'];
    return InviteJoinPreview(
      outcome: '${json['outcome'] ?? 'blocked'}',
      organizationName: json['organizationName'] as String?,
      workspacesToMove: names is List
          ? names.map((n) => n is String ? n : null).toList()
          : const <String?>[],
      workspaceIdsToMove: ids is List
          ? ids.map((i) => '$i').toList()
          : const <String>[],
    );
  }

  /// `will-join` | `already-member` | `external` | `blocked`.
  final String outcome;
  final String? organizationName;
  final List<String?> workspacesToMove;
  final List<String> workspaceIdsToMove;
}

class InviteResponse {
  const InviteResponse({
    required this.invitation,
    required this.joinPreview,
  });

  factory InviteResponse.fromJson(Object? json) {
    final map = json is Map ? json : const <Object?, Object?>{};
    final invitation = map['invitation'];
    final preview = map['joinPreview'];
    return InviteResponse(
      invitation: invitation is Map<Object?, Object?>
          ? InviteDetails.fromJson(invitation)
          : null,
      joinPreview: preview is Map<Object?, Object?>
          ? InviteJoinPreview.fromJson(preview)
          : null,
    );
  }

  final InviteDetails? invitation;
  final InviteJoinPreview? joinPreview;
}

/// `POST /api/invitations/[id]/accept` success body.
class InviteAcceptResult {
  const InviteAcceptResult({required this.redirectPath});

  final String redirectPath;
}

/// The backend calls the auth pages make. [HttpAuthApi] is the production
/// implementation; tests substitute a fake. Every method throws
/// [ApiClientError] on a non-2xx response and [ApiNetworkError] without one.
abstract class AuthApi {
  /// `GET /api/public-env` + `GET /api/auth/providers`.
  Future<AuthPageOptions> loadOptions();

  /// `GET /api/auth/get-session`.
  Future<AuthSession?> getSession({bool disableCookieCache = false});

  /// `POST /api/auth/sign-in/email`.
  Future<AuthUser?> signInEmail({
    required String email,
    required String password,
    required String callbackUrl,
  });

  /// `POST /api/auth/sign-up/email` (+ `x-captcha-response`).
  Future<SignUpResult> signUpEmail({
    required String email,
    required String password,
    required String name,
    String? captchaToken,
  });

  /// `POST /api/auth/sign-in/social` → the provider URL.
  Future<String> startSocialSignIn({
    required String provider,
    required String callbackUrl,
  });

  /// `POST /api/auth/forget-password`.
  Future<void> forgetPassword({
    required String email,
    required String redirectTo,
  });

  /// `POST /api/auth/reset-password`.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  /// `POST /api/auth/email-otp/verify-email`.
  Future<AuthUser?> verifyEmailOtp({
    required String email,
    required String otp,
  });

  /// `POST /api/auth/email-otp/send-verification-otp`.
  Future<void> sendVerificationOtp({required String email});

  /// `POST /api/auth/sign-out`.
  Future<void> signOut();

  /// `POST /api/auth/sso/resolve` → provider id.
  Future<String> resolveSsoProvider({
    required String email,
    String? providerId,
  });

  /// `POST /api/auth/sign-in/sso` → the IdP URL to open.
  Future<String> startSsoSignIn({
    required String email,
    required String providerId,
    required String callbackUrl,
    required String errorCallbackUrl,
  });

  /// `GET /api/auth/oauth2/public-client/prelogin?client_id=`.
  Future<OAuthPublicClient> oauthPublicClient({required String clientId});

  /// `POST /api/auth/oauth2/consent` `{accept, oauth_query}` → `url`.
  Future<String> oauthConsent({
    required bool accept,
    required String oauthQuery,
  });

  /// `GET /api/invitations/[id]?token=`.
  Future<InviteResponse> getInvitation({
    required String id,
    String? token,
  });

  /// `POST /api/invitations/[id]/accept`.
  Future<InviteAcceptResult> acceptInvitation({
    required String id,
    String? token,
    List<String>? disclosedWorkspaceIds,
    String? disclosedOutcome,
  });

  /// `${origin}/reset-password` for the forgot-password `redirectTo`.
  String absoluteUrl(String path);
}

/// [AuthApi] over [AuthRepository] and [SimHttpClient].
class HttpAuthApi implements AuthApi {
  HttpAuthApi({
    required AuthRepository auth,
    required SimHttpClient http,
    Future<void> Function()? onSessionChanged,
  }) : _auth = auth,
       _http = http,
       _onSessionChanged = onSessionChanged;

  final AuthRepository _auth;
  final SimHttpClient _http;

  /// Called after every successful call that sets or clears the session
  /// cookie, before the page navigates, so app-level session state (the
  /// router's signed-out guard reads `SessionCubit`) sees the new session.
  /// Without it the guard served the session cached while the login page was
  /// open and bounced a fresh sign-in back to /login (live e2e, 2026-10-22).
  final Future<void> Function()? _onSessionChanged;

  Future<T> _changingSession<T>(Future<T> Function() call) async {
    final result = await call();
    await _onSessionChanged?.call();
    return result;
  }

  @override
  Future<AuthPageOptions> loadOptions() async {
    Object? publicEnv;
    try {
      publicEnv = (await _http.send(
        method: 'GET',
        path: '/api/public-env',
      )).data;
    } on Exception {
      publicEnv = null;
    }
    final providers = await _auth.providers();
    return AuthPageOptions.fromResponses(
      publicEnv: publicEnv,
      providers: providers,
    );
  }

  @override
  Future<AuthSession?> getSession({bool disableCookieCache = false}) =>
      _auth.getSession(disableCookieCache: disableCookieCache);

  @override
  Future<AuthUser?> signInEmail({
    required String email,
    required String password,
    required String callbackUrl,
  }) => _changingSession(
    () => _auth.signInEmail(
      email: email,
      password: password,
      callbackUrl: callbackUrl,
    ),
  );

  @override
  Future<SignUpResult> signUpEmail({
    required String email,
    required String password,
    required String name,
    String? captchaToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/auth/sign-up/email',
      body: {'email': email, 'password': password, 'name': name},
      headers: {'x-captcha-response': ?captchaToken},
    );
    final data = response.data;
    final user = data is Map ? data['user'] : null;
    await _onSessionChanged?.call();
    return SignUpResult(user: user is Map ? AuthUser.fromJson(user) : null);
  }

  @override
  Future<String> startSocialSignIn({
    required String provider,
    required String callbackUrl,
  }) async {
    final start = await _auth.signInSocial(
      provider: provider,
      callbackUrl: callbackUrl,
    );
    return start.url;
  }

  @override
  Future<void> forgetPassword({
    required String email,
    required String redirectTo,
  }) => _auth.forgetPassword(email: email, redirectTo: redirectTo);

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _auth.resetPassword(token: token, newPassword: newPassword);

  @override
  Future<AuthUser?> verifyEmailOtp({
    required String email,
    required String otp,
  }) => _changingSession(
    () => _auth.verifyEmailOtp(email: email, otp: otp),
  );

  @override
  Future<void> sendVerificationOtp({required String email}) =>
      _auth.sendVerificationOtp(email: email);

  @override
  Future<void> signOut() => _changingSession(_auth.signOut);

  @override
  Future<String> resolveSsoProvider({
    required String email,
    String? providerId,
  }) => _auth.resolveSsoProvider(email: email, providerId: providerId);

  @override
  Future<String> startSsoSignIn({
    required String email,
    required String providerId,
    required String callbackUrl,
    required String errorCallbackUrl,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/auth/sign-in/sso',
      body: {
        'email': email,
        'providerId': providerId,
        'callbackURL': callbackUrl,
        'errorCallbackURL': errorCallbackUrl,
      },
    );
    final data = response.data;
    final url = data is Map ? data['url'] : null;
    if (url is! String || url.isEmpty) {
      throw ApiClientError(
        status: response.status,
        message: 'SSO sign-in did not return a URL',
        body: data,
      );
    }
    return url;
  }

  @override
  Future<OAuthPublicClient> oauthPublicClient({
    required String clientId,
  }) async {
    final response = await _http.send(
      method: 'GET',
      path: '/api/auth/oauth2/public-client/prelogin',
      query: {'client_id': clientId},
    );
    final data = response.data;
    final map = data is Map ? data : const <Object?, Object?>{};
    return OAuthPublicClient(
      clientId: '${map['client_id'] ?? clientId}',
      name: map['client_name'] as String?,
    );
  }

  @override
  Future<String> oauthConsent({
    required bool accept,
    required String oauthQuery,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/auth/oauth2/consent',
      body: {'accept': accept, 'oauth_query': oauthQuery},
    );
    final data = response.data;
    final url = data is Map ? data['url'] : null;
    if (url is! String || url.isEmpty) {
      throw ApiClientError(
        status: response.status,
        message: 'The authorization could not be completed.',
        body: data,
      );
    }
    return url;
  }

  @override
  Future<InviteResponse> getInvitation({
    required String id,
    String? token,
  }) async {
    final response = await _http.send(
      method: 'GET',
      path: '/api/invitations/:id',
      params: {'id': id},
      query: {'token': ?token},
    );
    return InviteResponse.fromJson(response.data);
  }

  @override
  Future<InviteAcceptResult> acceptInvitation({
    required String id,
    String? token,
    List<String>? disclosedWorkspaceIds,
    String? disclosedOutcome,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/invitations/:id/accept',
      params: {'id': id},
      body: {
        'token': ?token,
        'disclosedWorkspaceIds': ?disclosedWorkspaceIds,
        'disclosedOutcome': ?disclosedOutcome,
      },
    );
    final data = response.data;
    final path = data is Map ? data['redirectPath'] : null;
    return InviteAcceptResult(
      redirectPath: path is String && path.isNotEmpty
          ? path
          : defaultPostAuthRoute,
    );
  }

  @override
  String absoluteUrl(String path) => _http.resolveUrl(path);
}
