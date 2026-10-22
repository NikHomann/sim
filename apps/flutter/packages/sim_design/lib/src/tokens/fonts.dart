/// Font families bundled by this package (`pubspec.yaml` `flutter.fonts`).
///
/// Package fonts are registered under the `packages/<name>/<family>` key, so
/// these constants already carry the prefix and are passed to
/// `TextStyle.fontFamily` directly (never together with `package:`).
abstract final class SimFonts {
  /// Season Sans variable (wght 300-800) — the document font
  /// (`apps/sim/app/_styles/fonts/season/season.ts`, `<body class='font-season'>`).
  static const String season = 'packages/sim_design/Season Sans';

  /// Inter variable (wght 100-900) — chat message content, the composer,
  /// message sources and the rich markdown editor only.
  static const String inter = 'packages/sim_design/Inter';

  /// `--font-mono`: Martian Mono is not loaded in product, so the stack falls
  /// through to the platform monospace. The first family is only a hint.
  static const String mono = 'Martian Mono';

  /// `season.ts` fallback list (metric-adjusted Arial upstream).
  static const List<String> seasonFallback = <String>[
    'system-ui',
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'Noto Sans',
  ];

  /// `--font-mono` fallback stack.
  static const List<String> monoFallback = <String>[
    'ui-monospace',
    'SFMono-Regular',
    'Menlo',
    'Monaco',
    'Consolas',
    'Liberation Mono',
    'Courier New',
    'monospace',
  ];

  /// `--font-sans` (Tailwind v3 default stack) for non-branded surfaces.
  static const List<String> sansFallback = <String>[
    'ui-sans-serif',
    'system-ui',
    'sans-serif',
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Segoe UI Symbol',
    'Noto Color Emoji',
  ];
}
