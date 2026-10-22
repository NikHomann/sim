import 'package:flutter/material.dart';
import 'package:sim_design/sim_design.dart';

/// The `ChipConfirmModal` composition (`chip-modal.tsx:1655-1720`) with the
/// state owned by the caller, so pending labels, the disabled confirm and a
/// type-to-confirm body follow the caller's rebuilds: header with close,
/// message copy (plain or emphasised segments), optional body, then the
/// dismiss chip and the (destructive by default) confirm chip.
///
/// [defaultAction] decides what a plain Enter inside the modal does:
/// [SimChipModalDefaultAction.dismiss] activates the dismiss chip,
/// [SimChipModalDefaultAction.primary] the confirm chip,
/// [SimChipModalDefaultAction.none] nothing.
class ConfirmModalFrame extends StatelessWidget {
  const ConfirmModalFrame({
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onDismiss,
    super.key,
    this.parityId,
    this.confirmParityId,
    this.segments,
    this.text,
    this.body,
    this.pending = false,
    this.pendingLabel,
    this.confirmEnabled = true,
    this.confirmVariant = SimChipVariant.destructive,
    this.dismissLabel = 'Cancel',
    this.defaultAction = SimChipModalDefaultAction.dismiss,
  });

  final String title;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;
  final String? parityId;
  final String? confirmParityId;
  final List<SimConfirmTextSegment>? segments;
  final String? text;
  final Widget? body;
  final bool pending;
  final String? pendingLabel;
  final bool confirmEnabled;
  final SimChipVariant confirmVariant;
  final String dismissLabel;
  final SimChipModalDefaultAction defaultAction;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!isPlainEnter(event)) return KeyEventResult.ignored;
    switch (defaultAction) {
      case SimChipModalDefaultAction.dismiss:
        if (!pending) onDismiss();
        return KeyEventResult.handled;
      case SimChipModalDefaultAction.primary:
        if (confirmEnabled && !pending) onConfirm();
        return KeyEventResult.handled;
      case SimChipModalDefaultAction.none:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final disabled = !confirmEnabled || pending;
    final label = pending ? (pendingLabel ?? confirmLabel) : confirmLabel;
    final hasText =
        (text != null && text!.isNotEmpty) ||
        (segments?.any((s) => s.text.isNotEmpty) ?? false);
    Widget confirmChip = SimChip(
      label: label,
      variant: confirmVariant,
      enabled: !disabled,
      onPressed: onConfirm,
    );
    if (confirmParityId != null) {
      confirmChip = Semantics(
        identifier: confirmParityId,
        container: true,
        child: confirmChip,
      );
    }
    final content = Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SimChipModalHeader(
            title: title,
            onClose: onDismiss,
            closeEnabled: !pending,
          ),
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
              ?body,
            ],
          ),
          SimChipModalFooterShell(
            children: <Widget>[
              SimChip(
                label: dismissLabel,
                enabled: !pending,
                onPressed: onDismiss,
              ),
              confirmChip,
            ],
          ),
        ],
      ),
    );
    if (parityId == null) return content;
    return Semantics(identifier: parityId, container: true, child: content);
  }
}
