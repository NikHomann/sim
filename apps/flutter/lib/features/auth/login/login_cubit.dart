import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/login/login_state.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_navigator.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/auth_timers.dart';
import 'package:sim_app/features/auth/shared/email_validation.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';

/// `validatePassword` of `login-form.tsx:59-84`.
List<String> validateLoginPassword(String value) {
  if (value.isEmpty) return const <String>['Password is required.'];
  if (value.trim().isEmpty) return const <String>['Password cannot be empty.'];
  return const <String>[];
}

/// The password-field lines for a failed `client.signIn.email`
/// (`login-form.tsx:219-259`): the first line always, a second from the first
/// matching branch.
List<String> mapLoginError(ApiClientError error) {
  final code = error.code ?? '';
  final message = error.message;
  final lines = <String>['Invalid email or password'];
  if (code.contains('BAD_REQUEST') ||
      message.contains('Email and password sign in is not enabled')) {
    lines.add('Email sign in is currently disabled.');
  } else if (code.contains('INVALID_CREDENTIALS') ||
      message.contains('invalid password')) {
    lines.add('Invalid email or password. Please try again.');
  } else if (code.contains('USER_NOT_FOUND') || message.contains('not found')) {
    lines.add('No account found with this email. Please sign up first.');
  } else if (code.contains('MISSING_CREDENTIALS')) {
    lines.add('Please enter both email and password.');
  } else if (code.contains('EMAIL_PASSWORD_DISABLED')) {
    lines.add('Email and password login is disabled.');
  } else if (code.contains('FAILED_TO_CREATE_SESSION')) {
    lines.add('Failed to create session. Please try again later.');
  } else if (code.contains('too many attempts')) {
    lines.add(
      'Too many login attempts. Please try again later or reset your password.',
    );
  } else if (code.contains('account locked')) {
    lines.add(
      'Your account has been locked for security. Please reset your password.',
    );
  } else if (code.contains('network')) {
    lines.add('Network error. Please check your connection and try again.');
  } else if (message.contains('rate limit')) {
    lines.add('Too many requests. Please wait a moment before trying again.');
  }
  return lines;
}

/// The forgot-password modal's error copy for a failed
/// `POST /api/auth/forget-password` (`login-form.tsx:323-337`).
String mapForgotPasswordError(Object error) {
  var message = error is ApiClientError && error.message.isNotEmpty
      ? error.message
      : 'Failed to request password reset';
  if (message.contains('Invalid body parameters') ||
      message.contains('invalid email')) {
    message = 'Please enter a valid email address';
  } else if (message.contains('Email is required')) {
    message = 'Please enter your email address';
  } else if (message.contains('user not found') ||
      message.contains('User not found')) {
    message = 'No account found with this email address';
  }
  return message;
}

/// State machine of `/login` (`auth-login.md`).
class LoginCubit extends Cubit<LoginState> {
  LoginCubit({
    required AuthApi api,
    required AuthNavigator navigator,
    required AuthSessionStore sessionStore,
    required AuthTimers timers,
    required String origin,
    Map<String, String> query = const <String, String>{},
  }) : _api = api,
       _navigator = navigator,
       _store = sessionStore,
       _timers = timers,
       _origin = origin,
       _callbackParam = query['callbackUrl'],
       super(
         LoginState(
           callbackValid: validateCallbackUrl(
             query['callbackUrl'],
             origin: origin,
           ),
           callbackUrl:
               validateCallbackUrl(query['callbackUrl'], origin: origin)
               ? query['callbackUrl']!
               : defaultPostAuthRoute,
           isInviteFlow: query['invite_flow'] == 'true',
           resetSuccessMessage: query['resetSuccess'] == 'true'
               ? 'Password reset successful. Please sign in with your new password.'
               : null,
         ),
       );

  final AuthApi _api;
  final AuthNavigator _navigator;
  final AuthSessionStore _store;
  final AuthTimers _timers;
  final String _origin;
  final String? _callbackParam;

  /// `signupHref`: `/signup` with `invite_flow` and the validated callback.
  String get signupHref => buildAuthCrossLink(
    '/signup',
    callbackUrl: state.callbackValid ? state.callbackUrl : null,
    isInviteFlow: state.isInviteFlow,
  );

  /// Cold load: options (public env + providers) and the session. A signed-in
  /// visitor leaves for entry resolution unless the callback is the OAuth
  /// authorize endpoint (re-authentication for an OAuth client).
  Future<void> load() async {
    AuthPageOptions options;
    try {
      options = await _api.loadOptions();
    } on Exception {
      options = const AuthPageOptions();
    }
    AuthSession? session;
    try {
      session = await _api.getSession();
    } on Exception {
      session = null;
    }
    if (isClosed) return;
    if (session != null &&
        !isOAuthAuthorizationCallback(_callbackParam, origin: _origin)) {
      _navigator.go(defaultPostAuthRoute);
      return;
    }
    emit(state.copyWith(loading: false, options: options));
  }

  void emailChanged(String value) => emit(
    state.copyWith(
      email: value,
      emailErrors: validateEmailField(value),
      showEmailErrors: false,
    ),
  );

  void passwordChanged(String value) => emit(
    state.copyWith(
      password: value,
      passwordErrors: validateLoginPassword(value),
      showPasswordErrors: false,
    ),
  );

  /// Form submit: validate both fields, then `POST /api/auth/sign-in/email`.
  Future<void> submit() async {
    if (state.submitting) return;
    final email = normalizeEmail(state.email);
    final emailErrors = validateEmailField(email);
    final passwordErrors = validateLoginPassword(state.password);
    emit(
      state.copyWith(
        submitting: true,
        policyError: () => null,
        emailErrors: emailErrors,
        showEmailErrors: emailErrors.isNotEmpty,
        passwordErrors: passwordErrors,
        showPasswordErrors: passwordErrors.isNotEmpty,
      ),
    );
    if (emailErrors.isNotEmpty || passwordErrors.isNotEmpty) {
      emit(state.copyWith(submitting: false));
      return;
    }
    try {
      await _api.signInEmail(
        email: email,
        password: state.password,
        callbackUrl: state.callbackUrl,
      );
      if (isClosed) return;
      emit(state.copyWith(submitting: false, resetSuccessMessage: () => null));
      _navigator.goToDestination(
        postAuthDestination(state.callbackValid ? state.callbackUrl : null),
        origin: _origin,
      );
    } on ApiClientError catch (error) {
      if (isClosed) return;
      if (error.isEmailNotVerified || error.message.contains('not verified')) {
        _redirectToVerify(email);
        return;
      }
      if (error.isPolicyRefusal) {
        emit(
          state.copyWith(
            submitting: false,
            resetSuccessMessage: () => null,
            passwordErrors: const <String>[],
            showPasswordErrors: false,
            policyError: () => error.message,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          submitting: false,
          resetSuccessMessage: () => null,
          passwordErrors: mapLoginError(error),
          showPasswordErrors: true,
        ),
      );
    } on ApiNetworkError {
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          resetSuccessMessage: () => null,
          passwordErrors: const <String>['Invalid email or password'],
          showPasswordErrors: true,
        ),
      );
    }
  }

  void _redirectToVerify(String email) {
    _store.write(AuthStorageKeys.verificationEmail, email);
    emit(state.copyWith(submitting: false));
    _navigator.go('/verify');
  }

  /// Social chip: `POST /api/auth/sign-in/social` then leave for the provider.
  Future<void> startSocial(SocialProvider provider) async {
    if (state.socialInFlight != null) return;
    emit(state.copyWith(socialInFlight: () => provider));
    try {
      final url = await _api.startSocialSignIn(
        provider: provider.id,
        callbackUrl: state.callbackUrl,
      );
      _navigator.openTopLevel(url);
    } on Exception {
      // Logged only upstream; the label resets below.
    }
    if (!isClosed) emit(state.copyWith(socialInFlight: () => null));
  }

  /// SSO chip: `/sso?callbackUrl=<encoded>`.
  void openSso() => _navigator.go(
    '/sso?${encodeSearchParams({'callbackUrl': state.callbackUrl})}',
  );

  void goToSignup() => _navigator.go(signupHref);

  /// Logo: a document navigation to the site root.
  void goHome() => _navigator.openTopLevel('/');

  /// Terms / Privacy open in a new tab.
  void openLegal(String path) => _navigator.openNewTab(path);

  void openForgot() => emit(
    state.copyWith(forgot: const ForgotPasswordState(open: true)),
  );

  void closeForgot() {
    if (!state.forgot.open) return;
    emit(state.copyWith(forgot: const ForgotPasswordState()));
  }

  void forgotEmailChanged(String value) =>
      emit(state.copyWith(forgot: state.forgot.copyWith(email: value)));

  /// "Send Reset Link": client validation, then
  /// `POST /api/auth/forget-password {email, redirectTo}`; success shows the
  /// line and closes the modal 2s later.
  Future<void> sendReset() async {
    final forgot = state.forgot;
    if (forgot.submitting) return;
    if (forgot.email.isEmpty) {
      emit(
        state.copyWith(
          forgot: forgot.copyWith(
            statusType: ForgotStatusType.error,
            message: 'Please enter your email address',
          ),
        ),
      );
      return;
    }
    if (quickValidateEmailReason(normalizeEmail(forgot.email)) != null) {
      emit(
        state.copyWith(
          forgot: forgot.copyWith(
            statusType: ForgotStatusType.error,
            message: 'Please enter a valid email address',
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        forgot: forgot.copyWith(
          submitting: true,
          statusType: ForgotStatusType.none,
          message: '',
        ),
      ),
    );
    try {
      await _api.forgetPassword(
        email: forgot.email,
        redirectTo: _api.absoluteUrl('/reset-password'),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          forgot: state.forgot.copyWith(
            submitting: false,
            statusType: ForgotStatusType.success,
            message: 'Password reset link sent to your email',
          ),
        ),
      );
      _timers.schedule(const Duration(milliseconds: 2000), () {
        if (!isClosed) closeForgot();
      });
    } on Exception catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          forgot: state.forgot.copyWith(
            submitting: false,
            statusType: ForgotStatusType.error,
            message: mapForgotPasswordError(error),
          ),
        ),
      );
    }
  }
}
