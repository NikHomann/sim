import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

/// One badge colour pair (`--badge-*-bg` / `--badge-*-text`).
class SimBadgePalette {
  const SimBadgePalette({required this.background, required this.text});

  final Color background;
  final Color text;
}

/// One terminal status band (`--terminal-status-*-bg/-border/-color`).
class SimTerminalStatusPalette {
  const SimTerminalStatusPalette({
    required this.background,
    required this.border,
    this.text,
  });

  final Color background;
  final Color border;

  /// Null for the error band, which inherits the surrounding text colour upstream.
  final Color? text;
}

/// Every colour token of `apps/sim/app/_styles/globals.css` (`:root, .light` and
/// `.dark`), mapped in `docs/port/02-design-system.md` §1a. Values are the
/// upstream hex literals verbatim; nothing is derived.
class SimColors {
  const SimColors({
    required this.brightness,
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.surface4,
    required this.surface5,
    required this.surface6,
    required this.surface7,
    required this.surfaceHover,
    required this.surfaceActive,
    required this.workflowEdge,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.textSubtle,
    required this.textBody,
    required this.textIcon,
    required this.textIconMuted,
    required this.textInverse,
    required this.textMutedInverse,
    required this.textError,
    required this.textPlaceholder,
    required this.textSuccess,
    required this.border,
    required this.borderSuccess,
    required this.brandAgent,
    required this.brandSecondary,
    required this.brandAccent,
    required this.brandAccentHover,
    required this.brandBlue,
    required this.selection,
    required this.selectionMuted,
    required this.warning,
    required this.surfaceInverted,
    required this.surfaceInvertedHover,
    required this.borderInverted,
    required this.tooltipBg,
    required this.codeBg,
    required this.codeForeground,
    required this.codeLineNumber,
    required this.error,
    required this.errorMuted,
    required this.errorEmphasis,
    required this.caution,
    required this.success,
    required this.brandKnowledge,
    required this.selectionDark,
    required this.selectionBg,
    required this.highlightSearchActive,
    required this.highlightSearch,
    required this.highlightMatchBg,
    required this.highlightMatchText,
    required this.indicatorOnline,
    required this.indicatorActive,
    required this.indicatorInactive,
    required this.indicatorSeatFilled,
    required this.scrollbarThumb,
    required this.scrollbarThumbHover,
    required this.thinkingInkCurrent,
    required this.thinkingInkInner,
    required this.thinkingInkOuter,
    required this.thinkingInkGlow,
    required this.terminalStatusError,
    required this.terminalStatusInfo,
    required this.terminalStatusWarning,
    required this.badgeSuccess,
    required this.badgeError,
    required this.badgeGray,
    required this.badgeBlue,
    required this.badgeBlueSecondary,
    required this.badgePurple,
    required this.badgeOrange,
    required this.badgeAmber,
    required this.badgeTeal,
    required this.badgeCyan,
    required this.badgePink,
    required this.chipRingHairline,
    required this.chipRingShadow,
  });

  final Brightness brightness;

  // Surfaces
  final Color bg;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color surface4;
  final Color surface5;
  final Color surface6;
  final Color surface7;
  final Color surfaceHover;
  final Color surfaceActive;
  final Color workflowEdge;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final Color textSubtle;
  final Color textBody;
  final Color textIcon;
  final Color textIconMuted;
  final Color textInverse;
  final Color textMutedInverse;
  final Color textError;
  final Color textPlaceholder;
  final Color textSuccess;

  // Borders
  final Color border;
  final Color borderSuccess;

  /// `--border-1` and `--border-muted` are aliases of `--border` upstream.
  Color get border1 => border;
  Color get borderMuted => border;

  // Brand and state
  final Color brandAgent;
  final Color brandSecondary;
  final Color brandAccent;
  final Color brandAccentHover;
  final Color brandBlue;
  final Color selection;
  final Color selectionMuted;
  final Color warning;

  // Inverted surfaces and tooltip
  final Color surfaceInverted;
  final Color surfaceInvertedHover;
  final Color borderInverted;
  final Color tooltipBg;

  // Code editor
  final Color codeBg;
  final Color codeForeground;
  final Color codeLineNumber;

  // Semantic
  final Color error;
  final Color errorMuted;
  final Color errorEmphasis;
  final Color caution;
  final Color success;
  final Color brandKnowledge;
  final Color selectionDark;
  final Color selectionBg;
  final Color highlightSearchActive;
  final Color highlightSearch;
  final Color highlightMatchBg;
  final Color highlightMatchText;
  final Color indicatorOnline;
  final Color indicatorActive;
  final Color indicatorInactive;
  final Color indicatorSeatFilled;
  final Color scrollbarThumb;
  final Color scrollbarThumbHover;
  final Color thinkingInkCurrent;
  final Color thinkingInkInner;
  final Color thinkingInkOuter;
  final Color thinkingInkGlow;

  // Terminal status
  final SimTerminalStatusPalette terminalStatusError;
  final SimTerminalStatusPalette terminalStatusInfo;
  final SimTerminalStatusPalette terminalStatusWarning;

  // Badges
  final SimBadgePalette badgeSuccess;
  final SimBadgePalette badgeError;
  final SimBadgePalette badgeGray;
  final SimBadgePalette badgeBlue;
  final SimBadgePalette badgeBlueSecondary;
  final SimBadgePalette badgePurple;
  final SimBadgePalette badgeOrange;
  final SimBadgePalette badgeAmber;
  final SimBadgePalette badgeTeal;
  final SimBadgePalette badgeCyan;
  final SimBadgePalette badgePink;

  /// The `border-shadow` chip ring (`chipBorderShadowRing` in
  /// `packages/emcn/src/components/chip/chrome.ts`): a 1px hairline ring and a
  /// 0 1px 3px drop shadow. Light: rgba(28,40,64,.08) / rgba(28,40,64,.1);
  /// dark: `--border` / rgba(0,0,0,.3).
  final Color chipRingHairline;
  final Color chipRingShadow;

  /// The chip ring as box shadows (1px spread hairline + drop shadow).
  List<BoxShadow> get chipRing => <BoxShadow>[
    BoxShadow(color: chipRingHairline, spreadRadius: 1),
    BoxShadow(color: chipRingShadow, offset: const Offset(0, 1), blurRadius: 3),
  ];

  /// `--auth-primary-btn-*` (theme independent).
  static const Color authButtonBg = Color(0xFFFFFFFF);
  static const Color authButtonBorder = Color(0xFFFFFFFF);
  static const Color authButtonText = Color(0xFF000000);
  static const Color authButtonHoverBg = Color(0xFFE0E0E0);

  /// Browser `theme-color` meta values.
  static const Color browserThemeLight = Color(0xFFFFFFFF);
  static const Color browserThemeDark = Color(0xFF0C0C0C);

  /// Tailwind v3 gray scale pinned in `globals.css` (`--color-gray-50..950`).
  static const List<Color> gray = <Color>[
    Color(0xFFFAFAFA),
    Color(0xFFF5F5F5),
    Color(0xFFE5E5E5),
    Color(0xFFD4D4D4),
    Color(0xFFA3A3A3),
    Color(0xFF737373),
    Color(0xFF525252),
    Color(0xFF404040),
    Color(0xFF262626),
    Color(0xFF171717),
    Color(0xFF0A0A0A),
  ];

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static const SimColors light = SimColors(
    brightness: Brightness.light,
    bg: Color(0xFFFEFEFE),
    surface1: Color(0xFFFBFBFB),
    surface2: Color(0xFFFFFFFF),
    surface3: Color(0xFFF7F7F7),
    surface4: Color(0xFFF5F5F5),
    surface5: Color(0xFFF3F3F3),
    surface6: Color(0xFFE5E5E5),
    surface7: Color(0xFFD9D9D9),
    surfaceHover: Color(0xFFF2F2F2),
    surfaceActive: Color(0xFFECECEC),
    workflowEdge: Color(0xFFE0E0E0),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF525252),
    textTertiary: Color(0xFF5C5C5C),
    textMuted: Color(0xFF7A7A7A),
    textSubtle: Color(0xFF8C8C8C),
    textBody: Color(0xFF434343),
    textIcon: Color(0xFF5A5A5A),
    textIconMuted: Color(0xFF5C5C5C),
    textInverse: Color(0xFFFFFFFF),
    textMutedInverse: Color(0xFFA0A0A0),
    textError: Color(0xFFEF4444),
    textPlaceholder: Color(0xFF8D8D8D),
    textSuccess: Color(0xFF22C55E),
    border: Color(0xFFD8D8D8),
    borderSuccess: Color(0xFFE0E0E0),
    brandAgent: Color(0xFF6F3DFA),
    brandSecondary: Color(0xFF33B4FF),
    brandAccent: Color(0xFF33C482),
    brandAccentHover: Color(0xFF2DAC72),
    brandBlue: Color(0xFF3B6FE0),
    selection: Color(0xFF1A5CF6),
    selectionMuted: Color(0x471A5CF6),
    warning: Color(0xFFEA580C),
    surfaceInverted: Color(0xFF1B1B1B),
    surfaceInvertedHover: Color(0xFF363636),
    borderInverted: Color(0xFF363636),
    tooltipBg: Color(0xFF1B1B1B),
    codeBg: Color(0xFFF5F5F5),
    codeForeground: Color(0xFF1A1A1A),
    codeLineNumber: Color(0xFF737373),
    error: Color(0xFFDC2626),
    errorMuted: Color(0xFFFECACA),
    errorEmphasis: Color(0xFFB91C1C),
    caution: Color(0xFFF59E0B),
    success: Color(0xFF22C55E),
    brandKnowledge: Color(0xFF00B0B0),
    selectionDark: Color(0xFF264F78),
    selectionBg: Color(0xFFADD6FF),
    highlightSearchActive: Color(0xFFF6AD55),
    highlightSearch: Color(0xFFFCD34D),
    highlightMatchBg: Color(0xFFBAE6FD),
    highlightMatchText: Color(0xFF0369A1),
    indicatorOnline: Color(0xFF33C482),
    indicatorActive: Color(0xFF4ADE80),
    indicatorInactive: Color(0xFFB7B7B7),
    indicatorSeatFilled: Color(0xFF34B5FF),
    scrollbarThumb: Color(0xFFC0C0C0),
    scrollbarThumbHover: Color(0xFFA8A8A8),
    thinkingInkCurrent: Color(0xFF2C2C2C),
    thinkingInkInner: Color(0xFF2C2C2C),
    thinkingInkOuter: Color(0xFF5F5F5F),
    thinkingInkGlow: Color(0x99FFFFFF),
    terminalStatusError: SimTerminalStatusPalette(
      background: Color(0xFFFEF2F2),
      border: Color(0xFFF87171),
    ),
    terminalStatusInfo: SimTerminalStatusPalette(
      background: Color(0xFFF7F7F7),
      border: Color(0xFFA3A3A3),
      text: Color(0xFF525252),
    ),
    terminalStatusWarning: SimTerminalStatusPalette(
      background: Color(0xFFFEFCE8),
      border: Color(0xFFFACC15),
      text: Color(0xFFA16207),
    ),
    badgeSuccess: SimBadgePalette(
      background: Color(0xFFBBF7D0),
      text: Color(0xFF15803D),
    ),
    badgeError: SimBadgePalette(
      background: Color(0xFFFECACA),
      text: Color(0xFFDC2626),
    ),
    badgeGray: SimBadgePalette(
      background: Color(0xFFE7E5E4),
      text: Color(0xFF57534E),
    ),
    badgeBlue: SimBadgePalette(
      background: Color(0xFFBFDBFE),
      text: Color(0xFF1D4ED8),
    ),
    badgeBlueSecondary: SimBadgePalette(
      background: Color(0xFFBAE6FD),
      text: Color(0xFF0369A1),
    ),
    badgePurple: SimBadgePalette(
      background: Color(0xFFE9D5FF),
      text: Color(0xFF7C3AED),
    ),
    badgeOrange: SimBadgePalette(
      background: Color(0xFFFED7AA),
      text: Color(0xFFC2410C),
    ),
    badgeAmber: SimBadgePalette(
      background: Color(0xFFFDE68A),
      text: Color(0xFFA16207),
    ),
    badgeTeal: SimBadgePalette(
      background: Color(0xFF99F6E4),
      text: Color(0xFF0F766E),
    ),
    badgeCyan: SimBadgePalette(
      background: Color(0xFFCFFAFE),
      text: Color(0xFF0891B2),
    ),
    badgePink: SimBadgePalette(
      background: Color(0xFFFBCFE8),
      text: Color(0xFFBE185D),
    ),
    chipRingHairline: Color(0x141C2840),
    chipRingShadow: Color(0x1A1C2840),
  );

  static const SimColors dark = SimColors(
    brightness: Brightness.dark,
    bg: Color(0xFF1B1B1B),
    surface1: Color(0xFF1E1E1E),
    surface2: Color(0xFF232323),
    surface3: Color(0xFF242424),
    surface4: Color(0xFF292929),
    surface5: Color(0xFF363636),
    surface6: Color(0xFF454545),
    surface7: Color(0xFF505050),
    surfaceHover: Color(0xFF262626),
    surfaceActive: Color(0xFF2C2C2C),
    workflowEdge: Color(0xFF454545),
    textPrimary: Color(0xFFE6E6E6),
    textSecondary: Color(0xFFCCCCCC),
    textTertiary: Color(0xFFB3B3B3),
    textMuted: Color(0xFF6E6E6E),
    textSubtle: Color(0xFF7D7D7D),
    textBody: Color(0xFFC1C1C1),
    textIcon: Color(0xFF969696),
    textIconMuted: Color(0xFF949494),
    textInverse: Color(0xFF1B1B1B),
    textMutedInverse: Color(0xFFB3B3B3),
    textError: Color(0xFFEF4444),
    textPlaceholder: Color(0xFF8D8D8D),
    textSuccess: Color(0xFF22C55E),
    border: Color(0xFF444444),
    borderSuccess: Color(0xFF575757),
    brandAgent: Color(0xFF701FFC),
    brandSecondary: Color(0xFF33B4FF),
    brandAccent: Color(0xFF33C482),
    brandAccentHover: Color(0xFF2DAC72),
    brandBlue: Color(0xFF5B8DEF),
    selection: Color(0xFF4B83F7),
    selectionMuted: Color(0x594B83F7),
    warning: Color(0xFFFF6600),
    surfaceInverted: Color(0xFF242424),
    surfaceInvertedHover: Color(0xFF363636),
    borderInverted: Color(0xFF3D3D3D),
    tooltipBg: Color(0xFFFDFDFD),
    codeBg: Color(0xFF1F1F1F),
    codeForeground: Color(0xFFEEEEEE),
    codeLineNumber: Color(0xFFA8A8A8),
    error: Color(0xFFF87171),
    errorMuted: Color(0xFFF6D2D2),
    errorEmphasis: Color(0xFFB91C1C),
    caution: Color(0xFFF59E0B),
    success: Color(0xFF22C55E),
    brandKnowledge: Color(0xFF00B0B0),
    selectionDark: Color(0xFF264F78),
    selectionBg: Color(0xFF264F78),
    highlightSearchActive: Color(0xFFF6AD55),
    highlightSearch: Color(0xFFFCD34D),
    highlightMatchBg: Color(0x3333B4FF),
    highlightMatchText: Color(0xFF7DD3FC),
    indicatorOnline: Color(0xFF33C482),
    indicatorActive: Color(0xFF4ADE80),
    indicatorInactive: Color(0xFFB7B7B7),
    indicatorSeatFilled: Color(0xFF34B5FF),
    scrollbarThumb: Color(0xFF5A5A5A),
    scrollbarThumbHover: Color(0xFF6A6A6A),
    thinkingInkCurrent: Color(0xFFD6D6D6),
    thinkingInkInner: Color(0xFFA7A7A7),
    thinkingInkOuter: Color(0xFFD6D6D6),
    thinkingInkGlow: Color(0xE6FFFFFF),
    terminalStatusError: SimTerminalStatusPalette(
      background: Color(0xFF491515),
      border: Color(0xFF883827),
    ),
    terminalStatusInfo: SimTerminalStatusPalette(
      background: Color(0xFF383838),
      border: Color(0xFF686868),
      text: Color(0xFFB7B7B7),
    ),
    terminalStatusWarning: SimTerminalStatusPalette(
      background: Color(0xFF3D3520),
      border: Color(0xFF5C4D1F),
      text: Color(0xFFD4A72C),
    ),
    badgeSuccess: SimBadgePalette(
      background: Color(0x3322C55E),
      text: Color(0xFF86EFAC),
    ),
    badgeError: SimBadgePalette(
      background: Color(0xFF551A1A),
      text: Color(0xFFFCA5A5),
    ),
    badgeGray: SimBadgePalette(
      background: Color(0xFF3A3A3A),
      text: Color(0xFFA8A8A8),
    ),
    badgeBlue: SimBadgePalette(
      background: Color(0x333B82F6),
      text: Color(0xFF93C5FD),
    ),
    badgeBlueSecondary: SimBadgePalette(
      background: Color(0x3333B4FF),
      text: Color(0xFF7DD3FC),
    ),
    badgePurple: SimBadgePalette(
      background: Color(0x33A855F7),
      text: Color(0xFFD8B4FE),
    ),
    badgeOrange: SimBadgePalette(
      background: Color(0x33F97316),
      text: Color(0xFFFDBA74),
    ),
    badgeAmber: SimBadgePalette(
      background: Color(0x33F59E0B),
      text: Color(0xFFFCD34D),
    ),
    badgeTeal: SimBadgePalette(
      background: Color(0x3314B8A6),
      text: Color(0xFF5EEAD4),
    ),
    badgeCyan: SimBadgePalette(
      background: Color(0x330EA5E9),
      text: Color(0xFF7DD3FC),
    ),
    badgePink: SimBadgePalette(
      background: Color(0x33EC4899),
      text: Color(0xFFF9A8D4),
    ),
    chipRingHairline: Color(0xFF444444),
    chipRingShadow: Color(0x4D000000),
  );

  /// Tailwind `color-mix(in srgb, a X%, b)`: `in srgb` is gamma-encoded sRGB,
  /// so a plain channel lerp reproduces it.
  static Color mix(Color a, Color b, double aFraction) =>
      Color.lerp(b, a, aFraction)!;

  /// Tailwind `brightness-106` on a solid fill.
  static Color brighten(Color color, double factor) {
    int scale(double channel) => (channel * 255 * factor).round().clamp(0, 255);
    return Color.fromARGB(
      (color.a * 255).round(),
      scale(color.r),
      scale(color.g),
      scale(color.b),
    );
  }
}
