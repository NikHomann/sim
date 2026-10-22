import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/keyboard.dart';
import 'package:sim_design/src/interaction/pressable.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/widgets/chip/chip.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';
import 'package:sim_design/src/widgets/fields/editable.dart';
import 'package:sim_design/src/widgets/menu/dropdown_menu.dart';
import 'package:sim_design/src/widgets/menu/menu_styles.dart';
import 'package:sim_design/src/widgets/menu/popover.dart';
import 'package:sim_design/src/widgets/overflow_text.dart';

/// A selectable option in a [SimChipCombobox] (`ComboboxOption`).
class SimComboboxOption {
  const SimComboboxOption({
    required this.value,
    required this.label,
    this.icon,
    this.leading,
    this.enabled = true,
    this.hidden = false,
    this.keepOpen = false,
    this.onSelect,
    this.selected,
    this.suffix,
  });

  final String value;
  final String label;
  final SimIconData? icon;
  final Widget? leading;
  final bool enabled;

  /// Hidden from the picker list but still resolves for display.
  final bool hidden;
  final bool keepOpen;

  /// Custom select handler; replaces `onChanged` for action options.
  final VoidCallback? onSelect;

  /// Explicit selection state for action options.
  final bool? selected;

  /// Trailing element (e.g. a folder chevron).
  final Widget? suffix;
}

/// A group of options with an optional section header.
class SimComboboxOptionGroup {
  const SimComboboxOptionGroup({required this.items, this.section});

  final String? section;
  final List<SimComboboxOption> items;
}

/// Port of `packages/emcn/src/components/chip-combobox/chip-combobox.tsx`
/// over `combobox/combobox.tsx`: a 30px `rounded-lg` chip trigger (chip
/// surface tokens, `--text-body`) opening a popover list with search,
/// free-text entry (`editable`), multi-select, groups, loading and error
/// states, per-option icons, and a virtualised list once more than 100
/// options are shown. The list is capped at [maxHeight] (192px).
class SimChipCombobox extends StatefulWidget {
  const SimChipCombobox({
    super.key,
    this.options = const <SimComboboxOption>[],
    this.groups,
    this.value,
    this.onChanged,
    this.multiSelect = false,
    this.multiSelectValues = const <String>[],
    this.onMultiSelectChange,
    this.placeholder = 'Select...',
    this.enabled = true,
    this.editable = false,
    this.searchable = false,
    this.searchPlaceholder = 'Search...',
    this.filterOptions = true,
    this.isLoading = false,
    this.error,
    this.maxHeight = 192,
    this.onOpenChange,
    this.onSearchChange,
    this.fullWidth = true,
    this.semanticsLabel,
  });

  final List<SimComboboxOption> options;
  final List<SimComboboxOptionGroup>? groups;
  final String? value;
  final ValueChanged<String>? onChanged;
  final bool multiSelect;
  final List<String> multiSelectValues;
  final ValueChanged<List<String>>? onMultiSelectChange;
  final String placeholder;
  final bool enabled;

  /// Free-text mode: the trigger is a text field whose value filters the list.
  final bool editable;
  final bool searchable;
  final String searchPlaceholder;
  final bool filterOptions;
  final bool isLoading;
  final String? error;
  final double maxHeight;
  final ValueChanged<bool>? onOpenChange;
  final ValueChanged<String>? onSearchChange;
  final bool fullWidth;
  final String? semanticsLabel;

  /// `VIRTUALIZE_OPTION_THRESHOLD`.
  static const int virtualizeThreshold = 100;

  @override
  State<SimChipCombobox> createState() => _SimChipComboboxState();
}

class _ComboboxRow {
  const _ComboboxRow.section(this.section) : option = null;
  const _ComboboxRow.option(this.option) : section = null;

  final String? section;
  final SimComboboxOption? option;
}

class _SimChipComboboxState extends State<SimChipCombobox> {
  SimPopoverHandle? _popover;
  final FocusNode _focus = FocusNode(debugLabel: 'SimChipCombobox');
  late final TextEditingController _editable = TextEditingController(
    text: _labelFor(widget.value) ?? widget.value ?? '',
  );
  final TextEditingController _search = TextEditingController();
  int _highlight = -1;
  final GlobalKey _anchorKey = GlobalKey();

  @override
  void didUpdateWidget(SimChipCombobox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editable &&
        oldWidget.value != widget.value &&
        !_focus.hasFocus) {
      _editable.text = _labelFor(widget.value) ?? widget.value ?? '';
    }
    _popover?.rebuild();
  }

  @override
  void dispose() {
    _popover?.close();
    _focus.dispose();
    _editable.dispose();
    _search.dispose();
    super.dispose();
  }

  List<SimComboboxOptionGroup> get _sections =>
      widget.groups ??
      <SimComboboxOptionGroup>[SimComboboxOptionGroup(items: widget.options)];

  Iterable<SimComboboxOption> get _all sync* {
    for (final g in _sections) {
      yield* g.items;
    }
  }

  String? _labelFor(String? value) =>
      _all.where((o) => o.value == value).map((o) => o.label).firstOrNull;

  String get _query => widget.editable ? _editable.text : _search.text;

  List<_ComboboxRow> _rows() {
    final query = _query.trim().toLowerCase();
    final filter =
        (!widget.editable || widget.filterOptions) && query.isNotEmpty;
    final rows = <_ComboboxRow>[];
    for (final group in _sections) {
      final items = group.items.where((o) {
        if (o.hidden) return false;
        if (!filter) return true;
        return o.label.toLowerCase().contains(query);
      }).toList();
      if (items.isEmpty) continue;
      if (group.section != null) rows.add(_ComboboxRow.section(group.section));
      rows.addAll(items.map(_ComboboxRow.option));
    }
    return rows;
  }

  bool _isSelected(SimComboboxOption option) {
    if (option.selected != null) return option.selected!;
    if (widget.multiSelect) {
      return widget.multiSelectValues.contains(option.value);
    }
    return widget.value == option.value;
  }

  void _select(SimComboboxOption option) {
    if (!option.enabled) return;
    if (option.onSelect != null) {
      option.onSelect!();
    } else if (widget.multiSelect) {
      final selected = widget.multiSelectValues;
      widget.onMultiSelectChange?.call(
        selected.contains(option.value)
            ? selected.where((v) => v != option.value).toList()
            : <String>[...selected, option.value],
      );
    } else {
      widget.onChanged?.call(option.value);
      if (widget.editable) _editable.text = option.label;
    }
    if (!option.keepOpen && !widget.multiSelect) {
      _popover?.close();
    } else {
      _popover?.rebuild();
    }
  }

  void _moveHighlight(int step) {
    final rows = _rows();
    final selectable = <int>[
      for (var i = 0; i < rows.length; i++)
        if (rows[i].option?.enabled ?? false) i,
    ];
    if (selectable.isEmpty) return;
    final pos = selectable.indexOf(_highlight);
    setState(() {
      _highlight = pos < 0
          ? (step > 0 ? selectable.first : selectable.last)
          : selectable[(pos + step + selectable.length) % selectable.length];
    });
    _popover?.rebuild();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final open = _popover?.isOpen ?? false;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!open) {
        _open();
      } else {
        _moveHighlight(1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && open) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (open && event is KeyDownEvent && isKeyboardActivation(event)) {
      if (widget.editable && key == LogicalKeyboardKey.space) {
        return KeyEventResult.ignored;
      }
      final rows = _rows();
      if (_highlight >= 0 && _highlight < rows.length) {
        final option = rows[_highlight].option;
        if (option != null) _select(option);
        return KeyEventResult.handled;
      }
      if (widget.editable && key != LogicalKeyboardKey.space) {
        widget.onChanged?.call(_editable.text);
        _popover?.close();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _open() {
    if (_popover?.isOpen ?? false) return;
    _highlight = -1;
    _search.clear();
    widget.onOpenChange?.call(true);
    _popover = SimPopover.show(
      _anchorKey.currentContext!,
      matchAnchorWidth: true,
      sideOffset: 4,
      maxHeight:
          widget.maxHeight +
          2 * SimMenuStyles.padding.top +
          (widget.searchable ? 36 : 0),
      builder: _buildList,
      onClose: () {
        _popover = null;
        _highlight = -1;
        if (mounted) widget.onOpenChange?.call(false);
      },
    );
  }

  Widget _buildList(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final rows = _rows();
    final virtualize = rows.length > SimChipCombobox.virtualizeThreshold;
    const rowHeight = SimLayoutRow.height;
    Widget body;
    if (widget.isLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SimSpinner()),
      );
    } else if (widget.error != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          widget.error!,
          style: sim.text.caption.copyWith(color: c.textError),
        ),
      );
    } else if (rows.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Text(
          'No results',
          textAlign: TextAlign.center,
          style: sim.text.small.copyWith(color: c.textMuted),
        ),
      );
    } else {
      Widget rowBuilder(BuildContext context, int index) {
        final row = rows[index];
        if (row.section != null) return SimMenuHeading(row.section!);
        final option = row.option!;
        return SimMenuRow(
          label: option.label,
          icon: option.icon,
          leading: option.leading,
          trailing: option.suffix,
          enabled: option.enabled,
          highlighted: _highlight == index,
          selected: _isSelected(option),
          onHover: () {
            if (_highlight != index) {
              setState(() => _highlight = index);
              _popover?.rebuild();
            }
          },
          onPressed: () => _select(option),
        );
      }

      final height = math.min(widget.maxHeight, rows.length * rowHeight);
      body = SizedBox(
        height: height,
        child: virtualize
            ? ListView.builder(
                itemCount: rows.length,
                itemExtent: rowHeight,
                itemBuilder: rowBuilder,
              )
            : ListView(
                children: <Widget>[
                  for (var i = 0; i < rows.length; i++)
                    SizedBox(height: rowHeight, child: rowBuilder(context, i)),
                ],
              ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.searchable)
          SimMenuSearchField(
            controller: _search,
            placeholder: widget.searchPlaceholder,
            onChanged: (v) {
              widget.onSearchChange?.call(v);
              _highlight = -1;
              _popover?.rebuild();
            },
            onNavigationKey: (event) => _onKey(_focus, event),
          ),
        body,
      ],
    );
  }

  String get _displayLabel {
    if (widget.multiSelect) {
      final n = widget.multiSelectValues.length;
      if (n == 0) return widget.placeholder;
      if (n == 1) {
        return _labelFor(widget.multiSelectValues.first) ?? widget.placeholder;
      }
      return '$n selected';
    }
    return _labelFor(widget.value) ?? widget.value ?? widget.placeholder;
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final hasValue = widget.multiSelect
        ? widget.multiSelectValues.isNotEmpty
        : (widget.value != null && widget.value!.isNotEmpty);
    final textStyle = sim.text.sm.copyWith(
      color: hasValue ? c.textBody : c.textMuted,
    );
    Widget content;
    if (widget.editable) {
      content = SimEditable(
        controller: _editable,
        focusNode: _focus,
        placeholder: widget.placeholder,
        style: sim.text.sm.copyWith(color: c.textBody),
        enabled: widget.enabled,
        onChanged: (v) {
          widget.onChanged?.call(v);
          _highlight = -1;
          if (!(_popover?.isOpen ?? false)) _open();
          _popover?.rebuild();
        },
        onKeyEvent: _onKey,
        onFocusChanged: (focused) {
          if (focused && !(_popover?.isOpen ?? false)) _open();
        },
      );
    } else {
      content = SimOverflowText(label: _displayLabel, style: textStyle);
    }
    return SimPressable(
      key: _anchorKey,
      onPressed: widget.editable ? null : _open,
      enabled: widget.enabled,
      focusNode: widget.editable ? null : _focus,
      onKeyEvent: widget.editable ? null : _onKey,
      semanticsLabel: widget.semanticsLabel ?? _displayLabel,
      excludeSemantics: widget.editable,
      builder: (context, state) => Opacity(
        opacity: widget.enabled ? 1 : SimChipChrome.fieldDisabledOpacity,
        child: AnimatedContainer(
          duration: SimMotion.of(SimMotion.colors),
          height: SimChipChrome.height,
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(
            horizontal: SimChipChrome.paddingX,
          ),
          decoration: SimChipChrome.fieldSurface(
            c,
            error: widget.error != null && !widget.isLoading,
          ),
          child: Row(
            mainAxisSize: widget.fullWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            spacing: SimChipChrome.gap,
            children: <Widget>[
              Flexible(
                fit: widget.fullWidth ? FlexFit.tight : FlexFit.loose,
                child: content,
              ),
              if (widget.isLoading)
                const SimSpinner()
              else
                const SimChipChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row height constants shared by combobox lists.
abstract final class SimLayoutRow {
  static const double height = SimMenuStyles.headingHeight;
}

/// Convenience alias kept for API parity with the upstream `Combobox` export.
typedef SimCombobox = SimChipCombobox;

/// Re-exported so consumers can build custom rows with the chip chevron.
typedef SimComboboxChevron = SimChipChevron;

/// Re-exported icon alias used by option builders.
const SimIconData simComboboxCheckIcon = SimIcons.check;
