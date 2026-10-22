// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: apps/flutter/generated/manifest.json (upstream commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c)
// Regenerate: dart run tools/gen/main.dart (from apps/flutter)
// ignore_for_file: type=lint

/// A function-valued upstream field that has no static representation.
///
/// [id] is `<owner>.<path>`, the key into `closures.json`; the Dart port keyed
/// on it lives in the workflow package.
class FnRef {
  const FnRef(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is FnRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FnRef($id)';
}

/// An icon component reference: `<set>/<name>`, the key into `icons.g.dart`.
class IconRef {
  const IconRef(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is IconRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'IconRef($id)';
}

/// A JavaScript regular expression literal that appeared in a config value.
class RegexRef {
  const RegexRef(this.source, this.flags);

  final String source;
  final String flags;

  @override
  String toString() => 'RegexRef(/$source/$flags)';
}
