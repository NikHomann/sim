import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_design/sim_design.dart';

/// `itemType` of `DeleteModal` (`delete-modal.tsx`).
enum DeleteItemType { workflow, folder, mixed, chat }

/// The title of a delete confirmation (`delete-modal.tsx:73-86`).
String deleteModalTitle(DeleteItemType type, List<String> names) {
  final multiple = names.length > 1;
  return switch (type) {
    DeleteItemType.workflow =>
      multiple ? 'Delete workflows' : 'Delete workflow',
    DeleteItemType.folder => multiple ? 'Delete folders' : 'Delete folder',
    DeleteItemType.chat => multiple ? 'Delete chats' : 'Delete chat',
    DeleteItemType.mixed => 'Delete items',
  };
}

/// The description segments (`buildDescriptionSegments` + the restore
/// note): "Are you sure you want to delete **names**? " + red warning +
/// " You can restore it from Recently deleted in Settings."
List<SimConfirmTextSegment> deleteModalSegments(
  DeleteItemType type,
  List<String> names,
) {
  final multiple = names.length > 1;
  final warning = switch (type) {
    DeleteItemType.workflow =>
      'All associated blocks, executions, and configuration will be removed.',
    DeleteItemType.folder =>
      multiple
          ? 'All workflows and contents within these folders will be archived.'
          : 'All associated workflows and contents will be archived.',
    DeleteItemType.chat =>
      'The chat and its conversation history will be archived.',
    DeleteItemType.mixed =>
      'All selected workflows and folders, including their contents, will be archived.',
  };
  final List<SimConfirmTextSegment> lead;
  if (names.isEmpty) {
    final what = switch (type) {
      DeleteItemType.workflow => 'this workflow',
      DeleteItemType.folder => 'this folder',
      DeleteItemType.chat => 'this chat',
      DeleteItemType.mixed => 'the selected items',
    };
    lead = <SimConfirmTextSegment>[
      SimConfirmTextSegment('Are you sure you want to delete $what? '),
    ];
  } else {
    final bold = type == DeleteItemType.chat && multiple
        ? '${names.length} chats'
        : names.join(', ');
    lead = <SimConfirmTextSegment>[
      const SimConfirmTextSegment('Are you sure you want to delete '),
      SimConfirmTextSegment(bold, bold: true),
      const SimConfirmTextSegment('? '),
    ];
  }
  return <SimConfirmTextSegment>[
    ...lead,
    SimConfirmTextSegment(warning, error: true),
    const SimConfirmTextSegment(' '),
    const SimConfirmTextSegment(
      'You can restore it from Recently deleted in Settings.',
    ),
  ];
}

/// Opens the delete confirmation (`ChipConfirmModal`): "Delete" /
/// "Deleting..." while [onConfirm] runs, dismissal refused meanwhile; the
/// modal closes on success and stays open (pending cleared) on failure.
/// Enter does not confirm (`defaultAction='dismiss'`) except for a single
/// chat (`'confirm'`).
Future<void> showDeleteModal(
  BuildContext context, {
  required DeleteItemType type,
  required List<String> names,
  required Future<void> Function() onConfirm,
}) {
  final pending = ValueNotifier<bool>(false);
  final title = deleteModalTitle(type, names);
  return showSimChipModal<void>(
    context,
    size: SimModalSize.sm,
    semanticsLabel: title,
    dismissDisabled: () => pending.value,
    builder: (context) => Parity(
      'sidebar.tree.delete-modal',
      child: _DeleteModalContent(
        title: title,
        segments: deleteModalSegments(type, names),
        pending: pending,
        confirmOnEnter: type == DeleteItemType.chat && names.length <= 1,
        onConfirm: onConfirm,
      ),
    ),
  ).whenComplete(pending.dispose);
}

class _DeleteModalContent extends StatelessWidget {
  const _DeleteModalContent({
    required this.title,
    required this.segments,
    required this.pending,
    required this.confirmOnEnter,
    required this.onConfirm,
  });

  final String title;
  final List<SimConfirmTextSegment> segments;
  final ValueNotifier<bool> pending;
  final bool confirmOnEnter;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final modal = SimModalScope.of(context);
    Future<void> confirm() async {
      if (pending.value) return;
      pending.value = true;
      try {
        await onConfirm();
        pending.value = false;
        modal.close();
      } on Object {
        pending.value = false;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SimChipModalHeader(title: title),
        SimChipModalBody(
          children: <Widget>[
            SimChipModalDescription(
              spans: <InlineSpan>[
                for (final s in segments)
                  TextSpan(
                    text: s.text,
                    style: TextStyle(
                      fontVariations: s.bold
                          ? const <FontVariation>[FontVariation('wght', 500)]
                          : null,
                      color: s.error ? c.textError : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
        ValueListenableBuilder<bool>(
          valueListenable: pending,
          builder: (context, isPending, _) {
            SimChipModalScope.maybeOf(context)?.setPrimary(
              confirmOnEnter ? () => unawaited(confirm()) : null,
              enabled: !isPending,
            );
            return SimChipModalFooterShell(
              children: <Widget>[
                SimChip(
                  label: 'Cancel',
                  enabled: !isPending,
                  onPressed: modal.close,
                ),
                SimChip(
                  label: isPending ? 'Deleting...' : 'Delete',
                  variant: SimChipVariant.destructive,
                  enabled: !isPending,
                  onPressed: () => unawaited(confirm()),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
