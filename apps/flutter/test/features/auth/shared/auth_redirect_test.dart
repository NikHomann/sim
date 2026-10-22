// Failure modes:
// - a callback on another origin, a protocol-relative URL or a javascript:
//   URL must be rejected; relative paths and same-origin absolute URLs pass
// - an empty or unparsable callback is rejected rather than crashing
// - the OAuth authorize callback is recognised only on the same origin and
//   exact path
// - `redirect` must win over `callbackUrl`; `/invite/` implies the invite flow
// - cross links must encode the callback like URLSearchParams (a destination
//   carrying its own query survives) and omit empty params
// - API, CLI, desktop, the login bridge and the SSO launch route are
//   top-level destinations; the auth pages, `/home`, `/workspace/**`, `/o/**`
//   and `/invite/**` are in-app; a same-origin absolute URL is reduced to
//   its path and routed by that path; another origin stays top-level
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';

void main() {
  const origin = 'http://localhost:3001';

  group('validateCallbackUrl', () {
    test('accepts relative paths and same-origin absolute URLs', () {
      expect(validateCallbackUrl('/home', origin: origin), isTrue);
      expect(
        validateCallbackUrl('/invite/abc?token=t', origin: origin),
        isTrue,
      );
      expect(
        validateCallbackUrl('http://localhost:3001/workspace', origin: origin),
        isTrue,
      );
    });

    test('rejects other origins, protocol-relative and scheme URLs', () {
      expect(
        validateCallbackUrl('https://evil.com/x', origin: origin),
        isFalse,
      );
      expect(validateCallbackUrl('//evil.com/x', origin: origin), isFalse);
      expect(
        validateCallbackUrl('javascript:alert(1)', origin: origin),
        isFalse,
      );
      expect(
        validateCallbackUrl('http://localhost:3000/', origin: origin),
        isFalse,
      );
    });

    test('rejects empty, null and unparsable values', () {
      expect(validateCallbackUrl('', origin: origin), isFalse);
      expect(validateCallbackUrl(null, origin: origin), isFalse);
      expect(validateCallbackUrl('http://[', origin: origin), isFalse);
    });
  });

  group('isOAuthAuthorizationCallback', () {
    test('matches the same-origin authorize path only', () {
      expect(
        isOAuthAuthorizationCallback(
          '/api/auth/oauth2/authorize?client_id=x',
          origin: origin,
        ),
        isTrue,
      );
      expect(
        isOAuthAuthorizationCallback(
          'https://evil.com/api/auth/oauth2/authorize',
          origin: origin,
        ),
        isFalse,
      );
      expect(isOAuthAuthorizationCallback('/home', origin: origin), isFalse);
      expect(isOAuthAuthorizationCallback(null, origin: origin), isFalse);
    });
  });

  group('resolveAuthRedirect', () {
    test('redirect wins over callbackUrl', () {
      final r = resolveAuthRedirect(redirect: '/a', callbackUrl: '/b');
      expect(r.rawCallbackUrl, '/a');
      expect(r.isInviteFlow, isFalse);
    });

    test('invite flow from the flag or the destination', () {
      expect(
        resolveAuthRedirect(callbackUrl: '/invite/x').isInviteFlow,
        isTrue,
      );
      expect(
        resolveAuthRedirect(
          callbackUrl: '/home',
          inviteFlow: 'true',
        ).isInviteFlow,
        isTrue,
      );
      expect(resolveAuthRedirect().rawCallbackUrl, '');
    });
  });

  group('buildAuthCrossLink', () {
    test('omits the query when nothing is carried', () {
      expect(buildAuthCrossLink('/signup'), '/signup');
      expect(buildAuthCrossLink('/login', callbackUrl: ''), '/login');
    });

    test('encodes like URLSearchParams and keeps nested queries intact', () {
      expect(
        buildAuthCrossLink(
          '/signup',
          callbackUrl: '/cli/auth?callback=http://127.0.0.1:1&state=a b',
          isInviteFlow: true,
          isNewUser: true,
        ),
        '/signup?invite_flow=true&callbackUrl=%2Fcli%2Fauth%3Fcallback%3Dhttp%3A%2F%2F127.0.0.1%3A1%26state%3Da+b&new=true',
      );
    });
  });

  group('resolveDestination', () {
    ({bool inApp, String location}) resolve(String location) =>
        resolveDestination(location, origin: origin);

    test('Next-owned paths go top-level', () {
      for (final path in <String>[
        '/api/auth/oauth2/authorize?x=1',
        '/cli/auth?x',
        '/sso/launch/okta?iss=x',
        '/oauth/sign-in?client_id=x',
        '/credential-groups/abc',
        '/desktop/auth?port=1',
        '/terms',
      ]) {
        expect(resolve(path), (inApp: false, location: path), reason: path);
      }
    });

    test('bundle-owned paths go in-app', () {
      for (final path in <String>[
        '/home',
        '/invite/abc?token=t',
        '/workspace/1/w/2',
        '/o/org-1/home',
        '/sso?callbackUrl=%2Fhome',
        '/oauth/consent?client_id=x',
        '/login?resetSuccess=true',
        '/',
      ]) {
        expect(resolve(path), (inApp: true, location: path), reason: path);
      }
      expect(isFlutterRoute('/homely'), isFalse);
      expect(isFlutterRoute('/sso/launch/x'), isFalse);
    });

    test('same-origin absolute URLs are reduced to their path', () {
      expect(
        resolve('http://localhost:3001/workspace/x?tab=1#frag'),
        (inApp: true, location: '/workspace/x?tab=1#frag'),
      );
      expect(
        resolve('http://localhost:3001/api/auth/oauth2/authorize?c=1'),
        (inApp: false, location: '/api/auth/oauth2/authorize?c=1'),
      );
      expect(
        resolve('https://evil.com/home'),
        (inApp: false, location: 'https://evil.com/home'),
      );
    });
  });

  test('postAuthDestination falls back to /home', () {
    expect(postAuthDestination(null), '/home');
    expect(postAuthDestination(''), '/home');
    expect(postAuthDestination('/invite/x'), '/invite/x');
  });
}
