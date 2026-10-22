import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/features/workspace_shell/modals/confirm_modal_frame.dart';
import 'package:sim_app/features/workspace_shell/modals/create_workspace_modal.dart';
import 'package:sim_design/sim_design.dart';

/// Opens the delete-workspace confirm (`delete-modal.tsx` with
/// `itemType='workspace'`, `modal.delete-workspace`; the switcher spec's
/// `workspace.switcher.delete-modal` is an alias): type the exact name to
/// enable "Delete"; Enter never confirms. [onConfirm] deletes and, for the
/// current workspace, switches away (`WorkspaceSwitcherActions.delete`).
/// The modal closes afterwards whether or not it threw: upstream
/// `confirmDeleteWorkspace` logs and swallows the error and
/// `handleDeleteWorkspace` then closes.
Future<void> showDeleteWorkspaceModal(
  BuildContext context, {
  required String workspaceName,
  required Future<void> Function() onConfirm,
}) {
  final pending = ValueNotifier<bool>(false);
  return showSimChipModal<void>(
    context,
    size: SimModalSize.sm,
    semanticsLabel: 'Delete workspace',
    dismissDisabled: () => pending.value,
    builder: (context) => DeleteWorkspaceModal(
      workspaceName: workspaceName,
      pending: pending,
      onConfirm: onConfirm,
    ),
  ).whenComplete(pending.dispose);
}

class DeleteWorkspaceModal extends StatefulWidget {
  const DeleteWorkspaceModal({
    required this.workspaceName,
    required this.pending,
    required this.onConfirm,
    super.key,
  });

  final String workspaceName;
  final ValueNotifier<bool> pending;
  final Future<void> Function() onConfirm;

  @override
  State<DeleteWorkspaceModal> createState() => _DeleteWorkspaceModalState();
}

class _DeleteWorkspaceModalState extends State<DeleteWorkspaceModal> {
  final TextEditingController _confirmation = TextEditingController();
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _confirmation.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  String get _name => widget.workspaceName;

  Future<void> _confirm() async {
    if (_confirmation.text != _name || _deleting) return;
    final close = SimModalScope.of(context).close;
    setState(() => _deleting = true);
    widget.pending.value = true;
    try {
      await widget.onConfirm();
    } on Object catch (error) {
      developer.log(
        'Error deleting workspace',
        name: 'sim_app.workspaces',
        error: error,
      );
    }
    widget.pending.value = false;
    close();
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final hasName = _name.isNotEmpty;
    return ConfirmModalFrame(
      parityId: 'modal.delete-workspace',
      confirmParityId: 'modal.delete-workspace.confirm',
      title: 'Delete workspace',
      defaultAction: SimChipModalDefaultAction.none,
      segments: <SimConfirmTextSegment>[
        if (hasName) ...<SimConfirmTextSegment>[
          const SimConfirmTextSegment('Are you sure you want to delete '),
          SimConfirmTextSegment(_name, bold: true),
          const SimConfirmTextSegment('? '),
        ] else
          const SimConfirmTextSegment(
            'Are you sure you want to delete this workspace? ',
          ),
        const SimConfirmTextSegment(
          'This will permanently remove all associated workflows, tables, '
          'files, logs, and knowledge bases.',
          error: true,
        ),
        const SimConfirmTextSegment(' This action cannot be undone.'),
      ],
      body: Semantics(
        identifier: 'modal.delete-workspace.confirm-input',
        container: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SimLayout.chipModalFieldGutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: SimLayout.chipModalLabelGap,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      const TextSpan(text: 'Type '),
                      TextSpan(
                        text: _name,
                        style: TextStyle(color: c.textPrimary),
                      ),
                      const TextSpan(text: ' to confirm'),
                    ],
                  ),
                  style: sim.text.small.copyWith(color: c.textMuted),
                ),
              ),
              _ConfirmInput(
                controller: _confirmation,
                placeholder: _name,
                enabled: !_deleting,
              ),
            ],
          ),
        ),
      ),
      confirmLabel: 'Delete',
      pendingLabel: 'Deleting...',
      pending: _deleting,
      confirmEnabled: _confirmation.text == _name,
      onConfirm: () => unawaited(_confirm()),
      onDismiss: SimModalScope.of(context).close,
    );
  }
}

/// The type-to-confirm input; Enter is owned (does nothing) so it never
/// confirms (`defaultAction='none'`).
class _ConfirmInput extends StatelessWidget {
  const _ConfirmInput({
    required this.controller,
    required this.placeholder,
    required this.enabled,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SimChipInput(
    controller: controller,
    placeholder: placeholder,
    enabled: enabled,
    semanticsLabel: 'Type $placeholder to confirm',
    onKeyEvent: (node, event) =>
        isPlainEnter(event) ? KeyEventResult.handled : KeyEventResult.ignored,
  );
}

/// Opens the leave-workspace confirm (`workspace-header.tsx:867-883`,
/// `modal.leave-workspace`; the switcher spec's
/// `workspace.switcher.leave-modal` is an alias): Enter = Cancel. [onConfirm]
/// leaves and, for the current workspace, switches away
/// (`WorkspaceSwitcherActions.leave`); success closes. When it throws the
/// modal stays open and [onError] reports it, by default the toast
/// "Couldn't leave workspace" with the server reason (`:412-431`).
Future<void> showLeaveWorkspaceModal(
  BuildContext context, {
  required String workspaceName,
  required Future<void> Function() onConfirm,
  void Function(Object error)? onError,
}) {
  final pending = ValueNotifier<bool>(false);
  final report =
      onError ??
      (Object error) =>
          (locator.isRegistered<SimToasts>()
                  ? locator<SimToasts>()
                  : SimToasts.instance)
              .error(
                "Couldn't leave workspace",
                description: errorMessageOf(
                  error,
                  'Please try again in a moment.',
                ),
              );
  return showSimChipModal<void>(
    context,
    size: SimModalSize.sm,
    semanticsLabel: 'Leave workspace',
    dismissDisabled: () => pending.value,
    builder: (context) => LeaveWorkspaceModal(
      workspaceName: workspaceName,
      pending: pending,
      onConfirm: () async {
        try {
          await onConfirm();
        } on Object catch (error) {
          developer.log(
            'Error leaving workspace',
            name: 'sim_app.workspaces',
            error: error,
          );
          report(error);
          rethrow;
        }
      },
    ),
  ).whenComplete(pending.dispose);
}

class LeaveWorkspaceModal extends StatefulWidget {
  const LeaveWorkspaceModal({
    required this.workspaceName,
    required this.pending,
    required this.onConfirm,
    super.key,
  });

  final String workspaceName;
  final ValueNotifier<bool> pending;
  final Future<void> Function() onConfirm;

  @override
  State<LeaveWorkspaceModal> createState() => _LeaveWorkspaceModalState();
}

class _LeaveWorkspaceModalState extends State<LeaveWorkspaceModal> {
  bool _leaving = false;

  Future<void> _confirm() async {
    if (_leaving) return;
    final close = SimModalScope.of(context).close;
    setState(() => _leaving = true);
    widget.pending.value = true;
    try {
      await widget.onConfirm();
      widget.pending.value = false;
      close();
    } on Object {
      widget.pending.value = false;
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.workspaceName.isEmpty
        ? 'this workspace'
        : widget.workspaceName;
    return ConfirmModalFrame(
      parityId: 'modal.leave-workspace',
      confirmParityId: 'modal.leave-workspace.confirm',
      title: 'Leave workspace',
      segments: <SimConfirmTextSegment>[
        const SimConfirmTextSegment('Are you sure you want to leave '),
        SimConfirmTextSegment(name, bold: true),
        const SimConfirmTextSegment(
          '? You will lose access to all workflows and data in this '
          'workspace. This action cannot be undone.',
        ),
      ],
      confirmLabel: 'Leave workspace',
      pendingLabel: 'Leaving...',
      pending: _leaving,
      onConfirm: () => unawaited(_confirm()),
      onDismiss: SimModalScope.of(context).close,
    );
  }
}
