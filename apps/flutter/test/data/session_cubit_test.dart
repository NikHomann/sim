// Failure modes of SessionCubit (spec §4.1, §7, §9, §10 #9-11, #84):
// 1. stale time: a second load within 5 min makes no request; after 5 min
//    (fake clock) it does;
// 2. the focus hook refetches only when stale (and never throws on a
//    failure);
// 3. a live session that settles to `null` is "expired"; an error never is;
//    `sawSession` stays false when the first read is already `null`;
// 4. `refresh` cancels, reads past the cookie cache and overwrites the
//    cache entry;
// 5. an impersonated session polls with `disableCookieCache=true` every
//    interval and the poll stops once the session is no longer impersonated;
// 6. the superuser flag reads `user.role === 'admin'`;
// 7. reset drops the arm so a later `null` is not an expiry.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';

import 'support/mocks.dart';

void main() {
  late MockAuthRepository auth;
  late DateTime now;
  late QueryClient queryClient;
  late SessionCubit cubit;
  late int calls;

  setUp(() {
    auth = MockAuthRepository();
    now = DateTime.utc(2026);
    queryClient = QueryClient(now: () => now);
    calls = 0;
    when(
      () => auth.getSession(
        disableCookieCache: any(named: 'disableCookieCache'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      calls += 1;
      return session();
    });
    cubit = SessionCubit(
      auth: auth,
      queryClient: queryClient,
      impersonationInterval: const Duration(milliseconds: 20),
    );
  });

  tearDown(() => cubit.close());

  test('stale time 5 min with a fake clock', () async {
    await cubit.load();
    await cubit.load();
    expect(calls, 1);
    now = now.add(const Duration(minutes: 4, seconds: 59));
    await cubit.load();
    expect(calls, 1);
    now = now.add(const Duration(seconds: 2));
    await cubit.load();
    expect(calls, 2);
  });

  test('focus refetches only when stale and swallows failures', () async {
    await cubit.load();
    await cubit.onFocus();
    expect(calls, 1);
    now = now.add(const Duration(minutes: 6));
    when(
      () => auth.getSession(
        disableCookieCache: any(named: 'disableCookieCache'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      calls += 1;
      throw apiError(500);
    });
    await cubit.onFocus();
    expect(calls, 2);
    expect(cubit.state.hasError, isTrue);
    expect(
      cubit.state.isExpired,
      isFalse,
      reason: 'an error is never an expiry',
    );
    expect(cubit.state.isSignedIn, isTrue, reason: 'previous data is kept');
  });

  test('live → null is expired; a first null is not', () async {
    await cubit.load();
    expect(cubit.state.sawSession, isTrue);
    when(
      () => auth.getSession(
        disableCookieCache: any(named: 'disableCookieCache'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => null);
    await cubit.refresh();
    expect(cubit.state.isExpired, isTrue);
    expect(cubit.state.isSignedIn, isFalse);

    final fresh = SessionCubit(auth: auth, queryClient: QueryClient());
    await fresh.load();
    expect(fresh.state.sawSession, isFalse);
    expect(fresh.state.isExpired, isFalse);
    await fresh.close();
  });

  test('refresh bypasses the cookie cache and overwrites the entry', () async {
    await cubit.load();
    when(
      () => auth.getSession(
        disableCookieCache: true,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => session(role: 'admin'));
    final refreshed = await cubit.refresh();
    expect(refreshed?.user.role, 'admin');
    expect(cubit.state.isSuperuser, isTrue);
    expect(
      queryClient
          .getQueryData<SessionSnapshot>(SessionKeys.detail())
          ?.session
          ?.user
          .role,
      'admin',
    );
    verify(
      () => auth.getSession(
        disableCookieCache: true,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test(
    'impersonation polls past the cookie cache and stops afterwards',
    () async {
      var impersonated = true;
      when(
        () => auth.getSession(
          disableCookieCache: any(named: 'disableCookieCache'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        calls += 1;
        return session(impersonatedBy: impersonated ? 'admin-1' : null);
      });
      await cubit.load();
      expect(cubit.state.isImpersonated, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(calls, greaterThanOrEqualTo(3));
      verify(
        () => auth.getSession(
          disableCookieCache: true,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(greaterThanOrEqualTo(2));
      impersonated = false;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final settled = calls;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(calls, settled, reason: 'polling stopped');
    },
  );

  test('reset drops the arm', () async {
    await cubit.load();
    cubit.reset();
    expect(cubit.state, const SessionState());
    when(
      () => auth.getSession(
        disableCookieCache: any(named: 'disableCookieCache'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => null);
    await cubit.load();
    expect(cubit.state.isExpired, isFalse);
  });
}
