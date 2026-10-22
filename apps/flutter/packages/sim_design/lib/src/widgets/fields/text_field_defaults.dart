import 'package:flutter/widgets.dart';

/// App-wide defaults for every [EditableText]-based field below it
/// (`SimEditable` and the chip fields built on it). The app supplies its
/// text-field context menu here (e.g. a paste that runs through its paste
/// admission guard) without each field passing it.
class SimTextFieldDefaults extends InheritedWidget {
  const SimTextFieldDefaults({
    required super.child,
    super.key,
    this.contextMenuBuilder,
  });

  /// The selection toolbar / context menu; `null` keeps the platform's
  /// adaptive toolbar.
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  static SimTextFieldDefaults? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SimTextFieldDefaults>();

  @override
  bool updateShouldNotify(SimTextFieldDefaults oldWidget) =>
      contextMenuBuilder != oldWidget.contextMenuBuilder;
}
