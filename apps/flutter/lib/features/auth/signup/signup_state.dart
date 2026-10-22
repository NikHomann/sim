import 'package:equatable/equatable.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';

/// State of the signup page (`signup-form.tsx`).
class SignupState extends Equatable {
  const SignupState({
    this.loading = true,
    this.options = const AuthPageOptions(),
    this.redirectUrl = '',
    this.isInviteFlow = false,
    this.name = '',
    this.email = '',
    this.password = '',
    this.nameErrors = const <String>[],
    this.emailErrors = const <String>[],
    this.passwordErrors = const <String>[],
    this.showNameErrors = false,
    this.showEmailErrors = false,
    this.showPasswordErrors = false,
    this.serverEmailError,
    this.formError,
    this.submitting = false,
    this.socialInFlight,
  });

  final bool loading;
  final AuthPageOptions options;

  /// The validated `redirect`/`callbackUrl`, or `''`.
  final String redirectUrl;
  final bool isInviteFlow;
  final String name;
  final String email;
  final String password;
  final List<String> nameErrors;
  final List<String> emailErrors;
  final List<String> passwordErrors;
  final bool showNameErrors;
  final bool showEmailErrors;
  final bool showPasswordErrors;

  /// `emailError`: the server's email-field line (cleared on typing).
  final String? serverEmailError;

  /// `formError`: the captcha failure line.
  final String? formError;
  final bool submitting;
  final SocialProvider? socialInFlight;

  /// `callbackURL` for social/SSO: `redirectUrl || '/home'`.
  String get callbackUrl =>
      redirectUrl.isNotEmpty ? redirectUrl : defaultPostAuthRoute;

  List<String> get visibleNameErrors =>
      showNameErrors ? nameErrors : const <String>[];

  /// Client errors while shown; otherwise the server line.
  List<String> get visibleEmailErrors {
    if (showEmailErrors && emailErrors.isNotEmpty) return emailErrors;
    if (serverEmailError != null && !showEmailErrors) {
      return <String>[serverEmailError!];
    }
    return const <String>[];
  }

  bool get emailHasError =>
      serverEmailError != null || (showEmailErrors && emailErrors.isNotEmpty);

  List<String> get visiblePasswordErrors =>
      showPasswordErrors ? passwordErrors : const <String>[];

  bool get canSubmit =>
      name.trim().isNotEmpty && email.trim().isNotEmpty && password.isNotEmpty;

  SignupState copyWith({
    bool? loading,
    AuthPageOptions? options,
    String? redirectUrl,
    bool? isInviteFlow,
    String? name,
    String? email,
    String? password,
    List<String>? nameErrors,
    List<String>? emailErrors,
    List<String>? passwordErrors,
    bool? showNameErrors,
    bool? showEmailErrors,
    bool? showPasswordErrors,
    String? Function()? serverEmailError,
    String? Function()? formError,
    bool? submitting,
    SocialProvider? Function()? socialInFlight,
  }) => SignupState(
    loading: loading ?? this.loading,
    options: options ?? this.options,
    redirectUrl: redirectUrl ?? this.redirectUrl,
    isInviteFlow: isInviteFlow ?? this.isInviteFlow,
    name: name ?? this.name,
    email: email ?? this.email,
    password: password ?? this.password,
    nameErrors: nameErrors ?? this.nameErrors,
    emailErrors: emailErrors ?? this.emailErrors,
    passwordErrors: passwordErrors ?? this.passwordErrors,
    showNameErrors: showNameErrors ?? this.showNameErrors,
    showEmailErrors: showEmailErrors ?? this.showEmailErrors,
    showPasswordErrors: showPasswordErrors ?? this.showPasswordErrors,
    serverEmailError: serverEmailError == null
        ? this.serverEmailError
        : serverEmailError(),
    formError: formError == null ? this.formError : formError(),
    submitting: submitting ?? this.submitting,
    socialInFlight: socialInFlight == null
        ? this.socialInFlight
        : socialInFlight(),
  );

  @override
  List<Object?> get props => [
    loading,
    options,
    redirectUrl,
    isInviteFlow,
    name,
    email,
    password,
    nameErrors,
    emailErrors,
    passwordErrors,
    showNameErrors,
    showEmailErrors,
    showPasswordErrors,
    serverEmailError,
    formError,
    submitting,
    socialInFlight,
  ];
}
