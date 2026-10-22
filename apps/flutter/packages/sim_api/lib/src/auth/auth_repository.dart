import 'package:dio/dio.dart';
import 'package:sim_api/src/auth/auth_models.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/sim_http_client.dart';

/// Better Auth error codes the auth pages branch on.
extension AuthErrorCodes on ApiClientError {
  /// `EMAIL_NOT_VERIFIED`: the login form redirects to `/verify`.
  bool get isEmailNotVerified => code?.contains('EMAIL_NOT_VERIFIED') ?? false;

  /// A 403 whose body carries a `message` is a policy refusal (SSO required,
  /// suspended account) shown in the form-level slot, not against the
  /// password field (`login-form.tsx:210`). A message-less 403 (or one with
  /// only `error`) is a credential error.
  bool get isPolicyRefusal {
    if (status != 403) return false;
    final payload = body;
    if (payload is! Map) return false;
    final text = payload['message'];
    return text is String && text.isNotEmpty;
  }
}

/// Minting a socket token failed because the session is gone (401): the
/// socket connects with a `null` token and the server rejects it, which the
/// app turns into re-authentication.
class SocketTokenAuthRequiredError implements Exception {
  const SocketTokenAuthRequiredError();

  @override
  String toString() => 'Authentication required';
}

/// Minting a socket token failed for a retryable reason (rate limit, 5xx,
/// network); [retryAfter] is the server's `Retry-After` when it sent one.
class SocketTokenUnavailableError implements Exception {
  const SocketTokenUnavailableError({this.retryAfter, this.cause});

  final Duration? retryAfter;
  final Object? cause;

  @override
  String toString() => 'Failed to generate socket token';
}

/// The Better Auth endpoints of `docs/port/03-api-and-auth.md` §1.
///
/// Every method throws [ApiClientError] on a non-2xx response (Better Auth
/// bodies are `{code, message}`), [ApiNetworkError] without a response.
class AuthRepository {
  AuthRepository(this._http);

  final SimHttpClient _http;

  static const _retryAfterMaxMs = 30000;

  /// `POST /api/auth/sign-in/email`. On success the session cookie is set and
  /// the signed-in user returned.
  Future<AuthUser?> signInEmail({
    required String email,
    required String password,
    String? callbackUrl,
    bool? rememberMe,
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/auth/sign-in/email',
      body: {
        'email': email,
        'password': password,
        'callbackURL': ?callbackUrl,
        'rememberMe': ?rememberMe,
      },
      cancelToken: cancelToken,
    );
    return _userOf(response.data);
  }

  /// `POST /api/auth/sign-up/email`. [captchaToken] goes out as
  /// `x-captcha-response` (Turnstile) when the deployment requires it.
  Future<AuthUser?> signUpEmail({
    required String email,
    required String password,
    required String name,
    String? callbackUrl,
    String? captchaToken,
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/auth/sign-up/email',
      body: {
        'email': email,
        'password': password,
        'name': name,
        'callbackURL': ?callbackUrl,
      },
      headers: {'x-captcha-response': ?captchaToken},
      cancelToken: cancelToken,
    );
    return _userOf(response.data);
  }

  /// `POST /api/auth/sign-in/social` → the provider URL to open.
  Future<SocialSignInStart> signInSocial({
    required String provider,
    required String callbackUrl,
    String? errorCallbackUrl,
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/auth/sign-in/social',
      body: {
        'provider': provider,
        'callbackURL': callbackUrl,
        'errorCallbackURL': ?errorCallbackUrl,
      },
      cancelToken: cancelToken,
    );
    final data = response.data;
    final url = data is Map ? data['url'] : null;
    if (url is! String || url.isEmpty) {
      throw ApiClientError(
        status: response.status,
        message: 'Social sign-in did not return a URL',
        body: data,
      );
    }
    return SocialSignInStart(
      url: url,
      redirect: data is Map && data['redirect'] == true,
    );
  }

  /// `POST /api/auth/email-otp/verify-email` (auto sign-in on success).
  Future<AuthUser?> verifyEmailOtp({
    required String email,
    required String otp,
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/auth/email-otp/verify-email',
      body: {'email': email, 'otp': otp},
      cancelToken: cancelToken,
    );
    return _userOf(response.data);
  }

  /// `POST /api/auth/email-otp/send-verification-otp`
  /// (`type: 'email-verification'` is the only type the catch-all allows).
  Future<void> sendVerificationOtp({
    required String email,
    String type = 'email-verification',
    CancelToken? cancelToken,
  }) async {
    await _http.send(
      method: 'POST',
      path: '/api/auth/email-otp/send-verification-otp',
      body: {'email': email, 'type': type},
      cancelToken: cancelToken,
    );
  }

  /// `GET /api/auth/get-session`; `null` when signed out. [disableCookieCache]
  /// forces a database read past Better Auth's 5-minute cookie cache.
  Future<AuthSession?> getSession({
    bool disableCookieCache = false,
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'GET',
      path: '/api/auth/get-session',
      query: {if (disableCookieCache) 'disableCookieCache': true},
      cancelToken: cancelToken,
    );
    return AuthSession.fromJson(response.data);
  }

  /// `POST /api/auth/sign-out`; also forgets the desktop cookie jar.
  Future<void> signOut({CancelToken? cancelToken}) async {
    try {
      await _http.send(
        method: 'POST',
        path: '/api/auth/sign-out',
        body: const <String, Object?>{},
        cancelToken: cancelToken,
      );
    } finally {
      await _http.clearCookies();
    }
  }

  /// `POST /api/auth/forget-password` `{email, redirectTo?}`.
  Future<void> forgetPassword({
    required String email,
    String? redirectTo,
    CancelToken? cancelToken,
  }) async {
    await _http.send(
      method: 'POST',
      path: '/api/auth/forget-password',
      body: {'email': email, 'redirectTo': ?redirectTo},
      cancelToken: cancelToken,
    );
  }

  /// `POST /api/auth/reset-password` `{token, newPassword}`.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
    CancelToken? cancelToken,
  }) async {
    await _http.send(
      method: 'POST',
      path: '/api/auth/reset-password',
      body: {'token': token, 'newPassword': newPassword},
      cancelToken: cancelToken,
    );
  }

  /// `GET /api/auth/providers`.
  Future<AuthProviders> providers({CancelToken? cancelToken}) async {
    final response = await _http.send(
      method: 'GET',
      path: '/api/auth/providers',
      cancelToken: cancelToken,
    );
    return AuthProviders.fromJson(response.data);
  }

  /// `POST /api/auth/sso/resolve` `{email, providerId?}` → the provider id
  /// to launch at `/sso/launch/[providerId]`.
  Future<String> resolveSsoProvider({
    required String email,
    String? providerId,
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/auth/sso/resolve',
      body: {'email': email, 'providerId': ?providerId},
      cancelToken: cancelToken,
    );
    final data = response.data;
    final resolved = data is Map ? data['providerId'] : null;
    if (resolved is! String || resolved.isEmpty) {
      throw ApiClientError(
        status: response.status,
        message: 'SSO resolve did not return a provider',
        body: data,
      );
    }
    return resolved;
  }

  /// `POST /api/auth/socket-token` → the one-time token for the Socket.IO
  /// handshake. Mirrors `generateSocketToken` in `socket-provider.tsx`: 401
  /// is [SocketTokenAuthRequiredError], anything else
  /// [SocketTokenUnavailableError] with the parsed `Retry-After`.
  Future<String> socketToken({CancelToken? cancelToken}) async {
    final ApiResponse<Object?> response;
    try {
      response = await _http.send(
        method: 'POST',
        path: '/api/auth/socket-token',
        headers: const {'cache-control': 'no-store'},
        cancelToken: cancelToken,
      );
    } on ApiClientError catch (error) {
      if (error.status == 401) throw const SocketTokenAuthRequiredError();
      final retryAfter = error.retryAfter;
      throw SocketTokenUnavailableError(
        retryAfter: retryAfter == null
            ? null
            : Duration(
                milliseconds: retryAfter.inMilliseconds.clamp(
                  0,
                  _retryAfterMaxMs,
                ),
              ),
        cause: error,
      );
    } on ApiNetworkError catch (error) {
      throw SocketTokenUnavailableError(cause: error);
    }
    final data = response.data;
    final token = data is Map ? data['token'] : null;
    if (token is! String || token.isEmpty) {
      throw SocketTokenUnavailableError(
        cause: ApiClientError(
          status: response.status,
          message: 'Invalid socket token',
          body: data,
        ),
      );
    }
    return token;
  }

  /// Desktop handoff: redeems the one-time token the loopback listener
  /// received at `POST /api/auth/one-time-token/verify`, which sets the
  /// session cookie in the desktop cookie jar. The listener itself is
  /// Phase 6.
  Future<AuthSession?> redeemOneTimeToken(
    String token, {
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/auth/one-time-token/verify',
      body: {'token': token},
      cancelToken: cancelToken,
    );
    return AuthSession.fromJson(response.data);
  }

  static AuthUser? _userOf(Object? data) {
    if (data is! Map) return null;
    final user = data['user'];
    return user is Map ? AuthUser.fromJson(user) : null;
  }
}
