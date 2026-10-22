import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_navigator.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';
import 'package:sim_app/features/auth/shared/email_validation.dart';

/// Copy of `ee/sso/components/sso-form.tsx:20-35`.
abstract final class SsoCopy {
  static const String signInError =
      'Unable to start SSO. Check your email and try again.';
  static const String noProviderError =
      'No SSO provider is configured for this email domain. Ask your administrator.';
  static const String testLinkError =
      'This sign-in link is not set up for your email domain. Ask your administrator for the right link.';
  static const Map<String, String> errorMessages = <String, String>{
    'account_not_found':
        'No account found. Please contact your administrator to set up SSO access.',
    'sso_failed': 'SSO authentication failed. Please try again.',
    'invalid_provider': 'SSO provider not configured correctly.',
    'sso_no_seats':
        'Your organization has no available seat capacity. Ask an administrator to increase capacity or remove an unused member.',
    'sso_account_conflict':
        'This Sim account is already a member of another organization. Leave that organization before trying again, or ask an administrator for external workspace access.',
    'sso_provisioning_failed':
        'SSO succeeded, but organization access could not be set up safely. No session was created; please try again or contact your administrator.',
  };

  /// `?error=` → message; an unknown code reads as the generic failure.
  static String? forErrorCode(String? code) {
    if (code == null) return null;
    return errorMessages[code] ??
        'SSO authentication failed. Please try again.';
  }
}

/// State of `/sso` (`auth-sso.md`).
class SsoState extends Equatable {
  const SsoState({
    this.loading = true,
    this.options = const AuthPageOptions(),
    this.email = '',
    this.emailErrors = const <String>[],
    this.showEmailErrors = false,
    this.formError,
    this.submitting = false,
    this.callbackUrl = defaultPostAuthRoute,
    this.testProviderId,
  });

  final bool loading;
  final AuthPageOptions options;
  final String email;
  final List<String> emailErrors;
  final bool showEmailErrors;
  final String? formError;
  final bool submitting;

  /// Validated `?callbackUrl`, default `/home`.
  final String callbackUrl;

  /// `?provider=`: a test link naming the provider to try.
  final String? testProviderId;

  List<String> get visibleEmailErrors =>
      showEmailErrors ? emailErrors : const <String>[];

  bool get hasEmailError => visibleEmailErrors.isNotEmpty;

  SsoState copyWith({
    bool? loading,
    AuthPageOptions? options,
    String? email,
    List<String>? emailErrors,
    bool? showEmailErrors,
    String? Function()? formError,
    bool? submitting,
  }) => SsoState(
    loading: loading ?? this.loading,
    options: options ?? this.options,
    email: email ?? this.email,
    emailErrors: emailErrors ?? this.emailErrors,
    showEmailErrors: showEmailErrors ?? this.showEmailErrors,
    formError: formError == null ? this.formError : formError(),
    submitting: submitting ?? this.submitting,
    callbackUrl: callbackUrl,
    testProviderId: testProviderId,
  );

  @override
  List<Object?> get props => [
    loading,
    options,
    email,
    emailErrors,
    showEmailErrors,
    formError,
    submitting,
    callbackUrl,
    testProviderId,
  ];
}

/// Port of `SSOFormContent`.
class SsoCubit extends Cubit<SsoState> {
  SsoCubit({
    required AuthApi api,
    required AuthNavigator navigator,
    required String origin,
    Map<String, String> query = const <String, String>{},
  }) : _api = api,
       _navigator = navigator,
       super(_initial(query, origin));

  static SsoState _initial(Map<String, String> query, String origin) {
    final callback = query['callbackUrl'];
    final email = query['email'] ?? '';
    final provider = query['provider'];
    return SsoState(
      email: email,
      emailErrors: validateEmailField(email),
      formError: SsoCopy.forErrorCode(query['error']),
      callbackUrl: validateCallbackUrl(callback, origin: origin)
          ? callback!
          : defaultPostAuthRoute,
      testProviderId: provider == null || provider.isEmpty ? null : provider,
    );
  }

  final AuthApi _api;
  final AuthNavigator _navigator;

  String get _encodedCallback => Uri.encodeComponent(state.callbackUrl);

  /// `/login?callbackUrl=<encoded>`.
  String get loginHref => '/login?callbackUrl=$_encodedCallback';

  /// `/signup?callbackUrl=<encoded>`.
  String get signupHref => '/signup?callbackUrl=$_encodedCallback';

  /// `errorCallbackURL` of the SSO sign-in: back to this form with
  /// `sso_failed`, the test provider (before `callbackUrl`, which the plugin
  /// appends to) and the callback.
  String get errorCallbackUrl {
    final provider = state.testProviderId;
    final providerPart = provider == null
        ? ''
        : '&provider=${Uri.encodeComponent(provider)}';
    return '/sso?error=sso_failed$providerPart&callbackUrl=$_encodedCallback';
  }

  /// Cold load: the page redirects to `/login` when SSO is disabled.
  Future<void> load() async {
    AuthPageOptions options;
    try {
      options = await _api.loadOptions();
    } on Exception {
      options = const AuthPageOptions();
    }
    if (isClosed) return;
    if (!options.ssoEnabled) {
      _navigator.go('/login');
      return;
    }
    emit(state.copyWith(loading: false, options: options));
  }

  void emailChanged(String value) => emit(
    state.copyWith(
      email: value,
      emailErrors: validateEmailField(value),
      showEmailErrors: false,
      formError: () => null,
    ),
  );

  /// Submit: resolve the provider, then start the SSO sign-in and leave for
  /// the IdP.
  Future<void> submit() async {
    if (state.submitting) return;
    final email = state.email.trim().toLowerCase();
    final errors = validateEmailField(email);
    emit(
      state.copyWith(
        submitting: true,
        formError: () => null,
        emailErrors: errors,
        showEmailErrors: errors.isNotEmpty,
      ),
    );
    if (errors.isNotEmpty) {
      emit(state.copyWith(submitting: false));
      return;
    }
    final String providerId;
    try {
      providerId = await _api.resolveSsoProvider(
        email: email,
        providerId: state.testProviderId,
      );
    } on Exception catch (error) {
      if (isClosed) return;
      final noProvider = error is ApiClientError && error.status == 404;
      final noProviderError = state.testProviderId != null
          ? SsoCopy.testLinkError
          : SsoCopy.noProviderError;
      emit(
        state.copyWith(
          submitting: false,
          formError: () => noProvider ? noProviderError : SsoCopy.signInError,
        ),
      );
      return;
    }
    try {
      final url = await _api.startSsoSignIn(
        email: email,
        providerId: providerId,
        callbackUrl: state.callbackUrl,
        errorCallbackUrl: errorCallbackUrl,
      );
      if (isClosed) return;
      emit(state.copyWith(submitting: false));
      _navigator.openTopLevel(url);
    } on Exception {
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          formError: () => SsoCopy.signInError,
        ),
      );
    }
  }

  void goToLogin() => _navigator.go(loginHref);

  void goToSignup() => _navigator.go(signupHref);

  void openLegal(String path) => _navigator.openNewTab(path);

  void goHome() => _navigator.openTopLevel('/');
}
