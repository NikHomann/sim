// Failure modes this file guards (docs/port/04-test-plan.md §1, L2):
// - a token-derived property drifts from the value measured in
//   docs/port/02-design-system.md (chip/menu geometry, type scale, tracking);
// - a variable-font style forgets its `wght` axis and silently renders at 400;
// - the z ladder loses its order (toast above modal, popover below modal);
// - theme-dependent chrome (primary chip, chip ring, filled fill) resolves to
//   the light value in dark mode;
// - the legacy `--border-1` / `--border-muted` aliases drift from `--border`
//   in either theme (globals.css keeps them as `var(--border)`);
// - the toast stack geometry, tab drop partition or tooltip edge flip
//   regress from the upstream algorithm.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_design/sim_design.dart';

void main() {
  group('chip and menu geometry (02 §1b, §1c, MENU_STYLES)', () {
    test('chip pill is 30px, px-2, gap-1.5, rounded-lg', () {
      expect(SimChipChrome.height, 30);
      expect(SimChipChrome.paddingX, 8);
      expect(SimChipChrome.gap, 6);
      expect(SimChipChrome.radius, 8);
      expect(SimChipChrome.contentIconSize, 16);
    });

    test('menu rows are 28px (sm 24px) on a 12px surface with p-1', () {
      expect(SimMenuStyles.rowHeight(SimMenuRowSize.md), 28);
      expect(SimMenuStyles.rowHeight(SimMenuRowSize.sm), 24);
      expect(SimMenuStyles.rowHeight(SimMenuRowSize.lg), 30);
      expect(SimMenuStyles.padding, const EdgeInsets.all(4));
      expect(
        SimMenuStyles.surface(SimColors.light).borderRadius,
        BorderRadius.circular(12),
      );
      expect(SimMenuStyles.sideOffset, 6);
    });

    test('button radius is 5px, 4px for the icon size', () {
      expect(SimRadii.button, 5);
      expect(SimRadii.buttonIcon, 4);
    });
  });

  group('type scale', () {
    const text = SimTextStyles.workspace;

    test('sizes match the scale and carry the wght axis', () {
      expect(text.sm.fontSize, 14);
      expect(text.small.fontSize, 13);
      expect(text.caption.fontSize, 12);
      expect(text.xs.fontSize, 11);
      expect(text.xs.height, 1.5);
      expect(text.sm.fontVariations, const <FontVariation>[
        FontVariation('wght', 400),
      ]);
      final medium = SimTextStyles.weight(text.sm, 500);
      expect(medium.fontVariations, const <FontVariation>[
        FontVariation('wght', 500),
      ]);
      expect(medium.fontWeight, FontWeight.w500);
    });

    test('workspace tracking is 0.02em, body tracking is 0.28px', () {
      expect(text.sm.letterSpacing, closeTo(0.28, 1e-9));
      expect(text.caption.letterSpacing, closeTo(0.24, 1e-9));
      expect(SimTextStyles.document.sm.letterSpacing, 0.28);
      expect(SimTextStyles.document.md.letterSpacing, 0.28);
      expect(text.mono(13).letterSpacing, 0);
    });

    test('page heading is 26px (28px from 640), leading 1.15, -0.01em', () {
      final narrow = text.pageHeading(viewportWidth: 500);
      final wide = text.pageHeading(viewportWidth: 640);
      expect(narrow.fontSize, 26);
      expect(wide.fontSize, 28);
      expect(wide.height, 1.15);
      expect(wide.letterSpacing, closeTo(-0.28, 1e-9));
      expect(wide.fontFamily, SimFonts.season);
    });
  });

  group('theme-dependent chrome', () {
    test('border-1 and border-muted alias --border in both themes', () {
      for (final c in <SimColors>[SimColors.light, SimColors.dark]) {
        expect(c.border1, c.border);
        expect(c.borderMuted, c.border);
      }
      expect(SimColors.light.border, const Color(0xFFD8D8D8));
      expect(SimColors.dark.border, const Color(0xFF444444));
    });

    test('filled fill is surface-5 light / surface-4 dark', () {
      expect(
        SimChipChrome.filledFill(SimColors.light),
        const Color(0xFFF3F3F3),
      );
      expect(SimChipChrome.filledFill(SimColors.dark), const Color(0xFF292929));
    });

    test('primary chip inverts: dark fill is white on --bg text', () {
      final light = resolveChipPaint(
        SimColors.light,
        variant: SimChipVariant.primary,
      );
      final dark = resolveChipPaint(
        SimColors.dark,
        variant: SimChipVariant.primary,
      );
      expect(light.fill, const Color(0xFF1A1A1A));
      expect(light.text, const Color(0xFFFFFFFF));
      expect(dark.fill, const Color(0xFFFFFFFF));
      expect(dark.text, const Color(0xFF1B1B1B));
      final hovered = resolveChipPaint(
        SimColors.light,
        variant: SimChipVariant.primary,
        hovered: true,
      );
      expect(hovered.fill, SimColors.light.textBody);
    });

    test(
      'border-shadow ring uses the documented light values and --border in dark',
      () {
        final light = SimColors.light.chipRing;
        expect(light.first.color, const Color(0x141C2840));
        expect(light.first.spreadRadius, 1);
        expect(light.last.color, const Color(0x1A1C2840));
        expect(light.last.offset, const Offset(0, 1));
        expect(light.last.blurRadius, 3);
        expect(SimColors.dark.chipRing.first.color, SimColors.dark.border);
        expect(SimColors.dark.chipRing.last.color, const Color(0x4D000000));
      },
    );

    test(
      'default chip hover and active are the two mutually exclusive row surfaces',
      () {
        final hover = resolveChipPaint(SimColors.light, hovered: true);
        final active = resolveChipPaint(
          SimColors.light,
          active: true,
          hovered: true,
        );
        expect(hover.fill, SimColors.light.surfaceHover);
        expect(active.fill, SimColors.light.surfaceActive);
      },
    );

    test(
      'icon buttons paint the muted icon colour only for quiet and ghost',
      () {
        final quiet = resolveButtonPaint(
          SimColors.light,
          variant: SimButtonVariant.quiet,
          size: SimButtonSize.icon,
        );
        final primary = resolveButtonPaint(
          SimColors.light,
          variant: SimButtonVariant.primary,
          size: SimButtonSize.icon,
        );
        expect(quiet.text, SimColors.light.textIconMuted);
        expect(primary.text, SimColors.light.textInverse);
      },
    );
  });

  group('ladders and layout constants', () {
    test('z ladder keeps toast below modal and poppers above it', () {
      expect(SimZ.dropdown < SimZ.toast, isTrue);
      expect(SimZ.toast < SimZ.modal, isTrue);
      expect(SimZ.modal < SimZ.popover, isTrue);
      expect(SimZ.popover < SimZ.tooltip, isTrue);
      expect(SimZ.tooltip < SimZ.takeover, isTrue);
      expect(SimZ.takeover < SimZ.shellGate, isTrue);
    });

    test('modal widths and the chip modal rhythm', () {
      expect(simModalMaxWidth(SimModalSize.sm), 440);
      expect(simModalMaxWidth(SimModalSize.md), 500);
      expect(simModalMaxWidth(SimModalSize.lg), 600);
      expect(simModalMaxWidth(SimModalSize.xl), 800);
      expect(simModalMaxWidth(SimModalSize.full), 1200);
      expect(SimLayout.chipModalLabelGap, 9);
      expect(SimLayout.chipModalBodyPaddingBottom, 18);
      expect(SimLayout.modalMaxHeightFraction, 0.84);
    });

    test('motion scale zeroes every duration', () {
      SimMotion.scale = 0;
      expect(SimMotion.of(SimMotion.modal), Duration.zero);
      SimMotion.scale = 0.5;
      expect(
        SimMotion.of(const Duration(milliseconds: 400)),
        const Duration(milliseconds: 200),
      );
      SimMotion.scale = 1;
      expect(
        SimMotion.of(SimMotion.toastStack),
        const Duration(milliseconds: 400),
      );
    });
  });

  group('ported algorithms', () {
    SimToastData toast(
      String id, {
      Duration duration = const Duration(seconds: 5),
      SimToastAction? action,
    }) => SimToastData(
      id: id,
      message: id,
      variant: SimToastVariant.standard,
      duration: duration,
      persistAcrossRoutes: false,
      action: action,
    );

    test(
      'orderToastStack keeps ongoing status toasts behind actionable ones',
      () {
        final unlock = toast(
          'unlock',
          duration: Duration.zero,
          action: SimToastAction(label: 'Unlock', onPressed: () {}),
        );
        final reconnecting = toast('reconnecting', duration: Duration.zero);
        List<String> ids(List<SimToastData> t) =>
            orderToastStack(t).map((e) => e.id).toList();
        expect(ids(<SimToastData>[unlock, reconnecting]), <String>[
          'unlock',
          'reconnecting',
        ]);
        expect(ids(<SimToastData>[toast('saved'), reconnecting]), <String>[
          'saved',
          'reconnecting',
        ]);
        expect(
          ids(<SimToastData>[
            unlock,
            reconnecting,
            toast('saved'),
            toast('joining', duration: Duration.zero),
          ]),
          <String>['saved', 'unlock', 'joining', 'reconnecting'],
        );
      },
    );

    test(
      'collapsed stack lifts 13px and shrinks 5% per depth, clamped to the front height',
      () {
        final ordered = <SimToastData>[toast('a'), toast('b'), toast('c')];
        final heights = <String, double>{'a': 56, 'b': 80, 'c': 40};
        final collapsed = layoutToastStack(ordered, heights, expanded: false);
        expect(collapsed[1].y, -13);
        expect(collapsed[2].y, -26);
        expect(collapsed[1].scale, closeTo(0.95, 1e-9));
        expect(collapsed[1].height, 56);
        final expanded = layoutToastStack(ordered, heights, expanded: true);
        expect(expanded[1].y, -(56 + 8));
        expect(expanded[2].y, -(56 + 8 + 80 + 8));
        expect(expanded[1].height, 80);
      },
    );

    test('eviction drops the oldest timed toast, never a persistent one', () {
      final store = SimToasts();
      final persistent = store.show(
        'persist',
        action: SimToastAction(label: 'x', onPressed: () {}),
      );
      store
        ..show('one')
        ..show('two')
        ..show('three');
      expect(store.toasts.map((t) => t.id), contains(persistent));
      expect(store.toasts.length, 3);
      expect(store.toasts.any((t) => t.message == 'one'), isFalse);
    });

    test('tabDropIndex clamps across the pinned partition', () {
      const tabs = <SimTabStripItem>[
        SimTabStripItem(id: 'p', title: 'p', pinned: true),
        SimTabStripItem(id: 'a', title: 'a'),
        SimTabStripItem(id: 'b', title: 'b'),
      ];
      expect(tabDropIndex(tabs, 'a', 0), isNull);
      expect(tabDropIndex(tabs, 'a', 3), 2);
      expect(tabDropIndex(tabs, 'p', 3), isNull);
      expect(tabDropIndex(tabs, 'b', 1), 1);
    });

    test(
      'tooltip flips away from the right edge within 360px and clamps to the gutter',
      () {
        const host = Size(1000, 800);
        final left = resolveTooltipPosition(const Offset(100, 100), host);
        final right = resolveTooltipPosition(const Offset(700, 100), host);
        final bottom = resolveTooltipPosition(const Offset(100, 700), host);
        final edge = resolveTooltipPosition(const Offset(2, 2), host);
        expect(left.alignX, SimTooltipAlignX.left);
        expect(right.alignX, SimTooltipAlignX.right);
        expect(left.alignY, SimTooltipAlignY.below);
        expect(bottom.alignY, SimTooltipAlignY.above);
        expect(edge.x, 16);
        expect(edge.y, 16);
      },
    );

    test('chipSelectOptionMatchesSearch never leaks another option alias', () {
      const github = SimChipSelectOption(
        value: 'github',
        label: 'GitHub CLI',
        searchTerms: <String>['gh'],
      );
      expect(chipSelectOptionMatchesSearch(github, 'bq'), isFalse);
      expect(chipSelectOptionMatchesSearch(github, 'GH'), isTrue);
    });
  });
}
