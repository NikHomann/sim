import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/input/composer_controller.dart';
import 'package:sim_app/features/chat/input/model/composer_resources.dart';
import 'package:sim_app/features/chat/input/widgets/context_mention_icon.dart';
import 'package:sim_design/sim_design.dart';

/// The `@` list's height cap (`max-h-[min(280px, available)]`).
const double mentionMenuMaxHeight = 280;

/// The `+` / `@` menu width (`w-[360px] max-w-[min(360px,100vw-16px)]`).
const double resourceMenuWidth = 360;

/// The skills menu's width cap (`max-w-[min(300px,100vw-32px)]`).
const double skillsMenuMaxWidth = 300;

/// One row of the `@` list.
typedef MentionCandidate = ComposerResource;

/// The family icon of a resource row (`renderDropdownItem`).
Widget resourceRowIcon(ComposerResource item, Color color) {
  final icon = switch (item.type) {
    ComposerResourceType.workflow => SimEmcnIcons.workflow,
    ComposerResourceType.table => SimEmcnIcons.table,
    ComposerResourceType.dashboard => SimEmcnIcons.dashboard,
    ComposerResourceType.test => SimEmcnIcons.shieldCheck,
    ComposerResourceType.file => documentIcon('', item.name),
    ComposerResourceType.knowledgebase => SimEmcnIcons.database,
    ComposerResourceType.folder ||
    ComposerResourceType.filefolder => SimEmcnIcons.folder,
    ComposerResourceType.task => SimEmcnIcons.task,
    ComposerResourceType.log => SimEmcnIcons.library,
    ComposerResourceType.integration => SimEmcnIcons.integration,
    ComposerResourceType.browser => SimEmcnIcons.globe,
    ComposerResourceType.terminal => SimEmcnIcons.terminalWindow,
    ComposerResourceType.generic => SimEmcnIcons.file,
  };
  return SimIcon(icon, color: color);
}

/// `buildMentionPreview` / the filtered list: an empty query previews at
/// most [mentionPreviewDefaultLimit] rows per family; a query searches
/// every family in full.
List<MentionCandidate> mentionCandidates(
  List<ComposerResourceGroup> groups,
  String query,
) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) {
    return [
      for (final group in groups)
        ...group.items.take(mentionPreviewDefaultLimit),
    ];
  }
  return [
    for (final group in groups)
      for (final item in group.items)
        if (item.matches(q)) item,
  ];
}

/// Where a caret menu floats: above the trigger glyph (`side=top
/// align=start sideOffset=8 collisionPadding=8`), flipped below when the
/// space above is smaller, shifted to stay inside the viewport.
@immutable
class CaretMenuPlacement {
  const CaretMenuPlacement({
    required this.caretLocal,
    required this.caretGlobal,
    required this.lineHeight,
  });

  /// The trigger's caret rect top-left in the field's (link target) space.
  final Offset caretLocal;

  /// The same point in global coordinates.
  final Offset caretGlobal;
  final double lineHeight;
}

/// Floats [child] at [placement] through a [CompositedTransformFollower]
/// (tracks scrolling and relayout) without ever taking focus.
class CaretMenuFrame extends StatelessWidget {
  const CaretMenuFrame({
    required this.link,
    required this.placement,
    required this.width,
    required this.maxHeight,
    required this.child,
    required this.semanticsIdentifier,
    super.key,
    this.fixedWidth = true,
  });

  final LayerLink link;
  final CaretMenuPlacement placement;

  /// The menu width (or its cap when not [fixedWidth]).
  final double width;
  final double maxHeight;
  final bool fixedWidth;
  final Widget child;
  final String semanticsIdentifier;

  static const double sideOffset = 8;
  static const double collisionPadding = 8;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final c = SimTheme.of(context).colors;
    final effectiveWidth = math.min(
      width,
      viewport.width - 2 * collisionPadding,
    );
    final above = placement.caretGlobal.dy - sideOffset - collisionPadding;
    final below =
        viewport.height -
        (placement.caretGlobal.dy + placement.lineHeight) -
        sideOffset -
        collisionPadding;
    final top = above >= math.min(maxHeight, 120) || above >= below;
    final cap = math
        .max(0, math.min(maxHeight, top ? above : below))
        .toDouble();
    var dx = 0.0;
    final right = placement.caretGlobal.dx + effectiveWidth;
    if (right > viewport.width - collisionPadding) {
      dx = viewport.width - collisionPadding - right;
    }
    if (placement.caretGlobal.dx + dx < collisionPadding) {
      dx = collisionPadding - placement.caretGlobal.dx;
    }
    final offset = top
        ? placement.caretLocal + Offset(dx, -sideOffset)
        : placement.caretLocal + Offset(dx, placement.lineHeight + sideOffset);
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        offset: offset,
        followerAnchor: top ? Alignment.bottomLeft : Alignment.topLeft,
        child: TextFieldTapRegion(
          child: Semantics(
            container: true,
            identifier: semanticsIdentifier,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: fixedWidth ? effectiveWidth : SimMenuStyles.minWidth,
                maxWidth: effectiveWidth,
                maxHeight: cap,
              ),
              child: DecoratedBox(
                decoration: SimMenuStyles.surface(c),
                child: Padding(padding: SimMenuStyles.padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A flat, cursor-driven list of 28px rows whose keyboard input arrives
/// from the field ([ComposerMenuHandle]); hover moves the cursor.
abstract class _CursorListState<T extends StatefulWidget> extends State<T>
    implements ComposerMenuHandle {
  final ScrollController scroll = ScrollController();
  int active = 0;

  int get itemCount;

  /// Offset of item [index] in the list (headings included).
  double offsetOf(int index);

  void attach();
  void detach();

  @override
  void initState() {
    super.initState();
    attach();
  }

  @override
  void dispose() {
    detach();
    scroll.dispose();
    super.dispose();
  }

  @override
  void moveActive(int delta) {
    final count = itemCount;
    if (count == 0) return;
    final next = active + delta;
    setState(() => active = next < 0 ? count - 1 : (next >= count ? 0 : next));
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    if (!mounted || !scroll.hasClients) return;
    final top = offsetOf(active);
    const row = SimLayout.menuRowHeight;
    final view = scroll.position.viewportDimension;
    final current = scroll.offset;
    if (top < current) {
      scroll.jumpTo(top);
    } else if (top + row > current + view) {
      scroll.jumpTo(top + row - view);
    }
  }
}

/// The `@` mention list (`PlusMenuDropdown` in mention mode): families with
/// headings, a cursor row, "No results"; never focused.
class MentionMenu extends StatefulWidget {
  const MentionMenu({
    required this.controller,
    required this.query,
    required this.groups,
    required this.hydrating,
    required this.onSelect,
    super.key,
  });

  final ComposerController controller;
  final String query;
  final List<ComposerResourceGroup> groups;
  final bool hydrating;
  final ValueChanged<ComposerResource> onSelect;

  @override
  State<MentionMenu> createState() => MentionMenuState();
}

class MentionMenuState extends _CursorListState<MentionMenu> {
  late List<MentionCandidate> _items = mentionCandidates(
    widget.groups,
    widget.query,
  );

  List<MentionCandidate> get items => _items;

  @override
  int get itemCount => _items.length;

  @override
  void attach() => widget.controller.mentionMenu = this;

  @override
  void detach() {
    if (identical(widget.controller.mentionMenu, this)) {
      widget.controller.mentionMenu = null;
    }
  }

  @override
  void didUpdateWidget(MentionMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.groups != widget.groups) {
      _items = mentionCandidates(widget.groups, widget.query);
      if (oldWidget.query != widget.query || active >= _items.length) {
        active = 0;
      }
    }
  }

  @override
  double offsetOf(int index) {
    var y = 0.0;
    for (var i = 0; i <= index && i < _items.length; i++) {
      if (i == 0 || _items[i - 1].type != _items[i].type) {
        y += SimMenuStyles.headingHeight;
      }
      if (i < index) y += SimLayout.menuRowHeight;
    }
    return y;
  }

  @override
  ComposerMenuSelectResult selectActive() {
    if (_items.isEmpty) {
      return widget.hydrating
          ? ComposerMenuSelectResult.hydrating
          : ComposerMenuSelectResult.empty;
    }
    widget.onSelect(_items[active.clamp(0, _items.length - 1)]);
    return ComposerMenuSelectResult.selected;
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    if (_items.isEmpty) {
      return SizedBox(
        height: SimLayout.menuRowHeight,
        child: Center(
          child: Text(
            'No results',
            style: sim.text.caption.copyWith(color: c.textMuted),
          ),
        ),
      );
    }
    final children = <Widget>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (i == 0 || _items[i - 1].type != item.type) {
        children.add(SimMenuHeading(item.type.label));
      }
      final index = i;
      children.add(
        SimMenuRow(
          label: item.name,
          leading: resourceRowIcon(item, c.textIcon),
          highlighted: i == active,
          semanticsIdentifier: i == 0 ? 'chat-input.plus-menu.row' : null,
          trailing: item.workspaceName == null
              ? null
              : Text(
                  item.workspaceName!,
                  style: sim.text.xs.copyWith(color: c.textMuted),
                ),
          onHover: () {
            if (active != index) setState(() => active = index);
          },
          onPressed: () => widget.onSelect(item),
        ),
      );
    }
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// One row of the `/` menu.
sealed class SlashCandidate {
  const SlashCandidate();

  String get name;
}

class SkillCandidate extends SlashCandidate {
  const SkillCandidate(this.skill);

  final ComposerSkill skill;

  @override
  String get name => skill.name;
}

class McpCandidate extends SlashCandidate {
  const McpCandidate(this.server);

  final ComposerMcpServer server;

  @override
  String get name => server.name;
}

/// The `/` skills + MCP list (`SkillsMenuDropdown`); never focused.
class SkillsMenu extends StatefulWidget {
  const SkillsMenu({
    required this.controller,
    required this.query,
    required this.skills,
    required this.mcpServers,
    required this.onSkill,
    required this.onMcp,
    super.key,
  });

  final ComposerController controller;
  final String query;
  final List<ComposerSkill> skills;
  final List<ComposerMcpServer> mcpServers;
  final ValueChanged<ComposerSkill> onSkill;
  final ValueChanged<ComposerMcpServer> onMcp;

  @override
  State<SkillsMenu> createState() => SkillsMenuState();
}

class SkillsMenuState extends _CursorListState<SkillsMenu> {
  List<SlashCandidate> get items {
    final q = widget.query.toLowerCase().trim();
    return [
      for (final s in widget.skills)
        if (q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            (s.workspaceName?.toLowerCase().contains(q) ?? false))
          SkillCandidate(s),
      for (final m in widget.mcpServers)
        if (q.isEmpty || m.name.toLowerCase().contains(q)) McpCandidate(m),
    ];
  }

  @override
  int get itemCount => items.length;

  @override
  void attach() => widget.controller.skillsMenu = this;

  @override
  void detach() {
    if (identical(widget.controller.skillsMenu, this)) {
      widget.controller.skillsMenu = null;
    }
  }

  @override
  void didUpdateWidget(SkillsMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) active = 0;
  }

  @override
  double offsetOf(int index) => index * SimLayout.menuRowHeight;

  /// The rows' natural width (the menu is content-sized up to 300px).
  double _contentWidth(SimTheme sim, List<SlashCandidate> list) {
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    var widest = 0.0;
    for (final item in list) {
      var w =
          SimMenuStyles.rowPaddingX * 2 +
          SimLayout.iconSize +
          SimMenuStyles.rowGap +
          measure(item.name, sim.text.small);
      final workspace = switch (item) {
        SkillCandidate(:final skill) => skill.workspaceName,
        McpCandidate() => null,
      };
      if (workspace != null) {
        w += SimMenuStyles.rowGap + measure(workspace, sim.text.xs);
      }
      widest = math.max(widest, w.ceilToDouble());
    }
    return math.min(
      math.max(widest, SimMenuStyles.minWidth - 8),
      skillsMenuMaxWidth - 8,
    );
  }

  void _select(SlashCandidate target) => switch (target) {
    SkillCandidate(:final skill) => widget.onSkill(skill),
    McpCandidate(:final server) => widget.onMcp(server),
  };

  @override
  ComposerMenuSelectResult selectActive() {
    final list = items;
    if (list.isEmpty) return ComposerMenuSelectResult.empty;
    _select(list[active.clamp(0, list.length - 1)]);
    return ComposerMenuSelectResult.selected;
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final list = items;
    if (list.isEmpty) {
      return SizedBox(
        height: SimLayout.menuRowHeight,
        child: Center(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'No skills or MCP servers',
              style: sim.text.caption.copyWith(color: c.textMuted),
            ),
          ),
        ),
      );
    }
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: scroll,
        child: SizedBox(
          width: _contentWidth(sim, list),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < list.length; i++)
                SimMenuRow(
                  label: list[i].name,
                  leading: switch (list[i]) {
                    SkillCandidate() => AgentSkillsIcon(
                      size: 14,
                      color: c.textIcon,
                    ),
                    McpCandidate() => McpIcon(size: 14, color: c.textIcon),
                  },
                  trailing: switch (list[i]) {
                    SkillCandidate(:final skill)
                        when skill.workspaceName != null =>
                      Text(
                        skill.workspaceName!,
                        style: sim.text.xs.copyWith(color: c.textMuted),
                      ),
                    _ => null,
                  },
                  highlighted: i == active,
                  semanticsIdentifier: i == 0
                      ? 'chat-input.skills-menu.row'
                      : null,
                  onHover: () {
                    if (active != i) setState(() => active = i);
                  },
                  onPressed: () => _select(list[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
