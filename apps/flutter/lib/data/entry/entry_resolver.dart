import 'package:equatable/equatable.dart';
import 'package:sim_api/sim_api.dart';

/// The routes the entry resolution handles (spec §8).
enum EntryRoute {
  /// `/` and `/home`.
  home,

  /// `/o`.
  organizationEntry,

  /// `/workspace` (the picker).
  workspacePicker,
}

/// What the session query says.
enum EntrySession { pending, signedOut, signedIn, error }

/// What the workspace list query says.
sealed class EntryWorkspaces {
  const EntryWorkspaces();
}

final class WorkspacesPending extends EntryWorkspaces {
  const WorkspacesPending();
}

final class WorkspacesLoaded extends EntryWorkspaces {
  const WorkspacesLoaded(this.list);

  final WorkspaceList list;
}

final class WorkspacesFailed extends EntryWorkspaces {
  const WorkspacesFailed({required this.status});

  /// HTTP status of the failure (`null` for a network error).
  final int? status;

  bool get isStaleSession => status == 401;
}

/// How the default-workspace creation of an empty picker ended.
enum DefaultWorkspaceCreation { notAttempted, pending, conflict, failed }

/// `?redirect=` of the picker.
enum EntryRedirectTarget { upgrade, settings }

/// Everything the decision reads; a pure value so the table in
/// [resolveEntry] can be tested row by row.
class EntryContext extends Equatable {
  const EntryContext({
    required this.route,
    required this.session,
    this.workspaces = const WorkspacesPending(),
    this.defaultWorkspaceCreation = DefaultWorkspaceCreation.notAttempted,
    this.raceRetryUsed = false,
    this.redirectTarget,
    this.redirectWorkflowId,
    this.upgradeReason,
  });

  final EntryRoute route;
  final EntrySession session;
  final EntryWorkspaces workspaces;
  final DefaultWorkspaceCreation defaultWorkspaceCreation;

  /// `sessionStorage.workspaceRaceRetry` was already set.
  final bool raceRetryUsed;
  final EntryRedirectTarget? redirectTarget;
  final String? redirectWorkflowId;
  final String? upgradeReason;

  @override
  List<Object?> get props => [
    route,
    session,
    workspaces,
    defaultWorkspaceCreation,
    raceRetryUsed,
    redirectTarget,
    redirectWorkflowId,
    upgradeReason,
  ];
}

/// The outcome of one resolution step.
sealed class EntryDecision extends Equatable {
  const EntryDecision();

  @override
  List<Object?> get props => const [];
}

/// A query is still pending: keep the loading page.
final class EntryWait extends EntryDecision {
  const EntryWait();
}

/// No session: `/login` (middleware rule for app surfaces).
final class EntryGoLogin extends EntryDecision {
  const EntryGoLogin();
}

/// Stale auth cookies (401 after a live session, or a clean `null` session
/// on the picker): sign out, clear, then `/login` (`recoverFromStaleSession`).
final class EntryRecoverStaleSession extends EntryDecision {
  const EntryRecoverStaleSession();
}

/// `/workspace`.
final class EntryGoWorkspacePicker extends EntryDecision {
  const EntryGoWorkspacePicker();
}

/// `/workspace/<id>` (plus `/settings/general` or the upgrade page; the
/// path is built by `workspaceDestination`, which validates the reason).
final class EntryGoWorkspace extends EntryDecision {
  const EntryGoWorkspace(this.workspaceId, {this.target, this.upgradeReason});

  final String workspaceId;
  final EntryRedirectTarget? target;
  final String? upgradeReason;

  @override
  List<Object?> get props => [workspaceId, target, upgradeReason];
}

/// `?redirect_workflow=`: fetch the workflow for its workspace, fall back
/// to [fallbackWorkspaceId].
final class EntryResolveWorkflowRedirect extends EntryDecision {
  const EntryResolveWorkflowRedirect(
    this.workflowId, {
    required this.fallbackWorkspaceId,
  });

  final String workflowId;
  final String fallbackWorkspaceId;

  @override
  List<Object?> get props => [workflowId, fallbackWorkspaceId];
}

/// Empty active list and creation allowed: `POST /api/workspaces
/// {name:'My Workspace'}` then navigate.
final class EntryCreateDefaultWorkspace extends EntryDecision {
  const EntryCreateDefaultWorkspace();

  String get name => 'My Workspace';
}

/// Empty list and `creationPolicy.canCreate === false`.
final class EntryShowBlocked extends EntryDecision {
  const EntryShowBlocked(this.policy);

  final WorkspaceCreationPolicy policy;

  @override
  List<Object?> get props => [policy];
}

/// "Could not load your workspaces" (also after a failed recovery).
final class EntryShowLoadError extends EntryDecision {
  const EntryShowLoadError();
}

/// The one-shot reload after a 409 on default workspace creation.
final class EntryReloadOnce extends EntryDecision {
  const EntryReloadOnce();
}

/// The client-side port of `home/page.tsx`, `o/page.tsx` and
/// `workspace/page.tsx` (spec §8), as a pure function over the cubit states.
/// The organization landing (§8.1) is not ported yet (known-gaps.md): a
/// signed-in viewer of `/`, `/home` or `/o` always goes to the picker.
///
/// | route | session | other inputs | decision |
/// |---|---|---|---|
/// | home, o | pending | | wait |
/// | home, o | signedOut | | login |
/// | home, o | error | | load error |
/// | home, o | signedIn | | workspace picker |
/// | picker | pending | | wait |
/// | picker | signedOut | | recover stale session |
/// | picker | error | | load error |
/// | picker | signedIn | creation conflict, retry unused | reload once |
/// | picker | signedIn | creation conflict, retry used | load error |
/// | picker | signedIn | creation failed | login |
/// | picker | signedIn | creation pending | wait |
/// | picker | signedIn | workspaces pending | wait |
/// | picker | signedIn | workspaces 401 | recover stale session |
/// | picker | signedIn | workspaces other error | load error |
/// | picker | signedIn | empty, canCreate false | blocked card |
/// | picker | signedIn | empty, allowed | create default workspace |
/// | picker | signedIn | `?redirect_workflow=` | resolve workflow redirect |
/// | picker | signedIn | rows | workspace (lastActive or first, `?redirect=`) |
EntryDecision resolveEntry(EntryContext context) {
  switch (context.route) {
    case EntryRoute.home:
    case EntryRoute.organizationEntry:
      return switch (context.session) {
        EntrySession.pending => const EntryWait(),
        EntrySession.signedOut => const EntryGoLogin(),
        EntrySession.error => const EntryShowLoadError(),
        EntrySession.signedIn => const EntryGoWorkspacePicker(),
      };
    case EntryRoute.workspacePicker:
      return _resolvePicker(context);
  }
}

EntryDecision _resolvePicker(EntryContext context) {
  switch (context.session) {
    case EntrySession.pending:
      return const EntryWait();
    case EntrySession.signedOut:
      return const EntryRecoverStaleSession();
    case EntrySession.error:
      return const EntryShowLoadError();
    case EntrySession.signedIn:
      break;
  }
  switch (context.defaultWorkspaceCreation) {
    case DefaultWorkspaceCreation.pending:
      return const EntryWait();
    case DefaultWorkspaceCreation.conflict:
      return context.raceRetryUsed
          ? const EntryShowLoadError()
          : const EntryReloadOnce();
    case DefaultWorkspaceCreation.failed:
      return const EntryGoLogin();
    case DefaultWorkspaceCreation.notAttempted:
      break;
  }
  switch (context.workspaces) {
    case WorkspacesPending():
      return const EntryWait();
    case WorkspacesFailed(:final isStaleSession):
      return isStaleSession
          ? const EntryRecoverStaleSession()
          : const EntryShowLoadError();
    case WorkspacesLoaded(:final list):
      final policy = list.creationPolicy;
      if (list.workspaces.isEmpty) {
        if (policy != null && !policy.canCreate) {
          return EntryShowBlocked(policy);
        }
        return const EntryCreateDefaultWorkspace();
      }
      final target = list.workspaces.firstWhere(
        (w) => w.id == list.lastActiveWorkspaceId,
        orElse: () => list.workspaces.first,
      );
      final workflowId = context.redirectWorkflowId;
      if (workflowId != null && workflowId.isNotEmpty) {
        return EntryResolveWorkflowRedirect(
          workflowId,
          fallbackWorkspaceId: target.id,
        );
      }
      return EntryGoWorkspace(
        target.id,
        target: context.redirectTarget,
        upgradeReason: context.upgradeReason,
      );
  }
}
