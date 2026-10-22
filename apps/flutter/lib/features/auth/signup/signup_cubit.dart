import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_navigator.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/email_validation.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';
import 'package:sim_app/features/auth/signup/signup_state.dart';

/// `PASSWORD_VALIDATIONS` of `signup-form.tsx:42-57`: every failing rule, in
/// rule order.
List<String> validateSignupPassword(String value) => <String>[
  if (value.length < 8) 'Password must be at least 8 characters long.',
  if (!RegExp('[A-Z]').hasMatch(value))
    'Password must include at least one uppercase letter.',
  if (!RegExp('[a-z]').hasMatch(value))
    'Password must include at least one lowercase letter.',
  if (!RegExp('[0-9]').hasMatch(value))
    'Password must include at least one number.',
  if (!RegExp(r'[#?!@$%^&*-]').hasMatch(value))
    'Password must include at least one special character.',
];

final RegExp _nameCharacters = RegExp(r"^[\p{L}\s\-']+$", unicode: true);
final RegExp _consecutiveSpaces = RegExp(r'\s\s');

/// `NAME_VALIDATIONS` of `signup-form.tsx:59-76, 171-193`.
List<String> validateSignupName(String value) {
  if (value.isEmpty) return const <String>['Name is required.'];
  if (value.trim().isEmpty) return const <String>['Name cannot be empty.'];
  return <String>[
    if (!_nameCharacters.hasMatch(value.trim()))
      'Name can only contain letters, spaces, hyphens, and apostrophes.',
    if (_consecutiveSpaces.hasMatch(value))
      'Name cannot contain consecutive spaces.',
  ];
}

/// Where a failed `client.signUp.email` lands (`signup-form.tsx:296-341`).
class SignupErrorMapping {
  const SignupErrorMapping({this.emailError, this.passwordErrors});

  final String? emailError;
  final List<String>? passwordErrors;
}

SignupErrorMapping mapSignupError(Object error) {
  const first = 'Failed to create account';
  final code = error is ApiClientError ? (error.code ?? '') : '';
  final message = error is ApiClientError ? error.message : '';
  if (code.contains('USER_ALREADY_EXISTS')) {
    return const SignupErrorMapping(
      emailError:
          'An account with this email already exists. Please sign in instead.',
    );
  }
  if (code.contains('BAD_REQUEST') ||
      message.contains('Email and password sign up is not enabled') ||
      code.contains('INVALID_EMAIL')) {
    return const SignupErrorMapping(emailError: first);
  }
  if (code.contains('PASSWORD_TOO_SHORT')) {
    return const SignupErrorMapping(
      passwordErrors: <String>[
        first,
        'Password must be at least 8 characters long.',
      ],
    );
  }
  if (code.contains('PASSWORD_TOO_LONG')) {
    return const SignupErrorMapping(
      passwordErrors: <String>[
        first,
        'Password must be less than 128 characters long.',
      ],
    );
  }
  if (code.contains('network')) {
    return const SignupErrorMapping(
      passwordErrors: <String>[
        first,
        'Network error. Please check your connection and try again.',
      ],
    );
  }
  if (code.contains('rate limit')) {
    return const SignupErrorMapping(
      passwordErrors: <String>[
        first,
        'Too many requests. Please wait a moment before trying again.',
      ],
    );
  }
  return const SignupErrorMapping(passwordErrors: <String>[first]);
}

/// State machine of `/signup` (`auth-signup.md`).
class SignupCubit extends Cubit<SignupState> {
  SignupCubit({
    required AuthApi api,
    required AuthNavigator navigator,
    required AuthSessionStore sessionStore,
    required String origin,
    Map<String, String> query = const <String, String>{},
  }) : _api = api,
       _navigator = navigator,
       _store = sessionStore,
       _origin = origin,
       _callbackParam = query['redirect'] ?? query['callbackUrl'],
       super(_initial(query, origin));

  static SignupState _initial(Map<String, String> query, String origin) {
    final redirect = resolveAuthRedirect(
      redirect: query['redirect'],
      callbackUrl: query['callbackUrl'],
      inviteFlow: query['invite_flow'],
    );
    final valid = validateCallbackUrl(redirect.rawCallbackUrl, origin: origin);
    final email = query['email'] ?? '';
    return SignupState(
      redirectUrl: valid ? redirect.rawCallbackUrl : '',
      isInviteFlow: redirect.isInviteFlow,
      email: email,
      emailErrors: email.isEmpty ? const <String>[] : validateEmailField(email),
    );
  }

  final AuthApi _api;
  final AuthNavigator _navigator;
  final AuthSessionStore _store;
  final String _origin;
  final String? _callbackParam;

  /// `buildAuthCrossLink('/login', { callbackUrl: redirectUrl || null, isInviteFlow })`.
  String get loginHref => buildAuthCrossLink(
    '/login',
    callbackUrl: state.redirectUrl.isEmpty ? null : state.redirectUrl,
    isInviteFlow: state.isInviteFlow,
  );

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

  void nameChanged(String value) => emit(
    state.copyWith(
      name: value,
      nameErrors: validateSignupName(value),
      showNameErrors: false,
    ),
  );

  void emailChanged(String value) => emit(
    state.copyWith(
      email: value,
      emailErrors: validateEmailField(value),
      showEmailErrors: false,
      serverEmailError: () => null,
    ),
  );

  void passwordChanged(String value) => emit(
    state.copyWith(
      password: value,
      passwordErrors: validateSignupPassword(value),
      showPasswordErrors: false,
    ),
  );

  /// Form submit (`signup-form.tsx:225-385`).
  Future<void> submit() async {
    if (state.submitting) return;
    final email = state.email.trim().toLowerCase();
    final password = state.password;
    final trimmedName = state.name.trim();
    final nameErrors = validateSignupName(trimmedName);
    final emailErrors = validateEmailField(email);
    final passwordErrors = validateSignupPassword(password);
    emit(
      state.copyWith(
        submitting: true,
        nameErrors: nameErrors,
        showNameErrors: nameErrors.isNotEmpty,
        emailErrors: emailErrors,
        showEmailErrors: emailErrors.isNotEmpty,
        passwordErrors: passwordErrors,
        showPasswordErrors: passwordErrors.isNotEmpty,
      ),
    );
    if (nameErrors.isNotEmpty ||
        emailErrors.isNotEmpty ||
        passwordErrors.isNotEmpty) {
      emit(state.copyWith(submitting: false));
      return;
    }
    if (trimmedName.length > 100) {
      emit(
        state.copyWith(
          submitting: false,
          nameErrors: const <String>[
            'Name will be truncated to 100 characters. Please shorten your name.',
          ],
          showNameErrors: true,
        ),
      );
      return;
    }
    emit(state.copyWith(formError: () => null));
    try {
      await _api.signUpEmail(
        email: email,
        password: password,
        name: trimmedName,
      );
    } on Exception catch (error) {
      if (isClosed) return;
      final mapping = mapSignupError(error);
      emit(
        state.copyWith(
          submitting: false,
          serverEmailError: mapping.emailError == null
              ? null
              : () => mapping.emailError,
          passwordErrors: mapping.passwordErrors,
          showPasswordErrors:
              mapping.passwordErrors != null || state.showPasswordErrors,
        ),
      );
      return;
    }
    try {
      await _api.getSession();
    } on Exception {
      // The destination page refetches the session itself.
    }
    if (isClosed) return;
    final verificationEnabled = state.options.emailVerificationEnabled;
    _store
      ..remove(AuthStorageKeys.verificationEmail)
      ..remove(AuthStorageKeys.postAuthRedirectUrl);
    emit(state.copyWith(submitting: false));
    if (verificationEnabled) {
      _store.write(AuthStorageKeys.verificationEmail, email);
      if (state.redirectUrl.isNotEmpty) {
        _store.write(AuthStorageKeys.postAuthRedirectUrl, state.redirectUrl);
      }
      _navigator.go(verifyFromSignupRoute);
      return;
    }
    _navigator.goToDestination(
      postAuthDestination(state.redirectUrl.isEmpty ? null : state.redirectUrl),
      origin: _origin,
    );
  }

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

  void openSso() => _navigator.go(
    '/sso?${encodeSearchParams({'callbackUrl': state.callbackUrl})}',
  );

  void goToLogin() => _navigator.go(loginHref);

  void goHome() => _navigator.openTopLevel('/');

  void openLegal(String path) => _navigator.openNewTab(path);
}
