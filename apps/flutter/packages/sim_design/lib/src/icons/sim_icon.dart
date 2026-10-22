import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:vector_graphics/vector_graphics_compat.dart';

/// Renders a bundled icon in the resolved colour.
///
/// Precompiled icons ([SimIconData.precompiled], the generated emcn set) draw
/// their `.vec` as a picture (crisp at any scale and DPR) tinted by a `srcIn`
/// colour filter, which equals `currentColor` for these single-colour
/// glyphs. Hand-ported icons, and any icon given a [strokeWidth], parse the
/// SVG with `currentColor` mapped through [SvgTheme].
///
/// Defaults match emcn: 14px, `--text-icon` (chips pass 16px). [strokeWidth]
/// overrides the icon's own `stroke-width` the way `[&_svg]:[stroke-width:1.25]`
/// does on `Button size='icon'`; [color] `null` reads the ambient [IconTheme]
/// colour when one was set, else `--text-icon`.
class SimIcon extends StatelessWidget {
  const SimIcon(
    this.icon, {
    super.key,
    this.size = SimLayout.iconSize,
    this.color,
    this.strokeWidth,
    this.semanticLabel,
  });

  final SimIconData icon;
  final double size;
  final Color? color;
  final double? strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ??
        IconTheme.of(context).color ??
        SimTheme.of(context).colors.textIcon;
    final vec = icon.vecAssetPath;
    // The box is always size x size, like `size-[14px]` on the web: glyphs
    // with a non-square viewBox (file icons, undo/redo) centre inside it.
    return SizedBox.square(
      dimension: size,
      child: vec != null && strokeWidth == null
          ? createCompatVectorGraphic(
              loader: AssetBytesLoader(vec, packageName: 'sim_design'),
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
              semanticsLabel: semanticLabel,
              excludeFromSemantics: semanticLabel == null,
              errorBuilder: _reportLoadError,
            )
          : SvgPicture(
              _SimSvgLoader(
                icon.assetPath,
                strokeWidth: strokeWidth,
                theme: SvgTheme(currentColor: resolved),
              ),
              width: size,
              height: size,
              semanticsLabel: semanticLabel,
              excludeFromSemantics: semanticLabel == null,
              errorBuilder: _reportLoadError,
            ),
    );
  }

  /// vector_graphics swallows load and decode errors (an empty box); surface
  /// them so a missing or undecodable asset fails loudly in debug and tests.
  Widget _reportLoadError(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'sim_design',
        context: ErrorDescription('while loading icon ${icon.name}'),
      ),
    );
    return const SizedBox.shrink();
  }
}

/// `Loader` with `animate`: the loader arcs spinning once per second
/// (`icons/animate/loader.module.css`), static when motion is off.
class SimSpinner extends StatefulWidget {
  const SimSpinner({
    super.key,
    this.size = SimLayout.iconSize,
    this.color,
    this.duration = SimMotion.loaderSpin,
  });

  final double size;
  final Color? color;
  final Duration duration;

  @override
  State<SimSpinner> createState() => _SimSpinnerState();
}

class _SimSpinnerState extends State<SimSpinner>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (!SimMotion.disabled) {
      _controller = AnimationController(
        vsync: this,
        duration: widget.duration,
      );
      unawaited(_controller!.repeat());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = SimIcon(
      SimIcons.loader,
      size: widget.size,
      color: widget.color,
    );
    final controller = _controller;
    if (controller == null) return icon;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Transform.rotate(
        angle: controller.value * 2 * math.pi,
        child: child,
      ),
      child: icon,
    );
  }
}

class _SimSvgLoader extends SvgAssetLoader {
  const _SimSvgLoader(super.assetName, {this.strokeWidth, super.theme})
    : super(packageName: 'sim_design');

  final double? strokeWidth;

  static final RegExp _rootTag = RegExp(r'<svg\b[^>]*>');
  static final RegExp _strokeWidth = RegExp('stroke-width="[^"]*"');

  /// Sets `stroke-width` on the root `<svg>` only, as the CSS
  /// `[&_svg]:[stroke-width:N]` does: children inherit it unless they carry
  /// their own `stroke-width` attribute.
  @override
  String provideSvg(ByteData? message) {
    final svg = super.provideSvg(message);
    if (strokeWidth == null) return svg;
    final root = _rootTag.firstMatch(svg);
    if (root == null) return svg;
    final tag = root.group(0)!;
    final patched = _strokeWidth.hasMatch(tag)
        ? tag.replaceFirst(_strokeWidth, 'stroke-width="$strokeWidth"')
        : tag.replaceFirst('<svg', '<svg stroke-width="$strokeWidth"');
    return svg.replaceRange(root.start, root.end, patched);
  }

  @override
  bool operator ==(Object other) =>
      other is _SimSvgLoader &&
      other.assetName == assetName &&
      other.packageName == packageName &&
      other.strokeWidth == strokeWidth &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(assetName, packageName, strokeWidth, theme);
}
