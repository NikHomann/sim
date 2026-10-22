// Failure modes of the row context menus (context-menu.tsx,
// workflow-item.tsx:478-503, folder-item.tsx:578-613):
// 1. item ORDER: workflow Open in new tab, Rename, Lock, Duplicate, Export,
//    ─, Delete; folder Rename, Create workflow, Create folder, Lock,
//    Duplicate, Export, ─, Delete;
// 2. single-row items disappear for a mixed or multi selection;
// 3. the separator appears only with items both above and below it;
// 4. read-only members lose Delete (hidden) and get disabled edits;
// 5. locks: own or inherited lock disables rename/create/delete; the lock
//    item needs admin and no locked ancestor and reads "Unlock" whenever
//    the row is effectively locked;
// 6. labels pluralise for multi-selections; folders without workflows
//    cannot be duplicated or exported.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_menus.dart';
import 'package:sim_design/sim_design.dart';

RowMenuGates gates({
  int workflows = 1,
  int folders = 0,
  bool canEdit = true,
  bool canAdmin = true,
  bool locked = false,
  bool inherited = false,
  bool canDelete = true,
  bool exportable = true,
}) => RowMenuGates(
  workflowCount: workflows,
  folderCount: folders,
  canEdit: canEdit,
  canAdmin: canAdmin,
  effectiveLocked: locked || inherited,
  inheritedLocked: inherited,
  canDeleteSelection: canDelete,
  hasExportableContent: exportable,
);

List<String?> ids(List<MenuSpec> specs) =>
    withDestructiveSeparator(specs).map((s) => s?.id).toList();

void main() {
  test('workflow menu order with the separator before Delete', () {
    expect(ids(workflowMenuSpecs(gates())), <String?>[
      'open-new-tab',
      'rename',
      'lock',
      'duplicate',
      'export',
      null,
      'delete',
    ]);
  });

  test('folder menu order', () {
    expect(ids(folderMenuSpecs(gates(workflows: 0, folders: 1))), <String?>[
      'rename',
      'create-workflow',
      'create-folder',
      'lock',
      'duplicate',
      'export',
      null,
      'delete',
    ]);
  });

  test('multi and mixed selections keep only selection-wide items', () {
    final multi = workflowMenuSpecs(gates(workflows: 2));
    expect(ids(multi), <String?>['duplicate', 'export', null, 'delete']);
    expect(multi.map((s) => s.label), <String>[
      'Duplicate 2 items',
      'Export 2 items',
      'Delete 2 items',
    ]);
    final mixed = folderMenuSpecs(gates(folders: 1));
    expect(ids(mixed), <String?>['duplicate', 'export', null, 'delete']);
  });

  test('read-only members: no Delete, no separator, edits disabled', () {
    final specs = workflowMenuSpecs(gates(canEdit: false, canAdmin: false));
    expect(ids(specs), <String?>[
      'open-new-tab',
      'rename',
      'lock',
      'duplicate',
      'export',
    ]);
    expect(
      specs.where((s) => !s.enabled).map((s) => s.id),
      <String>['rename', 'lock', 'duplicate', 'export'],
    );
  });

  test('separator rule needs both sides', () {
    const delete = MenuSpec(
      id: 'delete',
      label: 'Delete',
      icon: SimEmcnIcons.trash,
      destructive: true,
    );
    expect(withDestructiveSeparator(<MenuSpec>[delete]), <MenuSpec?>[delete]);
    expect(withDestructiveSeparator(<MenuSpec>[]), isEmpty);
  });

  test('locks gate rename, create and delete; Unlock when inherited', () {
    final own = folderMenuSpecs(gates(workflows: 0, folders: 1, locked: true));
    final byId = {for (final s in own) s.id: s};
    expect(byId['rename']!.enabled, isFalse);
    expect(byId['create-workflow']!.enabled, isFalse);
    expect(byId['create-folder']!.enabled, isFalse);
    expect(byId['delete']!.enabled, isFalse);
    expect(byId['lock']!.label, 'Unlock');
    expect(byId['lock']!.enabled, isTrue);

    final inherited = workflowMenuSpecs(gates(inherited: true));
    final lock = inherited.firstWhere((s) => s.id == 'lock');
    expect(lock.label, 'Unlock');
    expect(lock.enabled, isFalse);
    expect(
      workflowMenuSpecs(
        gates(canAdmin: false),
      ).firstWhere((s) => s.id == 'lock').enabled,
      isFalse,
    );
  });

  test('delete is refused when it would empty the workspace', () {
    final specs = workflowMenuSpecs(gates(canDelete: false));
    expect(specs.firstWhere((s) => s.id == 'delete').enabled, isFalse);
  });

  test('folders without workflows cannot be duplicated or exported', () {
    final specs = folderMenuSpecs(
      gates(workflows: 0, folders: 1, exportable: false),
    );
    final byId = {for (final s in specs) s.id: s};
    expect(byId['duplicate']!.enabled, isFalse);
    expect(byId['export']!.enabled, isFalse);
  });

  test('chat menu: single-row items and read/unread/pin variants', () {
    final single = chatMenuSpecs(
      selectedCount: 1,
      isUnread: true,
      isPinned: true,
      canEdit: false,
    );
    expect(ids(single), <String?>[
      'open-new-tab',
      'mark-read',
      'pin',
      'rename',
      null,
      'delete',
    ]);
    expect(single.firstWhere((s) => s.id == 'pin').label, 'Unpin');
    expect(single.where((s) => !s.enabled).map((s) => s.id), <String>[
      'rename',
      'delete',
    ]);
    final multi = chatMenuSpecs(
      selectedCount: 3,
      isUnread: false,
      isPinned: false,
      canEdit: true,
    );
    expect(ids(multi), <String?>['delete']);
    expect(multi.single.label, 'Delete 3 items');
  });
}
