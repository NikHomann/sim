import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sim_app/features/auth/shared/brand_icons.dart';
import 'package:sim_design/sim_design.dart';

/// `auth-shell.tsx` geometry.
abstract final class AuthShellMetrics {
  static const double columnWidth = 400;
  static const double logoHeight = 30;
  static const double headerPaddingY = 16;
  static const double headerMaxWidth = 1446;
  static const double columnPaddingX = 16;
  static const double columnPaddingBottom = 64;

  /// `px-12` at ≥ lg, `px-8` below, `px-5` below sm.
  static double headerGutter(double width) =>
      width >= SimBreakpoints.lg ? 48 : (width >= SimBreakpoints.sm ? 32 : 20);
}

/// Pins the light token layer and the document text defaults every auth and
/// status page wears (`.light`, `bg --bg`, `--text-primary`, 16px body,
/// 0.28px tracking) regardless of the visitor's theme.
class AuthLightTheme extends StatelessWidget {
  const AuthLightTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = simLightTheme(text: SimTextStyles.document);
    final sim = theme.extension<SimTheme>()!;
    return Theme(
      data: theme,
      child: DefaultTextStyle(
        style: sim.text.md.copyWith(color: sim.colors.textPrimary),
        child: ColoredBox(color: sim.colors.bg, child: child),
      ),
    );
  }
}

/// The logo-only header link (`<a href='/' aria-label='Sim home'>` with
/// `LogoMark` + `SimWordmark`): 30px tall, the wordmark 37×18 lifted 1.5px,
/// scaling to 1.08 on hover over 150ms. The hover easter egg's loader is not
/// reproduced.
class AuthLogoLink extends StatelessWidget {
  const AuthLogoLink({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    identifier: 'auth.shell.logo',
    child: SimPressable(
      onPressed: onPressed,
      isLink: true,
      semanticsLabel: 'Sim home',
      builder: (context, state) => SizedBox(
        height: AuthShellMetrics.logoHeight,
        // `widthFactor: 1` keeps the link at the wordmark's 37px instead of
        // stretching across the header row.
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: AnimatedScale(
            scale: state.hovered ? 1.08 : 1,
            duration: SimMotion.of(const Duration(milliseconds: 150)),
            curve: const Cubic(0.23, 1, 0.32, 1),
            child: Transform.translate(
              offset: const Offset(0, -1.5),
              child: const SimWordmark(),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Port of `app/(auth)/components/auth-shell.tsx`: the light page frame with
/// the logo header, the centred 400px column (`px-4 pb-16`) and an optional
/// footer in normal flow after the centred area.
class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.child,
    required this.onHome,
    super.key,
    this.footer,
  });

  final Widget child;

  /// `href='/'`: a document navigation to the site root.
  final VoidCallback onHome;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => AuthLightTheme(
    child: Semantics(
      container: true,
      identifier: 'auth.shell',
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    container: true,
                    identifier: 'auth.shell.header',
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AuthShellMetrics.headerPaddingY,
                        horizontal: AuthShellMetrics.headerGutter(
                          constraints.maxWidth,
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AuthShellMetrics.headerMaxWidth,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AuthLogoLink(onPressed: onHome),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      container: true,
                      identifier: 'auth.shell.column',
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: AuthShellMetrics.columnPaddingX,
                          right: AuthShellMetrics.columnPaddingX,
                          bottom: AuthShellMetrics.columnPaddingBottom,
                        ),
                        child: Center(
                          child: _IntrinsicWidthLimit(
                            maxWidth: AuthShellMetrics.columnWidth,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: AuthShellMetrics.columnWidth,
                              ),
                              // Shrink-wrap so the page column centres
                              // instead of stretching to the free height.
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[child],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ?footer,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Port of `LogoPage` + `LogoShell center` (`status-page.tsx:49-78`): the
/// status-page frame (header `py-4` at the 1728px content width, main centred
/// `px-4 pb-16`) holding a 410px card.
class LogoShell extends StatelessWidget {
  const LogoShell({required this.child, required this.onHome, super.key});

  final Widget child;
  final VoidCallback onHome;

  /// `PAGE_GUTTER`: px-10 at ≥ xl, 36 below, 32 below lg, 28 below md.
  static double gutter(double width) {
    if (width >= SimBreakpoints.xl) return 40;
    if (width >= SimBreakpoints.lg) return 36;
    if (width >= SimBreakpoints.md) return 32;
    return 28;
  }

  @override
  Widget build(BuildContext context) => AuthLightTheme(
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: gutter(constraints.maxWidth),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1728),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AuthLogoLink(onPressed: onHome),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 64,
                    ),
                    child: Center(
                      child: _IntrinsicWidthLimit(maxWidth: 410, child: child),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Measures intrinsic heights at no more than [maxWidth]: the shell's
/// `IntrinsicHeight` otherwise asks the centred column how tall it is at the
/// full viewport width, where its text wraps less than it will at 400px.
class _IntrinsicWidthLimit extends SingleChildRenderObjectWidget {
  const _IntrinsicWidthLimit({required this.maxWidth, required super.child});

  final double maxWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderIntrinsicWidthLimit(maxWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderIntrinsicWidthLimit renderObject,
  ) {
    renderObject.maxWidth = maxWidth;
  }
}

class _RenderIntrinsicWidthLimit extends RenderProxyBox {
  _RenderIntrinsicWidthLimit(this._maxWidth);

  double _maxWidth;

  double get maxWidth => _maxWidth;

  set maxWidth(double value) {
    if (_maxWidth == value) return;
    _maxWidth = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(math.min(width, _maxWidth));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(math.min(width, _maxWidth));
}

/// `StatusPageContent` / `DesktopHandoffShell` card: 410px max, centred,
/// 12px gap, 40px / 110% / −0.02em title and an 18px description in
/// `--text-muted` (handoff) or `--text-body` (status page).
class StatusCard extends StatelessWidget {
  const StatusCard({
    required this.title,
    required this.description,
    required this.identifier,
    super.key,
    this.mutedDescription = true,
    this.actions,
  });

  final String title;
  final String description;
  final String identifier;
  final bool mutedDescription;

  /// Rendered in the `mt-3` action row (gap 8, centred, wrapping).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Semantics(
      container: true,
      identifier: identifier,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: <Widget>[
            Semantics(
              container: true,
              identifier: '$identifier.title',
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: sim.text
                    .style(40, height: 1.1)
                    .copyWith(color: c.textPrimary, letterSpacing: -0.02 * 40),
              ),
            ),
            Semantics(
              container: true,
              identifier: '$identifier.description',
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: sim.text.lg.copyWith(
                  color: mutedDescription ? c.textMuted : c.textBody,
                ),
              ),
            ),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
