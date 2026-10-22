import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The hero's three pieces.
enum HeroSlot { heading, composer, suggested }

/// The empty-state cluster (`home.tsx:436-468`): heading (`mb-7`,
/// `max-w-chat`) over the composer host (`w-full max-w-chat`), centred in a
/// `min-h-full` column padded `pt-[2vh] pb-[22vh] px-6`, with the suggested
/// actions hanging below the composer out of flow (`md:absolute
/// md:inset-x-0 md:top-full`), so expanding them never moves the input.
///
/// Its height is the larger of [minHeight], the padded cluster and the
/// suggested section's bottom (an absolute child still extends the
/// scroller's overflow).
class HeroClusterLayout
    extends SlottedMultiChildRenderObjectWidget<HeroSlot, RenderBox> {
  const HeroClusterLayout({
    required this.heading,
    required this.composer,
    required this.suggested,
    required this.minHeight,
    required this.paddingTop,
    required this.paddingBottom,
    super.key,
    this.paddingX = 24,
    this.maxWidth = 704,
    this.headingGap = 28,
  });

  final Widget heading;
  final Widget composer;
  final Widget suggested;
  final double minHeight;
  final double paddingTop;
  final double paddingBottom;
  final double paddingX;
  final double maxWidth;
  final double headingGap;

  @override
  Iterable<HeroSlot> get slots => HeroSlot.values;

  @override
  Widget? childForSlot(HeroSlot slot) => switch (slot) {
    HeroSlot.heading => heading,
    HeroSlot.composer => composer,
    HeroSlot.suggested => suggested,
  };

  @override
  RenderHeroCluster createRenderObject(BuildContext context) =>
      RenderHeroCluster()
        ..minHeight = minHeight
        ..paddingTop = paddingTop
        ..paddingBottom = paddingBottom
        ..paddingX = paddingX
        ..maxWidth = maxWidth
        ..headingGap = headingGap;

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHeroCluster renderObject,
  ) => renderObject
    ..minHeight = minHeight
    ..paddingTop = paddingTop
    ..paddingBottom = paddingBottom
    ..paddingX = paddingX
    ..maxWidth = maxWidth
    ..headingGap = headingGap;
}

class RenderHeroCluster extends RenderBox
    with SlottedContainerRenderObjectMixin<HeroSlot, RenderBox> {
  double _minHeight = 0;
  double _paddingTop = 0;
  double _paddingBottom = 0;
  double _paddingX = 24;
  double _maxWidth = 704;
  double _headingGap = 28;

  double get minHeight => _minHeight;
  set minHeight(double v) => _set(_minHeight, v, (x) => _minHeight = x);
  double get paddingTop => _paddingTop;
  set paddingTop(double v) => _set(_paddingTop, v, (x) => _paddingTop = x);
  double get paddingBottom => _paddingBottom;
  set paddingBottom(double v) =>
      _set(_paddingBottom, v, (x) => _paddingBottom = x);
  double get paddingX => _paddingX;
  set paddingX(double v) => _set(_paddingX, v, (x) => _paddingX = x);
  double get maxWidth => _maxWidth;
  set maxWidth(double v) => _set(_maxWidth, v, (x) => _maxWidth = x);
  double get headingGap => _headingGap;
  set headingGap(double v) => _set(_headingGap, v, (x) => _headingGap = x);

  void _set(double current, double next, void Function(double) assign) {
    if (current == next) return;
    assign(next);
    markNeedsLayout();
  }

  RenderBox? get _heading => childForSlot(HeroSlot.heading);
  RenderBox? get _composer => childForSlot(HeroSlot.composer);
  RenderBox? get _suggested => childForSlot(HeroSlot.suggested);

  @override
  Iterable<RenderBox> get children => <RenderBox>[
    ?_heading,
    ?_composer,
    ?_suggested,
  ];

  static BoxParentData _data(RenderBox box) => box.parentData! as BoxParentData;

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final inner = math.max(0, width - 2 * _paddingX).toDouble();
    final column = math.min(_maxWidth, inner);
    final heading = _heading;
    final composer = _composer;
    final suggested = _suggested;
    heading?.layout(BoxConstraints(maxWidth: column), parentUsesSize: true);
    composer?.layout(
      BoxConstraints.tightFor(width: column),
      parentUsesSize: true,
    );
    suggested?.layout(
      BoxConstraints.tightFor(width: column),
      parentUsesSize: true,
    );
    final headingH = heading?.size.height ?? 0;
    final composerH = composer?.size.height ?? 0;
    final cluster = headingH + _headingGap + composerH;
    final padded = _paddingTop + cluster + _paddingBottom;
    var height = math.max(_minHeight, padded);
    final content = height - _paddingTop - _paddingBottom;
    final top = _paddingTop + (content - cluster) / 2;
    final left = _paddingX + (inner - column) / 2;
    if (heading != null) {
      _data(heading).offset = Offset(
        _paddingX + (inner - heading.size.width) / 2,
        top,
      );
    }
    final composerTop = top + headingH + _headingGap;
    if (composer != null) _data(composer).offset = Offset(left, composerTop);
    if (suggested != null) {
      final suggestedTop = composerTop + composerH;
      _data(suggested).offset = Offset(left, suggestedTop);
      height = math.max(height, suggestedTop + suggested.size.height);
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // The suggested section paints first: an open composer menu must
    // stay above it.
    for (final child in <RenderBox?>[_heading, _suggested, _composer]) {
      if (child != null) {
        context.paintChild(child, offset + _data(child).offset);
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in <RenderBox?>[_composer, _suggested, _heading]) {
      if (child == null) continue;
      final hit = result.addWithPaintOffset(
        offset: _data(child).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _maxWidth + 2 * _paddingX;

  @override
  double computeMinIntrinsicHeight(double width) => _minHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _minHeight;
}
