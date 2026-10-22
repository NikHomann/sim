// Failure modes:
// - `?token` is persisted under `inviteToken:<id>`; without it the stored
//   token is used; an empty `?token=` counts as absent
// - signed out without `?callbackUrl` bounces to
//   `/login?invite_flow=true&callbackUrl=...` (the proxy's guard); with it
//   the signed-out card shows (no invitation request); links carry
//   `invite_flow` and the callback with the token
// - fetch errors map code → body.error → status; a network failure is
//   `network-error`
// - a session email differing from the invitee is `email-mismatch`
// - `?error=` shows only until the invitation loads
// - accept guarded when the disclosure is missing; success → accepted card,
//   navigation after 1200ms, session refetch past the cookie cache
// - accept failures outrank fetch state; a server-error message from the
//   body replaces the default copy; `disclosure-outdated` is retryable
// - "sign in with a different account" signs out even when it fails and
//   navigates to the login link
// - display name: quoted names capped at 3, org name, fallbacks
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/invite/invite_cubit.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';

import '../support/fakes.dart';
import '../support/invite_fixtures.dart';

void main() {
  late FakeAuthApi api;
  late FakeAuthNavigator navigator;
  late MemoryAuthSessionStore store;
  late FakeAuthTimers timers;

  setUp(() {
    api = FakeAuthApi()
      ..session = testSession()
      ..inviteResponse = InviteResponse(
        invitation: invitation(),
        joinPreview: preview,
      );
    navigator = FakeAuthNavigator();
    store = MemoryAuthSessionStore();
    timers = FakeAuthTimers();
  });

  Future<InviteCubit> ready([
    Map<String, String> query = const {'token': 'tok'},
  ]) async {
    final cubit = InviteCubit(
      api: api,
      navigator: navigator,
      sessionStore: store,
      timers: timers,
      origin: testOrigin,
      inviteId: 'inv-1',
      query: query,
    );
    await cubit.load();
    return cubit;
  }

  test('token persisted, read back, empty query token ignored', () async {
    var cubit = await ready();
    expect(store.read(AuthStorageKeys.inviteToken('inv-1')), 'tok');
    expect(api.callsNamed('getInvitation').single.args, {
      'id': 'inv-1',
      'token': 'tok',
    });
    cubit = await ready(const {'token': ''});
    expect(cubit.state.token, 'tok');
    expect(cubit.callbackUrl, '/invite/inv-1?token=tok');
    expect(cubit.state.phase, InvitePhase.invitation);
  });

  test('signed out without callbackUrl bounces to login', () async {
    api.session = null;
    final cubit = await ready();
    expect(cubit.state.phase, InvitePhase.loading);
    expect(navigator.gone, [
      '/login?invite_flow=true&callbackUrl=%2Finvite%2Finv-1%3Ftoken%3Dtok',
    ]);
    expect(api.callsNamed('getInvitation'), isEmpty);
  });

  test('signed out: card variants and links', () async {
    api.session = null;
    const withCallback = {'token': 'tok', 'callbackUrl': '/invite/inv-1'};
    var cubit = await ready(withCallback);
    expect(cubit.state.phase, InvitePhase.signedOut);
    expect(navigator.gone, isEmpty);
    expect(api.callsNamed('getInvitation'), isEmpty);
    expect(
      cubit.loginHref(),
      '/login?invite_flow=true&callbackUrl=%2Finvite%2Finv-1%3Ftoken%3Dtok',
    );
    expect(cubit.signupHref(isNewUser: true), endsWith('&new=true'));
    cubit = await ready(const {...withCallback, 'new': 'true'});
    expect(cubit.state.isNewUser, isTrue);
    api.options = const AuthPageOptions(registrationDisabled: true);
    cubit = await ready(withCallback);
    expect(cubit.state.registrationDisabled, isTrue);
  });

  test('fetch error mapping', () async {
    api.inviteError = apiError(404, message: 'Invitation not found');
    var cubit = await ready();
    expect(cubit.state.phase, InvitePhase.error);
    expect(cubit.state.error!.code, 'invalid-invitation');
    api.inviteError = apiError(400, body: {'error': 'expired'});
    cubit = await ready();
    expect(cubit.state.error!.code, 'expired');
    api.inviteError = apiError(403, body: {'error': 'Forbidden'});
    cubit = await ready();
    expect(cubit.state.error!.code, 'forbidden');
    expect(cubit.state.error!.requiresAuth, isTrue);
    api.inviteError = const ApiNetworkError('offline');
    cubit = await ready();
    expect(cubit.state.error!.code, 'network-error');
    expect(cubit.state.error!.canRetry, isTrue);
    api.inviteError = apiError(503);
    cubit = await ready();
    expect(cubit.state.error!.code, 'server-error');
  });

  test('wrong account and url error precedence', () async {
    api.session = testSession(email: 'Other@Example.com');
    var cubit = await ready();
    expect(cubit.state.error!.code, 'email-mismatch');
    api.session = testSession(email: ' ADA@example.com ');
    cubit = await ready(const {'token': 'tok', 'error': 'expired'});
    expect(cubit.state.phase, InvitePhase.invitation);
    api.inviteResponse = const InviteResponse(
      invitation: null,
      joinPreview: null,
    );
    cubit = await ready(const {'token': 'tok', 'error': 'expired'});
    expect(cubit.state.error!.code, 'expired');
  });

  test('accept: disclosure guard, success, redirect after 1200ms', () async {
    api.inviteResponse = InviteResponse(
      invitation: invitation(),
      joinPreview: null,
    );
    var cubit = await ready();
    expect(cubit.state.isDisclosureMissing, isTrue);
    await cubit.accept();
    expect(api.callsNamed('acceptInvitation'), isEmpty);
    api.inviteResponse = InviteResponse(
      invitation: invitation(),
      joinPreview: preview,
    );
    await cubit.refresh();
    expect(cubit.state.isDisclosureMissing, isFalse);
    cubit = await ready();
    await cubit.accept();
    expect(api.callsNamed('acceptInvitation').single.args, {
      'id': 'inv-1',
      'token': 'tok',
      'disclosedWorkspaceIds': ['ws-p'],
      'disclosedOutcome': 'will-join',
    });
    expect(cubit.state.phase, InvitePhase.accepted);
    expect(
      api.callsNamed('getSession').last.args['disableCookieCache'],
      isTrue,
    );
    timers.elapse(const Duration(milliseconds: 1199));
    expect(navigator.gone, isEmpty);
    timers.elapse(const Duration(milliseconds: 1));
    expect(navigator.gone, ['/workspace/ws-1/home']);
  });

  test(
    'accept failures: retryable codes and server message override',
    () async {
      api.acceptError = apiError(409, body: {'error': 'disclosure-outdated'});
      var cubit = await ready();
      await cubit.accept();
      expect(cubit.state.phase, InvitePhase.error);
      expect(cubit.state.error!.code, 'disclosure-outdated');
      expect(cubit.state.error!.canRetry, isTrue);
      expect(cubit.state.accepting, isFalse);
      api.acceptError = apiError(
        500,
        body: {'error': 'server-error', 'message': 'DB down'},
      );
      cubit = await ready();
      await cubit.accept();
      expect(cubit.state.error!.message, 'DB down');
      api.acceptError = apiError(
        402,
        body: {'error': 'upgrade-required', 'message': 'x'},
      );
      cubit = await ready();
      await cubit.accept();
      expect(
        cubit.state.error!.message,
        getInviteError('upgrade-required').message,
      );
    },
  );

  test('sign in with a different account', () async {
    api
      ..session = testSession(email: 'other@example.com')
      ..signOutError = apiError(500);
    final cubit = await ready();
    await cubit.signInWithDifferentAccount();
    expect(api.callsNamed('signOut'), hasLength(1));
    expect(navigator.gone, [cubit.loginHref()]);
    cubit.tryAgain();
    expect(navigator.reloads, 1);
    cubit.returnHome();
    expect(navigator.topLevel, ['/']);
  });

  test('display name', () async {
    expect(formatQuotedNameList(['A', 'B'], 3), '"A", "B"');
    expect(
      formatQuotedNameList(['A', 'B', 'C', 'D'], 3),
      '"A", "B", "C" and 1 more',
    );
    api.inviteResponse = InviteResponse(
      invitation: invitation(names: ['A', null, 'C', 'D', 'E']),
      joinPreview: preview,
    );
    var cubit = await ready();
    expect(cubit.state.displayName, '"A", "C", "D" and 1 more');
    api.inviteResponse = InviteResponse(
      invitation: invitation(names: [null]),
      joinPreview: preview,
    );
    cubit = await ready();
    expect(cubit.state.displayName, 'a workspace');
    api.inviteResponse = InviteResponse(
      invitation: invitation(kind: 'organization', org: 'Acme'),
      joinPreview: preview,
    );
    cubit = await ready();
    expect(cubit.state.displayName, 'Acme');
    api.inviteResponse = InviteResponse(
      invitation: invitation(kind: 'organization'),
      joinPreview: preview,
    );
    cubit = await ready();
    expect(cubit.state.displayName, 'an organization');
  });
}
