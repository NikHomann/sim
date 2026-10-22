import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:sim_seed/src/ids.dart';

/// AES-256-GCM in the `iv:ciphertext:authTag` hex layout of
/// `packages/security/src/encryption.ts`, which the app decrypts with
/// `ENCRYPTION_KEY` (environment variables) or `API_ENCRYPTION_KEY`.
///
/// `decrypt` takes the IV length from the stored value, so a 12-byte IV (GCM's
/// native nonce size) round-trips with Node even though the app writes 16.
String encryptAesGcm({
  required List<int> key,
  required List<int> iv,
  required String plaintext,
}) {
  if (key.length != 32) throw ArgumentError('AES-256 key must be 32 bytes');
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(
        KeyParameter(Uint8List.fromList(key)),
        128,
        Uint8List.fromList(iv),
        Uint8List(0),
      ),
    );
  final out = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
  final split = out.length - 16;
  return '${toHex(iv)}:${toHex(out.sublist(0, split))}:${toHex(out.sublist(split))}';
}

/// `ENCRYPTION_KEY` is valid only as 64 hex characters (32 bytes).
List<int>? parseEncryptionKey(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(trimmed)) return null;
  return fromHex(trimmed);
}
