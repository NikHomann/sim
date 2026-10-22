/// Port of `apps/sim/app/(auth)/auth-redirect.ts` and
/// `validateCallbackUrl` (`lib/core/security/input-validation.ts:932-943`).
library;

import 'package:sim_app/app/router.dart';

/// `DEFAULT_POST_AUTH_ROUTE` / `APP_ENTRY_PATH`: what the auth requests carry
/// as `callbackURL` and where a sign-in lands when no callback was carried
/// (`/home`, owned by entry resolution).
const String defaultPostAuthRoute = AppRoutes.home;

/// `VERIFY_FROM_SIGNUP_ROUTE`.
const String verifyFromSignupRoute = '/verify?fromSignup=true';

/// Same-origin check of a callback URL: relative paths pass, other origins
/// (and unparsable values) fail. [origin] is the page origin
/// (`scheme://host[:port]`).
bool validateCallbackUrl(String? url, {required String origin}) {
  if (url == null || url.isEmpty) return false;
  final base = Uri.tryParse(origin);
  if (base == null) return false;
  final Uri parsed;
  try {
    parsed = base.resolve(url);
  } on FormatException {
    return false;
  }
  return _originOf(parsed) == _originOf(base);
}

String _originOf(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) return '';
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

/// `isOAuthAuthorizationCallback`: the OAuth re-authentication callback must
/// reach the form even when a session exists.
bool isOAuthAuthorizationCallback(
  String? callbackUrl, {
  required String origin,
}) {
  if (callbackUrl == null || callbackUrl.isEmpty) return false;
  final base = Uri.tryParse(origin);
  if (base == null) return false;
  final Uri parsed;
  try {
    parsed = base.resolve(callbackUrl);
  } on FormatException {
    return false;
  }
  return _originOf(parsed) == _originOf(base) &&
      parsed.path == '/api/auth/oauth2/authorize';
}

/// `resolveAuthRedirect`: `redirect` wins over `callbackUrl`; a destination
/// under `/invite/` implies the invite flow. Does not validate.
({String rawCallbackUrl, bool isInviteFlow}) resolveAuthRedirect({
  String? redirect,
  String? callbackUrl,
  String? inviteFlow,
}) {
  final raw = (redirect ?? '').isNotEmpty ? redirect! : (callbackUrl ?? '');
  return (
    rawCallbackUrl: raw,
    isInviteFlow: inviteFlow == 'true' || raw.startsWith('/invite/'),
  );
}

/// `buildAuthCrossLink`: the login ⇄ signup link carrying `invite_flow`,
/// `callbackUrl` and `new`, encoded like `URLSearchParams`.
String buildAuthCrossLink(
  String path, {
  String? callbackUrl,
  bool isInviteFlow = false,
  bool isNewUser = false,
}) {
  final params = <String, String>{
    if (isInviteFlow) 'invite_flow': 'true',
    if (callbackUrl != null && callbackUrl.isNotEmpty)
      'callbackUrl': callbackUrl,
    if (isNewUser) 'new': 'true',
  };
  if (params.isEmpty) return path;
  return '$path?${encodeSearchParams(params)}';
}

/// `URLSearchParams.toString()` encoding (`+` for spaces, `*-._` kept).
String encodeSearchParams(Map<String, String> params) => params.entries
    .map((e) => '${_formEncode(e.key)}=${_formEncode(e.value)}')
    .join('&');

String _formEncode(String value) =>
    Uri.encodeQueryComponent(value).replaceAll('%2A', '*');

/// Whether the Flutter bundle owns [path]: the auth pages, the app entry and
/// the app surfaces (`entry-resolution.md` section 3 and 8). Everything else
/// (`/api/...`, `/cli/...`, `/desktop/...`, `/oauth/sign-in`,
/// `/sso/launch/...`, the marketing pages) stays with Next.
bool isFlutterRoute(String path) {
  if (path == '/' || path == '/sso') return true;
  const exact = <String>{
    '/oauth/consent',
    '/oauth-error',
    '/oauth/chat-complete',
    '/oauth/credential-connected',
  };
  if (exact.contains(path)) return true;
  const prefixes = <String>[
    '/login',
    '/signup',
    '/verify',
    '/reset-password',
    '/invite',
    '/home',
    '/workspace',
    '/o',
  ];
  return prefixes.any(
    (prefix) => path == prefix || path.startsWith('$prefix/'),
  );
}

/// How to reach [location]: in-app when it is (or resolves, on [origin], to)
/// a path the bundle owns; otherwise a top-level browser navigation. An
/// absolute same-origin URL is reduced to its path, query and fragment.
({bool inApp, String location}) resolveDestination(
  String location, {
  required String origin,
}) {
  final base = Uri.tryParse(origin);
  final uri = Uri.tryParse(location);
  if (base == null || uri == null) return (inApp: false, location: location);
  if (!uri.hasScheme && !uri.hasAuthority) {
    return (inApp: isFlutterRoute(uri.path), location: location);
  }
  final resolved = base.resolve(location);
  if (_originOf(resolved) != _originOf(base)) {
    return (inApp: false, location: location);
  }
  final relative = Uri(
    path: resolved.path.isEmpty ? '/' : resolved.path,
    query: resolved.hasQuery ? resolved.query : null,
    fragment: resolved.hasFragment ? resolved.fragment : null,
  ).toString();
  return (inApp: isFlutterRoute(resolved.path), location: relative);
}

/// Post-auth destination: the validated callback when one was carried, else
/// `/home`.
String postAuthDestination(String? validatedCallback) =>
    validatedCallback != null && validatedCallback.isNotEmpty
    ? validatedCallback
    : defaultPostAuthRoute;
