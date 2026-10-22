import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/keyboard.dart';
import 'package:sim_design/src/overlay/anchored.dart';
import 'package:sim_design/src/overlay/overlay_manager.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/widgets/menu/dropdown_menu.dart';
import 'package:sim_design/src/widgets/menu/menu_styles.dart';
import 'package:sim_design/src/widgets/tooltip.dart';

/// `size` of a popover: `sm` 12px rows (24px), `md` 13px rows (28px).
enum SimPopoverSize { sm, md }

/// `colorScheme`: the page surface, or the inverted (dark-on-light) one.
enum SimPopoverColorScheme { standard, inverted }

/// `appearance`: the menu surface, or the tooltip surface (`p-1.5`).
enum SimPopoverAppearance { standard, tooltip }

/// Handle to an open popover.
class SimPopoverHandle {
  SimPopoverHandle._(this._entry, this.closed);

  final SimOverlayEntry _entry;
  final Future<void> closed;

  bool get isOpen => _entry.isMounted;
  void close() => _entry.dismiss();
  void rebuild() => _entry.markNeedsBuild();
}

/// Scope read by the popover content widgets (size, colour scheme, keyboard
/// selection, folder navigation).
class SimPopoverScope extends InheritedNotifier<SimPopoverController> {
  const SimPopoverScope({
    required SimPopoverController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static SimPopoverController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SimPopoverScope>()?.notifier;

  static SimPopoverController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'Popover widgets must be used within a popover');
    return controller!;
  }
}

/// Navigation and selection state of one popover (`PopoverContext`).
class SimPopoverController extends ChangeNotifier {
  SimPopoverController({
    this.size = SimPopoverSize.md,
    this.colorScheme = SimPopoverColorScheme.standard,
    this.onRequestClose,
  });

  final SimPopoverSize size;
  final SimPopoverColorScheme colorScheme;
  final VoidCallback? onRequestClose;

  final List<_ItemRegistration> _items = <_ItemRegistration>[];
  int _selectedIndex = -1;
  bool _keyboardNav = false;
  String? _folder;
  String? _folderTitle;
  VoidCallback? _folderSelect;
  String _search = '';

  int get selectedIndex => _selectedIndex;
  bool get isKeyboardNav => _keyboardNav;
  String? get currentFolder => _folder;
  bool get isInFolder => _folder != null;
  String? get folderTitle => _folderTitle;
  VoidCallback? get onFolderSelect => _folderSelect;
  String get searchQuery => _search;
  int get itemCount => _items.length;

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();
  }

  void openFolder(
    String id,
    String title, {
    FutureOr<void> Function()? onLoad,
    VoidCallback? onSelect,
  }) {
    _folder = id;
    _folderTitle = title;
    _folderSelect = onSelect;
    _selectedIndex = -1;
    notifyListeners();
    if (onLoad != null) unawaited(Future<void>.sync(onLoad));
  }

  void closeFolder() {
    _folder = null;
    _folderTitle = null;
    _folderSelect = null;
    _selectedIndex = -1;
    notifyListeners();
  }

  // ignore: avoid_positional_boolean_parameters, mirrors the upstream setter
  void setKeyboardNav(bool value) {
    if (_keyboardNav == value) return;
    _keyboardNav = value;
    notifyListeners();
  }

  void setSelectedIndex(int index) {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }

  int _register(_ItemRegistration item) {
    final existing = _items.indexOf(item);
    if (existing >= 0) return existing;
    _items.add(item);
    return _items.length - 1;
  }

  void _unregister(_ItemRegistration item) {
    _items.remove(item);
  }

  int _indexOf(_ItemRegistration item) => _items.indexOf(item);

  KeyEventResult handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final enabled = <int>[
      for (var i = 0; i < _items.length; i++)
        if (_items[i].enabled()) i,
    ];
    if (enabled.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      final pos = enabled.indexOf(_selectedIndex);
      final next = pos < 0
          ? (step > 0 ? enabled.first : enabled.last)
          : enabled[(pos + step + enabled.length) % enabled.length];
      _keyboardNav = true;
      _selectedIndex = next;
      notifyListeners();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && isKeyboardActivation(event)) {
      if (_selectedIndex >= 0 && _selectedIndex < _items.length) {
        _items[_selectedIndex].activate();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}

class _ItemRegistration {
  _ItemRegistration({required this.enabled, required this.activate});

  final bool Function() enabled;
  final VoidCallback activate;
}

/// Port of `packages/emcn/src/components/popover/popover.tsx`: a floating
/// surface (`MENU_STYLES.surface` + `p-1`) with collision-aware placement
/// (14px side offset, 20px above; 8px collision padding; 400px max height;
/// 160px/140px min width), size and colour-scheme variants, an optional
/// arrow, keyboard navigation over [SimPopoverItem]s, inline folder
/// navigation ([SimPopoverFolder] + [SimPopoverBackButton]) and a search box.
abstract final class SimPopover {
  static SimPopoverHandle show(
    BuildContext anchorContext, {
    required WidgetBuilder builder,
    SimSide side = SimSide.bottom,
    SimAlign align = SimAlign.start,
    double? sideOffset,
    double collisionPadding = SimLayout.popoverCollisionPadding,
    bool avoidCollisions = true,
    double? maxHeight,
    double? maxWidth,
    double? minWidth,
    bool matchAnchorWidth = false,
    SimPopoverSize size = SimPopoverSize.md,
    SimPopoverColorScheme colorScheme = SimPopoverColorScheme.standard,
    SimPopoverAppearance appearance = SimPopoverAppearance.standard,
    bool border = true,
    bool showArrow = false,
    bool modal = false,
    bool dismissOnOutsideTap = true,
    Rect? anchorRect,
    VoidCallback? onClose,
    String? semanticsIdentifier,
  }) {
    final overlay = SimOverlay.of(anchorContext);
    final anchor = anchorRect ?? overlay.rectOf(anchorContext);
    final closed = Completer<void>();
    final controller = SimPopoverController(
      size: size,
      colorScheme: colorScheme,
    );
    late final SimOverlayEntry entry;
    final animation = SimLayerAnimation();
    entry = SimOverlayEntry(
      modal: modal,
      dismissOnOutsideTap: dismissOnOutsideTap,
      onDismissRequested: () => animation.close(entry.remove),
      onRemoved: () {
        controller.dispose();
        onClose?.call();
        if (!closed.isCompleted) closed.complete();
      },
      builder: (context) => _PopoverLayer(
        controller: controller,
        animation: animation,
        anchor: anchor,
        side: side,
        align: align,
        sideOffset: sideOffset ?? (side == SimSide.top ? 20 : 14),
        collisionPadding: collisionPadding,
        avoidCollisions: avoidCollisions,
        maxHeight: maxHeight ?? SimLayout.popoverMaxHeight,
        maxWidth: maxWidth,
        minWidth:
            minWidth ??
            (maxWidth != null
                ? null
                : size == SimPopoverSize.sm
                ? SimLayout.popoverMinWidthSm
                : SimLayout.popoverMinWidth),
        matchAnchorWidth: matchAnchorWidth,
        appearance: appearance,
        border: border,
        showArrow: showArrow,
        modal: modal,
        contentKey: entry.contentKey,
        onRequestClose: entry.dismiss,
        builder: builder,
        semanticsIdentifier: semanticsIdentifier,
      ),
    );
    overlay.insert(entry);
    return SimPopoverHandle._(entry, closed.future);
  }
}

class _PopoverLayer extends StatefulWidget {
  const _PopoverLayer({
    required this.controller,
    required this.animation,
    required this.anchor,
    required this.side,
    required this.align,
    required this.sideOffset,
    required this.collisionPadding,
    required this.avoidCollisions,
    required this.maxHeight,
    required this.maxWidth,
    required this.minWidth,
    required this.matchAnchorWidth,
    required this.appearance,
    required this.border,
    required this.showArrow,
    required this.modal,
    required this.contentKey,
    required this.onRequestClose,
    required this.builder,
    this.semanticsIdentifier,
  });

  final SimPopoverController controller;
  final SimLayerAnimation animation;
  final Rect anchor;
  final SimSide side;
  final SimAlign align;
  final double sideOffset;
  final double collisionPadding;
  final bool avoidCollisions;
  final double maxHeight;
  final double? maxWidth;
  final double? minWidth;
  final bool matchAnchorWidth;
  final SimPopoverAppearance appearance;
  final bool border;
  final bool showArrow;
  final bool modal;
  final GlobalKey contentKey;
  final VoidCallback onRequestClose;
  final WidgetBuilder builder;
  final String? semanticsIdentifier;

  @override
  State<_PopoverLayer> createState() => _PopoverLayerState();
}

class _PopoverLayerState extends State<_PopoverLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SimMotion.of(SimMotion.popover),
    value: SimMotion.disabled ? 1 : 0,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'SimPopover');

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
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final inverted =
        widget.controller.colorScheme == SimPopoverColorScheme.inverted;
    final tooltipLike = widget.appearance == SimPopoverAppearance.tooltip;
    var decoration = inverted
        ? SimMenuStyles.invertedSurface(c)
        : SimMenuStyles.surface(c);
    if (!widget.border && !tooltipLike) {
      decoration = decoration.copyWith(
        border: Border.all(color: const Color(0x00000000)),
      );
    }
    final textColor = inverted && !sim.isDark ? SimColors.white : c.textBody;
    Widget content = SimPopoverScope(
      controller: widget.controller,
      child: Builder(builder: widget.builder),
    );
    content = Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, event) => widget.controller.handleKey(event),
      child: MouseRegion(
        onHover: (_) => widget.controller.setKeyboardNav(false),
        child: DefaultTextStyle.merge(
          style: sim.text.small.copyWith(color: textColor),
          child: content,
        ),
      ),
    );
    var surface = tooltipLike
        ? SimTooltipSurface(padding: const EdgeInsets.all(6), child: content)
        : DecoratedBox(
            decoration: decoration,
            child: Padding(padding: SimMenuStyles.padding, child: content),
          );
    if (widget.semanticsIdentifier != null) {
      surface = Semantics(
        container: true,
        identifier: widget.semanticsIdentifier,
        child: surface,
      );
    }
    if (widget.showArrow) {
      surface = _ArrowedSurface(
        side: widget.side,
        fill: inverted ? c.surfaceInverted : c.bg,
        stroke: inverted ? c.borderInverted : c.border,
        child: surface,
      );
    }
    final anchored = SimAnchoredOverlay(
      anchor: widget.anchor,
      side: widget.side,
      align: widget.align,
      sideOffset: widget.sideOffset,
      collisionPadding: widget.collisionPadding,
      avoidCollisions: widget.avoidCollisions,
      maxHeight: widget.maxHeight,
      maxWidth:
          widget.maxWidth ?? (tooltipLike ? SimLayout.tooltipMaxWidth : null),
      minWidth: widget.minWidth,
      matchAnchorWidth: widget.matchAnchorWidth,
      animation: _controller,
      contentKey: widget.contentKey,
      child: surface,
    );
    if (!widget.modal) return anchored;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const SimOverlayBarrier(color: Color(0x00000000)),
        anchored,
      ],
    );
  }
}

/// The 14x7 arrow toward the anchor.
class _ArrowedSurface extends StatelessWidget {
  const _ArrowedSurface({
    required this.side,
    required this.fill,
    required this.stroke,
    required this.child,
  });

  final SimSide side;
  final Color fill;
  final Color stroke;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final arrow = CustomPaint(
      size: const Size(14, 7),
      painter: _ArrowPainter(fill: fill, stroke: stroke, side: side),
    );
    return switch (side) {
      SimSide.bottom => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          arrow,
          Flexible(child: child),
        ],
      ),
      SimSide.top => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(child: child),
          arrow,
        ],
      ),
      SimSide.right => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          arrow,
          Flexible(child: child),
        ],
      ),
      SimSide.left => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(child: child),
          arrow,
        ],
      ),
    };
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({
    required this.fill,
    required this.stroke,
    required this.side,
  });

  final Color fill;
  final Color stroke;
  final SimSide side;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    switch (side) {
      case SimSide.bottom:
        path
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height);
      case SimSide.top:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0);
      case SimSide.right:
        path
          ..moveTo(size.width, 0)
          ..lineTo(0, size.height / 2)
          ..lineTo(size.width, size.height);
      case SimSide.left:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height);
    }
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      stroke != oldDelegate.stroke ||
      side != oldDelegate.side;
}

/// `PopoverItem`: a menu row with hover/active states, keyboard selection via
/// the popover scope, and an optional trailing check.
class SimPopoverItem extends StatefulWidget {
  const SimPopoverItem({
    required this.label,
    super.key,
    this.onPressed,
    this.icon,
    this.leading,
    this.trailing,
    this.active,
    this.enabled = true,
    this.showCheck = false,
    this.rootOnly = false,
    this.closeOnSelect = true,
    this.semanticsIdentifier,
  });

  final String label;
  final VoidCallback? onPressed;
  final SimIconData? icon;
  final Widget? leading;
  final Widget? trailing;

  /// Explicit highlight; otherwise the scope's keyboard/hover selection.
  final bool? active;
  final bool enabled;
  final bool showCheck;

  /// Hidden while inside a folder.
  final bool rootOnly;
  final bool closeOnSelect;

  /// `Semantics.identifier` on the row node; no visual effect.
  final String? semanticsIdentifier;

  @override
  State<SimPopoverItem> createState() => _SimPopoverItemState();
}

class _SimPopoverItemState extends State<SimPopoverItem> {
  late final _ItemRegistration _registration = _ItemRegistration(
    enabled: () => widget.enabled,
    activate: _activate,
  );
  SimPopoverController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = SimPopoverScope.maybeOf(context);
    if (next != _controller) {
      _controller?._unregister(_registration);
      _controller = next;
      _controller?._register(_registration);
    }
  }

  @override
  void dispose() {
    _controller?._unregister(_registration);
    super.dispose();
  }

  void _activate() {
    if (!widget.enabled) return;
    widget.onPressed?.call();
    if (widget.closeOnSelect) _controller?.onRequestClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final sim = SimTheme.of(context);
    final c = sim.colors;
    if (widget.rootOnly && (controller?.isInFolder ?? false)) {
      return const SizedBox.shrink();
    }
    final index = controller?._indexOf(_registration) ?? -1;
    final active =
        widget.active ?? (index >= 0 && controller?.selectedIndex == index);
    final inverted = controller?.colorScheme == SimPopoverColorScheme.inverted;
    final size = controller?.size == SimPopoverSize.sm
        ? SimMenuRowSize.sm
        : SimMenuRowSize.md;
    final invertedText = inverted && !sim.isDark ? SimColors.white : null;
    return SimMenuRow(
      label: widget.label,
      icon: widget.icon,
      leading: widget.leading,
      trailing: widget.trailing,
      enabled: widget.enabled,
      active: active,
      selected: widget.showCheck,
      size: size,
      textColor: invertedText,
      iconColor: invertedText,
      highlightColor: inverted ? c.surfaceInvertedHover : null,
      semanticsIdentifier: widget.semanticsIdentifier,
      onHover: () {
        if (controller != null && !controller.isKeyboardNav && index >= 0) {
          controller.setSelectedIndex(index);
        }
      },
      onPressed: _activate,
    );
  }
}

/// `PopoverSection`: a heading for a group of items (mt-1.5 except first).
class SimPopoverSection extends StatelessWidget {
  const SimPopoverSection(
    this.text, {
    super.key,
    this.rootOnly = false,
    this.first = false,
  });

  final String text;
  final bool rootOnly;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final controller = SimPopoverScope.maybeOf(context);
    if (rootOnly && (controller?.isInFolder ?? false)) {
      return const SizedBox.shrink();
    }
    final sim = SimTheme.of(context);
    final inverted = controller?.colorScheme == SimPopoverColorScheme.inverted;
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 6),
      child: SimMenuHeading(
        text,
        color: inverted && !sim.isDark ? sim.colors.textMutedInverse : null,
      ),
    );
  }
}

/// `PopoverDivider`.
class SimPopoverDivider extends StatelessWidget {
  const SimPopoverDivider({super.key, this.rootOnly = false});

  final bool rootOnly;

  @override
  Widget build(BuildContext context) {
    final controller = SimPopoverScope.maybeOf(context);
    if (rootOnly && (controller?.isInFolder ?? false)) {
      return const SizedBox.shrink();
    }
    final c = SimTheme.of(context).colors;
    return SimMenuSeparatorLine(
      color: controller?.colorScheme == SimPopoverColorScheme.inverted
          ? c.borderInverted
          : null,
    );
  }
}

/// `PopoverSearch`.
class SimPopoverSearch extends StatelessWidget {
  const SimPopoverSearch({
    super.key,
    this.placeholder = 'Search...',
    this.onChanged,
  });

  final String placeholder;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = SimPopoverScope.maybeOf(context);
    return SimMenuSearchField(
      placeholder: placeholder,
      inverted: controller?.colorScheme == SimPopoverColorScheme.inverted,
      onChanged: (v) {
        controller?.setSearch(v);
        onChanged?.call(v);
      },
      onNavigationKey: controller?.handleKey,
    );
  }
}

/// `PopoverFolder` (click mode): a row that replaces the popover content with
/// [children] and a back button.
class SimPopoverFolder extends StatelessWidget {
  const SimPopoverFolder({
    required this.id,
    required this.title,
    required this.children,
    super.key,
    this.icon,
    this.onOpen,
    this.onSelect,
    this.active,
    this.semanticsIdentifier,
  });

  final String id;
  final String title;
  final List<Widget> children;
  final SimIconData? icon;
  final FutureOr<void> Function()? onOpen;
  final VoidCallback? onSelect;
  final bool? active;

  /// `Semantics.identifier` on the folder row.
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final controller = SimPopoverScope.of(context);
    if (controller.isInFolder && controller.currentFolder != id) {
      return const SizedBox.shrink();
    }
    if (controller.currentFolder == id) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return SimPopoverItem(
      label: title,
      icon: icon,
      active: active,
      closeOnSelect: false,
      semanticsIdentifier: semanticsIdentifier,
      trailing: SimIcon(
        SimIcons.chevronRight,
        size: controller.size == SimPopoverSize.sm ? 12 : 14,
        color: SimTheme.of(context).colors.textIcon,
      ),
      onPressed: () =>
          controller.openFolder(id, title, onLoad: onOpen, onSelect: onSelect),
    );
  }
}

/// `PopoverBackButton`: shown inside folders; closes the folder.
class SimPopoverBackButton extends StatelessWidget {
  const SimPopoverBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SimPopoverScope.of(context);
    if (!controller.isInFolder) return const SizedBox.shrink();
    final title = controller.folderTitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SimPopoverItem(
          label: 'Back',
          icon: SimIcons.chevronLeft,
          closeOnSelect: false,
          onPressed: controller.closeFolder,
        ),
        if (title != null && controller.onFolderSelect != null)
          SimPopoverItem(
            label: title,
            closeOnSelect: false,
            onPressed: controller.onFolderSelect,
          )
        else if (title != null)
          SimPopoverSection(title),
      ],
    );
  }
}
