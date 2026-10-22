# Phase 1 review: sidebar, workflow tree, search palette, workspace switcher (v1)

Reviewer pass, read-only. Judged against `specs/workspace-sidebar.md`, `sidebar-workflow-tree.md`, `search-palette.md`, `workspace-switcher.md`, `data-phase1.md` and the React source at the baseline commit; React wins where it disagrees with a spec.

Gate results (run from `apps/flutter`):
- `flutter analyze --fatal-infos`: No issues found.
- `flutter test test/features/workspace_shell/sidebar test/features/workspace_shell/search test/features/workspace_shell/switcher`: 205 tests, all passed.

No blockers. Most of the problems sit in the seams (production wiring, URL resolution, overlay and gesture interplay), not in the ported algorithms. The ported algorithms are faithful:
- the tree ordering, DnD bands, normalisation, insert index and reorder split;
- the selection store semantics;
- the palette ranking constants and tie-breaks;
- the switcher ordering, its search threshold and armed Enter.

Paths are relative to `apps/flutter/` unless they start with `apps/sim/`.

## Findings

### 1. MAJOR: "Open in new tab" and "Copy link" build wrong URLs on web and Windows

**Spec / React:**
- tree rows 33, 44, 92; sidebar rows 48, 60; palette row 36;
- `workflow-item.tsx:175-177` (`window.open('/workspace/…')`, origin-relative), `nav-item-context-menu.tsx`, `search-modal.tsx:386`.

**Flutter:**
- `lib/features/workspace_shell/sidebar/sidebar_environment.dart:68-72` (`absoluteUrl` resolves against `Uri.base` when `baseUrl` is null). Production never sets `baseUrl` (`resolveSidebarServices`, `:281-288`).
- `lib/features/workspace_shell/search/search_palette.dart:231-241`.
- `lib/features/workspace_shell/switcher/switcher_actions.dart:45-46`.

**Problem:**
- In dart2js/wasm, `Uri.base` is `location.href`, not `document.baseURI`. With `usePathUrlStrategy()` (`lib/bootstrap.dart:43`), resolving `workspace/ws/w/x` from `/app/workspace/ws/w/y` gives `/app/workspace/ws/w/workspace/ws/w/x`.
- This breaks every Cmd/Ctrl-click, middle-click, context-menu "Open in new tab" (tree, rail flyout, nav chips) and "Copy link".
- On Windows, `Uri.base` is the process working directory, so `launchUrl` gets a `file:///…` URL.

**Fix:**
- Compute one app base once, in one place: on web, `web.document.baseURI` (the `<base href>`, i.e. `…/app/`); on desktop, the configured server origin + `/app/`.
- Pass it as `RouterSidebarNavigator.baseUrl`. Reuse that one helper in the palette and switcher.
- Add a test that sets a nested current location and asserts the opened and copied URL.

### 2. MAJOR: the realtime invalidation room never runs in production, and other sidebar services are never provided

**Spec / React:** tree row 85; sidebar rows 41, 73; `use-workspace-workflows-room.ts:22-29`.

**Flutter:** `sidebar_environment.dart:179-196` reads `optional<RealtimeTransport>()`, but nothing in `lib/` registers a `RealtimeTransport`. So `sidebar.dart:92-99` never starts `WorkspaceWorkflowsRoom`, and edits made in another tab or by a teammate never refresh the tree until the 60 s staleness expires. The same factory never provides:
- `fetchStatusIndicator`: the hosted status card never polls;
- `chats`, `tables`, `files`: "No chats yet" / "No tables yet" / "No files yet" show even when data exists;
- `organizationHref`: the profile menu never shows Organization.

**Fix:**
- Register the socket transport and the status fetcher in the locator and pass them through `fromLocator`.
- Until the Phase 4 data sources exist, hide or explicitly mark the Chats and Tables/Files empty states, rather than claiming emptiness.
- Add a chrome-level test that the room joins on mount.

### 3. MAJOR (needs a runtime repro): holding the secondary button over 100 ms on a tree row opens both the row menu and the empty-area popover

**Spec / React:**
- tree row 52; `workflow-list.tsx:541-553`. The empty-area menu fires only when the target is the container, a `.space-y-0.5` gap or the empty zone, and row handlers stop propagation.

**Flutter:**
- `lib/features/workspace_shell/sidebar/tree/workflow_tree.dart:665-676`: an outer `GestureDetector(onSecondaryTapDown: openEmptyAreaMenu)` wraps every row.
- Each row's `SimPressable` also has `onSecondaryTapDown` (`packages/sim_design/lib/src/interaction/pressable.dart:182-184`).

**Problem:**
- Both are `TapGestureRecognizer`s in the same arena. When the press outlasts `kPressTimeout` (100 ms), `didExceedDeadline` calls `handleTapDown` on every member still in the arena, so both callbacks fire.
- `sidebar_widget_test.dart:161` uses `tester.tap(..., buttons: kSecondaryButton)` (down and up in one frame), so it never exercises this.

**Fix:**
- Resolve the empty-area menu from hit position, not with a competing recognizer. For example, a `Listener(onPointerDown)` on the tree that opens the empty menu only when no row zone (`_zones`, `_emptyZones`) contains the point.
- Or give rows a flag that the outer handler checks.
- Add a test: `startGesture(buttons: kSecondaryButton)`, `pump(150ms)`, `up`; expect one menu.

### 4. MAJOR (web): the browser's own context menu is not suppressed

**Flutter:** nothing in `lib/` or `packages/*/lib` calls `BrowserContextMenu.disableContextMenu()`. Flutter web enables the browser menu by default, so right-clicking a tree row, chat row, nav chip or switcher row shows the native browser menu over the Flutter menu.

**Fix:** call `BrowserContextMenu.disableContextMenu()` at web startup (`bootstrap.dart`).

### 5. MAJOR: creating a workflow or folder sends a client-computed `sortOrder`; the server must receive none

**Spec / React:**
- tree §Ordering ("the server receives no `sortOrder` for creates"); data-phase1 rows on `useCreateWorkflow` and `useCreateFolder`.
- `apps/sim/hooks/queries/workflows.ts:184-193` sends `variables.sortOrder` (undefined from the sidebar) and computes top-insertion only for the optimistic row.
- `hooks/queries/folders.ts:237-247`: same.
- The server computes its own top insertion from the DB when the value is absent (`app/api/workflows/route.ts:93,128`, `lib/workflows/sort-order.ts`).

**Flutter:**
- `lib/data/workflows/workflows_cubit.dart:222-229, 250` (`sortOrder: order.toInt()` always sent).
- `lib/data/folders/folders_cubit.dart:144-151, 169`.

**Problem:**
- The persisted order comes from the client cache. When the folder list is not loaded yet (the workflow cache only), or another tab or user has inserted since the last fetch, the new row is stored below existing items, which permanently diverges from React.
- `tree_operations_test.dart` header item 5 claims "the top-insertion sort order" but stubs `sortOrder: any`, so nothing pins the wire value.

**Fix:**
- Keep `order` for the optimistic row only. Send `sortOrder` to the repository only when the caller passed one explicitly.
- Add contract tests asserting that the create bodies have no `sortOrder` key.

### 6. MAJOR: `SimScrollFade` remounts the whole sidebar scroll subtree when edge state flips

**Spec / React:** sidebar rows 6, 25, 33, 66.

**Flutter:**
- `packages/sim_design/lib/src/widgets/scroll_fade.dart:82-87` returns a bare `NotificationListener` when there are no edges and a `ShaderMask(NotificationListener)` otherwise. The element at that slot changes type.
- The sidebar's `GlobalKey` (`sidebar.dart:47, 298`) sits above it.

**Problem:** these all reset, along with the scroll offset:
- `ChatsSection` state ("See more" count, selection, rename);
- every `SidebarSection._expanded`;
- the hover controllers;
- an open tree rename (its `WorkflowTree` state is rebuilt).

For example, collapsing "Chats" so the list fits springs the section back open, and "See more" that overflows resets to 5.

**Fix:** always build the `ShaderMask` (an opaque gradient when there are no edges), or key the listener.

### 7. MAJOR: the palette's Create folder and Import workflow rows never appear, and permission gating is never fed

**Spec / React:**
- palette rows 36, 38, 50; `sidebar.tsx:1945-1947` passes `onCreateFolder` and `onImportWorkflow`;
- the permission config drives the hidden pages.

**Flutter:**
- `lib/features/workspace_shell/chrome/workspace_chrome.dart:280-297` passes only `onCreateWorkflow`, and no `permissions:` or `accessRequestsEnabled:`.
- `search/palette_content.dart:105-120` therefore drops both rows. `PalettePermissionConfig()` stays all false, so hidden Tables/Files/Knowledge/Integrations always show.
- There are two parallel config types: `palette_models.dart:349-366` and `SidebarPermissionConfig` (`sidebar_environment.dart:119-133`). The sidebar's copy is also only ever the default (`sidebar.dart:258`).

**Fix:**
- Route Create folder through `TreeOperations.createFolder` (for example, a registered command, as with `add-workflow`), and route Import to the import seam.
- Use one shared permission-config type fed from `GET /api/permission-groups/user` to both the sidebar and the palette.
- Add a chrome-level test. The current palette tests inject the handlers themselves.

### 8. MAJOR: switcher Invite teammates, View invitations and Upload logo are dead in production

**Spec / React:** switcher rows 30, 40, 41; `workspace-header.tsx:404-407, 761-784`.

**Flutter:**
- `lib/features/workspace_shell/sidebar/seams.dart:46-52` builds `WorkspaceSwitcherChip` without `onInviteTeammates`, `onViewInvitations` or `onUploadLogo`.
- `switcher/workspace_switcher.dart:334, 339, 438` call them with `?.call()`.
- `showInviteModal`, `showPendingInvitationsModal` and `WorkspaceLogoUploader` exist but are unreferenced.
- `invitationsDisabledByConfig` is never passed.

**Fix:** wire all three in `WorkspaceSwitcherSlot`, and test through the slot, not the bare chip.

### 9. MAJOR: the switcher row context menu is modal, which breaks row-to-row "…" handoff

**Spec / React:**
- switcher rows 31-32. `context-menu.tsx:201` uses `modal={false}`.
- `workspace-header.tsx:340-354, 702-704` keeps the switcher open when another row's "…" is pressed.

**Flutter:**
- `switcher/workspace_switcher.dart:370-375` opens it with `SimOverlayEntry(modal: true)` plus a full-screen `SimOverlayBarrier` (`:1644`).
- So other rows' `_RowActionButton` pointer-down (`:1392-1395`) is never hit, and the dismissal closes the whole switcher.
- The anchor is a 0×0 rect with offset 4 (React: 1×1 trigger, so 5 px below).

**Fix:** reuse `showSidebarContextMenu` (`sidebar/shared/context_menu.dart`, non-modal, `+5`), and delete `_ContextMenuLayer` (`:1560-1702`).

### 10. MAJOR (Windows): Ctrl/Meta-click and middle-click on a switcher row do nothing

**Spec / React:** switcher row 25; `workspace-header.tsx:713-725`.

**Flutter:**
- `switcher/switcher_actions.dart:175-176`: `GoRouterSwitcherNavigator.openInNewTab` returns early when `!kIsWeb`.
- The row then returns without switching (`workspace_switcher.dart:1188-1195`).

**Fix:** route through `SidebarNavigator.openInNewTab` (it already falls back to `launchUrl`), and drop the duplicate navigator (see finding 21).

### 11. MAJOR (Windows, not runtime-verified): uploaded workspace logos and user avatars won't load

**Spec / React:** `logoUrl` is `/…` or `https://…` (`contracts/workspaces.ts`).

**Flutter:**
- `switcher/identity_tile.dart:61-69` passes the raw value to `Image.network`.
- `sidebar/footer/sidebar_footer.dart:168` does the same.

**Problem:** a server-relative path has no host on desktop, and no session cookie is sent.

**Fix:** resolve against the API base (as `auth_api.dart:577` does) and load through the authenticated client.

### 12. MAJOR: switcher keyboard highlight snaps to the top instead of "nearest"

**Spec / React:** switcher row 23; `workspace-header.tsx:236-242` (`scrollIntoView({block:'nearest'})`).

**Flutter:** `switcher/workspace_switcher.dart:806-810` calls `Scrollable.ensureVisible(ctx)` with default alignment 0.0, so every arrow press scrolls the row to the top of the 200 px list.

**Fix:** use `alignmentPolicy: keepVisibleAtEnd` / `keepVisibleAtStart` depending on direction, and test that the offset is unchanged when the row is already visible.

### 13. MAJOR: the palette list shows a scrollbar

**Spec / React:** palette row 12 (`scrollbar-none`, `search-modal.tsx:1360`).

**Flutter:** `search/search_palette.dart:898-911` builds a plain `ListView` under `MaterialApp.router`. The desktop and web scroll behaviour adds a `Scrollbar` (themed in `sim_theme.dart:169-186`).

**Fix:** use `ScrollConfiguration.of(context).copyWith(scrollbars: false)`.

### 14. MAJOR (performance, grows with the Phase 2 catalogue): the palette re-ranks every section on every rebuild

**Spec / React:** `search-modal.tsx:1062-1201` memoises `entriesBySection` on the deferred query.

**Flutter:** `search/search_palette.dart:735` calls `_compute()` in `build()`, so it reruns on every arrow, hover and Tab `setState`.

**Fix:** compute only on query, data or `didUpdateWidget` changes and render from the cache. Also track the selection by entry id, not index (`:437, 539`): today a stream update while the palette is open can make Enter open a different row.

### 15. MAJOR: in the collapsed rail, chat Rename locks the flyout open with no input

**Spec / React:** sidebar row 58; `collapsed-sidebar-menu.tsx:298-330`.

**Flutter:**
- `sidebar/chats/chats_section.dart:289-312` never renders an edit row for `_editingId`.
- `:170-191` locks the hover menu.
- `:130` refuses to unlock while editing.

The flyout stays pinned until the sidebar is expanded.

**Fix:** render an `InlineRenameField(small: true, maxLength: 100)` edit row, as `workflows/workflows_section.dart:228-231` does.

### 16. MAJOR: chat selection is local and never cross-clears workflow/folder selection

**Spec / React:** sidebar rows 54, 65; `stores/folders/store.ts:104-119, 175-189, 207-262, 282-289` (chat selection actions clear workflows and folders; `selectOnly` and `clearAllSelection` clear chats).

**Flutter:**
- `sidebar/chats/chats_section.dart:51-52, 69-85` keeps selection in `State`.
- `sidebar/tree/tree_cubit.dart` has no chat selection.
- `sidebar.dart:126-133` resets only the tree.

The anchor is also never updated on toggle (`chats_section.dart:80-83`; React `store.ts:218-238`).

**Fix:** move `selectedChats` and `lastSelectedChatId` into `SidebarTreeCubit` with the store's cross-clearing.

### 17. MAJOR: a rail flyout gets stuck after a collapse/expand round-trip

**Flutter:**
- `sidebar/rail/rail_flyout.dart:44-48`: no initial `_sync`.
- `:66-73`: `dispose` leaves the controller open.
- `rail/hover_menu.dart:25-29, 46-50`: no notify when already open.

**Problem:** hover a rail flyout, then press Mod+B twice. The chip keeps its active fill and hover never reopens the flyout.

**Fix:** close or reset the controller in `RailFlyout.dispose`, or sync after the first frame.

### 18. MINOR: a second "…" click reopens the menu unless the exit animation outlasts the click

**Spec / React:**
- tree row 43; sidebar chat menu;
- React `handleMorePointerDown` (`workflow-item.tsx`, "…" `onPointerDown`) records the open state before the outside-press handler closes the menu.

**Flutter:**
- `sidebar/tree/workflow_tree.dart:353-360` (`_closeOpenMenuFor` checks `menu.isOpen && menuOpenId == id` at tap-up).
- The overlay dismisses on outside pointer-down (`packages/sim_design/lib/src/overlay/overlay_manager.dart:206-217`).
- `SimMenuHandle.isOpen` stays true only while the exit tween runs, and is false immediately under `SimMotion.disabled` (`overlay_manager.dart:96-104`).
- `menuOpenId` is cleared in a microtask (`:362-369`).
- The same applies to `chats/chats_section.dart:395, 308`.

**Fix:** a `Listener(onPointerDown)` on the "…" button that records whether this row's menu is open; on tap, close-only when it was.

### 19. MINOR: revealing the active workflow re-runs less often than React

**Spec / React:** tree row 34. `workflow-list.tsx:360-372` depends on `folderMap`, so any folder change re-expands the active path and re-selects the active workflow if it is not selected, for example after a drop clears the selection.

**Flutter:** `sidebar/tree/workflow_tree.dart:537-552` keys on `'$active|$folderId|${tree.folders.length}'`. A reparented ancestor (folder drag), a rename or a post-drop selection clear does not re-run it.

**Fix:** key on the active id plus the folder path ids (and their parents), and re-apply `revealActiveWorkflow` whenever the folder list or workflow list identity changes. Note that `revealActiveWorkflow` already no-ops when there is nothing to change.

### 20. MINOR: selection clearing after delete and duplicate differs from the React hooks

**Spec / React:**
- `use-delete-folder.ts:56-57`: a single folder delete calls `clearSelection()`.
- `use-duplicate-selection.ts:127-129`: a mixed or multi-folder duplicate also calls `clearFolderSelection()`.

**Flutter:**
- `sidebar/tree/tree_operations.dart:259-262` skips every clear for a single folder.
- `:196` clears only the workflow selection after any duplicate.

**Fix:**
- For delete: always `clearSelection()`, and add `clearFolderSelection()` when the selection was mixed or held more than one folder.
- For duplicate: add `clearFolderSelection()` when the selection was mixed or held more than one folder.

### 21. MINOR: duplicated logic and icon data across features

**Icons:** `search/shell_icons.dart:33-170` re-inlines about 25 glyphs that are already in `sidebar/shared/sidebar_glyphs.g.dart` (identical path data), with a second regex SVG parser and painter (`:201-298`). The switcher uses those copies.

**Navigation:** `SwitcherNavigator` / `GoRouterSwitcherNavigator` (`switcher/switcher_actions.dart:149-191`) duplicate `SidebarNavigator` / `RouterSidebarNavigator` and `seams.requestLeave`.

**Components:** `_ContextMenuLayer` duplicates `showSidebarContextMenu`, and `_RenameRow` duplicates `sidebar/shared/inline_rename.dart`.

**Visit recording:** the chip's `_recordVisit` (`workspace_switcher.dart:198-205`) repeats the chrome's `_enterWorkspace` (`workspace_chrome.dart:134-136`).

**Stub fallback:** `WorkspaceSwitcherSlot` silently falls back to a dead stub chip when `InvitationsCubit` is not registered (`seams.dart:39`). The sidebar does use the real chip in production (the locator registers it), but a misconfiguration would ship a no-op chip.

**Fix:**
- generate the missing glyphs into `SidebarIcons` and delete `ShellIcons`;
- have one navigator;
- assert, rather than fall back, outside tests.

### 22. MINOR: workflow row content geometry

**Spec / React:**
- tree row 19; `workflow-item.tsx:423-475`. The label wrapper is `div.min-w-0` (not flex-1) inside `gap-2`, so avatars follow the name.
- `RowActions` is a direct chip child, at the chip's 6 px gap.

**Flutter:** `sidebar/tree/workflow_tree.dart:1353-1399` puts label (`Expanded`), avatars and `SidebarRowActions` in one `Row(spacing: 8)`. The result:
- the label-to-"…" gap is 8 px, not 6;
- avatars sit at the far right;
- the double-click target is the full width.

**Fix:** use `Expanded(Row(spacing: 8, [Flexible(label), avatars]))` followed by the actions at the chip gap. Folder rows are correct as they are: React folder rows do use `gap-2`.

### 23. MINOR: no Esc-cancel of a drag, and no Enter/Space on the tree container

**Spec / React:**
- tree row 76 (native DnD cancels on Esc; `dragend` resets state and collapses spring-opened folders);
- tree row 95 (`workflow-list.tsx:563-569`).

**Flutter:**
- The `Draggable` in `workflow_tree.dart:973-997` has no Escape handling.
- The tree root (`:661-680`) is not focusable.

**Fix:**
- While dragging, register an Escape handler (overlay host or `HardwareKeyboard`) that cancels the drag. For example, keep a `GlobalKey` on the `Draggable` and cancel through `DragTarget`'s rejection path, or end through `_onDragEnded` with no drop.
- Make the tree a focusable `Focus` with Enter/Space resetting the selection.

### 24. MINOR: lifecycle of the `TreeOperations` busy flags

**Flutter:**
- `sidebar/tree/tree_operations.dart:69-75` resets `isCreatingWorkflow` only after `optimisticMutation` has awaited every invalidation refetch (`lib/data/core/mutations.dart:122-126`), so "+" stays disabled for an extra round trip. React's `isPending` clears when `mutationFn` settles, and its invalidations are fire-and-forget.
- `sidebar.dart:84-87` disposes the old `TreeOperations` on a workspace switch while futures may still write its `ValueNotifier`s (`whenComplete`, `finally`), which triggers "used after dispose" in debug.

**Fix:**
- In `mutations.dart`, do not await invalidations (`unawaited`).
- Guard the notifiers, or defer disposal until in-flight work ends.

### 25. MINOR: Import workflow and Export are silent no-ops in production

**Spec / React:** tree rows 9, 44-45 (menu items present; behaviour is Phase 2).

**Flutter:**
- `sidebar/workflows/workflows_section.dart:85-90`, `sidebar/tree/workflow_tree.dart:414-415, 467-468`: `onImportWorkflow` and `onExport` are never provided (`sidebar_environment.dart:236-240`), so the enabled items do nothing.
- The "Importing..." label and spinner state are not modelled.

**Fix:** either disable them with a "Coming in Phase 2" note in the spec's deferral list, or wire a stub that toasts. Record this as `verified-by-review` deferred, per the spec's own ambiguity note.

### 26. MINOR: tree-spec parity ids missing

**Spec:** tree §Parity ids lists:
- `sidebar.workflows.section`, `.header`, `.header.title`, `.header.menu`;
- `sidebar.tree.context-menu`, `.context-menu.item.<id>`, `.context-menu.separator`;
- `sidebar.rail.workflows.flyout.new`, `.flyout.folder.<id>`.

**Flutter:** only the `shell.sidebar.workflows*` ids exist (`workflows_section.dart:112-146, 350-353`). `menuEntries` (`tree/tree_menus.dart:234-248`) sets no identifiers.

**Fix:** add the ids (the `MenuSpec.id` is already the suffix). The L6 capture script cannot locate the menu rows otherwise.

### 27. MINOR: other switcher items

- On a cold load, `recordVisit` cancels the list GET just started (`workspaces_cubit.dart:202` after `workspace_chrome.dart:135-136`).
- `create` can prepend a duplicate row (`workspaces_cubit.dart:295-300`; React skips when present). Mutations await invalidation before modals close.
- Keyboard gaps:
  - ArrowDown on the trigger does not open the menu;
  - `_focusedId` is null after a keyboard open, so Enter is ignored (`workspace_switcher.dart:757, 897`);
  - there is no typeahead.
- The Leave modal has no Enter default (`switcher_modals.dart:342-356`; React `defaultAction='dismiss'`).
- The Delete modal hand-rolls its field instead of using `SimChipModalField` (`:201-233`).
- The footer separator uses a fixed `height: 1` (`workspace_switcher.dart:977-985`) instead of `SimLayout.borderWidth`.
- Escape vs outside-press is inferred from `HardwareKeyboard` state (`:260-262`); pass a dismissal reason instead.

### 28. MINOR: other palette items

- Possibly missing cmdk keyboard extras (Ctrl+J/N/P, Alt+Arrow group jump), not confirmed: cmdk is not vendored here (`search_palette.dart:619-648`).
- Dates are hard-coded to en-US (`palette_rows.dart:49-71`); React uses the browser locale.
- The block tile radius is `SimRadii.sm` (4 px); React uses `rounded-md` (6 px) (`palette_rows.dart:251`).
- `panelWidth`, `logsDashboard` and `onAskSim` are never passed by the chrome; ask-mode Enter silently drops the query (`search_palette.dart:284`).
- Outside-close fires on pointer-down; React fires on click.
- Spec errata, where the code already follows React:
  - workflow-context verbs belong in the page "Actions" group (`utils.ts:158-160`);
  - `hideCopilot` does not gate New chat or ask mode.

### 29. MINOR: other sidebar items

- **Profile menu order with billing:** React registry order is Settings, Subscription, Teammates, Recently deleted, Organization, Sign out (`components/settings/navigation.ts:448, 474, 665`). `footer/sidebar_footer.dart:46-74` follows the spec, which is wrong here; correct spec row 67.
- **Sign out for the anonymous principal:** it is shown to them (`sidebar_footer.dart:125`; React excludes `ANONYMOUS_USER_ID`).
- **Help modal:**
  - it trims before validating and sends trimmed values (`help_modal.dart:98-101`);
  - there is no drop target and no ≥2 MB compression;
  - on Windows the picker returns `[]`;
  - `Image.memory(Uint8List.fromList(...))` rebuilds on every hover (`:369-371`).
- **Status notice:**
  - it is unmounted on collapse, losing state (`sidebar.dart:352-353`);
  - it lacks the error-tinted hover and `role=alert` (`status_notice.dart:105-113`).
- **Presence avatars:** they draw a 1 px border (React `border-0`, `presence-avatars.tsx:38`) and ignore `avatarUrl`.
- **Copy link:** its clipboard Future is not caught (`nav/nav_chip.dart:111`).
- **Footer menu parity ids:** `shell.sidebar.footer.profile.menu` and `.help.menu` are missing.
- **Chat rows:** the "…" is not revealed on focus-within (`chats_section.dart:381-390`).
- **Rail flyout details:**
  - collapsed chat flyout rows show a Pin glyph and no multi-select highlight;
  - the Tables/Files rail closes on any pointer button (`nav/workspace_section.dart:91-92`);
  - pinned folders lack the Pin glyph;
  - flyout items have no Ctrl or middle-click.
- **Deferred rows, record them in the specs:** row 55 (hover prefetch), row 56 (chat drag) and row 43 (settings body swap) are not implemented.

### 30. MINOR: test quality

**Tree:**
- `tree_operations_test.dart` header item 5 claims the top-insertion sort order but asserts `sortOrder: any` (finding 5).
- No widget test drives:
  - the 12 px edge zones or the normalised drop line in the mounted tree;
  - Shift-clicking rows;
  - the background click reset;
  - a second "…" click;
  - a held right-click (finding 3);
  - the URL that "Open in new tab" produces (finding 1);
  - Escape during a drag.
- The single DnD widget test covers only the "inside" band.
- The golden asserts no geometry. The geometry lives in `sidebar_widget_test.dart:53-85`, which is real and honest.

**Chats:**
- No widget test covers selection, the multi-target menu, rename, delete, See more/less, rail rename, the rail collapse round-trip or the scroll-fade remount.
- `tree_menus_test.dart:142-170` restates `chatMenuSpecs`.

**Palette:**
- `_reveal` (scroll-into-view) and hover-moves-selection are untested.
- The golden header (`goldens/search_palette_golden_test.dart:1-5`) claims the folder receipt and identity tile are captured, but the committed image ends at "Pages".
- The icon smoke test (`palette_ranking_test.dart:474-492`) asserts only that nothing throws.
- `palette_content_test.dart:383` restates a constant (`'⌘↵'`).

**Switcher:**
- Header item 1 ("once per workspace id") is never exercised with a re-pump.
- Item 6 ("optimistic") passes with a refetch-only implementation (`workspace_switcher_test.dart:418-420`).
- These are untested: the "…" handoff, blur and forced-close save, roving keys, middle-click, invite-disabled to Billing, and scroll-into-view.
- The golden covers only the open menu and asserts no geometry.

**Overall:** failure-mode headers are present and mostly honest. `switcher_logic_test.dart`, `drop_logic_test.dart`, `tree_cubit_test.dart` and `palette_ranking_test.dart` test behaviour and would fail on broken code.

## Spec rows verified correct

**sidebar-workflow-tree.md:**
1-5, 7-18, 20-25, 29, 31-42, 44-49, 51-75, 77-84, 86-94, 96.
- 30 and 53 hold for the UI only; the wire `sortOrder` fails (finding 5).
- 72-75 were checked against `use-drag-drop.ts`: the insert index on the full sibling list, `fromDestination` before `fromOther`, the re-index 0..n-1, the split payloads with `parentId`/`folderId: null` at the root, concurrent requests, and the "Only some items moved" / "Failed to move items" toasts.

**workspace-sidebar.md:** 1, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19, 20, 21, 29, 30, 31 (logic; never fed, finding 7), 32, 33 (logic; finding 6), 34, 40, 42, 57, 58 (expanded rail), 59, 62, 64, 65, 66, 68, 70, 71.

**search-palette.md:**
- 1, 3, 4 (formula), 5-11, 13-22, 24-35, 37 (builder), 39-42, 45-49, 51.
- The ranking constants, tie-breaks, caps and section fill all match `utils.ts`.
- The palette is mounted once (`workspace_chrome.dart:280`), and Mod+K toggles it (Cmd on mac, Ctrl elsewhere, `allowInEditable: true`).
- Escape closes only the top layer (`overlay_manager.dart:195-204`).

**workspace-switcher.md:**
- 1-4, 6-22, 24, 27 (see finding 27), 28, 29, 33-39, 42-46.
- Pin 409/404 tolerance and the data-phase1 §6 workspace invalidation map match.
- Armed Enter matches React exactly: typing arms it, pointer movement disarms it, and an empty list is ignored.

**data-phase1.md:**
- Folders, workflows and pinned-items keys, stale times, optimistic and rollback shapes, and the invalidation prefixes match §4.5-4.7 and §6.
- Exception: the create `sortOrder` (finding 5).

## Rows failing or partial

| Spec | Rows | Finding |
|---|---|---|
| Tree | 19 | 22 |
| Tree | 43 | 18 |
| Tree | 76, 95 | 23 |
| Tree | 85 | 2 |
| Tree | 33, 44, 92 (new-tab URL) | 1 |
| Sidebar | 6 and 25 (remount side-effect) | 6 |
| Sidebar | 41, 73 | 2 |
| Sidebar | 48, 60 | 1 |
| Sidebar | 54 | 16 |
| Sidebar | 61, 63 | 17 |
| Sidebar | 67 | 29 (spec wrong) |
| Sidebar | 43, 55, 56 | not implemented |
| Palette | 2 | parity id `search.trigger.chip` vs `shell.sidebar.header.search` |
| Palette | 12 | 13 |
| Palette | 23 | 14 |
| Palette | 36 | 1, 7 |
| Palette | 38, 50 | 7 |
| Palette | 43, 44 | 28 |
| Palette | 55 | 28 |
| Switcher | 23 | 12 |
| Switcher | 25 | 10 |
| Switcher | 26 | partial; the workflow-store reset was not verified |
| Switcher | 30, 40, 41 | 8 |
| Switcher | 31, 32 | 9 |

## Rows not verifiable statically

- **Colour anchors:** tree A1-A8, sidebar S1-S10, palette S1-S8, switcher W1-W8, and token rows (tree 6 hover fill and 50 menu surface; sidebar 22-28). These need the L6 pixel capture.
- **Tree:**
  - 26-28 (presence is Phase 2; the stack is empty);
  - 59 (ghost visuals; the code matches `utils.ts:56-74` numerically);
  - 70 (auto-scroll feel; the constants and formula match).
- **Sidebar:** 44 and 75 (no presence or chat data source yet); row 5 has no layout-shift check between loading and ready.
- **Palette:**
  - 52-54 (Phase 2 and Phase 4 sources are empty);
  - whether Flutter web prevents Chrome's Ctrl+K when the handler returns handled;
  - ⌘/⇧/↵/⇥ glyph rendering (they show as tofu in goldens).
- **Switcher:** focus return to the trigger after close; overflow fade metrics.
- **Runtime-only:**
  - finding 3 (arena deadline double-fire): reasoning from the recognizer source; needs the suggested test;
  - finding 11 (Windows logo loading);
  - the browser context menu (finding 4);
  - whether the rail flyout closes when the cursor leaves the browser window.
