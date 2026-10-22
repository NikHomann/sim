# Phase 1 review: workspace chrome, global behaviours, entry resolution, workspace modals (v1)

Reviewer: independent (did not write the code). Date: 2026-10-22. Upstream baseline: commit 27b53561 (as in the specs).

Scope: `lib/features/workspace_shell/{chrome,shortcuts,modals,theme}/**`, `lib/features/workspace_shell/routes.dart`, `lib/features/entry/**`, `lib/app/app.dart`, `lib/app/router.dart`, `lib/data/entry/entry_resolver.dart` and their tests. These were judged against `specs/workspace-chrome.md`, `specs/global-behaviours.md`, `specs/workspace-modals.md`, `specs/entry-resolution.md`, `specs/data-phase1.md` §7–8 and the React source. Where a spec and React disagree, React wins.

## State at review time

- `flutter analyze --fatal-infos`: clean when the review started. At the end it reported **2 infos** (`discarded_futures` at line 33, `unnecessary_lambdas` at line 159) in `test/features/workspace_shell/integration/real_shell_test.dart`. That file was created at 10:01 while the review was running and is outside this scope, but its infos make the `--fatal-infos` gate fail now.
- `flutter test test/features/workspace_shell/chrome test/features/workspace_shell/shortcuts test/features/workspace_shell/modals test/features/entry test/data/entry_resolver_test.dart`: **115 tests, all passed**. I ran it twice, the second time after the concurrent edit below.
- The files changed while the review was running: `workspace_chrome.dart` and `workspace_chrome_test.dart` at 09:58. That edit made the feature-flags 403/404 stop denying access. The line numbers below refer to the files as of 10:07.

## Findings (most severe first)

### 1. BLOCKER: none of the reviewed workspace modals can be reached in the running app. The switcher ships duplicate create/delete/leave modals and never wires invite, invitations or logo upload
- Spec: `workspace-modals.md`, all rows (parity ids `modal.*`); React `workspace-header.tsx:839–866`, `sidebar.tsx:1220–1227, 1366–1372`.
- Flutter:
  - Nothing in `lib/` imports `lib/features/workspace_shell/modals/{create_workspace_modal,workspace_confirm_modals,invite_modal,pending_invitations_modal,logo_upload,emails_input}.dart` except the modal files themselves and their tests.
  - The switcher (`switcher/workspace_switcher.dart:24`) imports its own `switcher/switcher_modals.dart`. That file holds a second implementation of create (`:14`), delete (`:106`) and leave (`:254`) with different parity ids (`workspace.switcher.create-modal`, `…delete-modal`, `…leave-modal`).
  - `sidebar/seams.dart:46–52` mounts `WorkspaceSwitcherChip` without `onInviteTeammates`, `onViewInvitations` or `onUploadLogo`. The menu items then call null callbacks: `workspace_switcher.dart:334, 339, 438`. "Invite teammates", "View invitations" and "Upload logo" do nothing.
- What is wrong:
  - The invite, pending-invitations and logo-upload flows are absent from the product.
  - Create, delete and leave exist twice, with different behaviour and parity ids, so the L6 parity capture cannot find `modal.create-workspace` and the other spec ids.
  - The 15 modal tests and 6 modal goldens cover code that ships to nobody.
- Fix:
  - Keep one implementation. Either delete `switcher_modals.dart` and call the `modals/` versions from the switcher, or the reverse, and then move the spec parity ids onto the survivor.
  - Wire the three missing actions in `seams.dart`:
    - `onInviteTeammates` → `showInviteModal`, with an `InviteModalConfig` built from the active workspace (`organizationId`, `inviteDisabledReason`), `canInvite = userPermissions.canAdmin` and the env/permission-group invite gate.
    - `onViewInvitations` → `showPendingInvitationsModal`.
    - `onUploadLogo` → a file picker (`accept` = `logoImageTypes`), the optimistic preview, then `WorkspaceLogoUploader.upload`, reverting the preview on `null`.
  - Add one widget test that drives each modal from the real `WorkspaceSwitcherChip`.

### 2. MAJOR: on web, a redirect landing does not update the forced-light theme or the toast sweep
- Spec: `global-behaviours.md` row 18 and row 14; `entry-resolution.md` row 25; React `theme-provider.tsx:16–31, 70`, `toast.tsx:143–150`.
- Flutter: `lib/app/app.dart:44–45, 66–71`.
- What is wrong:
  - `_path` comes from `router.routeInformationProvider`. That provider calls `notifyListeners` only for `go`/`push` and for platform route changes. When GoRouter applies a `redirect`, `routerReportsNewRouteInformation` writes `_value` without notifying (`go_router-16.3.0/lib/src/information_provider.dart:123–152, 163–178`). At notification time, `value` still holds the pre-redirect request.
  - Example: a signed-out cold load of `/app/workspace/<id>/home` with `sim-theme=dark` is redirected by `appSurfaceRedirect` to `/login`. `_path` stays `/workspace/<id>/home`, so the login page renders dark even though `login` is a forced-light segment.
  - The same applies to every redirect-only transition: `/workspace/:id` → `/home` or `/w`, `/home` with chat off, and the settings legacy redirects. None of them run `sweepRoute()`.
- Fix:
  - Listen to `router.routerDelegate` and read `router.routerDelegate.currentConfiguration.uri.path`, the post-redirect location. Initialise `_path` the same way after the first frame.
  - Add a `SimApp` test: stored dark theme, signed out, deep link into the shell; expect `/login` with `ThemeMode.light`.

### 3. MAJOR: on web the paste admission guard does nothing; on Windows the context-menu paste bypasses it
- Spec: `workspace-chrome.md` row 31 and the "Paste anywhere editable" interaction; React `app/_shell/paste-admission-guard.tsx:225–324` (a capture-phase DOM `paste` listener).
- Flutter: `chrome/paste_admission_guard.dart:112–185` overrides `PasteTextIntent` only.
- What is wrong:
  - On web, `DefaultTextEditingShortcuts` maps Ctrl/Cmd+V to `DoNothingAndStopPropagationTextIntent` (`flutter/lib/src/widgets/default_text_editing_shortcuts.dart:836–839, 956–969`). The browser pastes natively into the engine's hidden `<input>`, so `PasteTextIntent` is never invoked and an oversized paste reaches the field unchecked.
  - On Windows, the selection toolbar's "Paste" calls `EditableTextState.pasteText` directly, not through the intent, so it is not guarded either.
  - `paste_guard_test.dart` runs only under `TargetPlatformVariant.only(TargetPlatform.windows)` on the VM with Ctrl+V, so it cannot see either gap.
- Fix:
  - On web, add a conditional-import `package:web` capture listener: `document.addEventListener('paste', …, true)`. It reads `clipboardData.getData('text/plain')`, resolves the limit from `PasteLimit.maybeOf(FocusManager.instance.primaryFocus.context)` (default 32 MiB), and on rejection calls `preventDefault()` + `stopImmediatePropagation()` and shows the same toast. Remove the listener on dispose.
  - On Windows, also guard the toolbar paste, e.g. with a `contextMenuBuilder` whose paste button goes through the same check.
  - Add an L5 web check for row 31.

### 4. MAJOR: the persistent connection toasts do not match React's composition
- Spec: `workspace-chrome.md` rows 22–23 and States "Reconnecting / Retrying workflow join / Offline / Join blocked"; React `workspace-permissions-provider.tsx:139–162`.
- Flutter: `lib/data/permissions/permissions_cubit.dart:165–173` (`toasts`), consumed by `chrome/permission_toasts.dart:72–94`.
- What is wrong: React has a single realtime-status slot, `isOfflineMode || isFileViewer ? null : showReconnecting ? 'Reconnecting...' : isRetryingWorkflowJoin ? 'Joining workflow...' : null`, plus separate offline and join-blocked toasts. The offline and join-blocked toasts are **not** suppressed on file-viewer routes. Flutter differs in three ways:
  - (a) It returns `[]` for file-viewer routes, which hides the offline and join-blocked toasts too.
  - (b) It can show "Reconnecting..." and "Joining workflow..." at the same time.
  - (c) It keeps showing the realtime status while offline.
  - (d) In addition, a toast the user dismissed with X is dropped from `_shown` (`permission_toasts.dart:88–90`), so the next distinct list re-shows it. React keeps its id ref and does not re-raise the same message.
- Fix:
  - Compute `realtime = (offline || fileViewer) ? null : reconnectingStable ? reconnecting : retryingJoin ? joining : null` and `toasts = [realtime?, offline?, joinBlocked?]`.
  - Treat a change in the realtime slot as dismiss + show.
  - Do not re-show a user-dismissed toast until its condition clears.
  - Tests: offline + reconnecting shows only "Connection unavailable"; file viewer + offline shows the offline toast; a dismissed toast stays dismissed while another one appears.

### 5. MAJOR: entry redirects push browser history where React replaces it, so Back gets trapped
- Spec: `entry-resolution.md` §6 (`router.replace(destinationFor(target))`); React `app/workspace/page.tsx:168, 229, 237, 263, 280` (all `router.replace`).
- Flutter: `features/entry/entry_pages.dart:92, 94, 96, 260, 279, 308, 366, 376`, all `router.go`. In go_router 16, `go` pushes a browser history entry (`replace` is false unless the engine history is empty, `information_provider.dart:130–150`).
- What is wrong: `/home` → `/workspace` → `/workspace/<id>/home` leaves `/home` and `/workspace` in history. Back from the workspace lands on `/workspace`, which immediately redirects forward again, so the user cannot go back past the app.
- Fix: navigate inside `Router.neglect(context, () => router.go(target))` for every entry decision (go_router's replace-in-history idiom), or resolve these decisions in router redirects (see finding 8).

### 6. MAJOR: the sidebar's data loads start one round-trip after host-context instead of in parallel
- Spec: `workspace-chrome.md` row 33; React `prefetch.ts:81–120` prefetches workflows, chats, folders, permissions, profile and workspaces together.
- Flutter:
  - `chrome/workspace_chrome.dart:129–141` starts host, flags, permissions, the workspace list, settings and the overlays.
  - Workflows and folders are first requested in `WorkspaceSidebar.initState` (`sidebar/sidebar.dart:88–89`).
  - The sidebar mounts only after the `ready` gate, i.e. after host-context resolves (`workspace_chrome.dart:205–209`).
- What is wrong: cold entry becomes host-context → (wait) → workflows/folders/chats/profile, adding one RTT to the first useful paint. That is the waterfall row 33 forbids.
- Fix: issue `WorkflowsCubit.load(id)`, `FoldersCubit.load(id)`, the chats list and the profile query from `_enterWorkspace`. The sidebar then binds to warm queries.

### 7. MAJOR: on Windows, sidebar width, collapse and theme are not persisted
- Spec: `workspace-chrome.md` "Collapse and persistence": "on Windows keep them in the `KeyValueStore`"; `global-behaviours.md` "Theme".
- Flutter: `packages/sim_api/lib/src/storage/platform/shared_web_state_stub.dart:4` returns an in-memory `MemorySharedWebState`. `SidebarController` and `ThemeModeController` read and write only through it (`chrome/sidebar_controller.dart:44–48`, `theme/theme_mode_controller.dart:52–55`).
- What is wrong: every relaunch on Windows resets the rail to 224 px, expands it, and resets the theme to `system` until settings sync.
- Fix: back the non-web `SharedWebState` with the `KeyValueStore`, keeping the same key names (`sidebar-state` envelope, `sidebar_collapsed`, `sim-theme`).

### 8. MAJOR: the NoTransitionPage plus extra-frame re-entry workaround avoids a real crash but depends on timing and has no test
- React: not applicable (`ShellRoute` is a Flutter artefact).
- Flutter: `features/entry/entry_pages.dart:17–36` (`_PostFrameOnce`), `features/workspace_shell/routes.dart:107–115` (`ShellRoute` page with a constant `pageKey`).
- Assessment:
  - The constraint is real. The `ShellRoute`'s nested `Navigator` has one `GlobalKey`. A removed shell page stays mounted until its overlay entry is torn down, one frame later even with a zero-duration page. If a new shell page mounts in that window, you get "Multiple widgets used the same GlobalKey".
  - Waiting one extra frame avoids that window, so it is a working fix and not a masked logic bug. But it depends on two unstated invariants:
    - (i) Every shell exit must be zero-duration. The `ShellRoute` must stay a `NoTransitionPage`; a `MaterialPage` there would leave the old shell alive for about 300 ms.
    - (ii) Every re-entry must go through `_PostFrameOnce`.
  - Any future path that navigates into the shell from a non-shell page right after leaving it will crash without warning, for example a direct `go('/workspace/…')` from an auth or invite page or from a router redirect.
  - Nothing tests the access-denied → CTA → picker → granted workspace sequence. `workspace_chrome_test.dart:60–62` only checks that `/workspace` was visited.
- Fix:
  - Preferred: resolve `/home`, `/o` and the picker in async GoRouter `redirect`s whenever the session and the list are cached. The root navigator then goes shell → shell with the same page key, with no intermediate page and replace semantics (which also fixes finding 5). Keep a page only for the loading and card states.
  - Minimum: document invariant (i) on the `ShellRoute`, and add the regression test above asserting `tester.takeException()` is null.

### 9. MAJOR: the settings dirty guard covers only the footer and the switcher
- Spec: `global-behaviours.md` rows 35–36, "Settings dirty guard"; `workspace-chrome.md` interaction "Click an in-app link while a settings editor is dirty"; React `settings-navigation-guard.tsx:13–47` intercepts every same-origin `a[href]` click in the capture phase.
- Flutter:
  - `guardedGo` (`chrome/settings_navigation_guard.dart:13–25`) is called only by `settings_guard_test.dart:45`.
  - Sidebar navigation calls `navigator.go` without the guard: `sidebar/nav/nav_chip.dart:69`, `sidebar/nav/workspace_section.dart:86`, `sidebar/tree/workflow_tree.dart:1311`, `sidebar/tree/tree_operations.dart:78`, `sidebar/chats/chats_section.dart:96`, `search/search_palette.dart:250`.
  - Only `sidebar_footer.dart:123` and the switcher use `requestLeave`.
- What is wrong: once a Phase 5 editor registers a dirty guard, clicking any nav row, workflow or chat discards the draft silently. The test proves only a helper that ships unused.
- Fix: route `SidebarNavigator.go` (`sidebar/sidebar_environment.dart:59, 100`) and the palette's navigation through `guardedGo`. Leave `Mod+L` unguarded (React's goto-logs is `router.push`, not an anchor click). Re-point the guard test at a real sidebar click.

### 10. MINOR: the session-expired takeover renders below the toasts and modals
- Spec: `global-behaviours.md` row 26 ("covers the viewport at z 500"); React `session-expired.tsx:66` (`z-[var(--z-takeover)]` 500, above toast 150 and modal 200).
- Flutter: `chrome/workspace_chrome.dart:249–254` places it inside the routed page. The app-level `SimToastStack` (`app/app.dart:93–98`) and the `SimOverlayHost` modals paint above it.
- What is wrong: a "Reconnecting..." toast or an open modal stays on top of "Your session expired. Signing you out…".
- Fix: show the takeover through the overlay host's takeover layer, keeping the same arming logic.

### 11. MINOR: the content-pane border does not reserve its 1 px, so the content can paint over it
- Spec: `workspace-chrome.md` row 8, anchor C2; React `workspace-chrome.tsx:62, 404–405` (`border-l` inside a border-box).
- Flutter: `chrome/sidebar_frame.dart:149–169`. The `DecoratedBox` paints the left border behind `ClipRect(child: content)`, and the child is not inset.
- What is wrong: content starts at x = 224 instead of 225. Any page that paints an opaque background (a `Scaffold`, or a full-bleed `--bg` box) erases the only divider between rail and content.
- Fix: `Padding(padding: EdgeInsets.only(left: 1))` around the child inside the decoration, or a foreground-positioned border plus that padding.

### 12. MINOR: a failed workspace delete keeps the modal open, but React closes it
- React: `use-workspace-management.ts:172–196` (`confirmDeleteWorkspace` catches and logs, does not rethrow) and `workspace-header.tsx:436–445` (closes after the awaited call). The spec's state summary ("modal stays open") is therefore wrong.
- Flutter: `modals/workspace_confirm_modals.dart:121–129`. `workspace_modals_test.dart:322` ("a failure keeps the modal open") encodes the spec.
- Fix: close the modal after a logged failure, update the test, and correct `workspace-modals.md` State summary and row 37 wording.

### 13. MINOR: the pending-invitations modal deviates from React in layout and error copy
- React: `view-invitations-modal.tsx:75–105, 124–206`.
- Flutter: `modals/pending_invitations_modal.dart:94–109, 113–191`.
- What is wrong:
  - There is no `IdentityTile` for a single-workspace grant.
  - There are no "Before you join" (`InvitationDisclosure`) or "Workspace access" (`InvitationWorkspaceAccess`) fields.
  - The actions are always inline; React moves them below the details when details exist.
  - "Refresh invitation" sits in the row instead of the disclosure field.
  - Accept and decline errors are fixed strings instead of `getInvitationErrorMessage(getErrorMessage(error,''), fallback)`.
  - The error state is a plain row instead of `SettingsQueryErrorState`.
- Fix: port the section structure and the error-message mapping (spec row 40, interaction rows).

### 14. MINOR: email chips render outside the emails field surface
- React: `chip-emails-input.tsx` (tags inside the chip field).
- Flutter: `modals/emails_input.dart:65–67, 176–218`. This is an admitted deviation: a `Wrap` of tags above a separate `SimChipInput`.
- Fix: render the tags inside the field surface, as an inline wrap before the text entry. Rows 26 and M8 depend on the field geometry.

### 15. MINOR: the organization entry is a silent stub, and the gap is not recorded in known-gaps
- Spec: `entry-resolution.md` §8 and rows 6, 8, 9, 29, 30 ("Until the endpoint exists, Flutter resolves to `/workspace` and records the difference in `known-gaps.md`").
- Flutter: no `OrganizationHomeResolver` is registered anywhere (`entry/entry_support.dart:68–71`). There are no `/o/:organizationId` or `/o/:organizationId/home` routes (`entry/entry_routes.dart:56–89`). If a resolver were registered, `EntryGoOrganizationHome` would navigate to `/o/<id>/home` (`entry_pages.dart:96`), which is an unknown route. `docs/port/known-gaps.md` has no row for this.
- Fix: add the known-gaps row. Either add the `/o/:id/**` routes with `OrganizationAccessDenied` or make the resolver impossible to register until they exist.

### 16. MINOR: the picker's clean-null branch cannot be reached through the real router
- Spec: `entry-resolution.md` rows 5 and 10; React `home/page.tsx:15–27` (invalid session → `/workspace`) and `workspace/page.tsx:100–119` (sign out stale cookies, then `/login`).
- Flutter: `entry/entry_routes.dart:29–35`. `appSurfaceRedirect` sends any non-error null session to `/login` before `/home` or the picker can run `recoverFromStaleSession`. Branch c of `resolveEntry` is reachable only in tests that disable the redirect.
- What is wrong: stale auth cookies are never cleared. The Flutter `/login` does not bounce, but the React app on the same origin will keep bouncing its `/login` back while the stale cookie lives.
- Fix: let `/workspace` pass the gate on a null session so the picker recovers, as React does. Otherwise record the deviation.

### 17. MINOR: `/workspace/:id/w` does not redirect to the first workflow
- Spec: `entry-resolution.md` row 22; React `w/page.tsx:34–45`.
- Flutter: `features/workspace_shell/routes.dart:126` renders a placeholder.
- Fix: add the redirect (`GET /api/workflows?workspaceId=` → first workflow), or mark the row as Phase 2 in the spec and known-gaps.

### 18. MINOR: on Windows, "Try again" on the `/home` error card does nothing
- Flutter: `entry/entry_pages.dart:102–103` calls `WorkspaceStatusCards.loadError(context)` without `onTryAgain`. The default `_reload` (`:164`) is `BrowserWindow().reload()`, which is a no-op off web (`auth/shared/platform/browser_stub.dart:19`).
- Fix: pass an in-app retry (`_session.load()` after invalidating the session query), as the picker does at `:242–254`.

### 19. MINOR: IME composition is not ignored by the shortcut matcher
- React: `global-commands-provider.tsx` ignores keydown when `event.isComposing`.
- Flutter: `shortcuts/shortcut_matcher.dart:84–99` defaults `isComposing` to false, and `shortcuts/global_commands.dart:124–128` never sets it.
- Fix: set `isComposing` from the focused `EditableText`'s `value.composing.isValid`.

### 20. MINOR: browser-reserved chords rely on engine behaviour that nothing verifies
- Spec: `global-behaviours.md:70` and row 5 ("the web build must `preventDefault` in a capture-phase DOM listener").
- Flutter: a `HardwareKeyboard` handler (`shortcuts/global_commands.dart:211–224`) that returns `handled`. On web this depends on the engine's raw-key reply calling `preventDefault` inside the same dispatch. Nothing proves that `Mod+L` / `Mod+K` never reach the browser.
- Fix: add an L5 web check, focused field plus Ctrl+L leaving the URL bar unfocused, or the DOM capture listener the spec names.

### 21. MINOR: feature-flags denial is half removed
- Flutter:
  - `chrome/workspace_chrome.dart:193–194`: `_denied` ignores its `flags` parameter.
  - `workspace_chrome.dart:37`: the class doc still says "host context (or feature flags) answered 403/404".
  - `workspace_chrome.dart:198`: the outer `BlocBuilder<FeatureFlagsCubit>` now only rebuilds the whole shell on every flags emit.
  - `data/runtime/feature_flags_cubit.dart:39–40` still documents "the same access-denied handling as the host context".
  - `data-phase1.md` §9 still says "403 feature-flags → same access-denied handling".
- Assessment: the behaviour (gate on host-context only) matches React's layout. The code and docs no longer agree.
- Fix: drop the parameter and the outer builder (read flags where they are consumed), and update the class doc, the cubit doc and data-phase1 §9.

### 22. MINOR: sign-out state differs from React
- Spec: `global-behaviours.md` rows 20–21; `workspace-chrome.md` row 18.
- Flutter:
  - `chrome/sidebar_controller.dart:89–93`: `reset()` writes `sidebar-state` back with 224 after `resetUserData` (`data/reset/reset_user_data.dart:60–69`) has wiped it. React leaves the key absent.
  - `sessionStorage` is never cleared (no `sessionStorage` handling in `data/reset/` or the storage package), so `workspaceRaceRetry` and similar survive sign-out.
- Fix: delete the key instead of writing the default, and clear `sessionStorage` in `resetUserData` on web.

### 23. MINOR: four smaller rows are missing
- Legacy `isCollapsed` migration (`workspace-chrome.md` row 19): `readSidebarCollapsed` reads only the cookie (`shared_web_state_web.dart:77–78`).
- `beforeunload` while dirty (`global-behaviours.md` row 37): not implemented.
- Branding (row 39): favicon and custom CSS are not applied; only `Title` is set (`workspace_chrome.dart` branding block).
- `<meta name="color-scheme" content="light dark">` (`global-behaviours.md` row 40): absent from `web/index.html`; `theme-color` is present.

### 24. MINOR: dead code
- `data/entry/entry_resolver.dart` has several things no page uses:
  - The `EntryRoute.workspace` and `EntryRoute.authPage` branches.
  - `EntryHostAccess`, `EntryGoWorkspaceHome`, `EntryGoWorkspaceEditor`, `EntryShowAccessDenied`, `EntryGoHome`, `EntryShowPage`.
  - `EntryGoOrganizationHome.path` (`'/o/<id>'`, while the page uses `/o/<id>/home`).
  - `EntryGoWorkspace.path`, which does not validate `reason` and so diverges from `workspaceDestination`.
  - `test/data/entry_resolver_test.dart:229–285` tests these dead branches.
- `app/router.dart:12–21`: `AppRoutes.workspacePicker`, `workspace` and `workflow` are unused. The dev SSE spike route (`:19–20, 39–44`) is still registered although its comment says "removed before Phase 1 ships".
- Fix: remove all of the above, or route `/workspace/:id` and the auth pages through `resolveEntry` so the table is used.

### 25. MINOR: test quality
- Several tests cover code that does not run in the app:
  - `settings_guard_test.dart` drives only the unused `guardedGo` (finding 9).
  - The modal tests and goldens cover modals that cannot be reached (finding 1).
  - The paste tests run only on the VM Windows variant (finding 3).
- The chrome and modal goldens compare against themselves only: alchemist images captured from the Flutter output, with no numeric assertion of the anchors (C1–C8, G4–G6, M1–M8). They catch regressions but cannot catch a drift present at capture. Add small numeric probe tests for the anchors (pixel at point = token), as `04-test-plan.md` §4 item 4 asks.
- The failure-mode headers are honest and specific. Exceptions:
  - `workspace_modals_test.dart:15` lists "a failure closes the modal" for delete; React closes it (finding 12).
  - `theme_mode_test.dart:59–90` re-enumerates the constant forced-light set. Keep two representative paths plus the "first segment only" case.
- Missing regression tests: redirect-landing theme (finding 2), shell re-entry (finding 8), toast composition (finding 4).

### 26. Spec corrections found during the review (no code change)
- `entry-resolution.md` (Data table, row h and the Network section) names `GET /api/workflows/[id]/state`. The React contract `getWorkflowStateContract` is `GET /api/workflows/[id]` (`lib/api/contracts/workflows.ts:737–740`), which is what Flutter calls (`workflows_repository.dart:131–138`).
- `workspace-modals.md` State summary: "Delete error: logged only (modal stays open)" is wrong; see finding 12.

## Spec rows verified correct

These rows were checked statically against the code and React. Where a row is verified only inside the modal code, finding 1 still means it is not in the shipped app.

- **workspace-chrome.md**: 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 16, 18 (web), 20, 21, 22, 24, 25 (the server answers 403 for unknown ids), 26, 28, 29, 30, 32, 36, 40.
  - Partial or failed: 8 (finding 11), 17 (web ok, Windows finding 7), 19 (finding 23), 23 (finding 4), 31 (finding 3), 33 (finding 6), 39 (finding 23).
- **global-behaviours.md**: 1, 2, 3, 4, 6, 19, 24 (focus via `AppLifecycleListener.onResume`), 25, 27, 28, 29, 30, 33, 35, 36, 38.
  - Partial or failed: 14 and 18 (finding 2), 20–22 (finding 22), 26 (finding 10), 37 and 40 (finding 23).
  - 39 is absent (Phase 2 consumer).
- **workspace-modals.md** (in `modals/` code only, see finding 1): 1, 12, 13, 14, 15, 18, 20, 21, 22, 23, 24, 25, 27, 28, 29, 31, 33, 34, 35, 36, 38, 39, 41, 42.
  - Partial: 19 (uploader ok; picker and preview unwired), 26 (finding 14), 40 (finding 13).
- **entry-resolution.md**: 1, 3, 7, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 26, 27, 28.
  - Partial or failed: 5 and 10 (finding 16), 6, 8, 9, 29 and 30 (finding 15), 22 (finding 17), 25 (finding 2).
- **data-phase1.md §7–8**:
  - The chrome-side mount of the loaders (host, flags, permissions, workspaces, settings, custom blocks, block visibility, provider models with the route and palette gate, branding) matches §7, except the sidebar loads (finding 6).
  - The §8 picker decision table in `resolveEntry` matches `workspace/page.tsx` row by row.
  - §8.1 (organization landing) is not implemented (finding 15).

## Rows not verifiable statically

- **workspace-chrome.md**:
  - 12–14 and C4–C8: colour anchors. The goldens look right, but they are self-referential (finding 25).
  - 15: collapsed label opacity, owned by the sidebar.
  - 27, window-blur half: depends on `AppLifecycleState` becoming inactive on web blur at runtime.
  - 34, 35, 37, 38: query keys, stale times and client defaults live in the data and `sim_api` layers, which were not reviewed here.
  - Focus order (Interactions): geometry-driven traversal of the overlaid handle.
- **global-behaviours.md**:
  - 5: browser `preventDefault` of handled chords (finding 20).
  - 7–13 and 15–17: the toast stack geometry, timers and ordering live in `sim_design` (`SimToastStack`), outside the listed code.
  - 23: footer sign-out, sidebar scope.
  - 31: G5/G6, golden only.
  - 32, 34: data layer.
- **workspace-modals.md**:
  - 2–11: ChipModal chrome and tokens, visual goldens only.
  - 16, 17, 32, 37: rename, invite gate and context-menu gating live in the switcher, outside this scope.
  - 30: invalidations inside `InvitationsCubit`, not reviewed.
- **entry-resolution.md**:
  - 2, 4: auth routes, outside this scope.
