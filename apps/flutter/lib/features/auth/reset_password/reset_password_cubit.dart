import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_navigator.dart';
import 'package:sim_app/features/auth/shared/auth_timers.dart';

/// Status line below the fields (`reset-password-content.tsx`).
enum ResetStatusType { none, success, error }

/// `reset-password-form.tsx:38-64`: every failing rule in order.
List<String> validateResetPassword(String password, String confirm) => <String>[
  if (password.length < 8) 'Password must be at least 8 characters long',
  if (password.length > 100) 'Password must not exceed 100 characters',
  if (!RegExp('[A-Z]').hasMatch(password))
    'Password must contain at least one uppercase letter',
  if (!RegExp('[a-z]').hasMatch(password))
    'Password must contain at least one lowercase letter',
  if (!RegExp('[0-9]').hasMatch(password))
    'Password must contain at least one number',
  if (!RegExp('[^A-Za-z0-9]').hasMatch(password))
    'Password must contain at least one special character',
  if (password != confirm) 'Passwords do not match',
];

/// State of `/reset-password` (`auth-reset-password.md`).
class ResetPasswordState extends Equatable {
  const ResetPasswordState({
    this.token,
    this.password = '',
    this.confirm = '',
    this.validationMessages = const <String>[],
    this.submitting = false,
    this.statusType = ResetStatusType.none,
    this.statusText = '',
  });

  final String? token;
  final String password;
  final String confirm;
  final List<String> validationMessages;
  final bool submitting;
  final ResetStatusType statusType;
  final String statusText;

  static const String missingTokenMessage =
      'Invalid or missing reset token. Please request a new password reset link.';

  bool get hasToken => token != null && token!.isNotEmpty;

  /// Fields and submit are disabled without a token and while submitting.
  bool get fieldsEnabled => hasToken && !submitting;

  bool get canSubmit =>
      fieldsEnabled && password.isNotEmpty && confirm.isNotEmpty;

  bool get hasValidationErrors => validationMessages.isNotEmpty;

  /// The status line: the token error wins, else the request outcome.
  ({ResetStatusType type, String text})? get status {
    if (!hasToken) {
      return (type: ResetStatusType.error, text: missingTokenMessage);
    }
    if (statusType == ResetStatusType.none) return null;
    return (type: statusType, text: statusText);
  }

  ResetPasswordState copyWith({
    String? password,
    String? confirm,
    List<String>? validationMessages,
    bool? submitting,
    ResetStatusType? statusType,
    String? statusText,
  }) => ResetPasswordState(
    token: token,
    password: password ?? this.password,
    confirm: confirm ?? this.confirm,
    validationMessages: validationMessages ?? this.validationMessages,
    submitting: submitting ?? this.submitting,
    statusType: statusType ?? this.statusType,
    statusText: statusText ?? this.statusText,
  );

  @override
  List<Object?> get props => [
    token,
    password,
    confirm,
    validationMessages,
    submitting,
    statusType,
    statusText,
  ];
}

/// Port of `reset-password-content.tsx` + `reset-password-form.tsx`.
class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  ResetPasswordCubit({
    required AuthApi api,
    required AuthNavigator navigator,
    required AuthTimers timers,
    Map<String, String> query = const <String, String>{},
  }) : _api = api,
       _navigator = navigator,
       _timers = timers,
       super(ResetPasswordState(token: query['token']));

  static const Duration redirectDelay = Duration(milliseconds: 1500);

  final AuthApi _api;
  final AuthNavigator _navigator;
  final AuthTimers _timers;

  void passwordChanged(String value) => emit(state.copyWith(password: value));

  void confirmChanged(String value) => emit(state.copyWith(confirm: value));

  /// Submit: build the rule list, stop if non-empty, else
  /// `POST /api/auth/reset-password {token, newPassword}`.
  Future<void> submit() async {
    if (!state.canSubmit) return;
    final errors = validateResetPassword(state.password, state.confirm);
    if (errors.isNotEmpty) {
      emit(state.copyWith(validationMessages: errors));
      return;
    }
    emit(
      state.copyWith(
        validationMessages: const <String>[],
        submitting: true,
        statusType: ResetStatusType.none,
        statusText: '',
      ),
    );
    try {
      await _api.resetPassword(
        token: state.token!,
        newPassword: state.password,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          statusType: ResetStatusType.success,
          statusText: 'Password reset successful! Redirecting to login...',
        ),
      );
      _timers.schedule(redirectDelay, () {
        if (!isClosed) _navigator.go('/login?resetSuccess=true');
      });
    } on Exception catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          statusType: ResetStatusType.error,
          statusText: error is ApiClientError && error.message.isNotEmpty
              ? error.message
              : 'Failed to reset password',
        ),
      );
    }
  }

  void backToLogin() => _navigator.go('/login');

  void goHome() => _navigator.openTopLevel('/');
}
