import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:sim_app/features/home/models.dart';

/// `resolveEffectiveResourceId` (`resource-view-policy.ts:21-43`) without
/// the desktop kinds: an explicit selection still on screen wins,
/// otherwise the last resource.
String? resolveEffectiveResourceId(
  List<HomeResource> resources,
  String? selectedResourceId,
) {
  if (resources.isEmpty) return null;
  if (selectedResourceId != null &&
      resources.any((r) => r.selectionId == selectedResourceId)) {
    return selectedResourceId;
  }
  return resources.last.selectionId;
}

/// `resolveResourceEventPresentation` (`resource-view-policy.ts:87-107`).
({bool activateResource, bool markActivity, bool revealPanel})
resolveResourceEventPresentation({
  required String? activeResourceId,
  required bool activationRequested,
  required bool panelCollapseOwnedByUser,
  required bool panelCollapsed,
  required String resourceId,
  required bool selectionOwnedByUser,
}) {
  final preserveCollapsedPanel = panelCollapsed && panelCollapseOwnedByUser;
  final preserveSelection =
      selectionOwnedByUser &&
      activeResourceId != null &&
      activeResourceId != resourceId;
  final activate =
      activationRequested && !preserveCollapsedPanel && !preserveSelection;
  return (
    activateResource: activate,
    markActivity: !activate,
    revealPanel:
        panelCollapsed && activationRequested && !panelCollapseOwnedByUser,
  );
}

/// The resource panel's view state for one Home mount: the port of
/// `useResourcePanelController` + `useChatResourcePanel`
/// (`use-resource-panel.ts`). It owns collapse (and who owns it), the URL
/// selection, the activity marks and the auto-open/auto-close rules; the
/// resource list itself belongs to the chat session.
class ResourcePanelController extends ChangeNotifier {
  ResourcePanelController({
    String? initialSelection,
    this.onSelectionChanged,
    this.onAddResource,
  }) : _selected = initialSelection;

  /// Writes `?resource=` (replace semantics, cleared when null).
  final ValueChanged<String?>? onSelectionChanged;

  /// `chat.addResource` of the session.
  final ValueChanged<HomeResource>? onAddResource;

  bool _collapsed = true;
  bool _skipTransition = false;
  bool _collapseOwnedByUser = false;
  bool _selectionOwnedByUser = false;
  Set<String> _activity = <String>{};
  String? _selected;
  List<HomeResource> _resources = const <HomeResource>[];
  String? _chatId;
  bool _synced = false;
  bool _compactLayout = false;
  bool _disposed = false;

  bool get isCollapsed => _collapsed;

  /// The panel opened by itself: its width must not animate.
  bool get skipTransition => _skipTransition;
  bool get collapseOwnedByUser => _collapseOwnedByUser;
  bool get selectionOwnedByUser => _selectionOwnedByUser;
  Set<String> get activityIds => Set<String>.unmodifiable(_activity);
  int get activityCount => _activity.length;

  /// The URL selection (`?resource=`), possibly not in the list.
  String? get selectedResourceId => _selected;
  List<HomeResource> get resources => _resources;

  /// The tab the panel shows.
  String? get activeResourceId =>
      resolveEffectiveResourceId(_resources, _selected);

  HomeResource? get activeResource {
    final id = activeResourceId;
    if (id == null) return null;
    for (final r in _resources) {
      if (r.selectionId == id) return r;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setCollapsed(bool collapsed) {
    if (_collapsed == collapsed) return;
    _collapsed = collapsed;
  }

  void _setSelected(String? id) {
    if (_selected == id) return;
    _selected = id;
    onSelectionChanged?.call(id);
  }

  void _clearActivity(String id) {
    if (!_activity.contains(id)) return;
    _activity = <String>{..._activity}..remove(id);
  }

  /// Feeds the session's chat id and resource list in; runs the effects of
  /// `useChatResourcePanel` (chat switch reset, auto-open, auto-close,
  /// activity pruning) in React's order.
  ///
  /// [compactLayout] is `isCompactLayout || isMobileViewport()` (`width <
  /// 768`): no auto-open there; a change re-runs the auto-open rule.
  void sync({
    required String? chatId,
    required List<HomeResource> resources,
    bool compactLayout = false,
  }) {
    final chatChanged = !_synced || chatId != _chatId;
    final resourcesChanged = !_synced || !listEquals(resources, _resources);
    final compactChanged = !_synced || compactLayout != _compactLayout;
    final previousChatId = _chatId;
    _chatId = chatId;
    _compactLayout = compactLayout;
    _resources = List<HomeResource>.unmodifiable(resources);
    _synced = true;
    if (chatChanged) {
      if (chatId == null) _setCollapsed(true);
      if (chatId == null ||
          (previousChatId != null && previousChatId != chatId)) {
        _collapseOwnedByUser = false;
        _selectionOwnedByUser = false;
        _activity = <String>{};
      }
    }
    if (resourcesChanged || chatChanged || compactChanged) {
      if (!compactLayout &&
          _resources.isNotEmpty &&
          _collapsed &&
          !_collapseOwnedByUser) {
        _setCollapsed(false);
        _skipTransition = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_disposed || !_skipTransition) return;
          _skipTransition = false;
          _notify();
        });
      }
      if (_resources.isEmpty && !_collapsed) _setCollapsed(true);
      final ids = <String>{for (final r in _resources) r.selectionId};
      final pruned = _activity.where(ids.contains).toSet();
      if (pruned.length != _activity.length) _activity = pruned;
    }
    _notify();
  }

  /// `collapseResource`: the user owns the collapse until the next chat.
  void collapse() {
    _collapseOwnedByUser = true;
    _selectionOwnedByUser = true;
    _setCollapsed(true);
    _notify();
  }

  /// `expandResource`: also clears the active tab's activity mark.
  void expand() {
    _collapseOwnedByUser = false;
    _selectionOwnedByUser = true;
    final active = activeResourceId;
    if (active != null) _clearActivity(active);
    _setCollapsed(false);
    _notify();
  }

  void toggle() => _collapsed ? expand() : collapse();

  /// `selectResourceFromUser`.
  void select(String resourceId) {
    _selectionOwnedByUser = true;
    _clearActivity(resourceId);
    if (activeResourceId != resourceId) _setSelected(resourceId);
    _notify();
  }

  /// `addResourceFromUser`: add, select, expand.
  void addFromUser(HomeResource resource) {
    _collapseOwnedByUser = false;
    _selectionOwnedByUser = true;
    // Read against the list before the add, like React's ref; expanding
    // first keeps the session's synchronous update from counting as an
    // auto-open (which would skip the width transition).
    final needsSelect = activeResourceId != resource.selectionId;
    _setCollapsed(false);
    onAddResource?.call(resource);
    _clearActivity(resource.selectionId);
    if (needsSelect) _setSelected(resource.selectionId);
    _notify();
  }

  /// `handleResourceInteraction` / a divider gesture: the user claims the
  /// current selection.
  void claimSelection() => _selectionOwnedByUser = true;

  /// `prepareResourceViewForAgentTurn` (every send).
  void prepareForAgentTurn() {
    _selectionOwnedByUser = false;
    if (_activity.isEmpty) return;
    _activity = <String>{};
    _notify();
  }

  /// `handleResourceEvent` (desktop: never keeps the chat visible).
  void handleResourceEvent(String resourceId, {required bool activate}) {
    final active = activeResourceId;
    final presentation = resolveResourceEventPresentation(
      activeResourceId: active,
      activationRequested: activate,
      panelCollapseOwnedByUser: _collapseOwnedByUser,
      panelCollapsed: _collapsed,
      resourceId: resourceId,
      selectionOwnedByUser: _selectionOwnedByUser,
    );
    if (presentation.revealPanel) _setCollapsed(false);
    if (presentation.markActivity) {
      _activity = <String>{..._activity, resourceId};
      _notify();
      return;
    }
    _clearActivity(resourceId);
    if (presentation.activateResource && active != resourceId) {
      _setSelected(resourceId);
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
