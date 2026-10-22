import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:sim_seed/src/ids.dart';

/// Default cookie name: Better Auth's `better-auth` prefix + `session_token`,
/// without the `__Secure-` prefix because the stack is plain HTTP
/// (`packages/better-auth/src/cookies/index.ts`, `createCookieGetter`).
const sessionCookieName = 'better-auth.session_token';

/// `makeSignature` from `better-auth/crypto` (v1.6.27): HMAC-SHA-256 over the
/// token with the auth secret as the raw key, returned as standard base64 with
/// padding (`btoa(String.fromCharCode(...signature))`, always 44 characters).
String signSessionToken(String token, String secret) {
  final mac = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(token));
  return base64.encode(mac.bytes);
}

/// The value the browser sends: `encodeURIComponent(token + '.' + signature)`,
/// exactly as `apps/sim/scripts/test-mobile-e2e.ts:263` builds it.
/// `Uri.encodeComponent` and `encodeURIComponent` keep the same unreserved set
/// (`-_.!~*'()`), so `+`, `/` and `=` from the base64 signature are escaped alike.
String sessionCookieValue(String token, String secret) =>
    Uri.encodeComponent('$token.${signSessionToken(token, secret)}');

/// Scrypt parameters of `@better-auth/utils/password` (re-exported by
/// `better-auth/crypto`): N=16384, r=16, p=1, 64-byte key, NFKC-normalised
/// password, 16-byte hex salt, stored as `<salt hex>:<key hex>`.
const scryptN = 16384;
const scryptR = 16;
const scryptP = 1;
const scryptKeyLength = 64;

/// Hash a password the way Better Auth's credential provider verifies it.
///
/// Dart has no NFKC normaliser in the SDK; the seeded password is ASCII, for
/// which normalisation is the identity. Non-ASCII passwords are refused rather
/// than hashed wrongly.
String hashPassword(String password, {required List<int> salt}) {
  if (password.codeUnits.any((c) => c > 0x7f)) {
    throw ArgumentError(
      'Seed passwords must be ASCII (no NFKC normaliser available)',
    );
  }
  if (salt.length != 16) throw ArgumentError('Better Auth salts are 16 bytes');
  final saltHex = toHex(salt);
  final scrypt = Scrypt()
    ..init(
      ScryptParameters(
        scryptN,
        scryptR,
        scryptP,
        scryptKeyLength,
        Uint8List.fromList(utf8.encode(saltHex)),
      ),
    );
  final key = scrypt.process(Uint8List.fromList(utf8.encode(password)));
  return '$saltHex:${toHex(key)}';
}
