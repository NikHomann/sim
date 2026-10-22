import 'package:flutter/painting.dart';
import 'package:sim_design/src/tokens/fonts.dart';

/// Which letter-spacing rule a text style follows (`globals.css`).
enum SimTracking {
  /// `body { letter-spacing: 0.28px }`.
  body,

  /// `.workspace-root { letter-spacing: 0.02em }` — the app shell.
  workspace,
}

/// The type scale (`02-design-system.md` §1b).
///
/// text-micro 10 · text-xs 11 (lh 1.5) · text-caption 12 · text-small 13 ·
/// text-sm 14 · text-base 15 · text-md 16 · text-lg 18. Weights are 400/500/600
/// only; every style sets `fontVariations` because the bundled faces are
/// variable fonts (`FontWeight` alone is ignored by them) and `fontWeight` for
/// the fallback faces. Line height is Tailwind's inherited 1.5 unless a style
/// says otherwise.
class SimTextStyles {
  const SimTextStyles({
    this.tracking = SimTracking.workspace,
    this.family = SimFonts.season,
    this.familyFallback = SimFonts.seasonFallback,
  });

  /// The app shell (`.workspace-root`, 0.02em tracking).
  static const SimTextStyles workspace = SimTextStyles();

  /// Document surfaces outside the workspace root (0.28px tracking).
  static const SimTextStyles document = SimTextStyles(
    tracking: SimTracking.body,
  );

  final SimTracking tracking;
  final String family;
  final List<String> familyFallback;

  static const int regular = 400;
  static const int medium = 500;
  static const int semibold = 600;

  static const double sizeMicro = 10;
  static const double sizeXs = 11;
  static const double sizeCaption = 12;
  static const double sizeSmall = 13;
  static const double sizeSm = 14;
  static const double sizeBase = 15;
  static const double sizeMd = 16;
  static const double sizeLg = 18;

  /// Default line height (`html { line-height: 1.5 }`).
  static const double defaultLineHeight = 1.5;

  /// Body letter-spacing in px, and workspace tracking as an em fraction.
  static const double bodyLetterSpacingPx = 0.28;
  static const double workspaceTrackingEm = 0.02;

  /// Resolves the letter spacing for a font size under this tracking rule.
  double letterSpacing(double fontSize) => switch (tracking) {
    SimTracking.body => bodyLetterSpacingPx,
    SimTracking.workspace => workspaceTrackingEm * fontSize,
  };

  /// Builds a style on the document face.
  TextStyle style(
    double fontSize, {
    int weight = regular,
    double height = defaultLineHeight,
    Color? color,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
    fontSize: fontSize,
    fontWeight: _fontWeight(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    letterSpacing: letterSpacing(fontSize),
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    color: color,
  );

  TextStyle get micro => style(sizeMicro);
  TextStyle get xs => style(sizeXs);
  TextStyle get caption => style(sizeCaption);
  TextStyle get small => style(sizeSmall);
  TextStyle get sm => style(sizeSm);
  TextStyle get base => style(sizeBase);
  TextStyle get md => style(sizeMd);
  TextStyle get lg => style(sizeLg);

  /// `pageHeadingClassName`: Season, 26px (28px at >= 640), leading 1.15,
  /// tracking -0.01em (`packages/emcn/src/components/page-heading/page-heading.ts`).
  TextStyle pageHeading({double viewportWidth = double.infinity}) {
    final size = viewportWidth >= 640 ? 28.0 : 26.0;
    return style(size, height: 1.15).copyWith(letterSpacing: -0.01 * size);
  }

  /// `.font-mono` — tracking resets to `normal` inside `.workspace-root`.
  TextStyle mono(
    double fontSize, {
    int weight = regular,
    double height = defaultLineHeight,
    Color? color,
  }) => TextStyle(
    fontFamily: SimFonts.mono,
    fontFamilyFallback: SimFonts.monoFallback,
    fontSize: fontSize,
    fontWeight: _fontWeight(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    letterSpacing: 0,
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    color: color,
  );

  /// Inter for chat message content and the composer.
  TextStyle inter(
    double fontSize, {
    int weight = regular,
    double height = defaultLineHeight,
    Color? color,
  }) => style(fontSize, weight: weight, height: height, color: color).copyWith(
    fontFamily: SimFonts.inter,
    fontFamilyFallback: SimFonts.sansFallback,
  );

  /// Re-weights a style, keeping `fontWeight` and `fontVariations` in step.
  static TextStyle weight(TextStyle style, int weight) => style.copyWith(
    fontWeight: _fontWeight(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
  );

  static FontWeight _fontWeight(int weight) => switch (weight) {
    <= 100 => FontWeight.w100,
    <= 200 => FontWeight.w200,
    <= 300 => FontWeight.w300,
    <= 400 => FontWeight.w400,
    <= 500 => FontWeight.w500,
    <= 600 => FontWeight.w600,
    <= 700 => FontWeight.w700,
    <= 800 => FontWeight.w800,
    _ => FontWeight.w900,
  };
}
