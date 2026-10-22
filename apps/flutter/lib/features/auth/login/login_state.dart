import 'package:equatable/equatable.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';

/// Outcome line of the forgot-password modal.
enum ForgotStatusType { none, success, error }

/// The forgot-password modal (`login-form.tsx:467-504`).
class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.open = false,
    this.email = '',
    this.submitting = false,
    this.statusType = ForgotStatusType.none,
    this.message = '',
  });

  final bool open;
  final String email;
  final bool submitting;
  final ForgotStatusType statusType;
  final String message;

  /// Primary enabled until the field is empty or a request is in flight.
  bool get canSend => email.isNotEmpty && !submitting;

  ForgotPasswordState copyWith({
    bool? open,
    String? email,
    bool? submitting,
    ForgotStatusType? statusType,
    String? message,
  }) => ForgotPasswordState(
    open: open ?? this.open,
    email: email ?? this.email,
    submitting: submitting ?? this.submitting,
    statusType: statusType ?? this.statusType,
    message: message ?? this.message,
  );

  @override
  List<Object?> get props => [open, email, submitting, statusType, message];
}

/// State of the login page (`login-form.tsx`).
class LoginState extends Equatable {
  const LoginState({
    this.loading = true,
    this.options = const AuthPageOptions(),
    this.callbackUrl = defaultPostAuthRoute,
    this.callbackValid = false,
    this.isInviteFlow = false,
    this.email = '',
    this.password = '',
    this.emailErrors = const <String>[],
    this.passwordErrors = const <String>[],
    this.showEmailErrors = false,
    this.showPasswordErrors = false,
    this.policyError,
    this.resetSuccessMessage,
    this.submitting = false,
    this.socialInFlight,
    this.forgot = const ForgotPasswordState(),
  });

  /// Options and session still loading: the route skeleton shows.
  final bool loading;
  final AuthPageOptions options;

  /// The validated `?callbackUrl`, else `/home` (sent as `callbackURL`).
  final String callbackUrl;

  /// Whether a valid `?callbackUrl` was carried in (it then survives the
  /// sign-up cross-link and decides the post-auth destination).
  final bool callbackValid;
  final bool isInviteFlow;
  final String email;
  final String password;
  final List<String> emailErrors;
  final List<String> passwordErrors;
  final bool showEmailErrors;
  final bool showPasswordErrors;

  /// A 403 refusal about the account, shown in the form-level slot.
  final String? policyError;

  /// `?resetSuccess=true` line, cleared by the next submit attempt.
  final String? resetSuccessMessage;
  final bool submitting;
  final SocialProvider? socialInFlight;
  final ForgotPasswordState forgot;

  List<String> get visibleEmailErrors =>
      showEmailErrors ? emailErrors : const <String>[];

  List<String> get visiblePasswordErrors =>
      showPasswordErrors ? passwordErrors : const <String>[];

  /// `canSubmit`: both fields filled.
  bool get canSubmit => email.trim().isNotEmpty && password.isNotEmpty;

  LoginState copyWith({
    bool? loading,
    AuthPageOptions? options,
    String? callbackUrl,
    bool? callbackValid,
    bool? isInviteFlow,
    String? email,
    String? password,
    List<String>? emailErrors,
    List<String>? passwordErrors,
    bool? showEmailErrors,
    bool? showPasswordErrors,
    String? Function()? policyError,
    String? Function()? resetSuccessMessage,
    bool? submitting,
    SocialProvider? Function()? socialInFlight,
    ForgotPasswordState? forgot,
  }) => LoginState(
    loading: loading ?? this.loading,
    options: options ?? this.options,
    callbackUrl: callbackUrl ?? this.callbackUrl,
    callbackValid: callbackValid ?? this.callbackValid,
    isInviteFlow: isInviteFlow ?? this.isInviteFlow,
    email: email ?? this.email,
    password: password ?? this.password,
    emailErrors: emailErrors ?? this.emailErrors,
    passwordErrors: passwordErrors ?? this.passwordErrors,
    showEmailErrors: showEmailErrors ?? this.showEmailErrors,
    showPasswordErrors: showPasswordErrors ?? this.showPasswordErrors,
    policyError: policyError == null ? this.policyError : policyError(),
    resetSuccessMessage: resetSuccessMessage == null
        ? this.resetSuccessMessage
        : resetSuccessMessage(),
    submitting: submitting ?? this.submitting,
    socialInFlight: socialInFlight == null
        ? this.socialInFlight
        : socialInFlight(),
    forgot: forgot ?? this.forgot,
  );

  @override
  List<Object?> get props => [
    loading,
    options,
    callbackUrl,
    callbackValid,
    isInviteFlow,
    email,
    password,
    emailErrors,
    passwordErrors,
    showEmailErrors,
    showPasswordErrors,
    policyError,
    resetSuccessMessage,
    submitting,
    socialInFlight,
    forgot,
  ];
}
