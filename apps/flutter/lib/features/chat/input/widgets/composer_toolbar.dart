import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/input/model/composer_models.dart';
import 'package:sim_design/sim_design.dart';

/// `InputToolbar`: leading and trailing control groups on one row (trailing
/// pushed right), wrapping the trailing group onto its own right-aligned
/// row when both do not fit (`flex flex-wrap justify-between gap-y-1`).
class ComposerToolbar extends StatelessWidget {
  const ComposerToolbar({
    required this.leading,
    required this.trailing,
    super.key,
  });

  /// Built with the item gap for the measured toolbar width.
  final List<Widget> Function(double gap, double toolbarWidth) leading;
  final List<Widget> Function(double gap, double toolbarWidth) trailing;

  /// `@max-[280px]/input-toolbar:gap-0 gap-1`.
  static double gapFor(double width) => width <= 280 ? 0 : 4;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final gap = gapFor(width);
      Widget group(List<Widget> children, String? id) {
        final row = ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 30),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: children,
          ),
        );
        return id == null
            ? row
            : Semantics(container: true, identifier: id, child: row);
      }

      return Semantics(
        container: true,
        identifier: 'chat-input.toolbar',
        child: _SplitWrap(
          runSpacing: 4,
          children: [
            group(leading(gap, width), 'chat-input.toolbar.leading'),
            group(trailing(gap, width), null),
          ],
        ),
      );
    },
  );
}

class _SplitWrap extends MultiChildRenderObjectWidget {
  const _SplitWrap({required this.runSpacing, required super.children});

  final double runSpacing;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSplitWrap(runSpacing);

  @override
  void updateRenderObject(BuildContext context, _RenderSplitWrap renderObject) {
    renderObject.runSpacing = runSpacing;
  }
}

class _SplitParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderSplitWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SplitParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SplitParentData> {
  _RenderSplitWrap(this._runSpacing);

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (value == _runSpacing) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SplitParentData) {
      child.parentData = _SplitParentData();
    }
  }

  @override
  void performLayout() {
    final leading = firstChild!;
    final trailing = childAfter(leading)!;
    final maxWidth = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: maxWidth);
    leading.layout(loose, parentUsesSize: true);
    trailing.layout(loose, parentUsesSize: true);
    final l = leading.size;
    final t = trailing.size;
    final lp = leading.parentData! as _SplitParentData;
    final tp = trailing.parentData! as _SplitParentData;
    if (l.width + t.width <= maxWidth) {
      final height = math.max(l.height, t.height);
      lp.offset = Offset(0, (height - l.height) / 2);
      tp.offset = Offset(maxWidth - t.width, (height - t.height) / 2);
      size = constraints.constrain(Size(maxWidth, height));
    } else {
      lp.offset = Offset.zero;
      tp.offset = Offset(maxWidth - t.width, l.height + _runSpacing);
      size = constraints.constrain(
        Size(maxWidth, l.height + _runSpacing + t.height),
      );
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final leading = firstChild;
    final trailing = leading == null ? null : childAfter(leading);
    if (leading == null || trailing == null) return constraints.smallest;
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    final l = leading.getDryLayout(loose);
    final t = trailing.getDryLayout(loose);
    final oneRow = l.width + t.width <= constraints.maxWidth;
    return constraints.constrain(
      Size(
        constraints.maxWidth,
        oneRow
            ? math.max(l.height, t.height)
            : l.height + _runSpacing + t.height,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// A round toolbar chip with a tooltip above (`Chip shape=round`).
class ComposerRoundChip extends StatelessWidget {
  const ComposerRoundChip({
    required this.icon,
    required this.label,
    required this.identifier,
    required this.onPressed,
    super.key,
  });

  final SimIconData icon;
  final String label;
  final String identifier;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    identifier: identifier,
    child: SimTooltip(
      message: label,
      preferAbove: true,
      child: SimChip(
        shape: SimChipShape.round,
        leftIcon: icon,
        semanticsLabel: label,
        onPressed: onPressed,
      ),
    ),
  );
}

/// `ComposerActionButton` + `SendButton`: the 28px circle; idle ArrowUp
/// (enabled #383838 / dark #E0E0E0, hover #575757 / #CFCFCF, disabled
/// #808080), streaming StopFilled 14px in the active colour.
class ComposerSendButton extends StatefulWidget {
  const ComposerSendButton({
    required this.isStreaming,
    required this.canSubmit,
    required this.onSubmit,
    required this.onStop,
    super.key,
  });

  final bool isStreaming;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final VoidCallback? onStop;

  static const double size = 28;
  static const Color activeLight = Color(0xFF383838);
  static const Color activeDark = Color(0xFFE0E0E0);
  static const Color hoverLight = Color(0xFF575757);
  static const Color hoverDark = Color(0xFFCFCFCF);
  static const Color disabled = Color(0xFF808080);
  static const double disabledOpacity = 0.7;

  @override
  State<ComposerSendButton> createState() => _ComposerSendButtonState();
}

class _ComposerSendButtonState extends State<ComposerSendButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dark = SimTheme.of(context).isDark;
    final streaming = widget.isStreaming;
    final active = streaming || widget.canSubmit;
    final enabled = streaming ? widget.onStop != null : widget.canSubmit;
    final fill = !active
        ? ComposerSendButton.disabled
        : _hovered && enabled
        ? (dark ? ComposerSendButton.hoverDark : ComposerSendButton.hoverLight)
        : (dark
              ? ComposerSendButton.activeDark
              : ComposerSendButton.activeLight);
    final glyph = dark ? SimColors.black : SimColors.white;
    final label = streaming ? 'Stop generation' : 'Send message';
    return Semantics(
      container: true,
      identifier: 'chat-input.send',
      button: true,
      enabled: enabled,
      label: label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: !enabled
              ? null
              : streaming
              ? widget.onStop
              : widget.onSubmit,
          // A disabled send (`disabled={!canSubmit}`) also takes emcn
          // Button's `disabled:opacity-70` over the grey circle.
          child: Opacity(
            opacity: !streaming && !widget.canSubmit
                ? ComposerSendButton.disabledOpacity
                : 1,
            child: Container(
              width: ComposerSendButton.size,
              height: ComposerSendButton.size,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: streaming
                  ? SimIcon(SimEmcnIcons.stopFilled, color: glyph)
                  : SimIcon(SimEmcnIcons.arrowUp, size: 16, color: glyph),
            ),
          ),
        ),
      ),
    );
  }
}

/// `ModelSettingTrigger` for reasoning effort: the value label in
/// `text-sm --text-icon`, collapsing to a 14px Brain icon when the toolbar
/// is 320px or narrower; the radio menu opens above, start-aligned.
class ComposerEffortChip extends StatelessWidget {
  const ComposerEffortChip({
    required this.effort,
    required this.options,
    required this.onChanged,
    required this.narrow,
    super.key,
  });

  final ComposerEffort effort;
  final List<ComposerEffort> options;
  final ValueChanged<ComposerEffort> onChanged;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Semantics(
      container: true,
      identifier: 'chat-input.effort',
      child: SimTooltip(
        message: 'Reasoning effort: ${effort.label}',
        preferAbove: true,
        child: Builder(
          builder: (anchor) => SimChip(
            shape: SimChipShape.round,
            semanticsLabel: 'Reasoning effort',
            leftAdornment: narrow
                ? SimIcon(SimEmcnIcons.brain, color: c.textIcon)
                : Text(
                    effort.label,
                    maxLines: 1,
                    style: composerLabelStyle(sim, c.textIcon),
                  ),
            onPressed: () => SimDropdownMenu.show(
              anchor,
              side: SimSide.top,
              entries: () => [
                for (final option in options)
                  SimMenuItem(
                    label: option.label,
                    radio: option == effort,
                    onSelect: () => onChanged(option),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Model menu chip (flag `mothership-model-selector`): value label with
/// a chevron, a 16px check on the current model, menu above, end-aligned.
class ComposerModelChip extends StatelessWidget {
  const ComposerModelChip({
    required this.selection,
    required this.onChanged,
    required this.narrow,
    super.key,
  });

  final ComposerModelSelection selection;
  final ValueChanged<ComposerModel> onChanged;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Semantics(
      container: true,
      identifier: 'chat-input.model',
      child: SimTooltip(
        message: 'Model: ${selection.model.label}',
        preferAbove: true,
        child: Builder(
          builder: (anchor) => SimChip(
            shape: SimChipShape.round,
            semanticsLabel: 'Model',
            leftAdornment: narrow
                ? SimIcon(SimEmcnIcons.sparkles, color: c.textIcon)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      Text(
                        selection.model.label,
                        maxLines: 1,
                        style: composerLabelStyle(sim, c.textIcon),
                      ),
                      SimIcon(SimIcons.chevronDown, color: c.textIcon),
                    ],
                  ),
            onPressed: () => SimDropdownMenu.show(
              anchor,
              side: SimSide.top,
              align: SimAlign.end,
              entries: () => [
                for (final model in ComposerModel.values)
                  SimMenuItem(
                    label: model.label,
                    trailing: model == selection.model
                        ? SimIcon(SimIcons.check, size: 16, color: c.textIcon)
                        : null,
                    onSelect: () => onChanged(model),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `FastModeToggle`: a round chip with a 14px Zap, `aria-pressed`.
class ComposerFastToggle extends StatelessWidget {
  const ComposerFastToggle({
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return Semantics(
      container: true,
      identifier: 'chat-input.fast',
      toggled: enabled,
      child: SimTooltip(
        message: 'Faster responses at a higher price',
        preferAbove: true,
        child: SimChip(
          shape: SimChipShape.round,
          active: enabled,
          semanticsLabel: 'Fast mode',
          leftAdornment: SimIcon(
            SimEmcnIcons.zap,
            color: enabled ? c.textPrimary : c.textIcon,
          ),
          onPressed: () => onChanged(!enabled),
        ),
      ),
    );
  }
}

/// `ConversationModeSelector`: ghost round dropdown (Build / Plan), start
/// aligned, no selected check; tooltip "Select mode ⇧ Tab" hidden while open.
class ComposerModeSelector extends StatefulWidget {
  const ComposerModeSelector({
    required this.value,
    required this.modes,
    required this.onChanged,
    super.key,
  });

  final ComposerMode value;
  final List<ComposerMode> modes;
  final ValueChanged<ComposerMode>? onChanged;

  @override
  State<ComposerModeSelector> createState() => _ComposerModeSelectorState();
}

class _ComposerModeSelectorState extends State<ComposerModeSelector> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    return Semantics(
      container: true,
      identifier: 'chat-input.mode',
      child: SimTooltip(
        enabled: !_open,
        preferAbove: true,
        content: onChanged == null
            ? const Text('Select mode')
            : const SimTooltipShortcut(
                keys: '⇧ Tab',
                child: Text('Select mode'),
              ),
        child: SimChipDropdown(
          options: [
            for (final mode in widget.modes)
              SimChipDropdownOption(value: mode.wire, label: mode.label),
          ],
          value: widget.value.wire,
          variant: SimChipTriggerVariant.ghost,
          shape: SimChipShape.round,
          align: SimAlign.start,
          matchTriggerWidth: false,
          showSelectedCheck: false,
          enabled: onChanged != null,
          semanticsLabel: 'Conversation mode',
          onOpenChange: (open) => setState(() => _open = open),
          onChanged: (wire) {
            final mode = widget.modes.firstWhere((m) => m.wire == wire);
            if (mode != widget.value) onChanged?.call(mode);
          },
        ),
      ),
    );
  }
}

/// The toolbar chips' value label: `text-sm` (20px line) in the composer
/// root's Inter (`inter.className`), not the workspace Season face.
TextStyle composerLabelStyle(SimTheme sim, Color color) =>
    sim.text.inter(SimTextStyles.sizeSm, height: 20 / 14, color: color);
