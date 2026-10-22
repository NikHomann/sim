import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/drop_logic.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_model.dart';

/// `HOVER_EXPAND_DELAY` (`use-drag-drop.ts:18`).
const Duration hoverExpandDelay = Duration(milliseconds: 400);

/// UI state of the workflow tree: the in-memory parts of
/// `stores/folders/store.ts` (expanded folders, workflow/folder selection,
/// the folder range anchor) plus the drag state of `use-drag-drop.ts` and
/// the row whose inline rename or context menu is open. Nothing here is
/// persisted; a reload starts collapsed.
class SidebarTreeState extends Equatable {
  const SidebarTreeState({
    this.expandedFolders = const <String>{},
    this.selectedWorkflows = const <String>{},
    this.selectedFolders = const <String>{},
    this.lastSelectedFolderId,
    this.selectedChats = const <String>{},
    this.lastSelectedChatId,
    this.dropIndicator,
    this.isDragging = false,
    this.draggingIds = const <String>{},
    this.hoverFolderId,
    this.editingId,
    this.savingId,
    this.menuOpenId,
  });

  final Set<String> expandedFolders;
  final Set<String> selectedWorkflows;
  final Set<String> selectedFolders;
  final String? lastSelectedFolderId;

  /// The chat rows' selection and its range anchor (`selectedChats`,
  /// `lastSelectedChatId`): selecting chats clears the workflow and folder
  /// selection and vice versa.
  final Set<String> selectedChats;
  final String? lastSelectedChatId;
  final DropIndicator? dropIndicator;
  final bool isDragging;

  /// The rows being dragged (rendered at 50 % opacity).
  final Set<String> draggingIds;
  final String? hoverFolderId;

  /// The row showing the inline rename input.
  final String? editingId;

  /// The row whose rename request is in flight (input disabled).
  final String? savingId;

  /// The row whose context menu is open (rendered active).
  final String? menuOpenId;

  bool isExpanded(String folderId) => expandedFolders.contains(folderId);

  SidebarTreeState copyWith({
    Set<String>? expandedFolders,
    Set<String>? selectedWorkflows,
    Set<String>? selectedFolders,
    String? lastSelectedFolderId,
    bool clearLastSelectedFolder = false,
    Set<String>? selectedChats,
    String? lastSelectedChatId,
    bool clearLastSelectedChat = false,
    DropIndicator? dropIndicator,
    bool clearDropIndicator = false,
    bool? isDragging,
    Set<String>? draggingIds,
    String? hoverFolderId,
    bool clearHoverFolder = false,
    String? editingId,
    bool clearEditing = false,
    String? savingId,
    bool clearSaving = false,
    String? menuOpenId,
    bool clearMenuOpen = false,
  }) => SidebarTreeState(
    expandedFolders: expandedFolders ?? this.expandedFolders,
    selectedWorkflows: selectedWorkflows ?? this.selectedWorkflows,
    selectedFolders: selectedFolders ?? this.selectedFolders,
    lastSelectedFolderId: clearLastSelectedFolder
        ? null
        : (lastSelectedFolderId ?? this.lastSelectedFolderId),
    selectedChats: selectedChats ?? this.selectedChats,
    lastSelectedChatId: clearLastSelectedChat
        ? null
        : (lastSelectedChatId ?? this.lastSelectedChatId),
    dropIndicator: clearDropIndicator
        ? null
        : (dropIndicator ?? this.dropIndicator),
    isDragging: isDragging ?? this.isDragging,
    draggingIds: draggingIds ?? this.draggingIds,
    hoverFolderId: clearHoverFolder
        ? null
        : (hoverFolderId ?? this.hoverFolderId),
    editingId: clearEditing ? null : (editingId ?? this.editingId),
    savingId: clearSaving ? null : (savingId ?? this.savingId),
    menuOpenId: clearMenuOpen ? null : (menuOpenId ?? this.menuOpenId),
  );

  @override
  List<Object?> get props => [
    expandedFolders,
    selectedWorkflows,
    selectedFolders,
    lastSelectedFolderId,
    selectedChats,
    lastSelectedChatId,
    dropIndicator,
    isDragging,
    draggingIds,
    hoverFolderId,
    editingId,
    savingId,
    menuOpenId,
  ];
}

/// The selection a context menu or a drag acts on, captured when it opens.
class CapturedSelection {
  const CapturedSelection({required this.workflowIds, required this.folderIds});

  final List<String> workflowIds;
  final List<String> folderIds;

  bool get isMixed => workflowIds.isNotEmpty && folderIds.isNotEmpty;
  int get count => workflowIds.length + folderIds.length;
}

/// Owns [SidebarTreeState]. Selection rules port `useFolderStore`,
/// `use-workflow-selection.ts` and `use-folder-selection.ts`; drag rules
/// port the state half of `use-drag-drop.ts` (indicator normalisation,
/// the 400 ms spring-open timer, the drag-end collapse of spring-opened
/// folders).
class SidebarTreeCubit extends Cubit<SidebarTreeState> {
  SidebarTreeCubit() : super(const SidebarTreeState());

  Timer? _hoverTimer;
  String? _sourceFolderId;
  final Set<String> _autoExpanded = <String>{};

  /// The scope of the dragged rows (`draggedSourceFolderRef`).
  String? get dragSourceFolderId => _sourceFolderId;

  // Expansion.

  void toggleExpanded(String folderId) {
    final next = {...state.expandedFolders};
    if (!next.remove(folderId)) next.add(folderId);
    emit(state.copyWith(expandedFolders: next));
  }

  void setExpanded(String folderId, {required bool expanded}) {
    if (state.isExpanded(folderId) == expanded) return;
    final next = {...state.expandedFolders};
    if (expanded) {
      next.add(folderId);
    } else {
      next.remove(folderId);
    }
    emit(state.copyWith(expandedFolders: next));
  }

  /// Expands the active workflow's folder path and selects it (when not
  /// already selected), as `workflow-list.tsx:360-372` does on every route
  /// or data change once both lists have loaded.
  void revealActiveWorkflow(SidebarTree tree, String workflowId) {
    final workflow = tree.workflow(workflowId);
    final folderId = workflow?.folderId;
    if (folderId != null) {
      final path = tree.folderPath(folderId);
      final next = {...state.expandedFolders, for (final f in path) f.id};
      if (next.length != state.expandedFolders.length) {
        emit(state.copyWith(expandedFolders: next));
      }
    }
    if (!state.selectedWorkflows.contains(workflowId)) selectOnly(workflowId);
  }

  // Workflow selection (store actions).

  void selectOnly(String workflowId) => emit(
    state.copyWith(
      selectedWorkflows: {workflowId},
      selectedFolders: const <String>{},
      clearLastSelectedFolder: true,
      selectedChats: const <String>{},
      clearLastSelectedChat: true,
    ),
  );

  void selectRange(List<String> orderedIds, String fromId, String toId) {
    final from = orderedIds.indexOf(fromId);
    final to = orderedIds.indexOf(toId);
    if (from == -1 || to == -1) return;
    final start = from < to ? from : to;
    final end = from < to ? to : from;
    emit(
      state.copyWith(
        selectedWorkflows: orderedIds.sublist(start, end + 1).toSet(),
      ),
    );
  }

  void toggleWorkflowSelection(String workflowId) {
    final next = {...state.selectedWorkflows};
    if (!next.remove(workflowId)) next.add(workflowId);
    emit(
      state.copyWith(
        selectedWorkflows: next,
        selectedChats: const <String>{},
        clearLastSelectedChat: state.selectedChats.isNotEmpty,
      ),
    );
  }

  void clearSelection() =>
      emit(state.copyWith(selectedWorkflows: const <String>{}));

  void clearFolderSelection() => emit(
    state.copyWith(
      selectedFolders: const <String>{},
      clearLastSelectedFolder: true,
    ),
  );

  void clearAllSelection() => emit(
    state.copyWith(
      selectedWorkflows: const <String>{},
      selectedFolders: const <String>{},
      clearLastSelectedFolder: true,
      selectedChats: const <String>{},
      clearLastSelectedChat: true,
    ),
  );

  void selectFolder(String folderId) => emit(
    state.copyWith(
      selectedFolders: {...state.selectedFolders, folderId},
      lastSelectedFolderId: folderId,
    ),
  );

  void _deselectFolder(String folderId) {
    final next = {...state.selectedFolders}..remove(folderId);
    final anchor = state.lastSelectedFolderId == folderId
        ? (next.isEmpty ? null : next.first)
        : state.lastSelectedFolderId;
    emit(
      state.copyWith(
        selectedFolders: next,
        lastSelectedFolderId: anchor,
        clearLastSelectedFolder: anchor == null,
      ),
    );
  }

  void _toggleFolderSelection(String folderId) {
    if (state.selectedFolders.contains(folderId)) {
      _deselectFolder(folderId);
    } else {
      emit(
        state.copyWith(
          selectedFolders: {...state.selectedFolders, folderId},
          lastSelectedFolderId: folderId,
        ),
      );
    }
    _clearChats();
  }

  void _selectFolderOnly(String folderId) => emit(
    state.copyWith(
      selectedFolders: {folderId},
      lastSelectedFolderId: folderId,
      selectedChats: const <String>{},
      clearLastSelectedChat: true,
    ),
  );

  void _clearChats() {
    if (state.selectedChats.isEmpty) return;
    emit(
      state.copyWith(
        selectedChats: const <String>{},
        clearLastSelectedChat: true,
      ),
    );
  }

  /// The workflow and folder selection, cleared when chats get selected.
  SidebarTreeState _withoutTreeSelection(SidebarTreeState next) =>
      next.copyWith(
        selectedWorkflows: const <String>{},
        selectedFolders: const <String>{},
        clearLastSelectedFolder: true,
      );

  // Chat selection (store actions, `use-chat-selection.ts`).

  /// `selectChatOnly`.
  void selectChatOnly(String chatId) => emit(
    _withoutTreeSelection(
      state.copyWith(selectedChats: {chatId}, lastSelectedChatId: chatId),
    ),
  );

  /// `toggleChatSelection`: the anchor moves to an added chat, and to
  /// another selected chat (or none) when the anchor is removed.
  void toggleChatSelection(String chatId) {
    final next = {...state.selectedChats};
    String? anchor;
    if (next.remove(chatId)) {
      anchor = state.lastSelectedChatId == chatId
          ? (next.isEmpty ? null : next.first)
          : state.lastSelectedChatId;
    } else {
      next.add(chatId);
      anchor = chatId;
    }
    emit(
      _withoutTreeSelection(
        state.copyWith(
          selectedChats: next,
          lastSelectedChatId: anchor,
          clearLastSelectedChat: anchor == null,
        ),
      ),
    );
  }

  /// `selectChatRange`: the anchor stays at [fromId].
  void selectChatRange(List<String> orderedIds, String fromId, String toId) {
    final from = orderedIds.indexOf(fromId);
    final to = orderedIds.indexOf(toId);
    if (from == -1 || to == -1) return;
    final start = from < to ? from : to;
    final end = from < to ? to : from;
    emit(
      _withoutTreeSelection(
        state.copyWith(
          selectedChats: orderedIds.sublist(start, end + 1).toSet(),
          lastSelectedChatId: fromId,
        ),
      ),
    );
  }

  /// `clearChatSelection`.
  void clearChatSelection() => _clearChats();

  /// `handleChatClick` (`use-chat-selection.ts:22-41`): no anchor (or one
  /// outside [orderedIds]) selects only; Shift ranges from the anchor, or
  /// toggles on the anchor itself; a plain click selects only.
  void chatClick(
    List<String> orderedIds,
    String chatId, {
    required bool shift,
  }) {
    final anchor = state.lastSelectedChatId;
    if (anchor == null || !orderedIds.contains(anchor)) {
      selectChatOnly(chatId);
    } else if (shift && anchor != chatId) {
      selectChatRange(orderedIds, anchor, chatId);
    } else if (shift) {
      toggleChatSelection(chatId);
    } else {
      selectChatOnly(chatId);
    }
  }

  void _selectFolderRange(List<String> orderedIds, String fromId, String toId) {
    final from = orderedIds.indexOf(fromId);
    final to = orderedIds.indexOf(toId);
    if (from == -1 || to == -1) return;
    final start = from < to ? from : to;
    final end = from < to ? to : from;
    emit(
      state.copyWith(
        selectedFolders: orderedIds.sublist(start, end + 1).toSet(),
        lastSelectedFolderId: fromId,
      ),
    );
  }

  /// `handleWorkflowClick` (`use-workflow-selection.ts:80-92`): Shift ranges
  /// from the active route workflow (or toggles without one), a plain click
  /// selects only this row. Cmd/Ctrl never reaches here.
  void workflowClick(
    SidebarTree tree,
    String workflowId, {
    required bool shift,
    String? activeWorkflowId,
  }) {
    if (shift && activeWorkflowId != null && activeWorkflowId != workflowId) {
      selectRange(tree.orderedWorkflowIds, activeWorkflowId, workflowId);
      _deselectConflictingFolders(tree);
    } else if (shift) {
      toggleWorkflowSelection(workflowId);
      _deselectConflictingFolders(tree);
    } else {
      selectOnly(workflowId);
    }
  }

  void _deselectConflictingFolders(SidebarTree tree) {
    if (state.selectedFolders.isEmpty) return;
    for (final workflowId in state.selectedWorkflows.toList()) {
      for (final folderId
          in tree.workflowAncestors[workflowId] ?? const <String>[]) {
        if (state.selectedFolders.contains(folderId)) _deselectFolder(folderId);
      }
    }
  }

  /// `handleFolderClick` (`use-folder-selection.ts:128-145`) for modifier
  /// clicks: Cmd/Ctrl toggles (the clicked folder wins over its relatives),
  /// Shift ranges from the anchor (ancestors win), and workflows inside
  /// selected folders are deselected either way.
  void folderClick(
    SidebarTree tree,
    String folderId, {
    required bool shift,
    required bool meta,
  }) {
    final anchor = state.lastSelectedFolderId;
    if (meta) {
      _toggleFolderSelection(folderId);
      _deselectRelatedFolders(tree, folderId);
    } else if (shift && anchor != null && anchor != folderId) {
      _selectFolderRange(tree.orderedFolderIds, anchor, folderId);
      _deduplicateFolders(tree);
    } else {
      _selectFolderOnly(folderId);
    }
    _deselectConflictingWorkflows(tree);
  }

  void _deselectRelatedFolders(SidebarTree tree, String folderId) {
    final folders = state.selectedFolders;
    if (!folders.contains(folderId) || folders.length <= 1) return;
    for (final id in <String>[
      ...?tree.folderAncestors[folderId],
      ...?tree.folderDescendants[folderId],
    ]) {
      if (state.selectedFolders.contains(id)) _deselectFolder(id);
    }
  }

  void _deduplicateFolders(SidebarTree tree) {
    if (state.selectedFolders.length <= 1) return;
    for (final folderId in state.selectedFolders.toList()) {
      final ancestors = tree.folderAncestors[folderId] ?? const <String>[];
      if (ancestors.any(state.selectedFolders.contains)) {
        _deselectFolder(folderId);
      }
    }
  }

  void _deselectConflictingWorkflows(SidebarTree tree) {
    if (state.selectedWorkflows.isEmpty) return;
    final next = {...state.selectedWorkflows};
    for (final folderId in state.selectedFolders) {
      next.removeAll(tree.folderDescendantWorkflows[folderId] ?? const []);
    }
    if (next.length != state.selectedWorkflows.length) {
      emit(state.copyWith(selectedWorkflows: next));
    }
  }

  /// Finder pattern (`folder-item.tsx:283-323`, `workflow-item.tsx:208-250`):
  /// a row outside the selection replaces it; a selected row acts on the
  /// whole selection.
  CapturedSelection captureForWorkflow(String workflowId) {
    if (!state.selectedWorkflows.contains(workflowId)) {
      clearAllSelection();
      emit(state.copyWith(selectedWorkflows: {workflowId}));
    }
    return _captured();
  }

  CapturedSelection captureForFolder(String folderId) {
    if (!state.selectedFolders.contains(folderId)) {
      clearAllSelection();
      selectFolder(folderId);
    }
    return _captured();
  }

  CapturedSelection _captured() => CapturedSelection(
    workflowIds: state.selectedWorkflows.toList(),
    folderIds: state.selectedFolders.toList(),
  );

  /// The rows a drag of [id] carries: the whole selection when the row is
  /// part of it, else only the row (`onDragStart`).
  DragSelection dragSelectionFor({
    required String id,
    required bool isFolder,
  }) {
    final selected = isFolder
        ? state.selectedFolders.contains(id)
        : state.selectedWorkflows.contains(id);
    if (selected) {
      return DragSelection(
        workflowIds: state.selectedWorkflows.toList(),
        folderIds: state.selectedFolders.toList(),
      );
    }
    return DragSelection(
      workflowIds: isFolder ? const <String>[] : <String>[id],
      folderIds: isFolder ? <String>[id] : const <String>[],
    );
  }

  // Rename and menu flags.

  void startEditing(String id) =>
      emit(state.copyWith(editingId: id, clearSaving: true));

  void stopEditing(String id) {
    if (state.editingId != id) return;
    emit(state.copyWith(clearEditing: true, clearSaving: true));
  }

  void setSaving(String? id) =>
      emit(state.copyWith(savingId: id, clearSaving: id == null));

  void setMenuOpen(String? id) =>
      emit(state.copyWith(menuOpenId: id, clearMenuOpen: id == null));

  // Drag and drop.

  /// `handleDragStart(sourceFolderId)`.
  void dragStart({
    required String? sourceFolderId,
    required Set<String> draggingIds,
  }) {
    _sourceFolderId = sourceFolderId;
    emit(state.copyWith(isDragging: true, draggingIds: draggingIds));
  }

  /// Sets the drop indicator, normalised against the live siblings; equal
  /// indicators do not re-emit.
  void setIndicator(
    DropIndicator? indicator,
    List<SiblingItem> Function(String? folderId) siblingsOf, {
    bool normalize = true,
  }) {
    final next = indicator == null || !normalize
        ? indicator
        : normalizeIndicator(indicator, siblingsOf);
    if (next == state.dropIndicator) return;
    emit(
      state.copyWith(dropIndicator: next, clearDropIndicator: next == null),
    );
  }

  /// Arms (or disarms) the 400 ms spring-open of a collapsed folder whose
  /// middle band is under the pointer.
  void setHoverFolder(String? folderId) {
    if (folderId == state.hoverFolderId) return;
    _hoverTimer?.cancel();
    _hoverTimer = null;
    emit(
      state.copyWith(
        hoverFolderId: folderId,
        clearHoverFolder: folderId == null,
      ),
    );
    if (folderId == null || !state.isDragging) return;
    if (state.isExpanded(folderId)) return;
    _hoverTimer = Timer(hoverExpandDelay, () {
      _hoverTimer = null;
      if (isClosed || !state.isDragging || state.hoverFolderId != folderId) {
        return;
      }
      _autoExpanded.add(folderId);
      setExpanded(folderId, expanded: true);
    });
  }

  /// The pointer left the tree: indicator and hover cleared, the drag lives
  /// on (`onLeave` of the scroll container).
  void dragLeave() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    emit(
      state.copyWith(clearDropIndicator: true, clearHoverFolder: true),
    );
  }

  /// `handleDrop` before the requests: returns the indicator the drop uses
  /// (read synchronously) and keeps the destination and its ancestors open.
  DropIndicator? takeDrop(SidebarTree tree) {
    final indicator = state.dropIndicator;
    final destination = indicator?.destinationFolderId;
    if (destination != null && _autoExpanded.isNotEmpty) {
      _autoExpanded.remove(destination);
      for (final folder in tree.folderPath(destination)) {
        _autoExpanded.remove(folder.id);
      }
    }
    emit(
      state.copyWith(
        clearDropIndicator: true,
        isDragging: false,
        draggingIds: const <String>{},
      ),
    );
    return indicator;
  }

  /// `handleDragEnd`: resets the drag and closes the folders this drag
  /// spring-opened (drop destinations excepted, see [takeDrop]).
  void dragEnd() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _sourceFolderId = null;
    var expanded = state.expandedFolders;
    if (_autoExpanded.isNotEmpty) {
      expanded = {...expanded}..removeAll(_autoExpanded);
      _autoExpanded.clear();
    }
    emit(
      state.copyWith(
        isDragging: false,
        draggingIds: const <String>{},
        clearDropIndicator: true,
        clearHoverFolder: true,
        expandedFolders: expanded,
      ),
    );
  }

  @override
  Future<void> close() {
    _hoverTimer?.cancel();
    return super.close();
  }
}
