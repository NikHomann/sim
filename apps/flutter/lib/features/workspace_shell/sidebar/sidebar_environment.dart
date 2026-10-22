import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_dirty_store.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_navigation_guard.dart';
import 'package:sim_app/features/workspace_shell/shared/app_links.dart';
import 'package:sim_app/features/workspace_shell/shared/permission_config.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/chat_models.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/http_chats_source.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/rail_resources.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/platform/sidebar_browser.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_cubit.dart';
import 'package:sim_design/sim_design.dart';

/// Navigation the sidebar, the palette and the switcher perform. Paths are
/// app paths without the `/app` base (`/workspace/{id}/w/{workflowId}`).
abstract class SidebarNavigator {
  /// The current path (`usePathname()`).
  String get location;

  /// Notifies when [location] changes.
  Listenable get changes;

  /// In-app navigation (`router.push` of a `Link`), behind the settings
  /// dirty guard like every in-app link click.
  void go(String path);

  /// Whether [openInNewTab] can open anything (a link base is known).
  bool get canOpenInNewTab;

  /// `window.open(href, '_blank', 'noopener,noreferrer')`; a no-op when
  /// [canOpenInNewTab] is false.
  void openInNewTab(String path);

  /// `window.open(url)` for external pages (docs, Slack, status).
  void openExternal(String url);

  /// The absolute URL of an app path (`window.location.origin + href`), or
  /// `null` when no link base is known (see [AppLinks]).
  String? absoluteUrl(String path);
}

/// [SidebarNavigator] over the app's [GoRouter] and the browser. Links
/// resolve through [AppLinks] (the document base on web, the configured
/// Sim origin on desktop); in-app navigation runs through the shell's
/// [ShellNavigator] (same-location clicks ignored, the settings dirty guard
/// asked first, like every `a[href]` click upstream).
class RouterSidebarNavigator implements SidebarNavigator {
  RouterSidebarNavigator(
    this.router, {
    ShellNavigator? shell,
    this.browser = const SidebarBrowser(),
    AppLinks? links,
  }) : shell = shell ?? ShellNavigator(router: router, dirty: _dirtyStore()),
       links = links ?? AppLinks.platform();

  final GoRouter router;
  final ShellNavigator shell;
  final SidebarBrowser browser;
  final AppLinks links;

  static SettingsDirtyStore? _dirtyStore() =>
      locator.isRegistered<SettingsDirtyStore>()
      ? locator<SettingsDirtyStore>()
      : null;

  @override
  String get location => router.routeInformationProvider.value.uri.path;

  @override
  Listenable get changes => router.routeInformationProvider;

  @override
  void go(String path) => shell.go(path);

  @override
  bool get canOpenInNewTab => links.available;

  @override
  void openInNewTab(String path) {
    final url = links.resolve(path);
    if (url != null) browser.openNewTab(url);
  }

  @override
  void openExternal(String url) => browser.openNewTab(url);

  @override
  String? absoluteUrl(String path) => links.resolve(path);
}

/// A navigator that only records (no router mounted; tests).
class InertSidebarNavigator implements SidebarNavigator {
  InertSidebarNavigator([String location = '/'])
    : _location = ValueNotifier<String>(location);

  final ValueNotifier<String> _location;

  /// Every path passed to [go], in order.
  final List<String> visited = <String>[];

  /// Every path opened in a new tab, in order.
  final List<String> openedInNewTab = <String>[];

  /// Every external URL opened, in order.
  final List<String> openedExternal = <String>[];

  @override
  String get location => _location.value;

  set location(String value) => _location.value = value;

  @override
  Listenable get changes => _location;

  @override
  void go(String path) {
    visited.add(path);
    location = path;
  }

  @override
  bool get canOpenInNewTab => true;

  @override
  void openInNewTab(String path) => openedInNewTab.add(path);

  @override
  void openExternal(String url) => openedExternal.add(url);

  @override
  String? absoluteUrl(String path) =>
      AppLinks(Uri.parse('http://localhost:3001/app/')).resolve(path);
}

/// The `status.sim.ai` indicator (`none`, `minor`, `major`, `critical`).
typedef StatusIndicatorFetcher = Future<String?> Function();

/// Everything the sidebar reads or calls outside its own folder. The
/// defaults come from the app locator; tests and the chrome override what
/// they need through [SidebarEnvironment].
class SidebarServices {
  SidebarServices({
    required this.workflows,
    required this.folders,
    required this.permissions,
    required this.featureFlags,
    required this.deploymentShape,
    required this.session,
    required this.workspaces,
    this.host,
    this.help,
    this.foldersRepository,
    SidebarNavigator? navigator,
    this.onToggleCollapsed,
    this.organizationHref,
    ShellPermissionConfigSource? permissionConfigs,
    this.accessRequestsEnabled = false,
    SidebarChatsSource? chats,
    RailResourceSource? tables,
    RailResourceSource? files,
    this.fetchStatusIndicator,
    this.isMac,
    SidebarTreeCubit? tree,
    this.realtime,
    this.onImportWorkflow,
    this.onExport,
    this.onSignOut,
    this.browser = const SidebarBrowser(),
    SimToasts? toasts,
    this.clipboard = _writeClipboard,
  }) : navigator = navigator ?? InertSidebarNavigator(),
       chats = chats ?? const EmptyChatsSource(),
       tables = tables ?? const EmptyRailResourceSource(),
       files = files ?? const EmptyRailResourceSource(),
       tree = tree ?? sharedSidebarTree,
       permissionConfigs = permissionConfigs ?? sharedPermissionConfigs,
       toasts = toasts ?? SimToasts.instance;

  /// The locator-backed services the app runs with.
  factory SidebarServices.fromLocator({SidebarNavigator? navigator}) {
    T? optional<T extends Object>() =>
        locator.isRegistered<T>() ? locator<T>() : null;
    return SidebarServices(
      workflows: locator<WorkflowsCubit>(),
      folders: locator<FoldersCubit>(),
      permissions: locator<PermissionsCubit>(),
      featureFlags: locator<FeatureFlagsCubit>(),
      deploymentShape: locator<DeploymentShapeCubit>(),
      session: locator<SessionCubit>(),
      workspaces: locator<WorkspacesCubit>(),
      host: optional<WorkspaceHostCubit>(),
      help: optional<HelpRepository>(),
      foldersRepository: optional<FoldersRepository>(),
      realtime: optional<RealtimeTransport>(),
      chats: sharedChatsSource,
      navigator: navigator,
    );
  }

  final WorkflowsCubit workflows;
  final FoldersCubit folders;
  final PermissionsCubit permissions;
  final FeatureFlagsCubit featureFlags;
  final DeploymentShapeCubit deploymentShape;
  final SessionCubit session;
  final WorkspacesCubit workspaces;
  final WorkspaceHostCubit? host;
  final HelpRepository? help;

  /// Used for the fresh `GET /api/folders` the folder naming runs.
  final FoldersRepository? foldersRepository;
  final SidebarNavigator navigator;

  /// The chrome's collapse toggle (writes the `sidebar_collapsed` cookie).
  final VoidCallback? onToggleCollapsed;

  /// `/o/{organizationId}` when the profile menu links to the organization.
  final String? organizationHref;

  /// `usePermissionConfig().config` per workspace (hidden tabs, Copilot).
  final ShellPermissionConfigSource permissionConfigs;

  /// Whether access requests are available (restricted rows stay visible
  /// with a lock instead of disappearing).
  final bool accessRequestsEnabled;
  final SidebarChatsSource chats;
  final RailResourceSource tables;
  final RailResourceSource files;

  /// Polls `status.sim.ai` on hosted deployments; `null` = never polled.
  final StatusIndicatorFetcher? fetchStatusIndicator;

  /// Overrides the platform detection of the shortcut labels.
  final bool? isMac;
  final SidebarTreeCubit tree;

  /// The socket the `workspace-workflows` room joins; `null` = no room.
  final RealtimeTransport? realtime;

  /// "Import workflow" (the `.json`/`.zip` parser is Phase 2).
  final VoidCallback? onImportWorkflow;

  /// "Export" of the captured selection (workflow serialisation is Phase 2).
  final void Function(CapturedSelection selection)? onExport;

  /// "Sign out" (`signOutAndRedirect`); owned by the auth/chrome layer.
  final Future<void> Function()? onSignOut;
  final SidebarBrowser browser;
  final SimToasts toasts;
  final Future<void> Function(String text) clipboard;

  bool get mac => isMac ?? browser.isMac;

  static Future<void> _writeClipboard(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

/// The tree state shared by every sidebar mount: `useFolderStore` is a
/// global store, so expanded folders and the selection survive a rail
/// collapse or a route change (but not a reload).
final SidebarTreeCubit sharedSidebarTree = SidebarTreeCubit();

/// Provides [SidebarServices] to the sidebar subtree.
class SidebarEnvironment extends InheritedWidget {
  const SidebarEnvironment({
    required this.services,
    required super.child,
    super.key,
  });

  final SidebarServices services;

  static SidebarServices? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SidebarEnvironment>()
      ?.services;

  @override
  bool updateShouldNotify(SidebarEnvironment oldWidget) =>
      services != oldWidget.services;
}

/// Resolves the services for [context]: the nearest [SidebarEnvironment],
/// else the locator with a [RouterSidebarNavigator] when a router is
/// mounted.
SidebarServices resolveSidebarServices(BuildContext context) {
  final provided = SidebarEnvironment.maybeOf(context);
  if (provided != null) return provided;
  final router = GoRouter.maybeOf(context);
  return SidebarServices.fromLocator(
    navigator: router == null
        ? null
        : RouterSidebarNavigator(router, shell: ShellNavigator.of(context)),
  );
}
