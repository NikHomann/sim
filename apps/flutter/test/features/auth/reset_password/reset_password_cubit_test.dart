// Failure modes:
// - no `?token`: the token error is the status, fields and submit disabled,
//   submit is a no-op
// - submit is refused until both fields are filled
// - every failing rule is listed in rule order including the mismatch; the
//   list persists while typing and only the next submit replaces it
// - success shows the green copy and navigates after 1500ms
// - a 400 shows the server message; a network failure the fallback; the
//   status is cleared when a new submit starts
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/reset_password/reset_password_cubit.dart';

import '../support/fakes.dart';

void main() {
  late FakeAuthApi api;
  late FakeAuthNavigator navigator;
  late FakeAuthTimers timers;

  setUp(() {
    api = FakeAuthApi();
    navigator = FakeAuthNavigator();
    timers = FakeAuthTimers();
  });

  ResetPasswordCubit build([
    Map<String, String> query = const {'token': 'tok'},
  ]) => ResetPasswordCubit(
    api: api,
    navigator: navigator,
    timers: timers,
    query: query,
  );

  test('missing token disables everything', () async {
    final cubit = build(const {});
    expect(cubit.state.status!.text, ResetPasswordState.missingTokenMessage);
    expect(cubit.state.status!.type, ResetStatusType.error);
    expect(cubit.state.fieldsEnabled, isFalse);
    cubit
      ..passwordChanged('Secret1!')
      ..confirmChanged('Secret1!');
    expect(cubit.state.canSubmit, isFalse);
    await cubit.submit();
    expect(api.calls, isEmpty);
  });

  test('rule list in order, persists while typing', () async {
    final cubit = build()
      ..passwordChanged('a' * 101)
      ..confirmChanged('b');
    await cubit.submit();
    expect(cubit.state.validationMessages, [
      'Password must not exceed 100 characters',
      'Password must contain at least one uppercase letter',
      'Password must contain at least one number',
      'Password must contain at least one special character',
      'Passwords do not match',
    ]);
    cubit.passwordChanged('Secret1!');
    expect(cubit.state.hasValidationErrors, isTrue);
    expect(api.calls, isEmpty);
    expect(
      validateResetPassword('short', 'short').first,
      'Password must be at least 8 characters long',
    );
  });

  test('success copy then /login?resetSuccess=true after 1500ms', () async {
    final cubit = build()
      ..passwordChanged('Secret1!')
      ..confirmChanged('Secret1!');
    await cubit.submit();
    expect(api.callsNamed('resetPassword').single.args, {
      'token': 'tok',
      'newPassword': 'Secret1!',
    });
    expect(cubit.state.status!.type, ResetStatusType.success);
    expect(
      cubit.state.status!.text,
      'Password reset successful! Redirecting to login...',
    );
    expect(cubit.state.validationMessages, isEmpty);
    timers.elapse(const Duration(milliseconds: 1499));
    expect(navigator.gone, isEmpty);
    timers.elapse(const Duration(milliseconds: 1));
    expect(navigator.gone, ['/login?resetSuccess=true']);
  });

  test(
    'server message and network fallback; status cleared on resubmit',
    () async {
      api.resetPasswordError = apiError(
        400,
        message:
            'This reset link is invalid or has expired. Please request a new one.',
      );
      final cubit = build()
        ..passwordChanged('Secret1!')
        ..confirmChanged('Secret1!');
      await cubit.submit();
      expect(cubit.state.status!.type, ResetStatusType.error);
      expect(
        cubit.state.status!.text,
        'This reset link is invalid or has expired. Please request a new one.',
      );
      api.resetPasswordError = const ApiNetworkError('offline');
      await cubit.submit();
      expect(cubit.state.status!.text, 'Failed to reset password');
      expect(cubit.state.submitting, isFalse);
    },
  );

  test('submitting disables the fields', () async {
    final cubit = build()
      ..passwordChanged('Secret1!')
      ..confirmChanged('Secret1!');
    final future = cubit.submit();
    expect(cubit.state.fieldsEnabled, isFalse);
    await future;
    expect(cubit.state.fieldsEnabled, isTrue);
  });
}
