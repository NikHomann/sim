import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        AdaptiveTextSelectionToolbar,
        desktopTextSelectionControls,
        materialTextSelectionControls;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/widgets/fields/text_field_defaults.dart';

/// The text-entry core every emcn field composes: an [EditableText] with the
/// platform selection gestures and context menu, a placeholder, and no chrome
/// of its own — the field around it paints the surface. It never draws a
/// Material decoration, focus ring or ripple.
///
/// Caret and selection colours come from the Sim theme (`caret-color:
/// var(--text-primary)`, `::selection` `--selection-muted`).
class SimEditable extends StatefulWidget {
  const SimEditable({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.style,
    this.placeholderStyle,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.cursor = SystemMouseCursors.text,
    this.onKeyEvent,
    this.onFocusChanged,
    this.selectAllOnFocus = false,
    this.scrollPadding = const EdgeInsets.all(20),
    this.textCapitalization = TextCapitalization.none,
    this.semanticsLabel,
    this.contextMenuBuilder,
  });

  /// The context menu of this field; falls back to the nearest
  /// [SimTextFieldDefaults.contextMenuBuilder], then the platform toolbar.
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final TextStyle? style;
  final TextStyle? placeholderStyle;

  /// `1` for a single-line input, `null` for an unbounded textarea.
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final bool autofocus;
  final TextAlign textAlign;
  final MouseCursor cursor;

  /// Runs on the field's focus node before the editable handles the key.
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final ValueChanged<bool>? onFocusChanged;
  final bool selectAllOnFocus;
  final EdgeInsets scrollPadding;
  final TextCapitalization textCapitalization;
  final String? semanticsLabel;

  @override
  State<SimEditable> createState() => SimEditableState();
}

/// State of a [SimEditable]; exposes [focus] and [editableTextKey].
class SimEditableState extends State<SimEditable>
    implements TextSelectionGestureDetectorBuilderDelegate {
  TextEditingController? _ownedController;
  FocusNode? _ownedFocus;
  late final TextSelectionGestureDetectorBuilder _gestures;

  TextEditingController get controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());
  FocusNode get focusNode =>
      widget.focusNode ??
      (_ownedFocus ??= FocusNode(debugLabel: 'SimEditable'));

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  void initState() {
    super.initState();
    _gestures = TextSelectionGestureDetectorBuilder(delegate: this);
    focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(SimEditable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocus)?.removeListener(_onFocus);
      focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocus);
    _ownedController?.dispose();
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (focusNode.hasFocus && widget.selectAllOnFocus) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    }
    widget.onFocusChanged?.call(focusNode.hasFocus);
    if (mounted) setState(() {});
  }

  /// Focuses the field with the caret at the end (`focusFirstTextInputIn`).
  void focus({bool caretAtEnd = true}) {
    focusNode.requestFocus();
    if (caretAtEnd) {
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final style = widget.style ?? sim.text.sm.copyWith(color: c.textPrimary);
    final placeholderStyle =
        widget.placeholderStyle ?? style.copyWith(color: c.textMuted);
    final interactive = widget.enabled;
    final formatters = <TextInputFormatter>[
      ...?widget.inputFormatters,
      if (widget.maxLength != null)
        LengthLimitingTextInputFormatter(widget.maxLength),
    ];
    final platform = defaultTargetPlatform;
    final desktop =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
    final editable = EditableText(
      key: editableTextKey,
      controller: controller,
      focusNode: focusNode,
      style: style,
      cursorColor: c.textPrimary,
      backgroundCursorColor: c.textMuted,
      selectionColor: c.selectionMuted,
      cursorWidth: 1,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
      readOnly: widget.readOnly || !interactive,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      keyboardType:
          widget.keyboardType ??
          (widget.maxLines == 1 ? TextInputType.text : TextInputType.multiline),
      textInputAction: widget.textInputAction,
      inputFormatters: formatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
      textCapitalization: widget.textCapitalization,
      scrollPadding: widget.scrollPadding,
      rendererIgnoresPointer: true,
      selectionControls: desktop
          ? desktopTextSelectionControls
          : materialTextSelectionControls,
      contextMenuBuilder:
          widget.contextMenuBuilder ??
          SimTextFieldDefaults.maybeOf(context)?.contextMenuBuilder ??
          (context, state) => AdaptiveTextSelectionToolbar.editableText(
            editableTextState: state,
          ),
      mouseCursor: widget.cursor,
    );
    final showPlaceholder =
        widget.placeholder != null && widget.placeholder!.isNotEmpty;
    Widget body = Stack(
      alignment: widget.textAlign == TextAlign.center
          ? Alignment.center
          : AlignmentDirectional.centerStart,
      children: <Widget>[
        if (showPlaceholder)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? IgnorePointer(
                    child: ExcludeSemantics(
                      child: Text(
                        widget.placeholder!,
                        style: placeholderStyle,
                        maxLines: widget.maxLines,
                        overflow: widget.maxLines == 1
                            ? TextOverflow.clip
                            : TextOverflow.visible,
                        softWrap: widget.maxLines != 1,
                        textAlign: widget.textAlign,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        editable,
      ],
    );
    body = _gestures.buildGestureDetector(
      behavior: HitTestBehavior.translucent,
      child: body,
    );
    body = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: widget.onKeyEvent == null
          ? null
          : (node, event) => widget.onKeyEvent!(focusNode, event),
      child: body,
    );
    if (!interactive) {
      body = IgnorePointer(child: body);
    }
    // Only the label and the enabled state: [RenderEditable] reports the
    // text-field, focus and read-only flags itself. Repeating `textField` or
    // `readOnly` here makes the two configurations incompatible (shared
    // flags), so under a semantics container the field splits into an
    // enabled, unfocused text field wrapping the focused one without an
    // enabled state. The web engine renders that inner `<input>` disabled
    // and never moves DOM focus to it; a dialog route then parks DOM focus
    // on another node, and once that node goes away the view reports a
    // focus loss and the framework drops keyboard focus from the field.
    return Semantics(
      label: widget.semanticsLabel,
      enabled: interactive,
      child: MouseRegion(
        cursor: interactive ? widget.cursor : SystemMouseCursors.forbidden,
        child: body,
      ),
    );
  }
}
