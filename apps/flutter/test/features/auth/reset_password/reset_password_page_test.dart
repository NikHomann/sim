// Failure modes:
// - no token: the error status shows and typing cannot reach the API
// - Enter submits; every failing rule renders as one form-level list and
//   both fields are marked
// - the success copy renders and the login redirect follows after 1.5s
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/reset_password/reset_password_cubit.dart';
import 'package:sim_app/features/auth/reset_password/reset_password_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

void main() {
  late FakeAuthDeps deps;

  setUp(() => deps = FakeAuthDeps());

  testWidgets('missing token', (tester) async {
    await pumpAuthPage(tester, const ResetPasswordPage(query: {}), deps: deps);
    await tester.pumpAndSettle();
    expect(find.text(ResetPasswordState.missingTokenMessage), findsOneWidget);
    await tester.tap(byParityId('auth.reset.submit'));
    await tester.pumpAndSettle();
    expect(deps.api.calls, isEmpty);
  });

  testWidgets('validation list and success flow', (tester) async {
    await pumpAuthPage(
      tester,
      const ResetPasswordPage(query: {'token': 'tok'}),
      deps: deps,
    );
    await tester.pumpAndSettle();
    await tester.enterText(byParityId('auth.reset.password'), 'secret');
    await tester.enterText(byParityId('auth.reset.confirm'), 'other');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(byParityId('auth.reset.validation'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(
      find.text('Password must contain at least one number'),
      findsOneWidget,
    );
    expect(deps.api.calls, isEmpty);

    await tester.enterText(byParityId('auth.reset.password'), 'Secret1!');
    await tester.enterText(byParityId('auth.reset.confirm'), 'Secret1!');
    await tester.pump();
    await tester.tap(byParityId('auth.reset.submit'));
    await tester.pumpAndSettle();
    expect(byParityId('auth.reset.validation'), findsNothing);
    expect(
      find.text('Password reset successful! Redirecting to login...'),
      findsOneWidget,
    );
    deps.timers.elapse(const Duration(milliseconds: 1500));
    expect(deps.navigator.gone, ['/login?resetSuccess=true']);
  });
}
