import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/overlay/anchored.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/widgets/chip/chip_dropdown.dart';
import 'package:sim_design/src/widgets/menu/dropdown_menu.dart';
import 'package:sim_design/src/widgets/menu/menu_styles.dart';

/// A selectable option in a [SimChipSelect].
class SimChipSelectOption {
  const SimChipSelectOption({
    required this.value,
    required this.label,
    this.searchTerms = const <String>[],
    this.icon,
    this.enabled = true,
  });

  final String value;
  final String label;

  /// Additional search-only terms, never rendered.
  final List<String> searchTerms;
  final SimIconData? icon;
  final bool enabled;
}

/// A labelled group of options.
class SimChipSelectOptionGroup {
  const SimChipSelectOptionGroup({required this.items, this.section});

  final String? section;
  final List<SimChipSelectOption> items;
}

/// `chipSelectOptionMatchesSearch`: matches the label or a search alias.
bool chipSelectOptionMatchesSearch(SimChipSelectOption option, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return <String>[option.label, ...option.searchTerms].any(
    (term) => term.trim().toLowerCase().contains(normalized),
  );
}

/// Menu width of a [SimChipSelect]: the trigger's width, or a fixed px value.
class SimChipSelectWidth {
  const SimChipSelectWidth.trigger() : px = null, matchTrigger = true;
  const SimChipSelectWidth.px(this.px) : matchTrigger = false;

  final double? px;
  final bool matchTrigger;
}

/// Port of `packages/emcn/src/components/chip-select/chip-select.tsx`: the
/// platform filter dropdown — a `filled` chip trigger with a trailing chevron
/// opening a `DropdownMenu`. Single-select rows, multi-select checkbox rows
/// (menu stays open; optional "All" clear row), grouped sections, and an
/// in-menu search for long lists. The menu is at least 160px wide.
class SimChipSelect extends StatefulWidget {
  const SimChipSelect({
    super.key,
    this.options,
    this.groups,
    this.value,
    this.onChanged,
    this.multiSelect = false,
    this.multiSelectValues = const <String>[],
    this.onMultiSelectChange,
    this.placeholder = 'Select...',
    this.displayLabel,
    this.enabled = true,
    this.searchable = false,
    this.searchPlaceholder = 'Search...',
    this.showAllOption = false,
    this.allOptionLabel = 'All',
    this.align = SimAlign.end,
    this.fullWidth = false,
    this.dropdownWidth,
    this.maxHeight,
    this.stayBelow = false,
    this.semanticsLabel,
  });

  final List<SimChipSelectOption>? options;
  final List<SimChipSelectOptionGroup>? groups;
  final String? value;
  final ValueChanged<String>? onChanged;
  final bool multiSelect;
  final List<String> multiSelectValues;
  final ValueChanged<List<String>>? onMultiSelectChange;
  final String placeholder;

  /// Overrides the computed trigger label.
  final String? displayLabel;
  final bool enabled;
  final bool searchable;
  final String searchPlaceholder;
  final bool showAllOption;
  final String allOptionLabel;
  final SimAlign align;

  /// Stretch the trigger (form fields); otherwise content width capped at 240px.
  final bool fullWidth;
  final SimChipSelectWidth? dropdownWidth;
  final double? maxHeight;

  /// Keep the menu below the trigger and shrink it instead of flipping.
  final bool stayBelow;
  final String? semanticsLabel;

  @override
  State<SimChipSelect> createState() => _SimChipSelectState();
}

class _SimChipSelectState extends State<SimChipSelect> {
  SimMenuHandle? _menu;
  String _query = '';

  List<SimChipSelectOptionGroup> get _sections =>
      widget.groups ??
      <SimChipSelectOptionGroup>[
        SimChipSelectOptionGroup(
          items: widget.options ?? const <SimChipSelectOption>[],
        ),
      ];

  List<SimChipSelectOption> get _all => <SimChipSelectOption>[
    for (final g in _sections) ...g.items,
  ];

  @override
  void didUpdateWidget(SimChipSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    _menu?.rebuild();
  }

  @override
  void dispose() {
    _menu?.close();
    super.dispose();
  }

  String get _triggerLabel {
    if (widget.displayLabel != null) return widget.displayLabel!;
    final all = _all;
    if (widget.multiSelect) {
      final selected = widget.multiSelectValues;
      if (selected.isEmpty) {
        return widget.showAllOption
            ? widget.allOptionLabel
            : widget.placeholder;
      }
      if (selected.length == 1) {
        return all
                .where((o) => o.value == selected.first)
                .map((o) => o.label)
                .firstOrNull ??
            widget.placeholder;
      }
      return '${selected.length} selected';
    }
    if (widget.value == null || widget.value!.isEmpty) {
      return widget.placeholder;
    }
    return all
            .where((o) => o.value == widget.value)
            .map((o) => o.label)
            .firstOrNull ??
        widget.placeholder;
  }

  void _toggle(String value) {
    final selected = widget.multiSelectValues;
    widget.onMultiSelectChange?.call(
      selected.contains(value)
          ? selected.where((v) => v != value).toList()
          : <String>[...selected, value],
    );
  }

  List<SimMenuEntry> _entries() {
    final sim = SimTheme.of(context);
    final filtered = <SimChipSelectOptionGroup>[
      for (final g in _sections)
        if (!widget.searchable || _query.trim().isEmpty)
          g
        else
          SimChipSelectOptionGroup(
            section: g.section,
            items: g.items
                .where((o) => chipSelectOptionMatchesSearch(o, _query))
                .toList(),
          ),
    ].where((g) => g.items.isNotEmpty).toList();
    return <SimMenuEntry>[
      if (widget.searchable)
        SimMenuSearch(
          placeholder: widget.searchPlaceholder,
          onChanged: (v) => _query = v,
        ),
      if (widget.multiSelect && widget.showAllOption)
        SimMenuItem(
          label: widget.allOptionLabel,
          checked: widget.multiSelectValues.isEmpty,
          keepOpen: true,
          onSelect: () => widget.onMultiSelectChange?.call(const <String>[]),
        ),
      if (filtered.isEmpty)
        SimMenuCustom(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Text(
              'No results',
              textAlign: TextAlign.center,
              style: sim.text.small.copyWith(color: sim.colors.textMuted),
            ),
          ),
        )
      else
        for (final group in filtered) ...<SimMenuEntry>[
          if (group.section != null) SimMenuLabel(group.section!),
          for (final option in group.items)
            if (widget.multiSelect)
              SimMenuItem(
                label: option.label,
                icon: option.icon,
                enabled: option.enabled,
                checked: widget.multiSelectValues.contains(option.value),
                keepOpen: true,
                onSelect: () => _toggle(option.value),
              )
            else
              SimMenuItem(
                label: option.label,
                icon: option.icon,
                enabled: option.enabled,
                selected: widget.value == option.value,
                onSelect: () => widget.onChanged?.call(option.value),
              ),
        ],
    ];
  }

  void _open() {
    if (_menu?.isOpen ?? false) {
      _menu!.close();
      return;
    }
    _query = '';
    final width = widget.dropdownWidth;
    _menu = SimDropdownMenu.show(
      context,
      entries: _entries,
      align: widget.align,
      matchAnchorWidth: width?.matchTrigger ?? false,
      width: width?.px,
      minWidth: 160,
      maxWidth: width == null ? SimMenuStyles.maxWidth : null,
      maxHeight:
          widget.maxHeight ??
          (widget.stayBelow ? 240 : SimMenuStyles.maxHeight),
      avoidCollisions: !widget.stayBelow,
      autofocus: !widget.searchable,
      onClose: () {
        _menu = null;
        _query = '';
      },
    );
  }

  @override
  Widget build(BuildContext context) => SimChipTrigger(
    label: _triggerLabel,
    onPressed: _open,
    fullWidth: widget.fullWidth,
    maxWidth: widget.fullWidth ? null : 240,
    enabled: widget.enabled,
    semanticsLabel: widget.semanticsLabel,
  );
}
