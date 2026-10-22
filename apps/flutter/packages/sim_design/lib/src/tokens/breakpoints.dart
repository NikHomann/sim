/// Tailwind breakpoints pinned in px (`globals.css` `--breakpoint-*`).
abstract final class SimBreakpoints {
  static const double sm = 640;

  /// The mobile/desktop split.
  static const double md = 768;
  static const double lg = 1024;
  static const double xl = 1280;
  static const double xxl = 1536;

  /// Home/chat reading column (`--container-chat: 44rem`).
  static const double chatColumn = 704;

  static bool isMobile(double width) => width < md;
}
