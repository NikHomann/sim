import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_navigator.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/auth_timers.dart';
import 'package:sim_app/features/auth/shared/email_validation.dart';

/// `VerificationStatus` of `use-verification.ts`.
enum VerifyStatus { idle, verifying, verified, error }

/// State of `/verify` (`auth-verify.md`).
class VerifyState extends Equatable {
  const VerifyState({
    this.loading = true,
    this.email,
    this.otp = '',
    this.status = VerifyStatus.idle,
    this.isResending = false,
    this.errorMessage = '',
    this.countdown = 0,
    this.hasEmailService = true,
    this.isProduction = false,
    this.isEmailVerificationEnabled = true,
  });

  final bool loading;

  /// Session email, else the stored `verificationEmail`; null when unknown.
  final String? email;
  final String otp;
  final VerifyStatus status;
  final bool isResending;
  final String errorMessage;

  /// Seconds left before "Resend" returns.
  final int countdown;
  final bool hasEmailService;
  final bool isProduction;
  final bool isEmailVerificationEnabled;

  bool get isOtpComplete => otp.length == 6;
  bool get isVerified => status == VerifyStatus.verified;
  bool get isLoading => status == VerifyStatus.verifying || isResending;
  bool get isInvalidOtp => status == VerifyStatus.error;

  String get title => isVerified ? 'Email Verified' : 'Verify your email';

  String get description {
    if (isVerified) {
      return 'Your email has been verified. Redirecting to dashboard...';
    }
    if (!isEmailVerificationEnabled) {
      return 'Email verification is disabled. Redirecting to dashboard...';
    }
    if (hasEmailService) {
      return 'A verification code has been sent to ${email ?? 'your email'}';
    }
    if (!isProduction) {
      return 'Development mode: Check your console logs for the verification code';
    }
    return 'Error: Email verification is enabled but no email service is configured';
  }

  VerifyState copyWith({
    bool? loading,
    String? Function()? email,
    String? otp,
    VerifyStatus? status,
    bool? isResending,
    String? errorMessage,
    int? countdown,
    bool? hasEmailService,
    bool? isProduction,
    bool? isEmailVerificationEnabled,
  }) => VerifyState(
    loading: loading ?? this.loading,
    email: email == null ? this.email : email(),
    otp: otp ?? this.otp,
    status: status ?? this.status,
    isResending: isResending ?? this.isResending,
    errorMessage: errorMessage ?? this.errorMessage,
    countdown: countdown ?? this.countdown,
    hasEmailService: hasEmailService ?? this.hasEmailService,
    isProduction: isProduction ?? this.isProduction,
    isEmailVerificationEnabled:
        isEmailVerificationEnabled ?? this.isEmailVerificationEnabled,
  );

  @override
  List<Object?> get props => [
    loading,
    email,
    otp,
    status,
    isResending,
    errorMessage,
    countdown,
    hasEmailService,
    isProduction,
    isEmailVerificationEnabled,
  ];
}

/// Port of `use-verification.ts` + the countdown of `verify-content.tsx`.
class VerifyCubit extends Cubit<VerifyState> {
  VerifyCubit({
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
       _redirectAfter = query['redirectAfter'],
       super(const VerifyState());

  static const Duration autoVerifyDelay = Duration(milliseconds: 300);
  static const Duration redirectDelay = Duration(milliseconds: 1000);
  static const int resendCooldownSeconds = 30;

  final AuthApi _api;
  final AuthNavigator _navigator;
  final AuthSessionStore _store;
  final AuthTimers _timers;
  final String _origin;
  final String? _redirectAfter;
  Timer? _autoVerify;
  Timer? _countdown;

  @override
  Future<void> close() {
    _autoVerify?.cancel();
    _countdown?.cancel();
    return super.close();
  }

  /// `resolveRedirectUrl`: the stored destination (validated, unsafe values
  /// evicted) overridden by a validated `?redirectAfter`.
  String? _resolveRedirectUrl() {
    String? resolved;
    final stored = _store.read(AuthStorageKeys.postAuthRedirectUrl);
    if (stored != null && validateCallbackUrl(stored, origin: _origin)) {
      resolved = stored;
    } else if (stored != null) {
      _store.remove(AuthStorageKeys.postAuthRedirectUrl);
    }
    final param = _redirectAfter;
    if (param != null &&
        param.isNotEmpty &&
        validateCallbackUrl(param, origin: _origin)) {
      resolved = param;
    }
    return resolved;
  }

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
    final sessionEmail = session?.user.email;
    final email = sessionEmail != null && sessionEmail.isNotEmpty
        ? sessionEmail
        : _store.read(AuthStorageKeys.verificationEmail);
    final verificationEnabled = options.emailVerificationEnabled;
    emit(
      state.copyWith(
        loading: false,
        email: () => email,
        hasEmailService: options.emailServiceConfigured,
        isProduction: options.isProduction,
        isEmailVerificationEnabled: verificationEnabled,
      ),
    );
    if (!verificationEnabled) await _skipVerification();
  }

  /// Verification not enforceable: mark verified, consume the stored
  /// destination, refetch the session and leave at once.
  Future<void> _skipVerification() async {
    emit(state.copyWith(status: VerifyStatus.verified));
    final destination = _resolveRedirectUrl();
    _store.remove(AuthStorageKeys.postAuthRedirectUrl);
    try {
      await _api.getSession();
    } on Exception {
      // The destination page refetches the session itself.
    }
    if (isClosed) return;
    _navigator.goToDestination(
      postAuthDestination(destination),
      origin: _origin,
    );
  }

  /// `handleOtpChange` + the 300ms auto-verify effect.
  void otpChanged(String value) {
    var next = state.copyWith(otp: value);
    if (value.length == 6) {
      next = next.copyWith(
        status: state.status == VerifyStatus.error
            ? VerifyStatus.idle
            : state.status,
        errorMessage: '',
      );
    }
    emit(next);
    _autoVerify?.cancel();
    if (value.length == 6 &&
        state.email != null &&
        state.status != VerifyStatus.verifying &&
        state.status != VerifyStatus.verified &&
        !state.isResending) {
      _autoVerify = _timers.schedule(autoVerifyDelay, () {
        if (!isClosed) unawaited(verifyCode());
      });
    }
  }

  /// `verifyCode`: `POST /api/auth/email-otp/verify-email`.
  Future<void> verifyCode() async {
    final email = state.email;
    if (!state.isOtpComplete || email == null) return;
    if (state.status == VerifyStatus.verifying ||
        state.status == VerifyStatus.verified) {
      return;
    }
    _autoVerify?.cancel();
    emit(state.copyWith(status: VerifyStatus.verifying, errorMessage: ''));
    try {
      await _api.verifyEmailOtp(email: normalizeEmail(email), otp: state.otp);
      if (isClosed) return;
      emit(state.copyWith(status: VerifyStatus.verified));
      try {
        await _api.getSession();
      } on Exception {
        // The destination page refetches the session itself.
      }
      if (isClosed) return;
      final destination = postAuthDestination(_resolveRedirectUrl());
      _store
        ..remove(AuthStorageKeys.verificationEmail)
        ..remove(AuthStorageKeys.postAuthRedirectUrl);
      _timers.schedule(redirectDelay, () {
        if (!isClosed) {
          _navigator.goToDestination(destination, origin: _origin);
        }
      });
    } on ApiClientError catch (error) {
      if (isClosed) return;
      final message = error.code == 'SSO_REQUIRED' && error.message.isNotEmpty
          ? error.message
          : 'Invalid verification code. Please check and try again.';
      emit(
        state.copyWith(
          status: VerifyStatus.error,
          errorMessage: message,
          otp: '',
        ),
      );
    } on Exception catch (error) {
      if (isClosed) return;
      final text = '$error';
      var message =
          'Verification failed. Please check your code and try again.';
      if (text.contains('expired')) {
        message =
            'The verification code has expired. Please request a new one.';
      } else if (text.contains('invalid')) {
        message = 'Invalid verification code. Please check and try again.';
      } else if (text.contains('attempts')) {
        message = 'Too many failed attempts. Please request a new code.';
      }
      emit(
        state.copyWith(
          status: VerifyStatus.error,
          errorMessage: message,
          otp: '',
        ),
      );
    }
  }

  /// "Resend": `POST /api/auth/email-otp/send-verification-otp` and the 30s
  /// countdown, which starts regardless of the outcome.
  Future<void> resend() async {
    if (state.isLoading || state.countdown > 0) return;
    _startCountdown();
    final email = state.email;
    if (email == null ||
        !state.hasEmailService ||
        !state.isEmailVerificationEnabled) {
      return;
    }
    emit(state.copyWith(isResending: true, errorMessage: ''));
    try {
      await _api.sendVerificationOtp(email: normalizeEmail(email));
      if (isClosed) return;
      emit(state.copyWith(isResending: false));
    } on Exception {
      if (isClosed) return;
      emit(
        state.copyWith(
          isResending: false,
          errorMessage:
              'Failed to resend verification code. Please try again later.',
        ),
      );
    }
  }

  void _startCountdown() {
    _countdown?.cancel();
    emit(state.copyWith(countdown: resendCooldownSeconds));
    _countdown = _timers.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      final next = state.countdown - 1;
      emit(state.copyWith(countdown: next < 0 ? 0 : next));
      if (next <= 0) timer.cancel();
    });
  }

  /// "Back to signup": forget the hop state, then `/signup`.
  void backToSignup() {
    _store
      ..remove(AuthStorageKeys.verificationEmail)
      ..remove(AuthStorageKeys.postAuthRedirectUrl);
    _navigator.go('/signup');
  }

  void goHome() => _navigator.openTopLevel('/');
}
