import 'package:flutter/painting.dart';

/// Shadow scale (`02-design-system.md` §1d, `globals.css` `--shadow-*`).
///
/// The theme-dependent entries (`overlay`, `ambient`) carry light and dark
/// values; everything else is identical in both themes.
class SimShadows {
  const SimShadows({required this.overlay, required this.ambient});

  static const SimShadows light = SimShadows(
    overlay: <BoxShadow>[
      BoxShadow(
        color: Color(0x1C000000),
        offset: Offset(0, 10),
        blurRadius: 30,
      ),
    ],
    ambient: <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 12)],
  );

  static const SimShadows dark = SimShadows(
    overlay: <BoxShadow>[
      BoxShadow(
        color: Color(0x4D000000),
        offset: Offset(0, 10),
        blurRadius: 30,
      ),
    ],
    ambient: <BoxShadow>[BoxShadow(color: Color(0x38000000), blurRadius: 12)],
  );

  /// `--shadow-overlay`: 0 10px 30px rgba(0,0,0,.11) (dark .3).
  final List<BoxShadow> overlay;

  /// `--shadow-ambient` (chat input): 0 0 12px 0 rgba(0,0,0,.08) (dark .22).
  final List<BoxShadow> ambient;

  /// `--shadow-subtle`: 0 2px 4px 0 rgba(0,0,0,.08).
  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), offset: Offset(0, 2), blurRadius: 4),
  ];

  /// `--shadow-medium` (menus): 0 4px 12px rgba(0,0,0,.1).
  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 12),
  ];

  /// `--shadow-kbd`: 0 4px 0 0 rgba(48,48,48,1).
  static const List<BoxShadow> kbd = <BoxShadow>[
    BoxShadow(color: Color(0xFF303030), offset: Offset(0, 4)),
  ];

  /// `--shadow-kbd-sm`: 0 2px 0 0 rgba(48,48,48,1).
  static const List<BoxShadow> kbdSm = <BoxShadow>[
    BoxShadow(color: Color(0xFF303030), offset: Offset(0, 2)),
  ];

  /// `--shadow-card`: 0 1px 3px rgba(0,0,0,.04).
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 3),
  ];

  /// Tailwind `shadow-xs`: 0 1px 2px 0 rgb(0 0 0 / 0.05) (tooltips, thumbs).
  static const List<BoxShadow> xs = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// Tailwind `shadow-md` (details panel).
  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];
}
