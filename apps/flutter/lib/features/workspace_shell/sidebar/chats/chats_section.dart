import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/chat_models.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/hover_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/rail_flyout.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/context_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/inline_rename.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_chip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_tooltip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_section.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/delete_modal.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_cubit.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_menus.dart';
import 'package:sim_design/sim_design.dart';

/// Chats shown before "See more" (`useState(5)`).
const int chatPageSize = 5;

/// `#EAB308`: the dot of a chat with a running stream.
const Color chatActiveDot = Color(0xFFEAB308);

/// The "Chats" section (`sidebar.tsx:1529-1651`), rendered only while chat
/// is enabled and not hidden by the permission group. Rows come from
/// [SidebarServices.chats] (empty until the Phase 4 chat layer exists).
///
/// The chat selection lives in the shared tree cubit with the workflow and
/// folder selection (`useFolderStore`): selecting chats clears those and
/// vice versa.
class ChatsSection extends StatefulWidget {
  const ChatsSection({
    required this.workspaceId,
    required this.collapsed,
    required this.pathname,
    required this.services,
    required this.canEdit,
    super.key,
  });

  final String workspaceId;
  final bool collapsed;
  final String pathname;
  final SidebarServices services;
  final bool canEdit;

  @override
  State<ChatsSection> createState() => _ChatsSectionState();
}

class _ChatsSectionState extends State<ChatsSection> {
  final HoverMenuController _hover = HoverMenuController();
  int _visible = chatPageSize;
  String? _menuOpenId;
  String? _editingId;
  InlineRenameController? _rename;

  SidebarServices get _services => widget.services;
  SidebarTreeCubit get _tree => _services.tree;

  String _href(String id) => '/workspace/${widget.workspaceId}/chat/$id';

  @override
  void dispose() {
    _hover.dispose();
    _rename?.dispose();
    super.dispose();
  }

  void _onRowTap(List<SidebarChat> chats, SidebarChat chat) {
    if (isModifierPressed) {
      _services.navigator.openInNewTab(_href(chat.id));
      return;
    }
    final shift = isShiftPressed;
    _tree.chatClick(chats.map((c) => c.id).toList(), chat.id, shift: shift);
    if (!shift) {
      _hover.close();
      _services.navigator.go(_href(chat.id));
    }
  }

  /// Right-click / "…" (`sidebar.tsx:674-728`): a row inside a multi-chat
  /// selection acts on the whole selection, any other row selects itself.
  void _openMenu(List<SidebarChat> chats, SidebarChat chat, Offset position) {
    final selected = _tree.state.selectedChats;
    final targets = selected.contains(chat.id) && selected.length > 1
        ? chats.where((c) => selected.contains(c.id)).toList()
        : <SidebarChat>[chat];
    if (targets.length == 1) _tree.selectChatOnly(chat.id);
    setState(() => _menuOpenId = chat.id);
    _hover.setLocked(locked: true);
    final single = targets.length == 1 ? targets.single : null;
    final handle = showSidebarContextMenu(
      context,
      position,
      semanticsIdentifier: 'shell.sidebar.chats.menu',
      entries: () => menuEntries(
        chatMenuSpecs(
          selectedCount: targets.length,
          isUnread: single?.isUnread ?? false,
          isPinned: single?.isPinned ?? false,
          canEdit: widget.canEdit,
          canOpenInNewTab: _services.navigator.canOpenInNewTab,
        ),
        (id) => _onMenu(id, targets),
      ),
    );
    unawaited(
      handle.closed.then((_) {
        if (!mounted) return;
        setState(() => _menuOpenId = null);
        if (_editingId == null) _hover.setLocked(locked: false);
      }),
    );
  }

  void _onMenu(String id, List<SidebarChat> targets) {
    final first = targets.first;
    final source = _services.chats;
    switch (id) {
      case 'open-new-tab':
        _services.navigator.openInNewTab(_href(first.id));
      case 'mark-read':
        unawaited(source.markRead(first.id));
      case 'mark-unread':
        unawaited(source.markUnread(first.id));
      case 'pin':
        unawaited(source.setPinned(first.id, pinned: !first.isPinned));
      case 'rename':
        _startRename(first);
      case 'delete':
        final ids = targets.map((c) => c.id).toList();
        unawaited(
          showDeleteModal(
            context,
            type: DeleteItemType.chat,
            names: targets.map((c) => c.name).toList(),
            onConfirm: () async {
              final viewing = ids.any((i) => widget.pathname == _href(i));
              await source.delete(ids);
              if (!mounted) return;
              _tree.clearChatSelection();
              if (viewing) {
                _services.navigator.go('/workspace/${widget.workspaceId}/home');
              }
            },
          ),
        );
    }
  }

  void _startRename(SidebarChat chat) {
    _rename?.dispose();
    _hover.setLocked(locked: true);
    setState(() {
      _editingId = chat.id;
      _rename = InlineRenameController(
        initialName: chat.name,
        onSave: (name) => _services.chats.rename(chat.id, name),
        onSavingChanged: (_) {
          if (mounted) setState(() {});
        },
        onExit: () {
          if (!mounted) return;
          final done = _rename;
          setState(() {
            _editingId = null;
            _rename = null;
          });
          _hover.setLocked(locked: false);
          WidgetsBinding.instance.addPostFrameCallback((_) => done?.dispose());
        },
      );
    });
  }

  /// The dot of a running (`#EAB308`) or unread (`--brand-accent`, unless
  /// open) chat (`ConversationListItem`).
  Widget? _dot(SidebarChat chat, bool current, SimColors c) {
    final dot = chat.isActive || (chat.isUnread && !current);
    if (!dot) return null;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: chat.isActive ? chatActiveDot : c.brandAccent,
        shape: BoxShape.circle,
      ),
    );
  }

  /// The expanded row's indicator: the dot, else the 12px pin
  /// (`sidebar.tsx:305-318`).
  Widget? _indicator(SidebarChat chat, bool current, SimColors c) {
    final dot = _dot(chat, current, c);
    if (dot != null) return dot;
    if (chat.isPinned) {
      return SimIcon(SimEmcnIcons.pin, size: 12, color: c.textIcon);
    }
    return null;
  }

  Widget _expandedRows(
    BuildContext context,
    List<SidebarChat>? chats,
    SidebarTreeState tree,
  ) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    if (chats == null) return const SizedBox.shrink();
    final rows = <Widget>[];
    if (chats.isEmpty) {
      rows.add(
        Container(
          height: SimChipChrome.height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            'No chats yet',
            style: sim.text.small.copyWith(color: c.textMuted),
          ),
        ),
      );
    }
    final selected = tree.selectedChats;
    final multi = selected.length > 1;
    for (final (i, chat) in chats.take(_visible).indexed) {
      final current = widget.pathname == _href(chat.id);
      final rename = _rename;
      if (_editingId == chat.id && rename != null) {
        rows.add(
          Container(
            height: SimChipChrome.height,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: c.surfaceActive,
              borderRadius: BorderRadius.circular(SimChipChrome.radius),
            ),
            alignment: Alignment.centerLeft,
            child: InlineRenameField(
              controller: rename,
              maxLength: 100,
              semanticsLabel: 'Rename chat ${chat.name}',
            ),
          ),
        );
        continue;
      }
      Widget row = _ChatRow(
        chat: chat,
        active:
            current ||
            (multi && selected.contains(chat.id)) ||
            _menuOpenId == chat.id,
        menuOpen: _menuOpenId == chat.id,
        indicator: _indicator(chat, current, c),
        onPressed: () => _onRowTap(chats, chat),
        onMiddleTap: () => _services.navigator.openInNewTab(_href(chat.id)),
        onMenu: (position) => _openMenu(chats, chat, position),
      );
      if (i == 0) row = Parity('shell.sidebar.chats.item', child: row);
      rows.add(row);
    }
    if (chats.length > chatPageSize) {
      final more = chats.length > _visible;
      rows.add(
        Parity(
          'shell.sidebar.chats.more',
          child: SidebarChip(
            label: more ? 'See more' : 'See less',
            textStyle: sim.text.small.copyWith(color: c.textMuted),
            onPressed: () => setState(
              () => _visible = more ? _visible + chatPageSize : chatPageSize,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SimLayout.sidebarItemGap,
        children: rows,
      ),
    );
  }

  /// `CollapsedChatFlyoutItem` rows: active for the open chat, a member of
  /// a multi-selection or an open menu; the dot only (no pin); the rename
  /// row (`EDIT_ROW_CLASS`, 100 characters) while renaming.
  List<SimMenuEntry> _flyoutEntries(List<SidebarChat>? chats) {
    if (chats == null) return const <SimMenuEntry>[];
    if (chats.isEmpty) {
      return const <SimMenuEntry>[
        SimMenuItem(label: 'No chats yet', enabled: false),
      ];
    }
    final c = SimTheme.of(context).colors;
    final selected = _tree.state.selectedChats;
    final multi = selected.length > 1;
    return <SimMenuEntry>[
      for (final chat in chats)
        if (chat.id == _editingId && _rename != null)
          SimMenuCustom(
            FlyoutEditRow(
              controller: _rename!,
              semanticsLabel: 'Rename chat ${chat.name}',
            ),
          )
        else
          SimMenuCustom(
            FlyoutRow(
              label: chat.name,
              active:
                  widget.pathname == _href(chat.id) ||
                  (multi && selected.contains(chat.id)),
              actionOpen: _menuOpenId == chat.id,
              actionLabel: 'Chat options',
              indicator: _dot(chat, widget.pathname == _href(chat.id), c),
              onPressed: () => _onRowTap(chats, chat),
              onMiddleTap: () =>
                  _services.navigator.openInNewTab(_href(chat.id)),
              onSecondaryTapDown: (p) => _openMenu(chats, chat, p),
              onAction: (rect) => _openMenu(chats, chat, rect.topRight),
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final listenable = _services.chats.chats(widget.workspaceId);
    return BlocBuilder<SidebarTreeCubit, SidebarTreeState>(
      bloc: _tree,
      buildWhen: (a, b) => a.selectedChats != b.selectedChats,
      builder: (context, tree) => ValueListenableBuilder<List<SidebarChat>?>(
        valueListenable: listenable,
        builder: (context, chats, _) => SidebarSection(
          title: 'Chats',
          railCollapsed: widget.collapsed,
          parityId: 'shell.sidebar.chats',
          titleParityId: 'shell.sidebar.chats.title',
          child: widget.collapsed
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Parity(
                      'shell.sidebar.rail.chats',
                      child: RailFlyout(
                        controller: _hover,
                        entries: () => _flyoutEntries(listenable.value),
                        trigger: (context, {required open}) => SidebarChip(
                          icon: SimEmcnIcons.task,
                          width: SimLayout.sidebarRailChip,
                          active: open,
                          semanticsLabel: 'Chats',
                          onPressed: () =>
                              open ? _hover.close() : _hover.open(),
                        ),
                      ),
                    ),
                  ),
                )
              : _expandedRows(context, chats, tree),
        ),
      ),
    );
  }
}

class _ChatRow extends StatefulWidget {
  const _ChatRow({
    required this.chat,
    required this.active,
    required this.menuOpen,
    required this.indicator,
    required this.onPressed,
    required this.onMiddleTap,
    required this.onMenu,
  });

  final SidebarChat chat;
  final bool active;
  final bool menuOpen;
  final Widget? indicator;
  final VoidCallback onPressed;
  final VoidCallback onMiddleTap;
  final void Function(Offset position) onMenu;

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _hovered = false;
  bool _focusWithin = false;

  @override
  Widget build(BuildContext context) => SidebarTooltip(
    label: widget.chat.name,
    enabled: false,
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // `group-focus-within`: keyboard focus on the row (or its "…")
      // reveals the action like hover does.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => setState(() => _focusWithin = focused),
        child: SidebarChip(
          active: widget.active,
          isLink: true,
          semanticsLabel: widget.chat.name,
          label: widget.chat.name,
          trailing: SidebarRowActions(
            revealed: _hovered || _focusWithin,
            open: widget.menuOpen,
            indicator: widget.indicator,
            actionLabel: 'Chat options',
            actionIconSize: 14,
            onAction: (rect) => widget.onMenu(moreButtonAnchor(rect)),
          ),
          onPressed: widget.onPressed,
          onMiddleTap: widget.onMiddleTap,
          onSecondaryTapDown: widget.onMenu,
        ),
      ),
    ),
  );
}
