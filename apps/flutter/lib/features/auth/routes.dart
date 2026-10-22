import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_app/features/auth/invite/invite_page.dart';
import 'package:sim_app/features/auth/login/login_page.dart';
import 'package:sim_app/features/auth/oauth/consent_page.dart';
import 'package:sim_app/features/auth/oauth/status_pages.dart';
import 'package:sim_app/features/auth/reset_password/reset_password_page.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/signup/signup_page.dart';
import 'package:sim_app/features/auth/sso/sso_page.dart';
import 'package:sim_app/features/auth/verify/verify_page.dart';

/// The auth paths (`docs/port/specs/auth-*.md`, `invite-accept.md`),
/// declared without the `/app` prefix (plan §3).
abstract final class AuthPaths {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verify = '/verify';
  static const String resetPassword = '/reset-password';
  static const String sso = '/sso';
  static const String oauthConsent = '/oauth/consent';
  static const String oauthError = '/oauth-error';
  static const String oauthChatComplete = '/oauth/chat-complete';
  static const String oauthCredentialConnected = '/oauth/credential-connected';
  static const String invite = '/invite/:id';

  /// First path segments the theme provider forces light for
  /// (`theme-provider.tsx:16-31`), the auth subset.
  static const Set<String> forcedLightSegments = <String>{
    'login',
    'signup',
    'reset-password',
    'sso',
    'invite',
    'verify',
    'oauth',
    'oauth-error',
  };
}

/// Scopes a page and keys it on the full location, so a navigation to the
/// same route with a different query remounts the page (its cubit reads the
/// query once; `sso-form.tsx:69` keys the form the same way).
Widget _scoped(BuildContext context, GoRouterState state, Widget page) =>
    AuthScope(
      key: ValueKey<String>(state.uri.toString()),
      deps: AuthDependencies.resolve(context),
      child: page,
    );

/// GoRouter routes for every auth page; the app mounts them in
/// `lib/app/router.dart`.
List<RouteBase> authRoutes() => <RouteBase>[
  GoRoute(
    path: AuthPaths.login,
    builder: (context, state) =>
        _scoped(context, state, LoginPage(query: state.uri.queryParameters)),
  ),
  GoRoute(
    path: AuthPaths.signup,
    builder: (context, state) =>
        _scoped(context, state, SignupPage(query: state.uri.queryParameters)),
  ),
  GoRoute(
    path: AuthPaths.verify,
    builder: (context, state) =>
        _scoped(context, state, VerifyPage(query: state.uri.queryParameters)),
  ),
  GoRoute(
    path: AuthPaths.resetPassword,
    builder: (context, state) => _scoped(
      context,
      state,
      ResetPasswordPage(query: state.uri.queryParameters),
    ),
  ),
  GoRoute(
    path: AuthPaths.sso,
    builder: (context, state) =>
        _scoped(context, state, SsoPage(query: state.uri.queryParameters)),
  ),
  GoRoute(
    path: AuthPaths.oauthConsent,
    builder: (context, state) =>
        _scoped(context, state, OAuthConsentPage(uri: state.uri)),
  ),
  GoRoute(
    path: AuthPaths.oauthError,
    builder: (context, state) => _scoped(
      context,
      state,
      OAuthErrorPage(query: state.uri.queryParameters),
    ),
  ),
  GoRoute(
    path: AuthPaths.oauthChatComplete,
    builder: (context, state) => _scoped(
      context,
      state,
      OAuthChatCompletePage(query: state.uri.queryParameters),
    ),
  ),
  GoRoute(
    path: AuthPaths.oauthCredentialConnected,
    builder: (context, state) => _scoped(
      context,
      state,
      CredentialConnectedPage(query: state.uri.queryParameters),
    ),
  ),
  GoRoute(
    path: AuthPaths.invite,
    builder: (context, state) => _scoped(
      context,
      state,
      InvitePage(
        inviteId: state.pathParameters['id'] ?? '',
        query: state.uri.queryParameters,
      ),
    ),
  ),
];
