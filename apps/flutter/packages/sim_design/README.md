# sim_design

Design system of the Flutter port of Sim (`docs/port/00-plan.md` §4.2,
tokens and measurements in `docs/port/02-design-system.md`). It depends on
Flutter and third-party packages only — never on another `sim_*` package.

Every widget's doc comment names the upstream file it ports
(`packages/emcn/src/components/...`); values are the upstream literals at
commit `27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c`.

## Contents

- **Tokens** — `SimColors` (light/dark, incl. terminal status, badge palettes,
  chip ring), `SimTextStyles` (variable-font styles: every style sets
  `fontVariations: [FontVariation('wght', …)]`; workspace 0.02em vs body
  0.28px tracking), `SimRadii`, `SimShadows`, `SimZ`, `SimMotion`
  (`SimMotion.scale = 0` disables motion — the app sets it under
  `SIM_E2E`), `SimBreakpoints`, `SimLayout`, `SimFonts`.
- **Theme** — `SimTheme` (`ThemeExtension`, `SimTheme.of(context)`),
  `simLightTheme()` / `simDarkTheme()` (Material defaults neutralised: no
  splash/hover/focus tints, 8px token scrollbars, branded selection, Season as
  the document face).
- **Fonts** — Season Sans (WOFF2 → TTF) and Inter variable (`LICENSES.md`).
- **Icons** — `SimIcon` renders SVG assets with `currentColor` mapped through
  `SvgTheme`; `SimIcons` holds the hand-ported glyphs the widgets need. The
  full emcn and brand sets are generated into `lib/src/icons/generated/` by
  the extraction step (see the README there); the barrel has commented
  exports ready for them.
- **Overlay manager** — `SimOverlayHost` stacks `SimOverlayEntry`s by the z
  ladder and closes layers on outside pointer-down and Escape the way Radix
  `DismissableLayer` does. Place it once near the root:

  ```dart
  MaterialApp(
    theme: simLightTheme(),
    darkTheme: simDarkTheme(),
    builder: (context, child) => SimOverlayHost(
      child: Stack(children: [child!, const SimToastStack()]),
    ),
  )
  ```

- **Widgets** (same names and variants as emcn; consumers pass props, never
  chrome): `SimChip`/`SimChipLink`, `SimChipInput`, `SimChipTextarea`,
  `SimChipCopyInput`, `SimChipSelect`, `SimChipDropdown`, `SimChipCombobox`,
  `SimChipSwitch`, `SimChipButtonGroup`, `SimChipTag`, `SimButton`,
  `SimDropdownMenu` (`show` / `showAt` for context menus), `SimPopover` and
  its content widgets, `SimTooltip` / `SimFloatingTooltip`, `SimToasts` +
  `SimToastStack`, `showSimModal` + `SimModalHeader/Body/Footer/Tabs`,
  `showSimChipModal` + `SimChipModalSurface/Header/Body/Field/Footer/Tabs`,
  `showSimChipConfirmModal`, `SimInput`, `SimTextarea`, `SimSwitch`,
  `SimCheckbox`, `SimSlider`, `SimBadge`, `SimSkeleton`, `SimTable`,
  `SimTabStrip`, `SimDetailsPanel`, `SimScrollFade`, `SimOverflowText`,
  `SimLabel`, `SimFieldDivider`, `SimPageHeading`, `SimKbd`.

Interaction rules: hover via `MouseRegion` (mouse only), Enter/Space activate
(`packages/emcn/src/lib/keyboard.ts`), focus-visible only from keyboard, no
Material ripples or focus rings anywhere.

## Tests

```
dart format .
flutter analyze --fatal-infos
flutter test --update-goldens   # regenerate goldens after a deliberate change
flutter test
```

Goldens (`test/goldens/`) use alchemist: `goldens/ci/` (obscured text, always
compared) and `goldens/<platform>/` (real text, compared outside `CI=true`).
`test/tokens_test.dart` checks token-derived properties against the measured
values in `02-design-system.md`.

## Known deviations

- `--overflow-fade-size` is 16px (code at the pinned commit); the doc's 18px
  is recorded in `SimLayout.overflowFade`'s comment.
- The tooltip's velocity flourish (skew/scale while the pointer moves) is not
  ported; position easing (150ms) is.
- `PopoverFolder expandOnHover` (hover submenus) is not ported; click-mode
  folders are. `DropdownMenu` submenus open on hover and ArrowRight.
- Tab-strip enter/exit scale animations are not ported; drag reordering,
  drop indicators, edge auto-scroll and keyboard handling are.
- Mobile touch-target expansion (`max-md:pointer-coarse:min-h-11`) is left to
  the app shell (`SimLayout.touchTarget`).
