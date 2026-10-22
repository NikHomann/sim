import 'package:flutter/animation.dart';

/// Durations and curves (`02-design-system.md` §1f, `globals.css` keyframes,
/// per-component literals in `packages/emcn`).
///
/// [scale] multiplies every duration returned by [of]; the app sets it to `0`
/// under `--dart-define=SIM_E2E=true` and when the platform reports reduced
/// motion (upstream: `prefers-reduced-motion` collapses everything to 0.01ms).
abstract final class SimMotion {
  /// Global multiplier applied by [of]. `1` by default, `0` disables motion.
  static double scale = 1;

  /// Returns [duration] scaled by [scale]; `Duration.zero` when motion is off.
  static Duration of(Duration duration) {
    if (scale <= 0) return Duration.zero;
    if (scale == 1) return duration;
    return Duration(microseconds: (duration.inMicroseconds * scale).round());
  }

  static bool get disabled => scale <= 0;

  // Keyframe animations
  static const Duration caretBlink = Duration(milliseconds: 1250);
  static const Duration ringPulse = Duration(milliseconds: 1500);
  static const Duration streamFadeIn = Duration(milliseconds: 300);
  static const Duration slideInBottom = Duration(milliseconds: 400);
  static const Duration collapsible = Duration(milliseconds: 300);
  static const Duration runningHatchScroll = Duration(milliseconds: 900);
  static const double runningHatchPeriodPx = 26;

  /// Tailwind `animate-pulse` period.
  static const Duration pulse = Duration(milliseconds: 2000);

  // Component transitions
  static const Duration popover = Duration(milliseconds: 150);
  static const Duration modal = Duration(milliseconds: 200);
  static const Duration tooltip = Duration(milliseconds: 150);
  static const Duration sidebarChevron = Duration(milliseconds: 150);
  static const Duration colors = Duration(milliseconds: 150);
  static const Duration menuRow = Duration.zero;
  static const Duration toastStack = Duration(milliseconds: 400);
  static const Duration toastResize = Duration(milliseconds: 300);
  static const Duration toastExit = Duration(milliseconds: 150);
  static const Duration toastStackExit = Duration(milliseconds: 200);
  static const Duration tab = Duration(milliseconds: 100);
  static const Duration tabReveal = Duration(milliseconds: 200);
  static const Duration detailsPanel = Duration(milliseconds: 200);
  static const Duration modalTabIndicator = Duration(milliseconds: 200);
  static const Duration copiedReset = Duration(milliseconds: 2000);
  static const Duration sidebarPeekOpen = Duration(milliseconds: 90);
  static const Duration sidebarPeekClose = Duration(milliseconds: 180);
  static const Duration loaderSpin = Duration(milliseconds: 1000);

  // Curves
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;

  /// `cubic-bezier(.16,1,.3,1)` (slide-in-bottom).
  static const Curve expoOut = Cubic(0.16, 1, 0.3, 1);

  /// `cubic-bezier(.4,0,.2,1)` (collapsible).
  static const Curve standard = Cubic(0.4, 0, 0.2, 1);

  /// Toast stack easing `[0.22, 1, 0.36, 1]`.
  static const Curve toast = Cubic(0.22, 1, 0.36, 1);

  /// Toast reveal blur-in `[0.2, 0, 0, 1]`; also the tab-strip ease.
  static const Curve tabEase = Cubic(0.2, 0, 0, 1);

  /// Tailwind `animate-pulse` timing `cubic-bezier(.4,0,.6,1)`.
  static const Curve pulseCurve = Cubic(0.4, 0, 0.6, 1);

  /// Popover/modal `zoom-in-95` start scale.
  static const double zoomStart = 0.95;

  /// Popover slide-in distance from the trigger side (`slide-in-from-*-2`).
  static const double popoverSlidePx = 8;
}
