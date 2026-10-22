// Failure modes:
// - the loading card shows while the session is pending
// - the signed-out card offers sign-in only under registrationDisabled, the
//   new-user ordering with `?new=true`, else sign-in first
// - the invitation card renders the disclosure (role, moving workspaces,
//   access rows) and Accept is the primary action
// - a missing disclosure disables Accept and shows "Refresh invitation"
// - the error card adds "Try Again" only for retryable codes and "Request
//   New Invitation" only when expired
// - the support footer is present under every card
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/invite/invite_page.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';

import '../support/fakes.dart';
import '../support/invite_fixtures.dart';
import '../support/pump.dart';

void main() {
  late FakeAuthDeps deps;

  setUp(() {
    deps = FakeAuthDeps()
      ..api.session = testSession()
      ..api.inviteResponse = InviteResponse(
        invitation: invitation(kind: 'organization', org: 'Acme'),
        joinPreview: preview,
      );
  });

  Future<void> pumpInvite(
    WidgetTester tester, {
    Map<String, String> query = const {'token': 'tok'},
  }) async {
    await pumpAuthPage(
      tester,
      InvitePage(inviteId: 'inv-1', query: query),
      deps: deps,
    );
  }

  testWidgets('loading card, then the invitation card', (tester) async {
    deps.api.gate = Completer<void>();
    await pumpInvite(tester);
    await tester.pump();
    expect(find.text('Loading'), findsOneWidget);
    expect(byParityId('invite.card.loader'), findsOneWidget);
    deps.api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Organization Invitation'), findsOneWidget);
    expect(find.text("You've been invited to join Acme."), findsOneWidget);
    expect(byParityId('invite.details'), findsOneWidget);
    expect(find.text('• Personal'), findsOneWidget);
    expect(find.text('write access'), findsOneWidget);
    expect(byParityId('invite.card.action.0'), findsOneWidget);
    expect(byParityId('auth.shell.supportFooter'), findsOneWidget);
    await tester.tap(byParityId('invite.card.action.0'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome!'), findsOneWidget);
  });

  testWidgets('signed-out variants', (tester) async {
    const withCallback = {'token': 'tok', 'callbackUrl': '/invite/inv-1'};
    deps = FakeAuthDeps();
    await pumpInvite(tester, query: withCallback);
    await tester.pumpAndSettle();
    expect(find.text("You've been invited!"), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Return to Home'), findsOneWidget);

    deps = FakeAuthDeps();
    await pumpInvite(tester, query: const {...withCallback, 'new': 'true'});
    await tester.pumpAndSettle();
    expect(find.text('I already have an account'), findsOneWidget);

    deps = FakeAuthDeps()
      ..api.options = const AuthPageOptions(registrationDisabled: true);
    await pumpInvite(tester, query: withCallback);
    await tester.pumpAndSettle();
    expect(find.text('Create an account'), findsNothing);
    expect(
      find.text('Account creation is disabled on this instance'),
      findsOneWidget,
    );
  });

  testWidgets('missing disclosure disables Accept and offers Refresh', (
    tester,
  ) async {
    deps.api.inviteResponse = InviteResponse(
      invitation: invitation(),
      joinPreview: null,
    );
    await pumpInvite(tester);
    await tester.pumpAndSettle();
    expect(find.text('Refresh invitation'), findsOneWidget);
    await tester.tap(byParityId('invite.card.action.0'));
    await tester.pumpAndSettle();
    expect(deps.api.callsNamed('acceptInvitation'), isEmpty);
  });

  testWidgets('error cards', (tester) async {
    deps.api.inviteError = apiError(400, body: {'error': 'expired'});
    await pumpInvite(tester);
    await tester.pumpAndSettle();
    expect(find.text('Invitation Error'), findsOneWidget);
    expect(find.text('Request New Invitation'), findsOneWidget);
    expect(find.text('Try Again'), findsNothing);

    deps = FakeAuthDeps()
      ..api.session = testSession()
      ..api.inviteError = apiError(503);
    await pumpInvite(tester);
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Request New Invitation'), findsNothing);

    deps = FakeAuthDeps()
      ..api.session = testSession(email: 'other@example.com')
      ..api.inviteResponse = InviteResponse(
        invitation: invitation(),
        joinPreview: preview,
      );
    await pumpInvite(tester);
    await tester.pumpAndSettle();
    expect(find.text('Wrong Account'), findsOneWidget);
    expect(find.text('Sign in with a different account'), findsOneWidget);
  });
}
