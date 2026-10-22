import 'dart:typed_data';

/// A file the user picked through the hidden file input.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;

  int get size => bytes.length;
}
