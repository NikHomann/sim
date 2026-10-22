import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// `getUserColor(userId)` (`lib/workspaces/colors.ts:7-53`): the identity
/// palette indexed by the sum of `charCodeAt(0)` over the id's code points.
Color userColor(String userId, SimColors colors) {
  final palette = <Color>[
    colors.indicatorActive,
    const Color(0xFFF472B6), // --color-pink-400
    colors.brandSecondary,
    const Color(0xFFFB923C), // --color-orange-400
    const Color(0xFFC084FC), // --color-purple-400
    const Color(0xFFFCD34D), // --color-amber-300
  ];
  var hash = 0;
  for (final rune in userId.runes) {
    // `Array.from` walks code points; `charCodeAt(0)` reads the lead unit.
    hash += rune > 0xFFFF ? 0xD800 + ((rune - 0x10000) >> 10) : rune;
  }
  return palette[hash.abs() % palette.length];
}
