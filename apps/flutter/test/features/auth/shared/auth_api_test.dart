// Failure modes:
// - `NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED`: only an explicit 'false',
//   '0' or false disables email; unset, '', 'true' keep it enabled
// - `emailEnabled` is the AND of the public flag and `emailSignupEnabled`
// - `ssoEnabled` prefers the providers flag and falls back to the public
//   `NEXT_PUBLIC_SSO_ENABLED` ('true' / '1' only), else false
// - absent `emailVerificationEnabled` / `emailServiceConfigured` are false
//   and absent `isProd` is true (spec defaults); present values win
// - a non-map or null `public-env` body is tolerated; the site key is only
//   taken when a non-empty string
// - the visibility matrix (`hasOnlySso`, `showBottomSection`, `showDivider`)
//   follows `login-form.tsx:362-368`
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';

void main() {
  AuthProviders providers({
    bool github = false,
    bool google = false,
    bool microsoft = false,
    bool registrationDisabled = false,
    bool? emailSignupEnabled,
    bool? emailVerificationEnabled,
    bool? emailServiceConfigured,
    bool? ssoEnabled,
    bool? isProd,
  }) => AuthProviders(
    githubAvailable: github,
    googleAvailable: google,
    microsoftAvailable: microsoft,
    registrationDisabled: registrationDisabled,
    emailSignupEnabled: emailSignupEnabled,
    emailVerificationEnabled: emailVerificationEnabled,
    emailServiceConfigured: emailServiceConfigured,
    ssoEnabled: ssoEnabled,
    isProd: isProd,
  );

  AuthPageOptions parse({Object? env, AuthProviders? p}) =>
      AuthPageOptions.fromResponses(
        publicEnv: env,
        providers: p ?? providers(),
      );

  test('public email flag: only explicit falsy values disable', () {
    for (final value in <Object?>[null, '', 'true', 'TRUE', '1', 'yes']) {
      expect(
        parse(
          env: {'NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED': value},
        ).emailEnabled,
        isTrue,
        reason: '$value',
      );
    }
    for (final value in <Object?>['false', 'FALSE', '0', false]) {
      expect(
        parse(
          env: {'NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED': value},
        ).emailEnabled,
        isFalse,
        reason: '$value',
      );
    }
  });

  test('emailEnabled is the AND of both flags', () {
    expect(
      parse(p: providers(emailSignupEnabled: false)).emailEnabled,
      isFalse,
    );
    expect(
      parse(
        env: {'NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED': 'false'},
        p: providers(emailSignupEnabled: true),
      ).emailEnabled,
      isFalse,
    );
    expect(parse(p: providers(emailSignupEnabled: true)).emailEnabled, isTrue);
  });

  test('ssoEnabled: providers first, public flag second, else false', () {
    expect(parse().ssoEnabled, isFalse);
    expect(parse(env: {'NEXT_PUBLIC_SSO_ENABLED': 'true'}).ssoEnabled, isTrue);
    expect(parse(env: {'NEXT_PUBLIC_SSO_ENABLED': '1'}).ssoEnabled, isTrue);
    expect(parse(env: {'NEXT_PUBLIC_SSO_ENABLED': 'yes'}).ssoEnabled, isFalse);
    expect(
      parse(
        env: {'NEXT_PUBLIC_SSO_ENABLED': 'true'},
        p: providers(ssoEnabled: false),
      ).ssoEnabled,
      isFalse,
    );
    expect(parse(p: providers(ssoEnabled: true)).ssoEnabled, isTrue);
  });

  test('absent server flags take the spec defaults; present values win', () {
    final absent = parse();
    expect(absent.emailVerificationEnabled, isFalse);
    expect(absent.emailServiceConfigured, isFalse);
    expect(absent.isProduction, isTrue);
    final present = parse(
      p: providers(
        emailVerificationEnabled: true,
        emailServiceConfigured: true,
        isProd: false,
      ),
    );
    expect(present.emailVerificationEnabled, isTrue);
    expect(present.emailServiceConfigured, isTrue);
    expect(present.isProduction, isFalse);
  });

  test('public-env tolerance and the site key', () {
    expect(parse(env: 'not json').emailEnabled, isTrue);
    expect(parse(env: ['x']).turnstileSiteKey, isNull);
    expect(
      parse(env: {'NEXT_PUBLIC_TURNSTILE_SITE_KEY': ''}).turnstileSiteKey,
      isNull,
    );
    expect(
      parse(env: {'NEXT_PUBLIC_TURNSTILE_SITE_KEY': 'k'}).turnstileSiteKey,
      'k',
    );
  });

  test('visibility matrix', () {
    final all = parse(p: providers(google: true, ssoEnabled: true));
    expect(all.hasOnlySso, isFalse);
    expect(all.showBottomSection, isTrue);
    expect(all.showDivider, isTrue);
    final ssoOnly = parse(
      p: providers(emailSignupEnabled: false, ssoEnabled: true),
    );
    expect(ssoOnly.hasOnlySso, isTrue);
    expect(ssoOnly.showBottomSection, isFalse);
    expect(ssoOnly.showDivider, isFalse);
    final socialNoEmail = parse(
      p: providers(emailSignupEnabled: false, github: true),
    );
    expect(socialNoEmail.showBottomSection, isTrue);
    expect(socialNoEmail.showDivider, isFalse);
    expect(parse().showBottomSection, isFalse);
  });
}
