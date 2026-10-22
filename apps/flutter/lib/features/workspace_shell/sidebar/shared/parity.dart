import 'package:flutter/widgets.dart';

/// Tags [child] with its spec parity id (`Semantics(container: true, identifier:)`), the id
/// the parity capture reads from the `flt-semantics-identifier` DOM.
class Parity extends StatelessWidget {
  const Parity(this.id, {required this.child, super.key});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(identifier: id, container: true, child: child);
}
