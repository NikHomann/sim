/// The z-index ladder (`globals.css` `--z-*`). Overlays are stacked by
/// `SimOverlayHost` in ascending order of these values, then insertion order.
abstract final class SimZ {
  static const int dropdown = 100;
  static const int toast = 150;
  static const int modal = 200;
  static const int popover = 300;
  static const int tooltip = 400;
  static const int takeover = 500;
  static const int shellGate = 600;
}
