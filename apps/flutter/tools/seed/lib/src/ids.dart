import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Namespace every fixture id is derived from. Changing it changes every id.
const seedNamespace = 'sim-flutter-e2e';

/// Deterministic UUID (version-5 layout, SHA-1 of `namespace:name`) for a fixture.
///
/// The seed never draws random ids: every row keeps the same id across runs and
/// machines so suites can hard-code deep links and `seed.json` is diffable.
/// Tables with a `uuid` column (`copilot_chats`, `copilot_messages`) need the
/// canonical 8-4-4-4-12 form, which this produces for every id.
String fixedId(String name) {
  final digest = sha1.convert(utf8.encode('$seedNamespace:$name')).bytes;
  final bytes = List<int>.from(digest.sublist(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Deterministic bytes for salts and IVs, so hashes and ciphertexts are stable too.
List<int> fixedBytes(String name, int length) {
  final out = <int>[];
  var counter = 0;
  while (out.length < length) {
    out.addAll(
      sha256.convert(utf8.encode('$seedNamespace:$name:$counter')).bytes,
    );
    counter++;
  }
  return out.sublist(0, length);
}

String toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> fromHex(String hex) {
  if (hex.length.isOdd) throw const FormatException('Odd-length hex string');
  return [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
}
