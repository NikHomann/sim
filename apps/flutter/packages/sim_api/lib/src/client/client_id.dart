import 'dart:math';

/// Header naming the app instance (the browser tab in React) that sent a
/// request. Port of `apps/sim/lib/api/client-id.ts`: an opaque correlation
/// token, never an authorization input.
const clientIdHeader = 'x-sim-client-id';

const _alphabet =
    'ModuleSymbhasOwnPr-0123456789ABCDEFGHNRVfgctiUvz_KqYTJkLxpZXIjQW';

/// A URL-safe id of [size] characters from the nanoid alphabet, matching
/// `generateShortId()` in `@sim/utils/id` (21 characters by default).
String generateShortId([int size = 21]) {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < size; i++) {
    buffer.write(_alphabet[random.nextInt(_alphabet.length)]);
  }
  return buffer.toString();
}
