import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// `authLoadingSkeletonVariants` shapes (`auth-loading-skeleton.tsx:7-12`).
enum AuthSkeletonShape { title, label, control, divider }

/// One `--surface-active` pulsing block in the auth skeleton geometry:
/// title 38px r4, label 14px r4, control 44px r10, divider 1px r1.
class AuthLoadingSkeleton extends StatelessWidget {
  const AuthLoadingSkeleton({
    required this.shape,
    super.key,
    this.width,
    this.marginTop = 0,
  });

  final AuthSkeletonShape shape;

  /// Null stretches to the column width (`w-full`).
  final double? width;
  final double marginTop;

  @override
  Widget build(BuildContext context) {
    final (height, radius) = switch (shape) {
      AuthSkeletonShape.title => (38.0, 4.0),
      AuthSkeletonShape.label => (14.0, 4.0),
      AuthSkeletonShape.control => (44.0, 10.0),
      AuthSkeletonShape.divider => (1.0, 1.0),
    };
    return Padding(
      padding: EdgeInsets.only(top: marginTop),
      child: SimSkeleton(
        width: width ?? double.infinity,
        height: height,
        radius: radius,
      ),
    );
  }
}

/// `AuthLoadingFrame`: the skeleton column (`flex flex-col items-center`).
class AuthLoadingFrame extends StatelessWidget {
  const AuthLoadingFrame({
    required this.children,
    required this.identifier,
    super.key,
  });

  final List<Widget> children;
  final String identifier;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    identifier: identifier,
    child: Column(children: children),
  );
}

/// `AuthLoadingField`: a label block over a full-width control on an 8px gap.
class AuthLoadingField extends StatelessWidget {
  const AuthLoadingField({
    required this.labelWidth,
    super.key,
    this.marginTop = 0,
  });

  final double labelWidth;
  final double marginTop;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: marginTop),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: <Widget>[
        AuthLoadingSkeleton(shape: AuthSkeletonShape.label, width: labelWidth),
        const AuthLoadingSkeleton(shape: AuthSkeletonShape.control),
      ],
    ),
  );
}

/// `AuthLoadingAlternateActions`: the divider and the two side-by-side
/// controls (`gap-3`) standing in for the social buttons.
class AuthLoadingAlternateActions extends StatelessWidget {
  const AuthLoadingAlternateActions({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      AuthLoadingSkeleton(shape: AuthSkeletonShape.divider, marginTop: 24),
      Padding(
        padding: EdgeInsets.only(top: 24),
        child: Row(
          spacing: 12,
          children: <Widget>[
            Expanded(
              child: AuthLoadingSkeleton(shape: AuthSkeletonShape.control),
            ),
            Expanded(
              child: AuthLoadingSkeleton(shape: AuthSkeletonShape.control),
            ),
          ],
        ),
      ),
    ],
  );
}
