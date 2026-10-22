import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_design/sim_design.dart';

/// The error text of a failed request (`getErrorMessage(err, fallback)`).
String errorMessageOf(Object error, String fallback) => switch (error) {
  final ApiClientError e when e.message.isNotEmpty => e.message,
  _ => fallback,
};

/// Opens `CreateWorkspaceModal` (`create-workspace-modal.tsx:415-476`,
/// `modal.create-workspace`; the switcher spec's
/// `workspace.switcher.create-modal` is an alias). [onConfirm] creates the
/// workspace and switches to it (`WorkspaceSwitcherActions.create`); on
/// success the modal closes, a thrown error shows in the modal
/// ([describeError], default `getErrorMessage(err, 'Failed to create
/// workspace')`) and the modal stays open.
Future<void> showCreateWorkspaceModal(
  BuildContext context, {
  required Future<void> Function(String name) onConfirm,
  String Function(Object error)? describeError,
}) {
  final pending = ValueNotifier<bool>(false);
  return showSimChipModal<void>(
    context,
    semanticsLabel: 'Create workspace',
    dismissDisabled: () => pending.value,
    builder: (context) => CreateWorkspaceModal(
      pending: pending,
      onConfirm: onConfirm,
      describeError:
          describeError ??
          (error) => errorMessageOf(error, 'Failed to create workspace'),
    ),
  ).whenComplete(pending.dispose);
}

/// The modal body; mounted fresh on every open, so the name and error
/// always start empty.
class CreateWorkspaceModal extends StatefulWidget {
  const CreateWorkspaceModal({
    required this.pending,
    required this.onConfirm,
    required this.describeError,
    super.key,
  });

  /// Mirrors the creating flag for the modal's `dismissDisabled`.
  final ValueNotifier<bool> pending;
  final Future<void> Function(String name) onConfirm;
  final String Function(Object error) describeError;

  @override
  State<CreateWorkspaceModal> createState() => _CreateWorkspaceModalState();
}

class _CreateWorkspaceModalState extends State<CreateWorkspaceModal> {
  final TextEditingController _name = TextEditingController();
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(_rebuild);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit => _name.text.trim().isNotEmpty && !_creating;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final close = SimModalScope.of(context).close;
    setState(() {
      _creating = true;
      _error = null;
    });
    widget.pending.value = true;
    try {
      await widget.onConfirm(_name.text.trim());
      widget.pending.value = false;
      close();
    } on Object catch (error) {
      widget.pending.value = false;
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = widget.describeError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SimChipModalScope.maybeOf(
      context,
    )?.setPrimary(() => unawaited(_submit()), enabled: _canSubmit);
    final modal = SimModalScope.of(context);
    return Semantics(
      identifier: 'modal.create-workspace',
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SimChipModalHeader(title: 'Create workspace'),
          SimChipModalBody(
            children: <Widget>[
              Semantics(
                identifier: 'modal.create-workspace.name',
                container: true,
                child: SimChipModalField.input(
                  title: 'Name',
                  controller: _name,
                  placeholder: 'Workspace name',
                  maxLength: 100,
                  required: true,
                  enabled: !_creating,
                ),
              ),
              SimChipModalError(_error),
            ],
          ),
          SimChipModalFooterShell(
            children: <Widget>[
              SimChip(
                label: 'Cancel',
                enabled: !_creating,
                onPressed: modal.close,
              ),
              Semantics(
                identifier: 'modal.create-workspace.submit',
                container: true,
                child: SimChip(
                  label: _creating ? 'Creating...' : 'Create',
                  variant: SimChipVariant.primary,
                  enabled: _canSubmit,
                  onPressed: () => unawaited(_submit()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
