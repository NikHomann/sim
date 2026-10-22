import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/home/access/permission_access_boundary.dart';
import 'package:sim_app/features/home/hero/credits_chip.dart';
import 'package:sim_app/features/home/hero/suggested_actions.dart';
import 'package:sim_app/features/home/home_http.dart';
import 'package:sim_app/features/home/panel/panel_width_store.dart';
import 'package:sim_app/features/home/panel/resource_inventory.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/http_chats_source.dart';
import 'package:sim_design/sim_design.dart';

/// Everything the Home surface reads outside its own folder. The app builds
/// it from the locator ([HomeServices.fromLocator]); tests provide their
/// own through [HomeEnvironment].
class HomeServices {
  HomeServices({
    required this.session,
    required this.host,
    required this.deploymentShape,
    required this.flags,
    required this.queries,
    required this.access,
    required this.credits,
    required this.signals,
    required this.inventory,
    required this.widths,
    this.http,
    this.workflows,
    this.folders,
    this.random,
    this.markRead,
    SimToasts? toasts,
  }) : toasts = toasts ?? SimToasts.instance;

  /// The app's services over the locator; the per-user caches (panel
  /// widths, access policy, sources) are shared and dropped on sign-out.
  factory HomeServices.fromLocator() {
    final shared = _shared;
    // A new locator generation (tests reset it) gets new services.
    if (shared != null && identical(shared.session, locator<SessionCubit>())) {
      return shared;
    }
    return _shared = _build();
  }

  static HomeServices? _shared;

  // ignore: prefer_constructors_over_static_methods, builds the shared one.
  static HomeServices _build() {
    T? optional<T extends Object>() =>
        locator.isRegistered<T>() ? locator<T>() : null;
    final client = optional<SimHttpClient>();
    final http = client == null ? null : SimHomeHttp(client);
    final queries = optional<QueryClient>() ?? QueryClient.instance;
    final workflows = optional<WorkflowsCubit>();
    final folders = optional<FoldersCubit>();
    final widths = ChatPanelWidthStore();
    final services = HomeServices(
      session: locator<SessionCubit>(),
      host: locator<WorkspaceHostCubit>(),
      deploymentShape: locator<DeploymentShapeCubit>(),
      flags: locator<FeatureFlagsCubit>(),
      queries: queries,
      http: http,
      workflows: workflows,
      folders: folders,
      access: HttpHomeAccessSource(http),
      credits: HttpCreditAvailabilitySource(http: http, queries: queries),
      signals: HttpSuggestionSignalsSource(http: http, queries: queries),
      inventory: HttpResourceInventorySource(
        http: http,
        queries: queries,
        workflows: workflows,
        folders: folders,
      ),
      widths: widths,
      markRead: sharedChatsSource?.markRead,
      toasts: optional<SimToasts>(),
    );
    if (locator.isRegistered<UserDataResetRegistry>()) {
      locator<UserDataResetRegistry>().register(() {
        widths.reset();
        _shared = null;
      });
    }
    return services;
  }

  /// Forgets the shared instance (locator resets in tests).
  static void resetShared() => _shared = null;

  final SessionCubit session;
  final WorkspaceHostCubit host;
  final DeploymentShapeCubit deploymentShape;
  final FeatureFlagsCubit flags;
  final QueryClient queries;
  final HomeHttp? http;
  final WorkflowsCubit? workflows;
  final FoldersCubit? folders;
  final HomeAccessSource access;
  final CreditAvailabilitySource credits;
  final SuggestionSignalsSource signals;
  final ResourceInventorySource inventory;
  final ChatPanelWidthStore widths;
  final SimToasts toasts;

  /// The suggested-actions draw (tests seed it).
  final math.Random? random;

  /// `POST /api/mothership/chats/read` with the optimistic list update
  /// (the sidebar's chat source).
  final Future<void> Function(String chatId)? markRead;

  /// The services for [context]: the nearest [HomeEnvironment], else the
  /// locator's.
  // ignore: prefer_constructors_over_static_methods, a lookup, not a build.
  static HomeServices of(BuildContext context) =>
      HomeEnvironment.maybeOf(context) ?? HomeServices.fromLocator();
}

/// Provides [HomeServices] to a subtree (tests).
class HomeEnvironment extends InheritedWidget {
  const HomeEnvironment({
    required this.services,
    required super.child,
    super.key,
  });

  final HomeServices services;

  static HomeServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeEnvironment>()?.services;

  @override
  bool updateShouldNotify(HomeEnvironment oldWidget) =>
      services != oldWidget.services;
}
