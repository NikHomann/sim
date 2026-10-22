/// The user of a Better Auth session (`AppSession.user` upstream).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.emailVerified,
    this.name,
    this.image,
    this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory AuthUser.fromJson(Map<Object?, Object?> json) => AuthUser(
    id: '${json['id'] ?? ''}',
    email: '${json['email'] ?? ''}',
    emailVerified: json['emailVerified'] as bool?,
    name: json['name'] as String?,
    image: json['image'] as String?,
    role: json['role'] as String?,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );

  final String id;
  final String email;
  final bool? emailVerified;
  final String? name;
  final String? image;
  final String? role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// The session row fields the app reads (`AppSession.session` upstream).
class SessionInfo {
  const SessionInfo({
    this.id,
    this.userId,
    this.activeOrganizationId,
    this.impersonatedBy,
    this.expiresAt,
  });

  factory SessionInfo.fromJson(Map<Object?, Object?> json) => SessionInfo(
    id: json['id'] as String?,
    userId: json['userId'] as String?,
    activeOrganizationId: json['activeOrganizationId'] as String?,
    impersonatedBy: json['impersonatedBy'] as String?,
    expiresAt: json['expiresAt'] is String
        ? DateTime.tryParse(json['expiresAt']! as String)
        : null,
  );

  final String? id;
  final String? userId;
  final String? activeOrganizationId;
  final String? impersonatedBy;
  final DateTime? expiresAt;
}

/// `GET /api/auth/get-session` → `{session, user}`.
class AuthSession {
  const AuthSession({required this.user, this.session});

  /// `null` when the body is `null` (no session) or carries no user.
  static AuthSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final user = json['user'];
    if (user is! Map) return null;
    final session = json['session'];
    return AuthSession(
      user: AuthUser.fromJson(user),
      session: session is Map ? SessionInfo.fromJson(session) : null,
    );
  }

  final AuthUser user;
  final SessionInfo? session;

  bool get isImpersonated => session?.impersonatedBy != null;
}

/// `GET /api/auth/providers`.
class AuthProviders {
  const AuthProviders({
    required this.githubAvailable,
    required this.googleAvailable,
    required this.microsoftAvailable,
    required this.registrationDisabled,
    this.emailSignupEnabled,
    this.emailVerificationEnabled,
    this.emailServiceConfigured,
    this.ssoEnabled,
    this.isProd,
  });

  factory AuthProviders.fromJson(Object? json) {
    final map = json is Map ? json : const <Object?, Object?>{};
    bool? optional(Object? value) => value is bool ? value : null;
    return AuthProviders(
      githubAvailable: map['githubAvailable'] == true,
      googleAvailable: map['googleAvailable'] == true,
      microsoftAvailable: map['microsoftAvailable'] == true,
      registrationDisabled: map['registrationDisabled'] == true,
      emailSignupEnabled: optional(map['emailSignupEnabled']),
      emailVerificationEnabled: optional(map['emailVerificationEnabled']),
      emailServiceConfigured: optional(map['emailServiceConfigured']),
      ssoEnabled: optional(map['ssoEnabled']),
      isProd: optional(map['isProd']),
    );
  }

  final bool githubAvailable;
  final bool googleAvailable;
  final bool microsoftAvailable;
  final bool registrationDisabled;

  /// `!DISABLE_EMAIL_SIGNUP`; null when the server did not send it (the
  /// auth pages treat that as enabled).
  final bool? emailSignupEnabled;

  /// `EMAIL_VERIFICATION_ENABLED && hasEmailService()`; null when absent
  /// (the auth pages treat that as `false`, `auth-verify.md` States).
  final bool? emailVerificationEnabled;

  /// `hasEmailService()`; null when absent (treated as `false`).
  final bool? emailServiceConfigured;

  /// `isSsoEnabled`; null means "as `NEXT_PUBLIC_SSO_ENABLED` says".
  final bool? ssoEnabled;

  /// `isProd`; null when absent (treated as `true`).
  final bool? isProd;
}

/// `POST /api/auth/sign-in/social` → `{url, redirect}`: the browser (or the
/// system browser on desktop) navigates to [url].
class SocialSignInStart {
  const SocialSignInStart({required this.url, required this.redirect});

  final String url;
  final bool redirect;
}
