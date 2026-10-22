import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/keyboard.dart';
import 'package:sim_design/src/overlay/anchored.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/widgets/button.dart';
import 'package:sim_design/src/widgets/chip/chip.dart';
import 'package:sim_design/src/widgets/chip/chip_dropdown.dart';
import 'package:sim_design/src/widgets/chip/chip_input.dart';
import 'package:sim_design/src/widgets/chip/chip_switch.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';
import 'package:sim_design/src/widgets/fields/editable.dart';
import 'package:sim_design/src/widgets/modal/modal.dart';
import 'package:sim_design/src/widgets/overflow_text.dart';
import 'package:sim_design/src/widgets/text_bits.dart';
import 'package:sim_design/src/widgets/tooltip.dart';

/// The modal's keyboard default: Enter in a single-line field fires the
/// primary action only for [primary].
enum SimChipModalDefaultAction { primary, dismiss, none }

/// Registers the footer's primary action so single-line fields can submit it
/// on Enter (`data-chip-modal-submit-action`).
class SimChipModalScope extends InheritedWidget {
  const SimChipModalScope({
    required this.registry,
    required super.child,
    super.key,
  });

  final SimChipModalRegistry registry;

  static SimChipModalRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SimChipModalScope>()?.registry;

  @override
  bool updateShouldNotify(SimChipModalScope oldWidget) =>
      registry != oldWidget.registry;
}

class SimChipModalRegistry {
  VoidCallback? _primary;
  bool _primaryEnabled = false;

  void setPrimary(VoidCallback? action, {required bool enabled}) {
    _primary = action;
    _primaryEnabled = enabled;
  }

  /// Fires the primary action when one is registered and enabled.
  bool submitPrimary() {
    if (_primary == null || !_primaryEnabled) return false;
    _primary!();
    return true;
  }
}

/// Opens a [SimChipModalSurface] inside a bare [showSimModal].
Future<T?> showSimChipModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  SimModalSize size = SimModalSize.md,
  bool Function()? dismissDisabled,
  String semanticsLabel = 'Dialog',
  double sidebarInset = 0,
}) => showSimModal<T>(
  context,
  size: size,
  bare: true,
  dismissDisabled: dismissDisabled,
  semanticsLabel: semanticsLabel,
  sidebarInset: sidebarInset,
  builder: (context) => SimChipModalSurface(child: Builder(builder: builder)),
);

/// `ChipModalSurface` (`packages/emcn/src/components/chip-modal/chip-modal.tsx`):
/// the outer `rounded-xl` ring on `--surface-4` (dark `--surface-5`) with a
/// 3px inset and 1px `--border`, holding the inner `rounded-lg` `--bg` panel.
class SimChipModalSurface extends StatefulWidget {
  const SimChipModalSurface({required this.child, super.key});

  final Widget child;

  @override
  State<SimChipModalSurface> createState() => _SimChipModalSurfaceState();
}

class _SimChipModalSurfaceState extends State<SimChipModalSurface> {
  final SimChipModalRegistry _registry = SimChipModalRegistry();

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return SimChipModalScope(
      registry: _registry,
      child: Container(
        padding: const EdgeInsets.all(SimLayout.chipModalShellPadding),
        decoration: BoxDecoration(
          color: sim.isDark ? c.surface5 : c.surface4,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(SimRadii.xl),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SimRadii.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.bg,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(SimRadii.lg),
            ),
            child: DefaultTextStyle.merge(
              style: sim.text.small.copyWith(color: c.textPrimary),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[widget.child],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `ChipModalSeparator`: the 1px `--border` hairline.
class SimChipModalSeparator extends StatelessWidget {
  const SimChipModalSeparator({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: SimLayout.borderWidth,
    child: ColoredBox(color: SimTheme.of(context).colors.border),
  );
}

/// `ChipModalHeader`: icon (16px), title (chip label), close button (14px
/// glyph, ghost, 14px extended hit area); px-4 pt-3, separator mt-3.
class SimChipModalHeader extends StatelessWidget {
  const SimChipModalHeader({
    required this.title,
    super.key,
    this.icon,
    this.onClose,
    this.closeEnabled = true,
    this.closeLabel = 'Close',
  });

  final String title;
  final SimIconData? icon;

  /// Defaults to closing the enclosing modal.
  final VoidCallback? onClose;
  final bool closeEnabled;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final modal = SimModalScope.maybeOf(context);
    final dismissDisabled = modal?.dismissDisabled ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: SimLayout.chipModalHeaderPaddingX,
            right: SimLayout.chipModalHeaderPaddingX,
            top: SimLayout.chipModalHeaderPaddingTop,
          ),
          child: Row(
            spacing: 8,
            children: <Widget>[
              Expanded(
                child: Row(
                  spacing: 8,
                  children: <Widget>[
                    if (icon != null)
                      SimIcon(icon!, size: SimChipChrome.contentIconSize),
                    Expanded(
                      child: SimOverflowText(
                        label: title,
                        style: sim.text.sm.copyWith(color: c.textBody),
                      ),
                    ),
                  ],
                ),
              ),
              SimButton(
                variant: SimButtonVariant.ghost,
                width: 14,
                height: 14,
                padding: EdgeInsets.zero,
                hitSlop: const EdgeInsets.all(14),
                enabled: closeEnabled && !dismissDisabled,
                semanticsLabel: closeLabel,
                onPressed: onClose ?? modal?.close,
                child: SimIcon(SimIcons.x, color: c.textIcon),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SimChipModalSeparator(),
      ],
    );
  }
}

/// `ChipModalTabs`: a [SimChipSwitch] at the top of a body.
class SimChipModalTabs extends StatelessWidget {
  const SimChipModalTabs({
    required this.tabs,
    required this.value,
    required this.onChanged,
    super.key,
    this.semanticsLabel,
  });

  final List<SimChipSwitchOption<String>> tabs;
  final String value;
  final ValueChanged<String> onChanged;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: SimChipSwitch<String>(
      options: tabs,
      value: value,
      onChanged: onChanged,
      semanticsLabel: semanticsLabel,
    ),
  );
}

/// `ChipModalBody`: fields on a 16px rhythm with the 8px gutter, pt-4 pb-4.5,
/// scrolling internally so header and footer stay pinned. [fullBleed] drops
/// the gutter and scrolling for one edge-to-edge surface.
class SimChipModalBody extends StatelessWidget {
  const SimChipModalBody({
    required this.children,
    super.key,
    this.fullBleed = false,
  });

  final List<Widget> children;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    if (fullBleed) {
      return Flexible(
        child: ClipRect(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
    }
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SimLayout.chipModalFieldGutter,
          SimLayout.chipModalBodyPaddingTop,
          SimLayout.chipModalFieldGutter,
          SimLayout.chipModalBodyPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: SimLayout.chipModalBodyGap,
          children: children,
        ),
      ),
    );
  }
}

/// `ChipModalDescription`: message copy, px-2 text-sm `--text-primary`.
class SimChipModalDescription extends StatelessWidget {
  const SimChipModalDescription({super.key, this.text, this.spans});

  final String? text;
  final List<InlineSpan>? spans;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final style = sim.text.sm.copyWith(color: sim.colors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text.rich(
        TextSpan(text: text, children: spans, style: style),
        style: style,
      ),
    );
  }
}

/// `ChipModalError`: a standalone submit error below the fields.
class SimChipModalError extends StatelessWidget {
  const SimChipModalError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    final sim = SimTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
      child: Text(
        message!,
        style: sim.text.caption.copyWith(color: sim.colors.textError),
      ),
    );
  }
}

/// `ChipModalField`: a labelled row — muted title (pl-0.5, `*` when
/// required), a 9px gap, the control, then an inline error or hint in
/// text-caption. Named constructors build the canonical controls; the default
/// constructor is the `custom` escape hatch.
class SimChipModalField extends StatelessWidget {
  const SimChipModalField({
    required this.title,
    required this.child,
    super.key,
    this.titleActions,
    this.required = false,
    this.error,
    this.hint,
    this.enabled = true,
    this.flush = false,
  });

  /// `type='input'` / `'email'` / `'password'`.
  SimChipModalField.input({
    required this.title,
    required TextEditingController controller,
    super.key,
    String? placeholder,
    bool password = false,
    bool email = false,
    bool mono = false,
    int? maxLength,
    ValueChanged<String>? onChanged,
    VoidCallback? onSubmit,
    bool submitOnEnter = true,
    TextInputType? keyboardType,
    this.titleActions,
    this.required = false,
    this.error,
    this.hint,
    this.enabled = true,
    this.flush = false,
  }) : child = _ChipModalInputControl(
         controller: controller,
         placeholder: placeholder,
         password: password,
         email: email,
         mono: mono,
         maxLength: maxLength,
         onChanged: onChanged,
         onSubmit: onSubmit,
         submitOnEnter: submitOnEnter,
         keyboardType: keyboardType,
         enabled: enabled,
         error: error != null,
         semanticsLabel: title,
       );

  /// `type='textarea'`.
  SimChipModalField.textarea({
    required this.title,
    required TextEditingController controller,
    super.key,
    String? placeholder,
    int rows = 3,
    double? minHeight,
    bool mono = false,
    bool viewOnly = false,
    int? maxLength,
    ValueChanged<String>? onChanged,
    this.titleActions,
    this.required = false,
    this.error,
    this.hint,
    this.enabled = true,
    this.flush = false,
  }) : child = SimChipTextarea(
         controller: controller,
         placeholder: placeholder,
         rows: rows,
         minHeight: minHeight,
         mono: mono,
         viewOnly: viewOnly,
         maxLength: maxLength,
         onChanged: onChanged,
         enabled: enabled,
         error: error != null,
         semanticsLabel: title,
       );

  /// `type='copy'`.
  SimChipModalField.copy({
    required this.title,
    required String value,
    super.key,
    String copyLabel = 'Copy',
    this.titleActions,
    this.hint,
    this.enabled = true,
    this.flush = false,
  }) : child = SimChipCopyInput(
         value: value,
         copyLabel: copyLabel,
         enabled: enabled,
         semanticsLabel: title,
       ),
       required = false,
       error = null;

  /// `type='dropdown'`.
  SimChipModalField.dropdown({
    required this.title,
    required List<SimChipDropdownOption> options,
    required ValueChanged<String> onChanged,
    super.key,
    String? value,
    String? placeholder,
    SimAlign align = SimAlign.end,
    this.titleActions,
    this.required = false,
    this.error,
    this.hint,
    this.enabled = true,
    this.flush = false,
  }) : child = SimChipDropdown(
         options: options,
         value: value,
         onChanged: onChanged,
         placeholder: placeholder,
         align: align,
         enabled: enabled,
         fullWidth: true,
         semanticsLabel: title,
       );

  final String title;
  final Widget child;
  final Widget? titleActions;
  final bool required;
  final String? error;
  final String? hint;
  final bool enabled;
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final label = Padding(
      padding: const EdgeInsets.only(left: 2),
      child: SimLabel(title, muted: true, required: required),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: flush ? 0 : SimLayout.chipModalFieldGutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SimLayout.chipModalLabelGap,
        children: <Widget>[
          if (titleActions != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 8,
              children: <Widget>[label, titleActions!],
            )
          else
            Align(alignment: AlignmentDirectional.centerStart, child: label),
          child,
          if (error != null)
            Text(error!, style: sim.text.caption.copyWith(color: c.textError))
          else if (hint != null)
            Text(hint!, style: sim.text.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

/// Single-line control with the Enter policy and the password treatment
/// (masked while unfocused, revealed while focused, eye toggle pins it).
class _ChipModalInputControl extends StatefulWidget {
  const _ChipModalInputControl({
    required this.controller,
    required this.placeholder,
    required this.password,
    required this.email,
    required this.mono,
    required this.maxLength,
    required this.onChanged,
    required this.onSubmit,
    required this.submitOnEnter,
    required this.keyboardType,
    required this.enabled,
    required this.error,
    required this.semanticsLabel,
  });

  final TextEditingController controller;
  final String? placeholder;
  final bool password;
  final bool email;
  final bool mono;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;
  final bool submitOnEnter;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool error;
  final String semanticsLabel;

  @override
  State<_ChipModalInputControl> createState() => _ChipModalInputControlState();
}

class _ChipModalInputControlState extends State<_ChipModalInputControl> {
  final GlobalKey<SimEditableState> _editable = GlobalKey<SimEditableState>();
  final FocusNode _focus = FocusNode(debugLabel: 'ChipModalInput');
  bool _revealed = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    setState(() {
      _focused = _focus.hasFocus;
      if (!_focused) _revealed = false;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!isPlainEnter(event)) return KeyEventResult.ignored;
    if (widget.onSubmit != null) {
      widget.onSubmit!();
      return KeyEventResult.handled;
    }
    if (!widget.submitOnEnter) return KeyEventResult.handled;
    final registry = SimChipModalScope.maybeOf(context);
    if (registry?.submitPrimary() ?? false) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final masked = widget.password && !(_focused || _revealed);
    return SimModalAutoFocus(
      editableKey: _editable,
      child: SimChipInput(
        editableKey: _editable,
        controller: widget.controller,
        focusNode: _focus,
        placeholder: widget.placeholder,
        enabled: widget.enabled,
        error: widget.error,
        mono: widget.mono,
        maxLength: widget.maxLength,
        obscureText: masked,
        keyboardType:
            widget.keyboardType ??
            (widget.email ? TextInputType.emailAddress : null),
        onChanged: widget.onChanged,
        onKeyEvent: _onKey,
        semanticsLabel: widget.semanticsLabel,
        endAdornment: widget.password && widget.controller.text.isNotEmpty
            ? SimButton(
                variant: SimButtonVariant.ghost,
                width: 24,
                height: 24,
                padding: EdgeInsets.zero,
                enabled: widget.enabled,
                semanticsLabel: _revealed ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _revealed = !_revealed),
                child: SimIcon(
                  _revealed ? SimIcons.eyeOff : SimIcons.eye,
                  color: c.textMuted,
                ),
              )
            : null,
      ),
    );
  }
}

/// A declarative footer action rendered as a chip.
class SimChipModalAction {
  const SimChipModalAction({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.disabledTooltip,
    this.variant,
    this.leftAdornment,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  /// Shown while disabled; honoured on the primary action only.
  final String? disabledTooltip;

  /// `primary` (default for the primary action) or `destructive`.
  final SimChipVariant? variant;
  final Widget? leftAdornment;
}

/// `ChipModalFooterShell`: separator + tinted `--surface-3` bar, px-4 py-2.
class SimChipModalFooterShell extends StatelessWidget {
  const SimChipModalFooterShell({
    required this.children,
    super.key,
    this.leading,
  });

  final List<Widget> children;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SimChipModalSeparator(),
        Container(
          color: c.surface3,
          padding: const EdgeInsets.symmetric(
            horizontal: SimLayout.chipModalFooterPaddingX,
            vertical: SimLayout.chipModalFooterPaddingY,
          ),
          child: Row(
            mainAxisAlignment: leading != null
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            spacing: 8,
            children: <Widget>[
              if (leading != null) Flexible(child: leading!),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: children,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `ChipModalFooter`: Cancel plus the right-anchored primary action, an
/// optional primary-adjacent action, far-left secondary actions and leading
/// content. The primary action registers for Enter submission.
class SimChipModalFooter extends StatefulWidget {
  const SimChipModalFooter({
    super.key,
    this.onCancel,
    this.cancelLabel = 'Cancel',
    this.cancelEnabled = true,
    this.hideCancel = false,
    this.defaultAction = SimChipModalDefaultAction.primary,
    this.primaryAction,
    this.primaryAdjacentAction,
    this.secondaryActions = const <Widget>[],
    this.leadingContent,
  });

  /// Defaults to closing the enclosing modal.
  final VoidCallback? onCancel;
  final String cancelLabel;
  final bool cancelEnabled;
  final bool hideCancel;
  final SimChipModalDefaultAction defaultAction;
  final SimChipModalAction? primaryAction;
  final Widget? primaryAdjacentAction;
  final List<Widget> secondaryActions;
  final Widget? leadingContent;

  @override
  State<SimChipModalFooter> createState() => _SimChipModalFooterState();
}

class _SimChipModalFooterState extends State<SimChipModalFooter> {
  void _register() {
    final registry = SimChipModalScope.maybeOf(context);
    final primary = widget.primaryAction;
    registry?.setPrimary(
      widget.defaultAction == SimChipModalDefaultAction.primary
          ? primary?.onPressed
          : null,
      enabled: primary?.enabled ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    _register();
    final modal = SimModalScope.maybeOf(context);
    final dismissDisabled = modal?.dismissDisabled ?? false;
    final primary = widget.primaryAction;
    final showsTooltip =
        primary != null && !primary.enabled && primary.disabledTooltip != null;
    Widget? primaryChip = primary == null
        ? null
        : SimChip(
            label: primary.label,
            variant: primary.variant ?? SimChipVariant.primary,
            leftAdornment: primary.leftAdornment,
            enabled: primary.enabled,
            onPressed: primary.onPressed,
          );
    if (showsTooltip && primaryChip != null) {
      primaryChip = SimTooltip(
        message: primary.disabledTooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.forbidden,
          child: primaryChip,
        ),
      );
    }
    final hasLeft =
        widget.leadingContent != null || widget.secondaryActions.isNotEmpty;
    return SimChipModalFooterShell(
      leading: hasLeft
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ?widget.leadingContent,
                ...widget.secondaryActions,
              ],
            )
          : null,
      children: <Widget>[
        if (!widget.hideCancel)
          SimChip(
            label: widget.cancelLabel,
            enabled: widget.cancelEnabled && !dismissDisabled,
            onPressed: widget.onCancel ?? modal?.close,
          ),
        ?widget.primaryAdjacentAction,
        ?primaryChip,
      ],
    );
  }
}

/// A run of confirmation copy (`ChipConfirmTextSegment`).
class SimConfirmTextSegment {
  const SimConfirmTextSegment(
    this.text, {
    this.bold = false,
    this.error = false,
  });

  final String text;
  final bool bold;
  final bool error;
}

/// The confirming action of a confirmation modal.
class SimChipConfirmAction {
  const SimChipConfirmAction({
    required this.label,
    required this.onPressed,
    this.variant = SimChipVariant.destructive,
    this.pending = false,
    this.pendingLabel,
    this.enabled = true,
    this.disabledTooltip,
  });

  final String label;
  final VoidCallback onPressed;
  final SimChipVariant variant;
  final bool pending;
  final String? pendingLabel;
  final bool enabled;
  final String? disabledTooltip;
}

/// `ChipConfirmModal`: a compact "are you sure?" dialog — header with close,
/// message copy (plain or emphasised segments), optional extra body content,
/// a named dismiss button and the (usually destructive) confirm. Dismissal is
/// refused while the confirm is pending. [confirm] is re-read on every
/// rebuild of the enclosing widget, so pending state flows through.
Future<void> showSimChipConfirmModal(
  BuildContext context, {
  required String title,
  required SimChipConfirmAction Function() confirm,
  SimIconData? icon,
  String? text,
  List<SimConfirmTextSegment>? segments,
  WidgetBuilder? body,
  SimChipModalDefaultAction defaultAction = SimChipModalDefaultAction.dismiss,
  String dismissLabel = 'Cancel',
  SimModalSize size = SimModalSize.sm,
  double sidebarInset = 0,
}) => showSimChipModal<void>(
  context,
  size: size,
  semanticsLabel: title,
  dismissDisabled: () => confirm().pending,
  sidebarInset: sidebarInset,
  builder: (context) => _ConfirmModalContent(
    title: title,
    icon: icon,
    text: text,
    segments: segments,
    body: body,
    confirm: confirm,
    defaultAction: defaultAction,
    dismissLabel: dismissLabel,
  ),
);

class _ConfirmModalContent extends StatelessWidget {
  const _ConfirmModalContent({
    required this.title,
    required this.icon,
    required this.text,
    required this.segments,
    required this.body,
    required this.confirm,
    required this.defaultAction,
    required this.dismissLabel,
  });

  final String title;
  final SimIconData? icon;
  final String? text;
  final List<SimConfirmTextSegment>? segments;
  final WidgetBuilder? body;
  final SimChipConfirmAction Function() confirm;
  final SimChipModalDefaultAction defaultAction;
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final action = confirm();
    final modal = SimModalScope.of(context);
    final label = action.pending
        ? (action.pendingLabel ?? action.label)
        : action.label;
    final disabled = !action.enabled || action.pending;
    Widget confirmChip = SimChip(
      label: label,
      variant: action.variant,
      enabled: !disabled,
      onPressed: action.onPressed,
    );
    if (disabled && action.disabledTooltip != null) {
      confirmChip = SimTooltip(
        message: action.disabledTooltip,
        child: confirmChip,
      );
    }
    final hasText =
        (text != null && text!.isNotEmpty) ||
        (segments?.any((s) => s.text.isNotEmpty) ?? false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SimChipModalHeader(title: title, icon: icon),
        SimChipModalBody(
          children: <Widget>[
            if (hasText)
              SimChipModalDescription(
                text: segments == null ? text : null,
                spans: segments == null
                    ? null
                    : <InlineSpan>[
                        for (final s in segments!)
                          TextSpan(
                            text: s.text,
                            style: TextStyle(
                              fontWeight: s.bold ? FontWeight.w500 : null,
                              fontVariations: s.bold
                                  ? const <FontVariation>[
                                      FontVariation('wght', 500),
                                    ]
                                  : null,
                              color: s.error ? c.textError : null,
                            ),
                          ),
                      ],
              ),
            if (body != null) body!(context),
          ],
        ),
        _ConfirmFooter(
          defaultAction: defaultAction,
          dismissLabel: dismissLabel,
          dismissEnabled: !action.pending,
          onDismiss: modal.close,
          confirmEnabled: !disabled,
          onConfirm: action.onPressed,
          child: confirmChip,
        ),
      ],
    );
  }
}

class _ConfirmFooter extends StatelessWidget {
  const _ConfirmFooter({
    required this.defaultAction,
    required this.dismissLabel,
    required this.dismissEnabled,
    required this.onDismiss,
    required this.confirmEnabled,
    required this.onConfirm,
    required this.child,
  });

  final SimChipModalDefaultAction defaultAction;
  final String dismissLabel;
  final bool dismissEnabled;
  final VoidCallback onDismiss;
  final bool confirmEnabled;
  final VoidCallback onConfirm;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    SimChipModalScope.maybeOf(context)?.setPrimary(
      defaultAction == SimChipModalDefaultAction.primary ? onConfirm : null,
      enabled: confirmEnabled,
    );
    return SimChipModalFooterShell(
      children: <Widget>[
        SimChip(
          label: dismissLabel,
          enabled: dismissEnabled,
          onPressed: onDismiss,
        ),
        child,
      ],
    );
  }
}
