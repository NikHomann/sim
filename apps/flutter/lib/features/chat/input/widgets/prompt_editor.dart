import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        AdaptiveTextSelectionToolbar,
        desktopTextSelectionHandleControls,
        materialTextSelectionHandleControls;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/input/composer_controller.dart';
import 'package:sim_app/features/chat/input/model/composer_resources.dart';
import 'package:sim_app/features/chat/input/widgets/caret_menus.dart';
import 'package:sim_design/sim_design.dart';

/// `PROMPT_TEXT_CLASSES`: `font-body` (the system UI stack, not Inter),
/// 14px on a fine pointer, leading 24px, tracking -0.015em.
TextStyle composerTextStyle(Color color) {
  const size = 14.0;
  return TextStyle(
    fontFamily: kIsWeb ? 'ui-sans-serif' : 'Segoe UI',
    fontFamilyFallback: const [
      '-apple-system',
      'system-ui',
      'Segoe UI',
      'Helvetica',
      'Apple Color Emoji',
      'Arial',
      'sans-serif',
      'Segoe UI Emoji',
      'Segoe UI Symbol',
    ],
    fontSize: size,
    height: 24 / size,
    letterSpacing: -0.015 * size,
    leadingDistribution: TextLeadingDistribution.even,
    color: color,
  );
}

/// The editor's height rules (`SCROLLER_CLASSES`, `max-h-[200px]`, hero
/// `min-h-[56px]`, plain-text mode 240px).
abstract final class PromptEditorMetrics {
  static const double maxHeight = 200;
  static const double plainTextMaxHeight = 240;
  static const double heroMinHeight = 56;
  static const double fieldPadding = 4;
  static const double lineHeight = 24;
}

/// What the caret menus show.
@immutable
class PromptEditorMenus {
  const PromptEditorMenus({
    this.groups = const [],
    this.hydrating = false,
    this.skills = const [],
    this.mcpServers = const [],
  });

  final List<ComposerResourceGroup> groups;
  final bool hydrating;
  final List<ComposerSkill> skills;
  final List<ComposerMcpServer> mcpServers;
}

/// The rendered face of [ComposerController] (`PromptEditor`): a native
/// [EditableText] whose span tree paints the chips, inside a scroller that
/// grows with the content up to the cap and hides its scrollbar, plus the
/// caret-anchored `@` and `/` menus, which never take focus.
class PromptEditor extends StatefulWidget {
  const PromptEditor({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.menus,
    required this.onResourcePicked,
    super.key,
    this.minHeight = 0,
    this.onFirstFocus,
    this.onPasteFromToolbar,
  });

  final ComposerController controller;
  final FocusNode focusNode;
  final ValueListenable<String> placeholder;
  final PromptEditorMenus menus;
  final double minHeight;

  /// A resource picked from the `@` list (inserted by the editor; the host
  /// is told through [ComposerController.onContextAdd]).
  final ValueChanged<ComposerResource> onResourcePicked;

  /// Latched once: starts the inventory lists on first focus.
  final VoidCallback? onFirstFocus;

  /// The selection toolbar's Paste (reads the clipboard through the
  /// composer's paste rules).
  final Future<void> Function()? onPasteFromToolbar;

  @override
  State<PromptEditor> createState() => PromptEditorState();
}

class PromptEditorState extends State<PromptEditor>
    implements TextSelectionGestureDetectorBuilderDelegate {
  final GlobalKey<EditableTextState> _editableKey =
      GlobalKey<EditableTextState>();
  final GlobalKey _targetKey = GlobalKey();
  final LayerLink _link = LayerLink();
  final OverlayPortalController _mentionPortal = OverlayPortalController();
  final OverlayPortalController _skillsPortal = OverlayPortalController();
  final ScrollController _scroll = ScrollController();
  late final TextSelectionGestureDetectorBuilder _gestures =
      TextSelectionGestureDetectorBuilder(delegate: this);
  bool _focused = false;

  @override
  GlobalKey<EditableTextState> get editableTextKey => _editableKey;

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  /// The live field state (caret rects, toolbar).
  EditableTextState? get editableText => _editableKey.currentState;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.focusNode
      ..addListener(_onFocusChanged)
      ..onKeyEvent = _onKey;
    _onControllerChanged();
  }

  @override
  void didUpdateWidget(PromptEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      _releaseKeyHandler(oldWidget.focusNode);
      widget.focusNode
        ..addListener(_onFocusChanged)
        ..onKeyEvent = _onKey;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _releaseKeyHandler(widget.focusNode);
    _scroll.dispose();
    super.dispose();
  }

  /// Clears [node]'s key handler when it is still ours (a host-owned node
  /// outlives this state; a handler someone else installed stays).
  void _releaseKeyHandler(FocusNode node) {
    // Tear-offs of the same method on the same instance compare equal.
    if (node.onKeyEvent == _onKey) node.onKeyEvent = null;
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus && !_focused) {
      _focused = true;
      widget.onFirstFocus?.call();
    }
  }

  void _onControllerChanged() {
    final mention = widget.controller.mentionQuery != null;
    final slash = widget.controller.slashQuery != null;
    void apply() {
      if (!mounted) return;
      if (mention != _mentionPortal.isShowing) {
        mention ? _mentionPortal.show() : _mentionPortal.hide();
      }
      if (slash != _skillsPortal.isShowing) {
        slash ? _skillsPortal.show() : _skillsPortal.hide();
      }
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  /// The caret rect at text offset [offset], for anchoring a menu.
  CaretMenuPlacement? placementAt(int offset) {
    final editable = _editableKey.currentState;
    final target = _targetKey.currentContext?.findRenderObject();
    if (editable == null || target is! RenderBox || !target.attached) {
      return null;
    }
    final render = editable.renderEditable;
    if (!render.hasSize) return null;
    final rect = render.getLocalRectForCaret(TextPosition(offset: offset));
    final global = render.localToGlobal(rect.topLeft);
    return CaretMenuPlacement(
      caretLocal: target.globalToLocal(global),
      caretGlobal: global,
      lineHeight: PromptEditorMetrics.lineHeight,
    );
  }

  /// Focuses the field with the caret at the end (`focusAtEnd`).
  void focusAtEnd() {
    widget.focusNode.requestFocus();
    final length = widget.controller.text.length;
    widget.controller.selection = TextSelection.collapsed(offset: length);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    return widget.controller.handleKey(ComposerKey.fromEvent(event));
  }

  Widget _contextMenu(BuildContext context, EditableTextState state) {
    final paste = widget.onPasteFromToolbar;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        for (final item in state.contextMenuButtonItems)
          if (item.type == ContextMenuButtonType.paste && paste != null)
            item.copyWith(
              onPressed: () {
                state.hideToolbar();
                unawaited(paste());
              },
            )
          else
            item,
      ],
    );
  }

  Widget _mentionOverlay(BuildContext context) {
    final query = widget.controller.mentionQuery;
    if (query == null) return const SizedBox.shrink();
    final placement = placementAt(query.start);
    if (placement == null) return const SizedBox.shrink();
    return CaretMenuFrame(
      link: _link,
      placement: placement,
      width: resourceMenuWidth,
      maxHeight: mentionMenuMaxHeight,
      semanticsIdentifier: 'chat-input.plus-menu',
      child: MentionMenu(
        controller: widget.controller,
        query: query.query,
        groups: [
          for (final group in widget.menus.groups)
            if (group.items.isNotEmpty) group,
        ],
        hydrating: widget.menus.hydrating,
        onSelect: widget.onResourcePicked,
      ),
    );
  }

  Widget _skillsOverlay(BuildContext context) {
    final query = widget.controller.slashQuery;
    if (query == null) return const SizedBox.shrink();
    final placement = placementAt(query.start);
    if (placement == null) return const SizedBox.shrink();
    return CaretMenuFrame(
      link: _link,
      placement: placement,
      width: skillsMenuMaxWidth,
      maxHeight: SimMenuStyles.maxHeight,
      fixedWidth: false,
      semanticsIdentifier: 'chat-input.skills-menu',
      child: SkillsMenu(
        controller: widget.controller,
        query: query.query,
        skills: widget.menus.skills,
        mcpServers: widget.menus.mcpServers,
        onSkill: widget.controller.insertSkill,
        onMcp: widget.controller.insertMcpServer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final style = composerTextStyle(c.textPrimary);
    final plain = widget.controller.plainTextMode;
    final field = EditableText(
      key: _editableKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: style,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      cursorColor: c.textPrimary,
      backgroundCursorColor: c.textMuted,
      selectionColor: c.selectionMuted,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      inputFormatters: [ComposerEditFormatter(widget.controller)],
      rendererIgnoresPointer: true,
      enableInteractiveSelection: true,
      selectionControls: switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.fuchsia => materialTextSelectionHandleControls,
        _ => desktopTextSelectionHandleControls,
      },
      contextMenuBuilder: _contextMenu,
      onTapOutside: (_) {
        widget.controller
          ..dismissMentionMenu()
          ..dismissSkillsMenu();
      },
      cursorWidth: 1,
    );
    final fieldBox = Semantics(
      container: true,
      identifier: 'chat-input.textarea',
      child: Padding(
        padding: const EdgeInsets.all(PromptEditorMetrics.fieldPadding),
        child: CompositedTransformTarget(
          link: _link,
          child: KeyedSubtree(
            key: _targetKey,
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: _gestures.buildGestureDetector(
                behavior: HitTestBehavior.translucent,
                child: field,
              ),
            ),
          ),
        ),
      ),
    );
    final placeholder = ValueListenableBuilder<String>(
      valueListenable: widget.placeholder,
      builder: (context, text, _) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => widget.controller.text.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(PromptEditorMetrics.fieldPadding),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: style.copyWith(color: c.textMuted),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
    final editor = Stack(
      children: [
        fieldBox,
        Positioned.fill(
          child: IgnorePointer(
            child: Semantics(
              container: true,
              identifier: 'chat-input.overlay',
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(child: IgnorePointer(child: placeholder)),
      ],
    );
    return OverlayPortal(
      controller: _mentionPortal,
      overlayChildBuilder: _mentionOverlay,
      child: OverlayPortal(
        controller: _skillsPortal,
        overlayChildBuilder: _skillsOverlay,
        child: Semantics(
          container: true,
          identifier: 'chat-input.editor',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (!widget.focusNode.hasFocus) widget.focusNode.requestFocus();
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.minHeight,
                maxHeight: plain
                    ? PromptEditorMetrics.plainTextMaxHeight
                    : PromptEditorMetrics.maxHeight,
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: editor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
