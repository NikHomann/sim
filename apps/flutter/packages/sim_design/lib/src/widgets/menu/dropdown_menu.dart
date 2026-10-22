import 'dart:async';

import 'package:flutter/material.dart' show Scrollbar;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/keyboard.dart';
import 'package:sim_design/src/overlay/anchored.dart';
import 'package:sim_design/src/overlay/overlay_manager.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';
import 'package:sim_design/src/widgets/fields/editable.dart';
import 'package:sim_design/src/widgets/menu/menu_styles.dart';
import 'package:sim_design/src/widgets/overflow_text.dart';

/// One entry of a [SimDropdownMenu].
sealed class SimMenuEntry {
  const SimMenuEntry();
}

/// `DropdownMenuItem` (also the checkbox and radio items when [checked] /
/// [radio] are set, which add the `pl-7` indicator slot).
class SimMenuItem extends SimMenuEntry {
  const SimMenuItem({
    required this.label,
    this.onSelect,
    this.icon,
    this.leading,
    this.trailing,
    this.shortcut,
    this.enabled = true,
    this.active = false,
    this.inset = false,
    this.checked,
    this.radio,
    this.keepOpen = false,
    this.size = SimMenuRowSize.md,
    this.selected = false,
    this.action,
    this.actionOpen = false,
    this.semanticsLabel,
    this.semanticsIdentifier,
  });

  final String label;
  final VoidCallback? onSelect;

  /// Leading 14px icon in `--text-icon`.
  final SimIconData? icon;

  /// Pre-rendered leading element (an avatar); wins over [icon].
  final Widget? leading;

  /// Trailing content (e.g. a status dot).
  final Widget? trailing;

  /// `DropdownMenuShortcut`: ml-auto, `--text-muted`, caption, tabular.
  final String? shortcut;
  final bool enabled;

  /// Renders the row selected (`--surface-active`, held through hover).
  final bool active;
  final bool inset;

  /// Checkbox item: shows a check in the indicator slot when true.
  final bool? checked;

  /// Radio item: shows a 6px dot in the indicator slot when true.
  final bool? radio;

  /// Keeps the menu open after selection (multi-select toggles).
  final bool keepOpen;
  final SimMenuRowSize size;

  /// `role='menuitemradio'` style trailing check (`MENU_STYLES.selectionIcon`).
  final bool selected;

  /// Inline action on the right edge, revealed on hover/focus.
  final Widget? action;
  final bool actionOpen;
  final String? semanticsLabel;

  /// `Semantics.identifier` on the row (parity/test hook, e.g.
  /// `shell.menu.rename`); no visual effect.
  final String? semanticsIdentifier;
}

/// `DropdownMenuSeparator`.
class SimMenuSeparator extends SimMenuEntry {
  const SimMenuSeparator({this.semanticsIdentifier});

  /// `Semantics.identifier` on the rule (parity/test hook).
  final String? semanticsIdentifier;
}

/// `DropdownMenuLabel`.
class SimMenuLabel extends SimMenuEntry {
  const SimMenuLabel(this.text, {this.inset = false});

  final String text;
  final bool inset;
}

/// `DropdownMenuSub` + `SubTrigger` + `SubContent`.
class SimMenuSub extends SimMenuEntry {
  const SimMenuSub({
    required this.label,
    required this.entries,
    this.icon,
    this.enabled = true,
    this.inset = false,
    this.semanticsIdentifier,
    this.contentSemanticsIdentifier,
  });

  final String label;
  final List<SimMenuEntry> entries;
  final SimIconData? icon;
  final bool enabled;
  final bool inset;

  /// `Semantics.identifier` on the sub-trigger row.
  final String? semanticsIdentifier;

  /// `Semantics.identifier` on the submenu surface.
  final String? contentSemanticsIdentifier;
}

/// `DropdownMenuSearchInput`: the in-menu search box (autofocused).
class SimMenuSearch extends SimMenuEntry {
  const SimMenuSearch({
    this.placeholder = 'Search...',
    this.onChanged,
    this.controller,
  });

  final String placeholder;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
}

/// Arbitrary content inside the menu padding (e.g. a "No results" line).
class SimMenuCustom extends SimMenuEntry {
  const SimMenuCustom(this.child);

  final Widget child;
}

/// Handle to an open menu.
class SimMenuHandle {
  SimMenuHandle._(this._entry, this.closed);

  final SimOverlayEntry _entry;

  /// Completes once the menu has left the overlay.
  final Future<void> closed;

  bool get isOpen => _entry.isMounted;

  void close() => _entry.dismiss();

  /// Re-renders the menu with the current [SimDropdownMenu] entries builder.
  void rebuild() => _entry.markNeedsBuild();
}

/// Port of `packages/emcn/src/components/dropdown-menu/dropdown-menu.tsx`,
/// styled by `MENU_STYLES`: a floating surface of 28px rows with keyboard
/// navigation (arrows wrap, Home/End, Enter/Space select, Escape closes,
/// ArrowRight/ArrowLeft open and close submenus), hover highlight, submenus,
/// separators, headings, an optional search box, and a context-menu mode
/// that opens at a pointer position.
abstract final class SimDropdownMenu {
  /// Opens a menu anchored to [anchorContext]'s render box.
  static SimMenuHandle show(
    BuildContext anchorContext, {
    required List<SimMenuEntry> Function() entries,
    SimSide side = SimSide.bottom,
    SimAlign align = SimAlign.start,
    double sideOffset = SimMenuStyles.sideOffset,
    bool matchAnchorWidth = false,
    double? width,
    double minWidth = SimMenuStyles.minWidth,
    double? maxWidth = SimMenuStyles.maxWidth,
    double maxHeight = SimMenuStyles.maxHeight,
    bool avoidCollisions = true,
    bool modal = true,
    bool autofocus = true,
    VoidCallback? onClose,
    String? semanticsIdentifier,
  }) {
    final overlay = SimOverlay.of(anchorContext);
    return _open(
      overlay,
      anchor: overlay.rectOf(anchorContext),
      entries: entries,
      side: side,
      align: align,
      sideOffset: sideOffset,
      matchAnchorWidth: matchAnchorWidth,
      width: width,
      minWidth: minWidth,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      avoidCollisions: avoidCollisions,
      modal: modal,
      autofocus: autofocus,
      onClose: onClose,
      semanticsIdentifier: semanticsIdentifier,
    );
  }

  /// Opens a context menu at a global pointer position (`onContextMenu`).
  static SimMenuHandle showAt(
    BuildContext context,
    Offset globalPosition, {
    required List<SimMenuEntry> Function() entries,
    double minWidth = SimMenuStyles.minWidth,
    double? maxWidth = SimMenuStyles.maxWidth,
    double maxHeight = SimMenuStyles.maxHeight,
    bool modal = true,
    VoidCallback? onClose,
    String? semanticsIdentifier,
  }) {
    final overlay = SimOverlay.of(context);
    final local = overlay.globalToHost(globalPosition);
    return _open(
      overlay,
      anchor: Rect.fromLTWH(local.dx, local.dy, 0, 0),
      entries: entries,
      side: SimSide.bottom,
      align: SimAlign.start,
      sideOffset: 0,
      matchAnchorWidth: false,
      width: null,
      minWidth: minWidth,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      avoidCollisions: true,
      modal: modal,
      autofocus: true,
      onClose: onClose,
      semanticsIdentifier: semanticsIdentifier,
    );
  }

  static SimMenuHandle _open(
    SimOverlayController overlay, {
    required Rect anchor,
    required List<SimMenuEntry> Function() entries,
    required SimSide side,
    required SimAlign align,
    required double sideOffset,
    required bool matchAnchorWidth,
    required double? width,
    required double minWidth,
    required double? maxWidth,
    required double maxHeight,
    required bool avoidCollisions,
    required bool modal,
    required bool autofocus,
    required VoidCallback? onClose,
    required String? semanticsIdentifier,
  }) {
    final closed = Completer<void>();
    final animation = SimLayerAnimation();
    late final SimOverlayEntry entry;
    entry = SimOverlayEntry(
      modal: modal,
      onDismissRequested: () => animation.close(entry.remove),
      onRemoved: () {
        onClose?.call();
        if (!closed.isCompleted) closed.complete();
      },
      builder: (context) => _MenuLayer(
        animation: animation,
        anchor: anchor,
        side: side,
        align: align,
        sideOffset: sideOffset,
        matchAnchorWidth: matchAnchorWidth,
        width: width,
        minWidth: minWidth,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        avoidCollisions: avoidCollisions,
        modal: modal,
        contentKey: entry.contentKey,
        autofocus: autofocus,
        entries: entries,
        onRequestClose: entry.dismiss,
        parentEntry: entry,
        semanticsIdentifier: semanticsIdentifier,
      ),
    );
    overlay.insert(entry);
    return SimMenuHandle._(entry, closed.future);
  }
}

class _MenuLayer extends StatefulWidget {
  const _MenuLayer({
    required this.animation,
    required this.anchor,
    required this.side,
    required this.align,
    required this.sideOffset,
    required this.matchAnchorWidth,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.maxHeight,
    required this.avoidCollisions,
    required this.modal,
    required this.contentKey,
    required this.autofocus,
    required this.entries,
    required this.onRequestClose,
    required this.parentEntry,
    this.isSubmenu = false,
    this.onPointerInside,
    this.semanticsIdentifier,
  });

  final SimLayerAnimation animation;
  final Rect anchor;
  final SimSide side;
  final SimAlign align;
  final double sideOffset;
  final bool matchAnchorWidth;
  final double? width;
  final double minWidth;
  final double? maxWidth;
  final double maxHeight;
  final bool avoidCollisions;
  final bool modal;
  final GlobalKey contentKey;
  final bool autofocus;
  final List<SimMenuEntry> Function() entries;
  final VoidCallback onRequestClose;
  final SimOverlayEntry parentEntry;
  final bool isSubmenu;
  final ValueChanged<bool>? onPointerInside;
  final String? semanticsIdentifier;

  @override
  State<_MenuLayer> createState() => _MenuLayerState();
}

class _MenuLayerState extends State<_MenuLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SimMotion.of(SimMotion.popover),
    value: SimMotion.disabled ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    widget.animation.controller = _controller;
    if (!SimMotion.disabled) unawaited(_controller.forward());
  }

  @override
  void dispose() {
    if (widget.animation.controller == _controller) {
      widget.animation.controller = null;
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final surface = SimAnchoredOverlay(
      anchor: widget.anchor,
      side: widget.side,
      align: widget.align,
      sideOffset: widget.sideOffset,
      matchAnchorWidth: widget.matchAnchorWidth,
      minWidth: widget.width ?? widget.minWidth,
      maxWidth: widget.width ?? widget.maxWidth,
      maxHeight: widget.maxHeight,
      avoidCollisions: widget.avoidCollisions,
      animation: _controller,
      contentKey: widget.contentKey,
      child: MouseRegion(
        onEnter: (_) => widget.onPointerInside?.call(true),
        onExit: (_) => widget.onPointerInside?.call(false),
        child: SimMenuList(
          entries: widget.entries,
          autofocus: widget.autofocus,
          onRequestClose: widget.onRequestClose,
          parentEntry: widget.parentEntry,
          isSubmenu: widget.isSubmenu,
          decoration: SimMenuStyles.surface(c),
          semanticsIdentifier: widget.semanticsIdentifier,
        ),
      ),
    );
    if (!widget.modal) return surface;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const SimOverlayBarrier(color: Color(0x00000000)),
        surface,
      ],
    );
  }
}

/// The scrolling list of menu rows with keyboard navigation. Also usable
/// inline (inside a popover surface) by passing [decoration] `null`.
class SimMenuList extends StatefulWidget {
  const SimMenuList({
    required this.entries,
    super.key,
    this.autofocus = true,
    this.onRequestClose,
    this.parentEntry,
    this.isSubmenu = false,
    this.decoration,
    this.padding = SimMenuStyles.padding,
    this.semanticsIdentifier,
  });

  final List<SimMenuEntry> Function() entries;
  final bool autofocus;
  final VoidCallback? onRequestClose;
  final SimOverlayEntry? parentEntry;
  final bool isSubmenu;
  final BoxDecoration? decoration;
  final EdgeInsets padding;

  /// `Semantics.identifier` on the menu container node (the surface).
  final String? semanticsIdentifier;

  @override
  State<SimMenuList> createState() => SimMenuListState();
}

/// State of a [SimMenuList]; exposes [handleNavigationKey] so an embedded
/// search field can forward arrow and Enter keys.
class SimMenuListState extends State<SimMenuList> {
  final FocusNode _focus = FocusNode(debugLabel: 'SimMenuList');
  final ScrollController _scroll = ScrollController();
  int _highlight = -1;
  bool _keyboardNav = false;
  List<SimMenuEntry> _entries = const <SimMenuEntry>[];
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};
  SimMenuHandle? _openSub;
  int _openSubIndex = -1;
  bool _pointerInSub = false;
  Timer? _subCloseTimer;

  @override
  void initState() {
    super.initState();
    _entries = widget.entries();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasSearch) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(SimMenuList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entries = widget.entries();
  }

  @override
  void dispose() {
    _subCloseTimer?.cancel();
    _openSub?.close();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _hasSearch => _entries.any((e) => e is SimMenuSearch);

  bool _selectable(SimMenuEntry e) =>
      (e is SimMenuItem && e.enabled) || (e is SimMenuSub && e.enabled);

  List<int> get _selectableIndexes => <int>[
    for (var i = 0; i < _entries.length; i++)
      if (_selectable(_entries[i])) i,
  ];

  void _setHighlight(int index, {bool keyboard = false}) {
    if (_highlight == index && _keyboardNav == keyboard) return;
    setState(() {
      _highlight = index;
      _keyboardNav = keyboard;
    });
    if (keyboard) _reveal(index);
  }

  void _reveal(int index) {
    final ctx = _rowKeys[index]?.currentContext;
    if (ctx == null) return;
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
      ),
    );
  }

  void _move(int step) {
    final indexes = _selectableIndexes;
    if (indexes.isEmpty) return;
    final current = indexes.indexOf(_highlight);
    int next;
    if (current < 0) {
      next = step > 0 ? indexes.first : indexes.last;
    } else {
      next = indexes[(current + step + indexes.length) % indexes.length];
    }
    _setHighlight(next, keyboard: true);
  }

  void _activate(int index) {
    if (index < 0 || index >= _entries.length) return;
    final entry = _entries[index];
    if (entry is SimMenuSub) {
      _openSubmenu(index, entry, focusFirst: true);
      return;
    }
    if (entry is SimMenuItem && entry.enabled) {
      entry.onSelect?.call();
      if (entry.keepOpen) {
        setState(() => _entries = widget.entries());
      } else {
        widget.onRequestClose?.call();
      }
    }
  }

  /// Arrow keys, Home/End, Enter/Space, and submenu open/close.
  KeyEventResult handleNavigationKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.home) {
      final i = _selectableIndexes;
      if (i.isNotEmpty) _setHighlight(i.first, keyboard: true);
    } else if (key == LogicalKeyboardKey.end) {
      final i = _selectableIndexes;
      if (i.isNotEmpty) _setHighlight(i.last, keyboard: true);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final entry = _highlight >= 0 ? _entries[_highlight] : null;
      if (entry is SimMenuSub && entry.enabled) {
        _openSubmenu(_highlight, entry, focusFirst: true);
      } else {
        return KeyEventResult.ignored;
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (!widget.isSubmenu) return KeyEventResult.ignored;
      widget.onRequestClose?.call();
    } else if (event is KeyDownEvent && isKeyboardActivation(event)) {
      if (_highlight < 0) return KeyEventResult.ignored;
      _activate(_highlight);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _openSubmenu(int index, SimMenuSub sub, {required bool focusFirst}) {
    if (_openSubIndex == index && (_openSub?.isOpen ?? false)) return;
    _closeSubmenu();
    final rowCtx = _rowKeys[index]?.currentContext;
    final overlay = SimOverlay.maybeOf(context);
    if (rowCtx == null || overlay == null) return;
    final anchor = overlay.rectOf(rowCtx);
    final closed = Completer<void>();
    final animation = SimLayerAnimation();
    late final SimOverlayEntry entry;
    entry = SimOverlayEntry(
      parent: widget.parentEntry,
      dismissOnOutsideTap: false,
      onDismissRequested: () => animation.close(entry.remove),
      onRemoved: () {
        if (!closed.isCompleted) closed.complete();
        if (mounted && _openSubIndex == index) {
          setState(() {
            _openSubIndex = -1;
            _openSub = null;
          });
          if (!_hasSearch) _focus.requestFocus();
        }
      },
      builder: (context) => _MenuLayer(
        animation: animation,
        anchor: anchor,
        side: SimSide.right,
        align: SimAlign.start,
        sideOffset: 0,
        matchAnchorWidth: false,
        width: null,
        minWidth: SimMenuStyles.minWidth,
        maxWidth: SimMenuStyles.submenuMaxWidth,
        maxHeight: SimMenuStyles.maxHeight,
        avoidCollisions: true,
        modal: false,
        contentKey: entry.contentKey,
        autofocus: focusFirst,
        entries: () => sub.entries,
        onRequestClose: entry.dismiss,
        parentEntry: entry,
        isSubmenu: true,
        onPointerInside: (inside) => _pointerInSub = inside,
        semanticsIdentifier: sub.contentSemanticsIdentifier,
      ),
    );
    overlay.insert(entry);
    setState(() {
      _openSub = SimMenuHandle._(entry, closed.future);
      _openSubIndex = index;
      _highlight = index;
    });
  }

  void _closeSubmenu() {
    _subCloseTimer?.cancel();
    _openSub?.close();
    _openSub = null;
    _openSubIndex = -1;
  }

  void _onRowHover(int index) {
    _setHighlight(index);
    final entry = _entries[index];
    if (entry is SimMenuSub && entry.enabled) {
      _subCloseTimer?.cancel();
      _openSubmenu(index, entry, focusFirst: false);
    } else if (_openSub != null && index != _openSubIndex) {
      // Leave a grace period so a diagonal move into the submenu survives.
      _subCloseTimer?.cancel();
      _subCloseTimer = Timer(const Duration(milliseconds: 120), () {
        if (!_pointerInSub && mounted) {
          setState(_closeSubmenu);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final children = <Widget>[];
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      final key = _rowKeys.putIfAbsent(i, GlobalKey.new);
      switch (entry) {
        case SimMenuItem():
          children.add(
            SimMenuRow(
              key: key,
              label: entry.label,
              icon: entry.icon,
              leading: entry.leading,
              trailing: entry.trailing,
              shortcut: entry.shortcut,
              enabled: entry.enabled,
              active: entry.active,
              highlighted: _highlight == i,
              inset: entry.inset,
              checked: entry.checked,
              radio: entry.radio,
              selected: entry.selected,
              size: entry.size,
              action: entry.action,
              actionOpen: entry.actionOpen,
              semanticsLabel: entry.semanticsLabel,
              semanticsIdentifier: entry.semanticsIdentifier,
              onHover: () => _onRowHover(i),
              onPressed: () => _activate(i),
            ),
          );
        case SimMenuSub():
          children.add(
            SimMenuRow(
              key: key,
              label: entry.label,
              icon: entry.icon,
              enabled: entry.enabled,
              inset: entry.inset,
              highlighted: _highlight == i,
              active: _openSubIndex == i,
              submenu: true,
              semanticsIdentifier: entry.semanticsIdentifier,
              onHover: () => _onRowHover(i),
              onPressed: () => _activate(i),
            ),
          );
        case SimMenuSeparator(:final semanticsIdentifier):
          children.add(
            semanticsIdentifier == null
                ? SimMenuSeparatorLine(key: key)
                : Semantics(
                    key: key,
                    identifier: semanticsIdentifier,
                    container: true,
                    child: const SimMenuSeparatorLine(),
                  ),
          );
        case SimMenuLabel():
          children.add(
            SimMenuHeading(entry.text, key: key, inset: entry.inset),
          );
        case SimMenuSearch():
          children.add(
            SimMenuSearchField(
              key: key,
              placeholder: entry.placeholder,
              controller: entry.controller,
              onChanged: (v) {
                entry.onChanged?.call(v);
                setState(() {
                  _entries = widget.entries();
                  _highlight = -1;
                });
              },
              onNavigationKey: handleNavigationKey,
            ),
          );
        case SimMenuCustom():
          children.add(KeyedSubtree(key: key, child: entry.child));
      }
    }
    final body = Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) => handleNavigationKey(event),
      child: MouseRegion(
        onExit: (_) {
          if (!_keyboardNav && _openSub == null) _setHighlight(-1);
        },
        child: Semantics(
          container: true,
          scopesRoute: false,
          identifier: widget.semanticsIdentifier,
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: widget.padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.decoration == null) return body;
    return DecoratedBox(
      decoration: widget.decoration ?? SimMenuStyles.surface(c),
      child: DefaultTextStyle.merge(
        style: sim.text.small.copyWith(color: c.textBody),
        child: body,
      ),
    );
  }
}

/// `dropdownMenuRowClass`: the canonical menu row.
class SimMenuRow extends StatelessWidget {
  const SimMenuRow({
    required this.label,
    super.key,
    this.icon,
    this.leading,
    this.trailing,
    this.shortcut,
    this.enabled = true,
    this.active = false,
    this.highlighted = false,
    this.inset = false,
    this.checked,
    this.radio,
    this.selected = false,
    this.submenu = false,
    this.size = SimMenuRowSize.md,
    this.action,
    this.actionOpen = false,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.onHover,
    this.onPressed,
    this.textColor,
    this.iconColor,
    this.highlightColor,
  });

  final String label;
  final SimIconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final String? shortcut;
  final bool enabled;
  final bool active;
  final bool highlighted;
  final bool inset;
  final bool? checked;
  final bool? radio;
  final bool selected;
  final bool submenu;
  final SimMenuRowSize size;
  final Widget? action;
  final bool actionOpen;
  final String? semanticsLabel;

  /// `Semantics.identifier` on the row node; no visual effect.
  final String? semanticsIdentifier;
  final VoidCallback? onHover;
  final VoidCallback? onPressed;
  final Color? textColor;
  final Color? iconColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final indicator = checked != null || radio != null;
    final leftPad = inset || indicator
        ? SimMenuStyles.insetPadding
        : SimMenuStyles.rowPaddingX;
    final fill = active
        ? c.surfaceActive
        : highlighted
        ? (highlightColor ?? c.surfaceHover)
        : const Color(0x00000000);
    final text = textColor ?? c.textBody;
    final iconTint = iconColor ?? c.textIcon;
    final style = SimMenuStyles.rowStyle(sim, size).copyWith(color: text);
    final showAction = action != null && (actionOpen || highlighted);
    final row = Container(
      height: SimMenuStyles.rowHeight(size),
      padding: EdgeInsets.only(
        left: leftPad,
        right: action != null && showAction ? 28 : SimMenuStyles.rowPaddingX,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(SimMenuStyles.rowRadius),
      ),
      child: Row(
        spacing: SimMenuStyles.rowGap,
        children: <Widget>[
          if (leading != null)
            leading!
          else if (icon != null)
            SimIcon(icon!, color: iconTint),
          Expanded(
            child: SimOverflowText(label: label, style: style),
          ),
          ?trailing,
          if (shortcut != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                shortcut!,
                style: sim.text.caption.copyWith(
                  color: c.textMuted,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          if (selected) SimIcon(SimIcons.check, color: iconTint),
          if (submenu) SimIcon(SimIcons.chevronRight, color: iconTint),
        ],
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: active || selected || (checked ?? false) || (radio ?? false),
        label: semanticsLabel ?? label,
        // A tagged row is its own node so the identifier is never merged
        // into (or overwritten by) a tagged surface around a lone row.
        container: semanticsIdentifier != null,
        identifier: semanticsIdentifier,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: enabled ? (_) => onHover?.call() : null,
          onHover: enabled && !highlighted ? (_) => onHover?.call() : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: Stack(
              children: <Widget>[
                row,
                if (indicator)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: 14,
                      child: Center(
                        child: (checked ?? false)
                            ? SimIcon(SimIcons.check, color: text)
                            : (radio ?? false)
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: text,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                if (action != null && showAction)
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(child: action),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `DropdownMenuItemAction`: the compact 18px icon button in a row's action
/// slot. Taps stop at the button so they do not select the row.
class SimMenuItemAction extends StatelessWidget {
  const SimMenuItemAction({
    required this.icon,
    required this.onPressed,
    super.key,
    this.semanticsLabel,
  });

  final SimIconData icon;
  final VoidCallback onPressed;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: 18,
        height: 18,
        child: Center(
          child: SimIcon(
            icon,
            size: 16,
            color: SimTheme.of(context).colors.textIcon,
          ),
        ),
      ),
    ),
  );
}

/// `DropdownMenuSearchInput`: the chip field surface at 28px with a leading
/// search glyph in `--text-muted`; autofocused, arrow keys forwarded.
class SimMenuSearchField extends StatefulWidget {
  const SimMenuSearchField({
    super.key,
    this.placeholder = 'Search...',
    this.controller,
    this.onChanged,
    this.onNavigationKey,
    this.autofocus = true,
    this.inverted = false,
  });

  final String placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final KeyEventResult Function(KeyEvent event)? onNavigationKey;
  final bool autofocus;
  final bool inverted;

  @override
  State<SimMenuSearchField> createState() => _SimMenuSearchFieldState();
}

class _SimMenuSearchFieldState extends State<SimMenuSearchField> {
  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final textStyle = sim.text.small.copyWith(
      color: widget.inverted && !sim.isDark ? SimColors.white : c.textBody,
    );
    final muted = widget.inverted && !sim.isDark
        ? c.textMutedInverse
        : c.textMuted;
    return Container(
      height: SimMenuStyles.searchHeight,
      margin: SimMenuStyles.searchMargin,
      padding: const EdgeInsets.symmetric(
        horizontal: SimMenuStyles.rowPaddingX,
      ),
      decoration: widget.inverted
          ? BoxDecoration(
              border: Border.all(color: c.borderInverted),
              borderRadius: BorderRadius.circular(SimMenuStyles.rowRadius),
            )
          : SimChipChrome.fieldSurface(c),
      child: Row(
        spacing: SimMenuStyles.rowGap,
        children: <Widget>[
          SimIcon(SimIcons.search, color: muted),
          Expanded(
            child: SimEditable(
              controller: widget.controller,
              placeholder: widget.placeholder,
              style: textStyle,
              placeholderStyle: textStyle.copyWith(color: muted),
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onKeyEvent: (node, event) {
                final key = event.logicalKey;
                final navigation =
                    key == LogicalKeyboardKey.arrowDown ||
                    key == LogicalKeyboardKey.arrowUp ||
                    key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter;
                if (!navigation || widget.onNavigationKey == null) {
                  return KeyEventResult.ignored;
                }
                return widget.onNavigationKey!(event);
              },
            ),
          ),
        ],
      ),
    );
  }
}
