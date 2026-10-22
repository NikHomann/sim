// Failure modes this golden guards (generated emcn icons):
// - the precompiled `.vec` ignores the requested colour (draws the compile
//   time black) instead of `--text-icon`, which disappears in dark mode;
// - glyphs blur, clip or shift because the picture is rasterised at the wrong
//   scale or a non-square viewBox stretches instead of centring;
// - filled glyphs (stop-filled, play) or text glyphs (pdf-icon) lose their
//   fill, and multi-stroke glyphs lose their per-path stroke widths;
// - the `strokeWidth` override, which falls back to the SVG source, renders
//   differently from the precompiled default beyond the thinner stroke.
import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

import 'golden_support.dart';

const List<SimIconData> _representative = <SimIconData>[
  SimEmcnIcons.arrowUpRight,
  SimEmcnIcons.asterisk,
  SimEmcnIcons.blimp,
  SimEmcnIcons.bookOpen,
  SimEmcnIcons.brainCircuit,
  SimEmcnIcons.bubbleChatPreview,
  SimEmcnIcons.calendar,
  SimEmcnIcons.chartColumn,
  SimEmcnIcons.chevronsUpDown,
  SimEmcnIcons.circleStop,
  SimEmcnIcons.clock,
  SimEmcnIcons.code,
  SimEmcnIcons.columns3,
  SimEmcnIcons.csvIcon,
  SimEmcnIcons.database,
  SimEmcnIcons.download,
  SimEmcnIcons.expand,
  SimEmcnIcons.file,
  SimEmcnIcons.folder,
  SimEmcnIcons.folderPlus,
  SimEmcnIcons.globe,
  SimEmcnIcons.hammer,
  SimEmcnIcons.hand,
  SimEmcnIcons.hexSimple,
  SimEmcnIcons.home,
  SimEmcnIcons.integration,
  SimEmcnIcons.key,
  SimEmcnIcons.library,
  SimEmcnIcons.linkedIn,
  SimEmcnIcons.lock,
  SimEmcnIcons.moreHorizontal,
  SimEmcnIcons.panelLeft,
  SimEmcnIcons.pdfIcon,
  SimEmcnIcons.pencil,
  SimEmcnIcons.play,
  SimEmcnIcons.redo,
  SimEmcnIcons.rocket,
  SimEmcnIcons.settings,
  SimEmcnIcons.stopFilled,
  SimEmcnIcons.table,
  SimEmcnIcons.trash,
  SimEmcnIcons.workflow,
  SimEmcnIcons.zoomIn,
];

Widget _grid(List<SimIconData> icons, {double size = 14, Color? color}) =>
    SizedBox(
      width: 300,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          for (final icon in icons) SimIcon(icon, size: size, color: color),
        ],
      ),
    );

void main() {
  themedGoldenTest(
    'emcn icons',
    fileName: 'emcn_icons',
    columns: 1,
    scenarios: ({required dark}) => <GoldenTestScenario>[
      GoldenTestScenario(
        name: '14px, --text-icon',
        child: _grid(_representative),
      ),
      GoldenTestScenario(
        name: '16px, explicit colour',
        child: _grid(
          _representative.take(12).toList(),
          size: 16,
          color: dark ? SimColors.dark.textBody : SimColors.light.textBody,
        ),
      ),
      GoldenTestScenario(
        name: 'strokeWidth 1.25 (SVG source) vs default',
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: <Widget>[
            SimIcon(SimEmcnIcons.workflow, size: 16),
            SimIcon(SimEmcnIcons.workflow, size: 16, strokeWidth: 1.25),
            SimIcon(SimEmcnIcons.folderPlus, size: 16),
            SimIcon(SimEmcnIcons.folderPlus, size: 16, strokeWidth: 1.25),
          ],
        ),
      ),
    ],
  );
}
