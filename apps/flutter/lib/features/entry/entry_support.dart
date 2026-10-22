import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/platform/browser.dart';

/// `UPGRADE_REASONS` (`lib/billing/upgrade-reasons.ts:12`).
const Set<String> upgradeReasons = <String>{
  'credits',
  'storage',
  'tables',
  'seats',
};

/// `WORKSPACE_RACE_RETRY_KEY` (`workspace/page.tsx:26`), in sessionStorage.
const String workspaceRaceRetryKey = 'workspaceRaceRetry';

/// The session query as the entry table reads it.
EntrySession entrySessionOf(SessionState state) {
  if (state.isPending) return EntrySession.pending;
  if (state.isSignedIn) return EntrySession.signedIn;
  if (state.hasError) return EntrySession.error;
  return EntrySession.signedOut;
}

/// The workspace list query as the picker reads it: any error is a
/// failure (a refetch error with stale data still blocks the redirect, like
/// `workspacesError` upstream), else the data, else pending.
EntryWorkspaces entryWorkspacesOf(WorkspacesState state) {
  final list = state.list;
  if (list.hasError) {
    return WorkspacesFailed(status: list.apiError?.status);
  }
  final data = list.data;
  if (data != null) return WorkspacesLoaded(data);
  return const WorkspacesPending();
}

/// `destinationFor(id)` (`workspace/page.tsx:129-134`):
/// `?redirect=upgrade` → `/workspace/<id>/upgrade[?reason=]` (only a known
/// reason is kept), `?redirect=settings` → `/workspace/<id>/settings/general`,
/// else `/workspace/<id>`.
String workspaceDestination(
  String workspaceId, {
  EntryRedirectTarget? target,
  String? upgradeReason,
}) => switch (target) {
  EntryRedirectTarget.upgrade =>
    '/workspace/$workspaceId/upgrade'
        '${upgradeReason != null && upgradeReasons.contains(upgradeReason) ? '?reason=$upgradeReason' : ''}',
  EntryRedirectTarget.settings => '/workspace/$workspaceId/settings/general',
  null => '/workspace/$workspaceId',
};

/// `?redirect=` of the picker.
EntryRedirectTarget? redirectTargetOf(String? raw) => switch (raw) {
  'upgrade' => EntryRedirectTarget.upgrade,
  'settings' => EntryRedirectTarget.settings,
  _ => null,
};

/// `handleWorkflowRedirect` (`workspace/page.tsx:136-160`): the workflow's
/// own workspace editor, else the fallback workspace.
Future<String> workflowRedirectTarget(
  String workflowId, {
  required String fallbackWorkspaceId,
}) async {
  try {
    final summary = await locator<WorkflowsRepository>().summary(workflowId);
    final workspaceId = summary.workspaceId;
    if (workspaceId != null && workspaceId.isNotEmpty) {
      return '/workspace/$workspaceId/w/$workflowId';
    }
  } on Object {
    // Falls back to the target workspace like `handleWorkflowRedirect`.
  }
  return '/workspace/$fallbackWorkspaceId';
}

final MemoryAuthSessionStore _memorySessionStore = MemoryAuthSessionStore();

/// `sessionStorage` (browser on web, memory elsewhere; a registered
/// [AuthSessionStore] wins).
AuthSessionStore entrySessionStore() {
  if (locator.isRegistered<AuthSessionStore>()) {
    return locator<AuthSessionStore>();
  }
  return const BrowserWindow().origin != null
      ? const BrowserSessionStore()
      : _memorySessionStore;
}

/// Clears the in-memory `sessionStorage` stand-in (sign-out, desktop).
void clearEntrySessionStore() => _memorySessionStore.values.clear();
