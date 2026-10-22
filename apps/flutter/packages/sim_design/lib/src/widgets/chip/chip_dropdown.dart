import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/pressable.dart';
import 'package:sim_design/src/overlay/anchored.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/widgets/chip/chip.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';
import 'package:sim_design/src/widgets/menu/dropdown_menu.dart';
import 'package:sim_design/src/widgets/menu/menu_styles.dart';
import 'package:sim_design/src/widgets/overflow_text.dart';

/// One option of a [SimChipDropdown].
class SimChipDropdownOption {
  const SimChipDropdownOption({
    required this.value,
    required this.label,
    this.icon,
    this.leading,
  });

  final String value;
  final String label;

  /// Leading 14px menu icon in `--text-icon`.
  final SimIconData? icon;

  /// Pre-rendered leading element (an avatar); wins over [icon].
  final Widget? leading;
}

/// Trigger chrome of a [SimChipDropdown]: `filled` (the bordered field chip,
/// default), `ghost` (the bare toolbar pill with `--text-icon` label), or any
/// other chip variant (`primary` for an inverse call-to-action).
enum SimChipTriggerVariant {
  filled,
  ghost,
  base,
  primary,
  destructive,
  borderShadow,
  border,
  outline,
}

/// Chip-styled dropdown trigger shared by [SimChipDropdown] and `SimChipSelect`:
/// a 30px pill with the owned 14px chevron in a 16px slot.
class SimChipTrigger extends StatelessWidget {
  const SimChipTrigger({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = SimChipTriggerVariant.filled,
    this.placeholder = false,
    this.leftIcon,
    this.iconOnly = false,
    this.fullWidth = false,
    this.active = false,
    this.enabled = true,
    this.shape = SimChipShape.rounded,
    this.maxWidth,
    this.semanticsLabel,
    this.focusNode,
    this.chevron = SimIcons.chevronDown,
  });

  final String label;
  final VoidCallback? onPressed;
  final SimChipTriggerVariant variant;

  /// Renders the label muted (nothing selected).
  final bool placeholder;
  final SimIconData? leftIcon;
  final bool iconOnly;
  final bool fullWidth;
  final bool active;
  final bool enabled;
  final SimChipShape shape;
  final double? maxWidth;
  final String? semanticsLabel;
  final FocusNode? focusNode;
  final SimIconData chevron;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final ghost = variant == SimChipTriggerVariant.ghost;
    final inverse =
        variant == SimChipTriggerVariant.primary ||
        variant == SimChipTriggerVariant.destructive;
    final chipVariant = switch (variant) {
      SimChipTriggerVariant.filled => SimChipVariant.filled,
      SimChipTriggerVariant.ghost => SimChipVariant.base,
      SimChipTriggerVariant.base => SimChipVariant.base,
      SimChipTriggerVariant.primary => SimChipVariant.primary,
      SimChipTriggerVariant.destructive => SimChipVariant.destructive,
      SimChipTriggerVariant.borderShadow => SimChipVariant.borderShadow,
      SimChipTriggerVariant.border => SimChipVariant.border,
      SimChipTriggerVariant.outline => SimChipVariant.outline,
    };
    final paint = resolveChipPaint(c, variant: chipVariant, active: active);
    final labelColor = inverse
        ? paint.text
        : placeholder
        ? c.textMuted
        : ghost
        ? c.textIcon
        : c.textBody;
    final iconColor = inverse ? paint.text : c.textIcon;
    Widget chip = SimPressable(
      onPressed: onPressed,
      enabled: enabled,
      focusNode: focusNode,
      semanticsLabel: semanticsLabel ?? label,
      builder: (context, state) {
        final p = resolveChipPaint(
          c,
          variant: chipVariant,
          active: active,
          hovered: state.hovered,
          focused: state.focused,
          triggerBorder: !ghost && !inverse,
        );
        return Opacity(
          opacity: enabled ? 1 : SimChipChrome.disabledOpacity,
          child: AnimatedContainer(
            duration: SimMotion.of(SimMotion.colors),
            height: SimChipChrome.height,
            width: fullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(
              horizontal: SimChipChrome.paddingX,
            ),
            decoration: BoxDecoration(
              color: p.fill,
              border: p.border,
              borderRadius: BorderRadius.circular(
                iconOnly || shape == SimChipShape.round
                    ? SimRadii.full
                    : SimChipChrome.radius,
              ),
              boxShadow: p.shadows,
            ),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              spacing: SimChipChrome.gap,
              children: <Widget>[
                if (leftIcon != null)
                  SimIcon(
                    leftIcon!,
                    size: SimChipChrome.contentIconSize,
                    color: iconColor,
                  ),
                if (!iconOnly)
                  Flexible(
                    fit: fullWidth ? FlexFit.tight : FlexFit.loose,
                    child: SimOverflowText(
                      label: label,
                      style: sim.text.sm.copyWith(color: labelColor),
                    ),
                  ),
                SimChipChevron(icon: chevron, color: iconColor),
              ],
            ),
          ),
        );
      },
    );
    if (maxWidth != null) {
      chip = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: chip,
      );
    }
    return chip;
  }
}

/// Port of `packages/emcn/src/components/chip-dropdown/chip-dropdown.tsx`:
/// a 30px pill that opens a `DropdownMenu` of options. Single mode reports
/// the picked value and closes; `multiple` toggles values, keeps the menu
/// open, and optionally shows an "All" reset row and a search field. The menu
/// matches the trigger width by default.
class SimChipDropdown extends StatefulWidget {
  const SimChipDropdown({
    required this.options,
    super.key,
    this.value,
    this.onChanged,
    this.multiple = false,
    this.values = const <String>[],
    this.onValuesChanged,
    this.placeholder,
    this.align = SimAlign.end,
    this.matchTriggerWidth = true,
    this.enabled = true,
    this.onOpenChange,
    this.leftIcon,
    this.variant = SimChipTriggerVariant.filled,
    this.shape = SimChipShape.rounded,
    this.active = false,
    this.fullWidth = false,
    this.iconOnly = false,
    this.showSelectedCheck = true,
    this.allLabel = 'All',
    this.showAllOption = true,
    this.searchable = false,
    this.searchPlaceholder = 'Search...',
    this.menuMaxHeight = SimMenuStyles.maxHeight,
    this.semanticsLabel,
    this.focusNode,
  });

  final List<SimChipDropdownOption> options;
  final String? value;
  final ValueChanged<String>? onChanged;
  final bool multiple;
  final List<String> values;
  final ValueChanged<List<String>>? onValuesChanged;
  final String? placeholder;
  final SimAlign align;
  final bool matchTriggerWidth;
  final bool enabled;
  final ValueChanged<bool>? onOpenChange;
  final SimIconData? leftIcon;
  final SimChipTriggerVariant variant;
  final SimChipShape shape;
  final bool active;
  final bool fullWidth;
  final bool iconOnly;
  final bool showSelectedCheck;
  final String allLabel;
  final bool showAllOption;
  final bool searchable;
  final String searchPlaceholder;
  final double menuMaxHeight;
  final String? semanticsLabel;
  final FocusNode? focusNode;

  @override
  State<SimChipDropdown> createState() => _SimChipDropdownState();
}

class _SimChipDropdownState extends State<SimChipDropdown> {
  SimMenuHandle? _menu;
  String _search = '';

  List<String> get _selected => widget.multiple
      ? widget.values
      : (widget.value == null ? const <String>[] : <String>[widget.value!]);

  @override
  void didUpdateWidget(SimChipDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _menu?.rebuild();
  }

  @override
  void dispose() {
    _menu?.close();
    super.dispose();
  }

  String get _displayLabel {
    final selected = _selected;
    if (widget.multiple) {
      if (selected.isEmpty) return widget.allLabel;
      if (selected.length == 1) {
        return widget.options
                .where((o) => o.value == selected.first)
                .map((o) => o.label)
                .firstOrNull ??
            widget.allLabel;
      }
      return '${selected.length} selected';
    }
    return widget.options
            .where((o) => o.value == selected.firstOrNull)
            .map((o) => o.label)
            .firstOrNull ??
        widget.placeholder ??
        'Select...';
  }

  List<SimMenuEntry> _entries() {
    final selected = _selected;
    final query = _search.trim().toLowerCase();
    final filtered = widget.searchable && query.isNotEmpty
        ? widget.options.where((o) => o.label.toLowerCase().contains(query))
        : widget.options;
    return <SimMenuEntry>[
      if (widget.multiple && widget.searchable)
        SimMenuSearch(
          placeholder: widget.searchPlaceholder,
          onChanged: (v) => _search = v,
        ),
      if (widget.multiple && widget.showAllOption)
        SimMenuItem(
          label: widget.allLabel,
          selected: selected.isEmpty,
          keepOpen: true,
          onSelect: () => widget.onValuesChanged?.call(const <String>[]),
        ),
      for (final option in filtered)
        SimMenuItem(
          label: option.label,
          icon: option.icon,
          leading: option.leading,
          selected: widget.showSelectedCheck && selected.contains(option.value),
          keepOpen: widget.multiple,
          onSelect: () {
            if (widget.multiple) {
              final next = selected.contains(option.value)
                  ? selected.where((v) => v != option.value).toList()
                  : <String>[...selected, option.value];
              widget.onValuesChanged?.call(next);
            } else {
              widget.onChanged?.call(option.value);
            }
          },
        ),
    ];
  }

  void _open() {
    if (_menu?.isOpen ?? false) {
      _menu!.close();
      return;
    }
    _search = '';
    widget.onOpenChange?.call(true);
    _menu = SimDropdownMenu.show(
      context,
      entries: _entries,
      align: widget.align,
      matchAnchorWidth: widget.matchTriggerWidth,
      maxWidth: widget.matchTriggerWidth ? null : SimMenuStyles.maxWidth,
      maxHeight: widget.menuMaxHeight,
      modal: false,
      autofocus: !(widget.multiple && widget.searchable),
      onClose: () {
        _menu = null;
        _search = '';
        if (mounted) widget.onOpenChange?.call(false);
      },
    );
  }

  @override
  Widget build(BuildContext context) => SimChipTrigger(
    label: _displayLabel,
    onPressed: _open,
    variant: widget.variant,
    placeholder: !widget.multiple && _selected.isEmpty,
    leftIcon: widget.leftIcon,
    iconOnly: widget.iconOnly && widget.leftIcon != null,
    fullWidth: widget.fullWidth,
    active: widget.active,
    enabled: widget.enabled,
    shape: widget.shape,
    semanticsLabel: widget.semanticsLabel,
    focusNode: widget.focusNode,
  );
}
