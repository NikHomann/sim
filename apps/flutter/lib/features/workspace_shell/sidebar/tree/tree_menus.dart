import 'package:flutter/foundation.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/context_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_model.dart';
import 'package:sim_design/sim_design.dart';

/// One item of the shared `ContextMenu` (`context-menu.tsx`).
@immutable
class MenuSpec {
  const MenuSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.destructive = false,
  });

  /// Parity suffix (`open-new-tab`, `rename`, `create-workflow`, …).
  final String id;
  final String label;
  final SimIconData icon;
  final bool enabled;

  /// Leave / Delete / Close*: the items below the separator.
  final bool destructive;

  @override
  String toString() => '$id${enabled ? '' : ' (disabled)'}';
}

/// The separator rule of `context-menu.tsx:173-193`: one separator before
/// the destructive group, only when at least one item sits above it and at
/// least one destructive item is shown. `null` marks the separator.
List<MenuSpec?> withDestructiveSeparator(List<MenuSpec> items) {
  final above = items.where((i) => !i.destructive).toList();
  final below = items.where((i) => i.destructive).toList();
  return <MenuSpec?>[
    ...above,
    if (above.isNotEmpty && below.isNotEmpty) null,
    ...below,
  ];
}

/// The inputs both row menus gate on.
@immutable
class RowMenuGates {
  const RowMenuGates({
    required this.workflowCount,
    required this.folderCount,
    required this.canEdit,
    required this.canAdmin,
    required this.effectiveLocked,
    required this.inheritedLocked,
    required this.canDeleteSelection,
    this.isDuplicating = false,
    this.isExporting = false,
    this.isCreatingWorkflow = false,
    this.isCreatingFolder = false,
    this.hasExportableContent = true,
    this.canOpenInNewTab = true,
    this.exportAvailable = true,
  });

  final int workflowCount;
  final int folderCount;
  final bool canEdit;
  final bool canAdmin;
  final bool effectiveLocked;
  final bool inheritedLocked;
  final bool canDeleteSelection;
  final bool isDuplicating;
  final bool isExporting;
  final bool isCreatingWorkflow;
  final bool isCreatingFolder;
  final bool hasExportableContent;

  /// A link base is known (`SidebarNavigator.canOpenInNewTab`).
  final bool canOpenInNewTab;

  /// An export flow exists (workflow serialisation is Phase 2; until then
  /// Export is shown disabled instead of doing nothing).
  final bool exportAvailable;

  int get selectedCount => workflowCount + folderCount;
  bool get isMixed => workflowCount > 0 && folderCount > 0;
}

MenuSpec _lock(RowMenuGates g) => MenuSpec(
  id: 'lock',
  // `isLocked={effectiveLocked}`: an inherited lock reads "Unlock" too.
  label: g.effectiveLocked ? 'Unlock' : 'Lock',
  icon: g.effectiveLocked ? SimEmcnIcons.unlock : SimEmcnIcons.lock,
  enabled: g.canAdmin && !g.inheritedLocked,
);

/// Workflow row menu (`workflow-item.tsx:478-503`): Open in new tab,
/// Rename, Lock/Unlock (single unmixed selection only), Duplicate, Export,
/// ─, Delete (editors only).
List<MenuSpec> workflowMenuSpecs(RowMenuGates g) {
  final single = !g.isMixed && g.workflowCount <= 1;
  return <MenuSpec>[
    if (single)
      MenuSpec(
        id: 'open-new-tab',
        label: 'Open in new tab',
        icon: SimEmcnIcons.squareArrowUpRight,
        enabled: g.canOpenInNewTab,
      ),
    if (single)
      MenuSpec(
        id: 'rename',
        label: 'Rename',
        icon: SimEmcnIcons.pencil,
        enabled: g.canEdit && !g.effectiveLocked,
      ),
    if (single) _lock(g),
    MenuSpec(
      id: 'duplicate',
      label: selectionActionLabel('Duplicate', g.selectedCount),
      icon: SimEmcnIcons.duplicate,
      enabled: g.canEdit && !g.isDuplicating,
    ),
    MenuSpec(
      id: 'export',
      label: selectionActionLabel('Export', g.selectedCount),
      icon: SimEmcnIcons.download,
      enabled: g.canEdit && g.exportAvailable,
    ),
    if (g.canEdit)
      MenuSpec(
        id: 'delete',
        label: selectionActionLabel('Delete', g.selectedCount),
        icon: SimEmcnIcons.trash,
        enabled: g.canDeleteSelection && !g.effectiveLocked,
        destructive: true,
      ),
  ];
}

/// Folder row menu (`folder-item.tsx:578-613`): Rename, Create workflow,
/// Create folder, Lock/Unlock (single unmixed selection only), Duplicate,
/// Export, ─, Delete (editors only). No "Open in new tab".
List<MenuSpec> folderMenuSpecs(RowMenuGates g) {
  final single = !g.isMixed && g.folderCount <= 1;
  final editable = g.canEdit && !g.effectiveLocked;
  return <MenuSpec>[
    if (single)
      MenuSpec(
        id: 'rename',
        label: 'Rename',
        icon: SimEmcnIcons.pencil,
        enabled: editable,
      ),
    if (single)
      MenuSpec(
        id: 'create-workflow',
        label: 'Create workflow',
        icon: SimEmcnIcons.plus,
        enabled: editable && !g.isCreatingWorkflow,
      ),
    if (single)
      MenuSpec(
        id: 'create-folder',
        label: 'Create folder',
        icon: SimEmcnIcons.folderPlus,
        enabled: editable && !g.isCreatingFolder,
      ),
    if (single) _lock(g),
    MenuSpec(
      id: 'duplicate',
      label: selectionActionLabel('Duplicate', g.selectedCount),
      icon: SimEmcnIcons.duplicate,
      enabled: g.canEdit && !g.isDuplicating && g.hasExportableContent,
    ),
    MenuSpec(
      id: 'export',
      label: selectionActionLabel('Export', g.selectedCount),
      icon: SimEmcnIcons.download,
      enabled:
          g.canEdit &&
          !g.isExporting &&
          g.hasExportableContent &&
          g.exportAvailable,
    ),
    if (g.canEdit)
      MenuSpec(
        id: 'delete',
        label: selectionActionLabel('Delete', g.selectedCount),
        icon: SimEmcnIcons.trash,
        enabled: !g.effectiveLocked && g.canDeleteSelection,
        destructive: true,
      ),
  ];
}

/// Chat row menu (`sidebar.tsx:1874-1899`): Open in new tab, Mark as
/// read/unread, Pin/Unpin (single only), Rename, ─, Delete.
List<MenuSpec> chatMenuSpecs({
  required int selectedCount,
  required bool isUnread,
  required bool isPinned,
  required bool canEdit,
  bool canOpenInNewTab = true,
}) {
  final single = selectedCount <= 1;
  return <MenuSpec>[
    if (single)
      MenuSpec(
        id: 'open-new-tab',
        label: 'Open in new tab',
        icon: SimEmcnIcons.squareArrowUpRight,
        enabled: canOpenInNewTab,
      ),
    if (single && isUnread)
      const MenuSpec(
        id: 'mark-read',
        label: 'Mark as read',
        icon: SimEmcnIcons.eye,
      ),
    if (single && !isUnread)
      const MenuSpec(
        id: 'mark-unread',
        label: 'Mark as unread',
        icon: SimEmcnIcons.mail,
      ),
    if (single)
      MenuSpec(
        id: 'pin',
        label: isPinned ? 'Unpin' : 'Pin',
        icon: isPinned ? SimEmcnIcons.pinOff : SimEmcnIcons.pin,
      ),
    if (single)
      MenuSpec(
        id: 'rename',
        label: 'Rename',
        icon: SimEmcnIcons.pencil,
        enabled: canEdit,
      ),
    MenuSpec(
      id: 'delete',
      label: selectionActionLabel('Delete', selectedCount),
      icon: SimEmcnIcons.trash,
      enabled: canEdit,
      destructive: true,
    ),
  ];
}

/// Renders specs as menu entries; [onSelect] receives the spec id. With a
/// [parityPrefix] (`sidebar.tree.context-menu`) every item carries
/// `<prefix>.item.<id>` and the separator `<prefix>.separator`.
List<SimMenuEntry> menuEntries(
  List<MenuSpec> specs,
  void Function(String id) onSelect, {
  String? parityPrefix,
}) => <SimMenuEntry>[
  for (final spec in withDestructiveSeparator(specs))
    if (spec == null)
      SimMenuSeparator(
        semanticsIdentifier: parityPrefix == null
            ? null
            : '$parityPrefix.separator',
      )
    else
      sidebarMenuItem(
        spec.icon,
        spec.label,
        () => onSelect(spec.id),
        enabled: spec.enabled,
        semanticsIdentifier: parityPrefix == null
            ? null
            : '$parityPrefix.item.${spec.id}',
      ),
];
