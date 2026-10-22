import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/panel/resource_inventory.dart';
import 'package:sim_app/features/home/panel/resource_registry.dart';
import 'package:sim_app/features/home/panel/resource_tabs.dart';
import 'package:sim_design/sim_design.dart';

/// `getDisplayStatus` + `STATUS_CONFIG[...].color` (`logs/utils.ts:74-115`)
/// for the 5px square of a log row; null for a plain success.
Color? logStatusColor(SimColors c, String? status) => switch (status) {
  'failed' => c.textError,
  'pending' || 'running' || 'redacting' || 'cancelling' => const Color(
    0xFFF59E0B,
  ),
  'cancelled' => const Color(0xFFF97316),
  _ => null,
};

/// The leaf families with a folder tree (`FOLDERED_SECTION_SPECS`,
/// `add-resource-dropdown.tsx:158-163`).
enum _FolderSource { group, tableStructure, knowledgeBaseStructure }

const Map<HomeResourceType, (_FolderSource, HomeResourceType?, bool)>
_folderedSpecs = <HomeResourceType, (_FolderSource, HomeResourceType?, bool)>{
  // (folders from, selectable folder type, order by sortOrder)
  HomeResourceType.table: (_FolderSource.tableStructure, null, false),
  HomeResourceType.file: (
    _FolderSource.group,
    HomeResourceType.filefolder,
    false,
  ),
  HomeResourceType.knowledgebase: (
    _FolderSource.knowledgeBaseStructure,
    null,
    false,
  ),
  HomeResourceType.workflow: (_FolderSource.group, null, true),
};

/// Family types the foldered submenus already render (their folder group
/// never gets a submenu of its own): `FOLDERED_RESOURCE_TYPES`.
const Set<HomeResourceType> _folderedResourceTypes = <HomeResourceType>{
  HomeResourceType.table,
  HomeResourceType.file,
  HomeResourceType.filefolder,
  HomeResourceType.knowledgebase,
  HomeResourceType.workflow,
  HomeResourceType.folder,
};

/// A flat candidate of the filtered view.
typedef _Candidate = ({HomeResourceType type, InventoryItem item});

/// The `+` of the resource strip (`AddResourceDropdown`): a 26px subtle
/// action ("Add resource" tooltip, `Add resource tab` label) opening the
/// 320px resource picker (`home.panel.add-menu`): a search box, then one
/// submenu per family in [resourceMenuOrder] (folder trees for tables,
/// files, knowledge bases and workflows), a trailing "Loading resources"
/// row while lists are pending; typing switches to a flat filtered list
/// with an ↑/↓ cursor, Enter or Tab selecting.
class AddResourceControl extends StatefulWidget {
  const AddResourceControl({
    required this.workspaceId,
    required this.inventory,
    required this.onAdd,
    super.key,
    this.excludeTypes = addResourceExcludedTypes,
    this.dashboardsEnabled = false,
    this.testsEnabled = false,
  });

  final String workspaceId;
  final ResourceInventorySource inventory;
  final ValueChanged<HomeResource> onAdd;
  final List<HomeResourceType> excludeTypes;
  final bool dashboardsEnabled;
  final bool testsEnabled;

  @override
  State<AddResourceControl> createState() => AddResourceControlState();
}

class AddResourceControlState extends State<AddResourceControl> {
  SimMenuHandle? _menu;
  ValueListenable<ResourceInventory>? _inventory;
  String _query = '';
  int _cursor = 0;

  bool get isOpen => _menu?.isOpen ?? false;

  @override
  void dispose() {
    _detach();
    _menu?.close();
    super.dispose();
  }

  void _detach() {
    _inventory?.removeListener(_onInventory);
    _inventory = null;
    HardwareKeyboard.instance.removeHandler(_onKey);
  }

  void _onInventory() => _menu?.rebuild();

  /// Opens the picker (the lists start loading now, never before).
  void open() {
    if (isOpen) return;
    _query = '';
    _cursor = 0;
    _inventory = widget.inventory.load(
      widget.workspaceId,
      excluded: widget.excludeTypes.toSet(),
      dashboardsEnabled: widget.dashboardsEnabled,
      testsEnabled: widget.testsEnabled,
    )..addListener(_onInventory);
    HardwareKeyboard.instance.addHandler(_onKey);
    _menu = SimDropdownMenu.show(
      context,
      entries: _entries,
      sideOffset: 8,
      width: 320,
      minWidth: 320,
      maxWidth: 320,
      modal: false,
      semanticsIdentifier: 'home.panel.add-menu',
      onClose: () {
        _detach();
        _menu = null;
      },
    );
  }

  void _select(HomeResourceType type, InventoryItem item) {
    final resource = resourceFromItem(type, item, widget.workspaceId);
    final menu = _menu;
    if (menu == null) {
      widget.onAdd(resource);
      return;
    }
    menu.close();
    unawaited(menu.closed.then((_) => widget.onAdd(resource)));
  }

  ResourceInventory get _current =>
      _inventory?.value ?? const ResourceInventory(isHydrating: true);

  /// `ResourceMenuSearch.filtered`.
  List<_Candidate> _filtered() {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return const <_Candidate>[];
    return <_Candidate>[
      for (final entry in _current.groups.entries)
        for (final item in entry.value)
          if (item.name.toLowerCase().contains(q))
            (type: entry.key, item: item),
    ];
  }

  /// ↑/↓ move the cursor, Enter or Tab (without Shift) select, while the
  /// search box filters (`handleSearchKeyDown`).
  bool _onKey(KeyEvent event) {
    if (!isOpen || _query.trim().isEmpty) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final filtered = _filtered();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _cursor = (_cursor + 1).clamp(
        0,
        filtered.isEmpty ? 0 : filtered.length - 1,
      );
      _menu?.rebuild();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _cursor = (_cursor - 1).clamp(
        0,
        filtered.isEmpty ? 0 : filtered.length - 1,
      );
      _menu?.rebuild();
      return true;
    }
    final tab =
        key == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed;
    if ((key == LogicalKeyboardKey.enter || tab) && event is KeyDownEvent) {
      if (_cursor < filtered.length) {
        final pick = filtered[_cursor];
        _select(pick.type, pick.item);
        return true;
      }
    }
    return false;
  }

  List<SimMenuEntry> _entries() {
    final inventory = _current;
    return <SimMenuEntry>[
      SimMenuSearch(
        placeholder: 'Search resources',
        onChanged: (value) {
          _query = value;
          _cursor = 0;
        },
      ),
      if (_query.trim().isNotEmpty)
        ..._filteredEntries(inventory)
      else ...<SimMenuEntry>[
        ..._sectionEntries(inventory),
        if (inventory.isHydrating)
          const SimMenuItem(label: 'Loading resources', enabled: false),
      ],
    ];
  }

  List<SimMenuEntry> _filteredEntries(ResourceInventory inventory) {
    final filtered = _filtered();
    if (filtered.isEmpty) {
      return <SimMenuEntry>[
        SimMenuCustom(
          _EmptyFilterRow(
            label: inventory.isHydrating ? 'Loading resources' : 'No results',
          ),
        ),
      ];
    }
    return <SimMenuEntry>[
      SimMenuCustom(
        _FilteredRows(
          candidates: filtered,
          cursor: _cursor,
          onHover: (index) {
            if (_cursor == index) return;
            _cursor = index;
            _menu?.rebuild();
          },
          onSelect: (c) => _select(c.type, c.item),
        ),
      ),
    ];
  }

  /// `useResourceTreeSections` + `ResourceMenuSections`.
  List<SimMenuEntry> _sectionEntries(ResourceInventory inventory) {
    final entries = <SimMenuEntry>[];
    final types = inventory.groups.keys.toList()..sort(byResourceMenuOrder);
    for (final type in types) {
      final items = inventory.itemsOf(type);
      final config = resourceConfig(type);
      final spec = _folderedSpecs[type];
      if (spec != null) {
        final (source, folderType, bySortOrder) = spec;
        final folders = switch (source) {
          _FolderSource.tableStructure => inventory.tableFolders,
          _FolderSource.knowledgeBaseStructure =>
            inventory.knowledgeBaseFolders,
          _FolderSource.group => inventory.itemsOf(
            type == HomeResourceType.file
                ? HomeResourceType.filefolder
                : HomeResourceType.folder,
          ),
        };
        final nodes = buildResourceFolderTree(
          items,
          folders,
          orderBySortOrder: bySortOrder,
          pruneEmpty: folderType == null,
        );
        if (nodes.isEmpty) continue;
        entries.add(
          SimMenuSub(
            label: config.label,
            icon: config.icon,
            entries: _treeEntries(nodes, type, folderType),
          ),
        );
        continue;
      }
      if (_folderedResourceTypes.contains(type) || items.isEmpty) continue;
      entries.add(
        SimMenuSub(
          label: config.label,
          icon: config.icon,
          entries: <SimMenuEntry>[
            for (final item in items) _itemEntry(type, item),
          ],
        ),
      );
    }
    return entries;
  }

  List<SimMenuEntry> _treeEntries(
    List<ResourceTreeNode> nodes,
    HomeResourceType type,
    HomeResourceType? folderType,
  ) => <SimMenuEntry>[
    for (final node in nodes)
      switch (node) {
        ResourceTreeItem(:final item) => _itemEntry(type, item),
        ResourceTreeFolder(:final id, :final name, :final children) =>
          SimMenuSub(
            label: name,
            icon: SimEmcnIcons.folder,
            entries: <SimMenuEntry>[
              if (folderType != null)
                SimMenuItem(
                  label: name,
                  icon: SimEmcnIcons.folder,
                  onSelect: () => _select(
                    folderType,
                    InventoryItem(id: id, name: name),
                  ),
                ),
              ..._treeEntries(children, type, folderType),
            ],
          ),
      },
  ];

  SimMenuEntry _itemEntry(HomeResourceType type, InventoryItem item) =>
      SimMenuItem(
        label: type == HomeResourceType.log
            ? (item.workflowName ?? item.name)
            : item.name,
        icon: _rowIcon(type, item),
        trailing: type == HomeResourceType.log
            ? _LogTrailing(item: item)
            : null,
        onSelect: () => _select(type, item),
      );

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'home.panel.tabs.add',
    container: true,
    child: ResourceStripAction(
      icon: SimEmcnIcons.plus,
      label: 'Add resource tab',
      tooltip: 'Add resource',
      onPressed: open,
    ),
  );
}

/// `renderDropdownItem` glyphs: documents by name, otherwise the family's.
SimIconData? _rowIcon(HomeResourceType type, InventoryItem item) =>
    switch (type) {
      HomeResourceType.file => documentIcon(item.name),
      HomeResourceType.workflow ||
      HomeResourceType.table ||
      HomeResourceType.dashboard ||
      HomeResourceType.test ||
      HomeResourceType.knowledgebase ||
      HomeResourceType.folder ||
      HomeResourceType.filefolder ||
      HomeResourceType.log => resourceConfig(type).icon,
      _ => null,
    };

class _LogTrailing extends StatelessWidget {
  const _LogTrailing({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final color = logStatusColor(c, item.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: <Widget>[
        if (color != null)
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(SimRadii.xs),
            ),
          ),
        if (item.time != null)
          Text(
            item.time!,
            style: sim.text.caption.copyWith(color: c.textTertiary),
          ),
      ],
    );
  }
}

class _EmptyFilterRow extends StatelessWidget {
  const _EmptyFilterRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: sim.text.caption.copyWith(color: sim.colors.textTertiary),
      ),
    );
  }
}

class _FilteredRows extends StatelessWidget {
  const _FilteredRows({
    required this.candidates,
    required this.cursor,
    required this.onHover,
    required this.onSelect,
  });

  final List<_Candidate> candidates;
  final int cursor;
  final ValueChanged<int> onHover;
  final ValueChanged<_Candidate> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (var i = 0; i < candidates.length; i++)
        SimMenuRow(
          label: candidates[i].type == HomeResourceType.log
              ? (candidates[i].item.workflowName ?? candidates[i].item.name)
              : candidates[i].item.name,
          icon: _rowIcon(candidates[i].type, candidates[i].item),
          trailing: candidates[i].type == HomeResourceType.log
              ? _LogTrailing(item: candidates[i].item)
              : null,
          highlighted: i == cursor,
          onHover: () => onHover(i),
          onPressed: () => onSelect(candidates[i]),
        ),
    ],
  );
}
