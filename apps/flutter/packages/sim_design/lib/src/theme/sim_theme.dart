import 'package:flutter/material.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/tokens/shadows.dart';
import 'package:sim_design/src/tokens/text_styles.dart';

/// Theme extension carrying the Sim tokens. Read it with [SimTheme.of].
class SimTheme extends ThemeExtension<SimTheme> {
  const SimTheme({
    required this.colors,
    required this.shadows,
    this.text = SimTextStyles.workspace,
  });

  static const SimTheme light = SimTheme(
    colors: SimColors.light,
    shadows: SimShadows.light,
  );

  static const SimTheme dark = SimTheme(
    colors: SimColors.dark,
    shadows: SimShadows.dark,
  );

  final SimColors colors;
  final SimShadows shadows;
  final SimTextStyles text;

  Brightness get brightness => colors.brightness;
  bool get isDark => brightness == Brightness.dark;

  /// The nearest [SimTheme]; falls back to the light/dark default when the
  /// enclosing [ThemeData] was not built by [simLightTheme]/[simDarkTheme].
  static SimTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<SimTheme>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// Like [of] but without creating a dependency on the theme.
  static SimTheme? maybeOf(BuildContext context) =>
      Theme.of(context).extension<SimTheme>();

  @override
  SimTheme copyWith({
    SimColors? colors,
    SimShadows? shadows,
    SimTextStyles? text,
  }) => SimTheme(
    colors: colors ?? this.colors,
    shadows: shadows ?? this.shadows,
    text: text ?? this.text,
  );

  /// Token sets are discrete; a theme switch snaps at the midpoint.
  @override
  SimTheme lerp(ThemeExtension<SimTheme>? other, double t) {
    if (other is! SimTheme) return this;
    return t < 0.5 ? this : other;
  }
}

/// [ThemeData] for the light theme (`:root, .light`).
ThemeData simLightTheme({SimTextStyles text = SimTextStyles.workspace}) =>
    _buildTheme(SimTheme.light.copyWith(text: text));

/// [ThemeData] for the dark theme (`.dark`).
ThemeData simDarkTheme({SimTextStyles text = SimTextStyles.workspace}) =>
    _buildTheme(SimTheme.dark.copyWith(text: text));

/// Configures Material defaults so stock widgets inherit the tokens instead of
/// leaking Material styling: no splash/hover/focus tints, 8px scrollbar thumbs
/// in the scrollbar tokens, the branded text selection, token dividers and
/// icons, Season as the document face.
ThemeData _buildTheme(SimTheme sim) {
  final c = sim.colors;
  final t = sim.text;
  final colorScheme = ColorScheme(
    brightness: sim.brightness,
    primary: c.textPrimary,
    onPrimary: c.textInverse,
    secondary: c.textSecondary,
    onSecondary: c.textInverse,
    error: c.textError,
    onError: SimColors.white,
    surface: c.bg,
    onSurface: c.textPrimary,
    surfaceContainerLowest: c.surface1,
    surfaceContainerLow: c.surface2,
    surfaceContainer: c.surface3,
    surfaceContainerHigh: c.surface4,
    surfaceContainerHighest: c.surface5,
    onSurfaceVariant: c.textSecondary,
    outline: c.border,
    outlineVariant: c.border,
    shadow: SimColors.black,
    scrim: SimColors.black,
    inverseSurface: c.surfaceInverted,
    onInverseSurface: c.textInverse,
    inversePrimary: c.textInverse,
    surfaceTint: Colors.transparent,
  );
  final textTheme = TextTheme(
    displayLarge: t
        .pageHeading(viewportWidth: 1024)
        .copyWith(
          color: c.textPrimary,
        ),
    displayMedium: t.pageHeading().copyWith(color: c.textPrimary),
    headlineMedium: t.style(SimTextStyles.sizeLg, color: c.textPrimary),
    headlineSmall: t.style(SimTextStyles.sizeMd, color: c.textPrimary),
    titleLarge: t.style(SimTextStyles.sizeBase, color: c.textPrimary),
    titleMedium: t.style(SimTextStyles.sizeSm, color: c.textPrimary),
    titleSmall: t.style(SimTextStyles.sizeSmall, color: c.textPrimary),
    bodyLarge: t.style(SimTextStyles.sizeBase, color: c.textPrimary),
    bodyMedium: t.style(SimTextStyles.sizeSm, color: c.textPrimary),
    bodySmall: t.style(SimTextStyles.sizeSmall, color: c.textPrimary),
    labelLarge: t.style(SimTextStyles.sizeSm, color: c.textPrimary),
    labelMedium: t.style(SimTextStyles.sizeCaption, color: c.textPrimary),
    labelSmall: t.style(SimTextStyles.sizeXs, color: c.textPrimary),
  );
  final menuShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(SimRadii.menu),
    side: BorderSide(color: c.border),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: sim.brightness,
    colorScheme: colorScheme,
    extensions: <ThemeExtension<dynamic>>[sim],
    fontFamily: t.family,
    fontFamilyFallback: t.familyFallback,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    cardColor: c.surface2,
    dialogTheme: DialogThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: menuShape,
    ),
    dividerColor: c.border,
    dividerTheme: DividerThemeData(
      color: c.border,
      thickness: SimLayout.borderWidth,
      space: SimLayout.borderWidth,
    ),
    shadowColor: SimColors.black,
    hintColor: c.textMuted,
    disabledColor: c.textMuted,
    unselectedWidgetColor: c.border,
    // Material feedback paints nothing: emcn surfaces own their hover and
    // active fills and never draw ripples, focus rings or hover tints.
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    iconTheme: IconThemeData(color: c.textIcon, size: SimLayout.iconSize),
    primaryIconTheme: IconThemeData(
      color: c.textIcon,
      size: SimLayout.iconSize,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll<double>(
        SimLayout.scrollbarThickness,
      ),
      radius: const Radius.circular(SimRadii.scrollbarThumb),
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.hovered)
            ? c.scrollbarThumbHover
            : c.scrollbarThumb,
      ),
      trackColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      trackBorderColor: const WidgetStatePropertyAll<Color>(
        Colors.transparent,
      ),
      crossAxisMargin: 0,
      mainAxisMargin: 0,
      minThumbLength: 18,
      interactive: true,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.textPrimary,
      selectionColor: c.selectionMuted,
      selectionHandleColor: c.selection,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(SimRadii.lg),
        boxShadow: SimShadows.xs,
      ),
      textStyle: t.caption.copyWith(color: c.textBody),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: menuShape,
      textStyle: t.small.copyWith(color: c.textBody),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(c.bg),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        elevation: const WidgetStatePropertyAll<double>(0),
        shape: WidgetStatePropertyAll<OutlinedBorder>(menuShape),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.all(SimLayout.menuPadding),
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface1,
      foregroundColor: c.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: c.surface2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SimRadii.lg),
        side: BorderSide(color: c.border),
      ),
    ),
    checkboxTheme: const CheckboxThemeData(splashRadius: 0),
    radioTheme: const RadioThemeData(splashRadius: 0),
    switchTheme: const SwitchThemeData(splashRadius: 0),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: c.textBody,
      iconColor: c.textIcon,
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        foregroundColor: WidgetStatePropertyAll<Color>(c.textSecondary),
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    applyElevationOverlayColor: false,
  );
}

/// The `::selection` colour and caret for a given theme, exposed for editors
/// that do not read [ThemeData.textSelectionTheme].
TextSelectionThemeData simTextSelection(SimColors colors) =>
    TextSelectionThemeData(
      cursorColor: colors.textPrimary,
      selectionColor: colors.selectionMuted,
      selectionHandleColor: colors.selection,
    );
