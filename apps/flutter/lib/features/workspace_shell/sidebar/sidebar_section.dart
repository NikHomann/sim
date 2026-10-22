import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_design/sim_design.dart';

/// `SidebarSection` (`components/sidebar-section/sidebar-section.tsx`): an
/// 18px title row (caption, `--text-muted`, 16px gutters) whose toggle
/// collapses the body; the 14px chevron appears while the section is
/// hovered (or the toggle has keyboard focus) and turns −90° when closed.
/// Collapse is per-mount UI state. In the collapsed rail the title is a
/// static, invisible label and the body is forced open.
class SidebarSection extends StatefulWidget {
  const SidebarSection({
    required this.title,
    required this.child,
    super.key,
    this.action,
    this.railCollapsed = false,
    this.topGap = 0,
    this.parityId,
    this.titleParityId,
    this.sectionAliasId,
    this.headerParityId,
    this.labelParityId,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final bool railCollapsed;

  /// `SIDEBAR_SECTION_GAP_CLASS` (`mt-4`) where the section takes it.
  final double topGap;
  final String? parityId;
  final String? titleParityId;

  /// Detail-spec aliases of the same boxes (the tree spec's
  /// `sidebar.workflows.section`, `.header`, `.header.title`).
  final String? sectionAliasId;
  final String? headerParityId;
  final String? labelParityId;

  @override
  State<SidebarSection> createState() => _SidebarSectionState();
}

class _SidebarSectionState extends State<SidebarSection> {
  bool _expanded = true;
  bool _hovered = false;
  bool _toggleFocused = false;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    Widget label = Opacity(
      opacity: widget.railCollapsed ? 0 : 1,
      child: SimOverflowText(
        label: widget.title,
        style: sim.text.caption.copyWith(color: c.textMuted),
        tooltipEnabled: false,
      ),
    );
    if (widget.labelParityId != null) {
      label = Parity(widget.labelParityId!, child: label);
    }
    Widget titleRow;
    if (widget.railCollapsed) {
      titleRow = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: <Widget>[Flexible(child: label)]),
      );
    } else {
      final showChevron = _hovered || _toggleFocused;
      titleRow = SimPressable(
        semanticsLabel: widget.title,
        onPressed: () => setState(() => _expanded = !_expanded),
        onFocusChanged: (focused) => setState(() => _toggleFocused = focused),
        builder: (context, state) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 8,
            children: <Widget>[
              Flexible(child: label),
              Opacity(
                opacity: showChevron || state.focused ? 1 : 0,
                child: AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: SimMotion.of(SimMotion.sidebarChevron),
                  child: const SimIcon(SimEmcnIcons.chevronDown),
                ),
              ),
            ],
          ),
        ),
      );
      titleRow = Semantics(expanded: _expanded, child: titleRow);
    }
    if (widget.titleParityId != null) {
      titleRow = Parity(widget.titleParityId!, child: titleRow);
    }
    Widget header = SizedBox(
      height: SimLayout.sidebarSectionTitleRow,
      child: Row(
        children: <Widget>[
          Expanded(child: titleRow),
          if (widget.action != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _VerticalOverflow(child: widget.action),
            ),
        ],
      ),
    );
    if (widget.headerParityId != null) {
      header = Parity(widget.headerParityId!, child: header);
    }
    final open = widget.railCollapsed || _expanded;
    Widget section = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          if (open)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: widget.child,
            ),
        ],
      ),
    );
    if (widget.sectionAliasId != null) {
      section = Parity(widget.sectionAliasId!, child: section);
    }
    if (widget.parityId != null) {
      section = Parity(widget.parityId!, child: section);
    }
    return Padding(
      padding: EdgeInsets.only(top: widget.topGap),
      child: section,
    );
  }
}

/// Lays its child out at its own height inside the 18px title row and
/// centres it, letting it overflow vertically: the header's 20×20 icon
/// buttons hang 1px over the row like the `h-[18px]` flex row upstream,
/// instead of being squeezed to 18px.
class _VerticalOverflow extends SingleChildRenderObjectWidget {
  const _VerticalOverflow({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderVerticalOverflow();
}

class _RenderVerticalOverflow extends RenderShiftedBox {
  _RenderVerticalOverflow() : super(null);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      (size.height - child.size.height) / 2,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final offset = (child.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}
