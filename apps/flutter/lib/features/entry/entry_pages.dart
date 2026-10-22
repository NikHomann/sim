import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/platform/browser.dart';
import 'package:sim_app/features/entry/entry_support.dart';
import 'package:sim_app/features/workspace_shell/chrome/application_loading.dart';
import 'package:sim_app/features/workspace_shell/chrome/session_actions.dart';
import 'package:sim_app/features/workspace_shell/chrome/status_card.dart';

/// `router.replace(target)`: an entry decision replaces the current history
/// entry, so Back from the destination never lands on a page that would
/// redirect forward again.
void replaceLocation(BuildContext context, String location) {
  final router = GoRouter.of(context);
  Router.neglect(context, () => router.go(location));
}

/// Re-runs the current location's redirects in place (in-app "Try again").
void reresolveLocation(BuildContext context) {
  final router = GoRouter.of(context);
  Router.neglect(context, router.refresh);
}

/// Runs a side effect of a decision after the current frame, once per
/// token.
mixin _AfterFrameOnce<T extends StatefulWidget> on State<T> {
  Object? _lastToken;

  void runOnce(Object token, VoidCallback action) {
    if (_lastToken == token) return;
    _lastToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }
}

/// `/`, `/home` and `/o` when their redirect (`entryHomeRedirect`) did not
/// navigate: the session query failed (the "Could not load your
/// workspaces" card, retried in place) or is still pending.
class EntryPage extends StatefulWidget {
  const EntryPage({required this.route, super.key});

  /// [EntryRoute.home] (`/`, `/home`) or [EntryRoute.organizationEntry]
  /// (`/o`).
  final EntryRoute route;

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> with _AfterFrameOnce {
  late final SessionCubit _session = locator<SessionCubit>();

  @override
  void initState() {
    super.initState();
    unawaited(_session.load());
  }

  /// "Try again": a browser reload on web (as upstream), else reload the
  /// session and re-run the redirect.
  Future<void> _tryAgain() async {
    const window = BrowserWindow();
    if (window.origin != null) return window.reload();
    await _session.load();
    if (mounted) reresolveLocation(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      bloc: _session,
      builder: (context, state) {
        final decision = resolveEntry(
          EntryContext(route: widget.route, session: entrySessionOf(state)),
        );
        switch (decision) {
          case EntryShowLoadError():
            return WorkspaceStatusCards.loadError(
              context,
              onTryAgain: () => unawaited(_tryAgain()),
            );
          case EntryWait():
            break;
          default:
            // The session settled after the redirect ran (or changed while
            // the card showed): resolve again.
            runOnce(decision, () => reresolveLocation(context));
        }
        return const ApplicationLoading();
      },
    );
  }
}

/// The picker's two status cards (`workspace/page.tsx:46-72, 173-215`,
/// `entry.workspace.card`).
abstract final class WorkspaceStatusCards {
  /// The blocked card's copy by `blockedReasonCode`, then `workspaceMode`.
  static String blockedCopy(WorkspaceCreationPolicy policy) {
    switch (policy.blockedReasonCode) {
      case CreationBlockedReason.organizationSubscriptionInactive:
        return "Your organization's subscription is inactive, so new "
            "workspaces can't be created. Ask an organization owner to "
            'reactivate it.';
      case CreationBlockedReason.permissionGroupDenied:
        return "Your permission group doesn't allow creating workspaces, "
            "and you don't have access to an existing one. Ask an "
            'organization admin for workspace access.';
      case null:
        break;
    }
    if (policy.workspaceMode == WorkspaceMode.organization) {
      return "Your account is linked to an organization, but you don't have "
          'access to any of its workspaces. Ask an organization admin for '
          'workspace access, then check again — or sign out and back in if '
          'you recently left the organization.';
    }
    return 'Your plan has reached its workspace limit and none of your '
        'workspaces are active. Upgrade your plan to create another '
        'workspace, or contact support to restore an archived one.';
  }

  static Widget blocked(
    BuildContext context,
    WorkspaceCreationPolicy policy, {
    required VoidCallback onCheckAgain,
  }) => _card(
    context,
    title: 'No workspace access yet',
    description: blockedCopy(policy),
    primaryLabel: 'Check again',
    onPrimary: onCheckAgain,
  );

  static Widget loadError(
    BuildContext context, {
    required VoidCallback onTryAgain,
  }) => _card(
    context,
    title: 'Could not load your workspaces',
    description:
        'Something went wrong while loading your account. Try again, or '
        'sign out and log back in.',
    primaryLabel: 'Try again',
    onPrimary: onTryAgain,
  );

  static Widget _card(
    BuildContext context, {
    required String title,
    required String description,
    required String primaryLabel,
    required VoidCallback onPrimary,
  }) {
    return StatusCardPage(
      rootId: 'entry.workspace.card',
      iconId: 'entry.workspace.card.icon',
      title: title,
      description: description,
      actions: <StatusCardAction>[
        StatusCardAction(
          label: primaryLabel,
          primary: true,
          parityId: 'entry.workspace.card.primary',
          onPressed: onPrimary,
        ),
        StatusCardAction(
          label: 'Sign out',
          parityId: 'entry.workspace.card.sign-out',
          onPressed: () async {
            final recovered = await locator<SessionActions>()
                .recoverFromStaleSession();
            if (recovered && context.mounted) {
              replaceLocation(context, '/login');
            }
          },
        ),
      ],
    );
  }
}

/// The `/workspace` picker (`workspace/page.tsx:74-281`) when its redirect
/// (`workspacePickerRedirect`) did not navigate: stale-session recovery,
/// the blocked and error cards, default workspace creation with the single
/// 409 retry, and a re-resolution after "Try again" / "Check again".
class WorkspacePickerPage extends StatefulWidget {
  const WorkspacePickerPage({required this.query, super.key, this.onReload});

  final Map<String, String> query;

  /// `window.location.reload()`; defaults to a browser reload on web and an
  /// in-app re-resolution elsewhere.
  final VoidCallback? onReload;

  @override
  State<WorkspacePickerPage> createState() => _WorkspacePickerPageState();
}

class _WorkspacePickerPageState extends State<WorkspacePickerPage>
    with _AfterFrameOnce {
  late final SessionCubit _session = locator<SessionCubit>();
  late final WorkspacesCubit _workspaces = locator<WorkspacesCubit>();
  late final SessionActions _actions = locator<SessionActions>();
  late final AuthSessionStore _store = entrySessionStore();

  DefaultWorkspaceCreation _creation = DefaultWorkspaceCreation.notAttempted;
  bool _recoveryFailed = false;
  bool _workspacesRequested = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_session.load());
  }

  void _ensureWorkspaces(SessionState session) {
    if (_workspacesRequested || !session.isSignedIn) return;
    _workspacesRequested = true;
    unawaited(_workspaces.load());
  }

  /// "Check again" / "Try again", and the 409 re-resolution.
  void _reload() {
    final reload = widget.onReload;
    if (reload != null) return reload();
    const window = BrowserWindow();
    if (window.origin != null) return window.reload();
    setState(() {
      _generation++;
      _creation = DefaultWorkspaceCreation.notAttempted;
      _recoveryFailed = false;
    });
    unawaited(_session.load());
    unawaited(_workspaces.refetch());
  }

  Future<void> _recover() async {
    final recovered = await _actions.recoverFromStaleSession();
    if (!mounted) return;
    if (recovered) {
      replaceLocation(context, '/login');
    } else {
      setState(() => _recoveryFailed = true);
    }
  }

  String _destinationFor(String workspaceId) => workspaceDestination(
    workspaceId,
    target: redirectTargetOf(widget.query['redirect']),
    upgradeReason: widget.query['reason'],
  );

  Future<void> _createDefault() async {
    setState(() => _creation = DefaultWorkspaceCreation.pending);
    try {
      final created = await _workspaces.create(
        name: const EntryCreateDefaultWorkspace().name,
      );
      _store.remove(workspaceRaceRetryKey);
      if (mounted) replaceLocation(context, _destinationFor(created.id));
    } on ApiClientError catch (error) {
      if (!mounted) return;
      if (error.status == 409) {
        final retried = _store.read(workspaceRaceRetryKey) != null;
        if (retried) _store.remove(workspaceRaceRetryKey);
        setState(() {
          _creation = DefaultWorkspaceCreation.conflict;
          _recoveryFailed = retried;
        });
        return;
      }
      setState(() => _creation = DefaultWorkspaceCreation.failed);
    } on Object {
      if (mounted) setState(() => _creation = DefaultWorkspaceCreation.failed);
    }
  }

  Future<void> _redirectWorkflow(String workflowId, String fallback) async {
    final target = await workflowRedirectTarget(
      workflowId,
      fallbackWorkspaceId: fallback,
    );
    if (mounted) replaceLocation(context, target);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      bloc: _session,
      builder: (context, session) {
        _ensureWorkspaces(session);
        return BlocBuilder<WorkspacesCubit, WorkspacesState>(
          bloc: _workspaces,
          builder: (context, workspaces) =>
              _resolve(context, session, workspaces),
        );
      },
    );
  }

  Widget _resolve(
    BuildContext context,
    SessionState session,
    WorkspacesState workspaces,
  ) {
    final decision = resolveEntry(
      EntryContext(
        route: EntryRoute.workspacePicker,
        session: entrySessionOf(session),
        workspaces: entryWorkspacesOf(workspaces),
        defaultWorkspaceCreation: _creation,
        raceRetryUsed: _store.read(workspaceRaceRetryKey) != null,
        redirectTarget: redirectTargetOf(widget.query['redirect']),
        redirectWorkflowId: widget.query['redirect_workflow'],
        upgradeReason: widget.query['reason'],
      ),
    );
    if (decision is EntryShowBlocked) {
      return WorkspaceStatusCards.blocked(
        context,
        decision.policy,
        onCheckAgain: _reload,
      );
    }
    if (_recoveryFailed || decision is EntryShowLoadError) {
      return WorkspaceStatusCards.loadError(context, onTryAgain: _reload);
    }
    final token = (_generation, decision);
    switch (decision) {
      case EntryRecoverStaleSession():
        runOnce(token, () => unawaited(_recover()));
      case EntryCreateDefaultWorkspace():
        runOnce(token, () => unawaited(_createDefault()));
      case EntryReloadOnce():
        runOnce(token, () {
          _store.write(workspaceRaceRetryKey, '1');
          _reload();
        });
      case EntryGoLogin():
        runOnce(token, () => replaceLocation(context, '/login'));
      case EntryResolveWorkflowRedirect(
        :final workflowId,
        :final fallbackWorkspaceId,
      ):
        runOnce(
          token,
          () => unawaited(_redirectWorkflow(workflowId, fallbackWorkspaceId)),
        );
      case EntryGoWorkspace(:final workspaceId):
        runOnce(
          token,
          () => replaceLocation(context, _destinationFor(workspaceId)),
        );
      default:
        break;
    }
    return const ApplicationLoading();
  }
}
