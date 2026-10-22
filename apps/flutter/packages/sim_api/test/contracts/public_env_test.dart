// Failure modes of the public-env contract (spec §3.3, §10 #6-7):
// 1. a key without the `NEXT_PUBLIC_` prefix fails client validation;
// 2. a non-string value fails;
// 3. `isTruthy` accepts `true`/`1` case-insensitively, `isFalsy` accepts
//    `false`/`0`, anything else is neither;
// 4. the email form shows unless the signup flag is explicitly falsy;
// 5. the fallback deployment shape reads `NEXT_PUBLIC_CHAT_DISABLED`
//    inverted, `NEXT_PUBLIC_*_ENABLED` for the features, and `hosted` from
//    the app URL host (`sim.ai`, `*.sim.ai`) or `NEXT_PUBLIC_FORCE_HOSTED`;
// 6. an empty record resolves to the nothing-configured shape.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

void main() {
  test('a key without the prefix fails validation', () {
    expect(
      () =>
          PublicEnv.fromJson(const {'NEXT_PUBLIC_APP_URL': 'x', 'SECRET': 'y'}),
      throwsA(
        isA<ContractDecodeError>().having((e) => e.path, 'path', 'SECRET'),
      ),
    );
  });

  test('a non-string value fails validation', () {
    expect(
      () => PublicEnv.fromJson(const {'NEXT_PUBLIC_BILLING_ENABLED': true}),
      throwsA(isA<ContractDecodeError>()),
    );
  });

  test('isTruthy / isFalsy', () {
    expect(isTruthy('true'), isTrue);
    expect(isTruthy('TRUE'), isTrue);
    expect(isTruthy('1'), isTrue);
    expect(isTruthy('yes'), isFalse);
    expect(isTruthy(null), isFalse);
    expect(isFalsy('false'), isTrue);
    expect(isFalsy('0'), isTrue);
    expect(isFalsy(''), isFalse);
    expect(isFalsy(null), isFalse);
  });

  test('email/password signup is on unless explicitly falsy', () {
    expect(PublicEnv.empty.emailPasswordSignupEnabled, isTrue);
    expect(
      const PublicEnv({
        'NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED': 'false',
      }).emailPasswordSignupEnabled,
      isFalse,
    );
    expect(
      const PublicEnv({
        'NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED': 'maybe',
      }).emailPasswordSignupEnabled,
      isTrue,
    );
  });

  test('fallback deployment shape from the NEXT_PUBLIC_* values', () {
    const env = PublicEnv({
      'NEXT_PUBLIC_APP_URL': 'https://app.sim.ai',
      'NEXT_PUBLIC_BILLING_ENABLED': '1',
      'NEXT_PUBLIC_CHAT_DISABLED': 'true',
      'NEXT_PUBLIC_SSO_ENABLED': 'true',
      'NEXT_PUBLIC_INBOX_ENABLED': 'TRUE',
    });
    final shape = env.fallbackDeploymentShape;
    expect(shape.hosted, isTrue);
    expect(shape.billingEnabled, isTrue);
    expect(shape.chatEnabled, isFalse);
    expect(shape.features.sso, isTrue);
    expect(shape.features.inbox, isTrue);
    expect(shape.features.scim, isFalse);
  });

  test('hosted: sim.ai host or force flag, not another domain', () {
    expect(
      const PublicEnv({'NEXT_PUBLIC_APP_URL': 'https://sim.ai'}).hosted,
      isTrue,
    );
    expect(
      const PublicEnv({'NEXT_PUBLIC_APP_URL': 'http://localhost:3000'}).hosted,
      isFalse,
    );
    expect(
      const PublicEnv({'NEXT_PUBLIC_APP_URL': 'https://notsim.ai'}).hosted,
      isFalse,
    );
    expect(
      const PublicEnv({'NEXT_PUBLIC_FORCE_HOSTED': 'true'}).hosted,
      isTrue,
    );
  });

  test('an empty record is the nothing-configured shape', () {
    expect(PublicEnv.empty.fallbackDeploymentShape, const DeploymentShape());
  });
}
