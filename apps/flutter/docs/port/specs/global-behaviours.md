# Global behaviours (shortcuts, toasts, modal stores, theme, sign-out reset, session expiry, banners, access denied, deployment shape and flags)
Upstream: `app/workspace/[workspaceId]/utils/commands.ts`, `providers/global-commands-provider.tsx`, `packages/emcn/src/components/toast/toast.tsx`, `stores/modals/*`, `app/_shell/providers/theme-provider.tsx`, `stores/reset-all-stores.ts`, `stores/user-data-reset-registry.ts`, `stores/index.ts`, `lib/auth/sign-out.ts`, `components/session-expired`, `components/impersonation-banner`, `components/workspace-access-denied.tsx`, `app/o/[organizationId]/components/organization-access-denied.tsx`, `lib/core/config/deployment-shape.ts`, `providers/feature-flags-provider.tsx`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

Paths relative to `apps/sim/` unless stated. The command palette (`stores/modals/search` consumer UI) is mapped by another agent; only the store is listed here.

## Files

| File | Lines | Role |
|---|---|---|
| `app/workspace/[workspaceId]/utils/commands.ts` | 153 | `COMMAND_DEFINITIONS` registry (11 ids) |
| `app/workspace/[workspaceId]/providers/global-commands-provider.tsx` | 234 | keydown matcher, register/invoke |
| `lib/core/utils/platform.ts` | — | `isMacPlatform()` = `/Mac|iPhone|iPod|iPad/i.test(navigator.userAgent)` (5–8) |
| `packages/emcn/src/components/toast/toast.tsx` | 806 | `ToastProvider`, `toast`, `useToast` |
| `stores/modals/search/store.ts` / `types.ts` | 195 / 89 | palette open state + precomputed block data |
| `stores/modals/variables/store.ts` | 126 | floating variables modal geometry (persisted) |
| `app/_shell/providers/theme-provider.tsx` | 85 | next-themes config |
| `lib/core/utils/theme.ts` | 29 | `syncThemeToNextThemes` |
| `hooks/queries/general-settings.ts` | 195 | settings query/mutation (theme) |
| `app/layout.tsx` | 272 | root providers, pre-hydration layout script, meta |
| `lib/auth/sign-out.ts` | 21 | `signOutAndRedirect` |
| `stores/index.ts` | 64 | `clearUserData` |
| `stores/reset-all-stores.ts` | 59 | `resetAllStores` |
| `stores/user-data-reset-registry.ts` | 21 | `registerUserDataReset` / `resetRegisteredUserData` |
| `lib/auth/stale-session-recovery.ts` | 29 | `recoverFromStaleSession` |
| `hooks/queries/session.ts` | 85 | session query |
| `app/_shell/providers/session-provider.tsx` | 154 | session context, upgrade refresh |
| `app/workspace/[workspaceId]/components/session-expired/session-expired.tsx` | 86 | takeover |
| `app/workspace/[workspaceId]/components/impersonation-banner/impersonation-banner.tsx` | 49 | banner |
| `packages/emcn/src/components/banner/banner.tsx` | 78 | `Banner` |
| `app/workspace/[workspaceId]/components/workspace-access-denied.tsx` | 27 | |
| `app/o/[organizationId]/components/organization-access-denied.tsx` | 27 | |
| `lib/core/config/deployment-shape.ts` | 160 | shape store + readers |
| `hooks/use-seed-deployment-shape.ts` | 16 | |
| `lib/core/config/env-flags.ts` | — | `NEXT_PUBLIC_*` constants (fallback) |
| `app/workspace/[workspaceId]/providers/feature-flags-provider.tsx` | 33 | |
| `lib/api/contracts/workspaces.ts` | — | `deploymentShapeSchema` 275–284, `workspaceFeatureFlagsSchema` 332–357 |
| `components/settings/settings-navigation-guard.tsx` | 69 | dirty-state guard dialog |
| `components/settings/use-settings-browser-navigation.ts` | 217 | history guard + `beforeunload` |
| `stores/settings/dirty/store.ts` | 99 | dirty guards store |
| `lib/api/client/request.ts` / `errors.ts` | — | `requestJson`, `ApiClientError` |

## Layout

### Keyboard shortcut registry (no UI)
`COMMAND_DEFINITIONS` (`commands.ts:45–101`). `Mod` = `Meta` on macOS, `Ctrl` elsewhere (`global-commands-provider.tsx:226–240`).

| id | shortcut | allowInEditable | Registered by (Phase) | Handler |
|---|---|---|---|---|
| `open-search` | `Mod+K` | true | Sidebar (1) | toggle `useSearchModalStore.isOpen` (`sidebar.tsx:1342–1347`) |
| `toggle-sidebar` | `Mod+B` | false | Sidebar (1) | `onToggle` → `toggleCollapsed` (`sidebar.tsx:1355–1360`) |
| `goto-logs` | `Mod+L` | true | Sidebar (1) | `router.push('/workspace/{id}/logs')` (workspace id from params or from the pathname); on the desktop shell `focusVisibleBrowserOmnibox()` wins first (`sidebar.tsx:1325–1340`) |
| `add-workflow` | `Mod+Shift+P` | false | Sidebar (1) | create workflow when `canEdit && !isCreatingWorkflow` (`sidebar.tsx:1349–1354`) |
| `add-agent` | `Mod+Shift+A` | true | Sidebar (1) | `window.dispatchEvent(new CustomEvent('add-block-from-toolbar', {detail:{type:'agent', enableTriggerMode:false}}))` — consumed by the canvas (Phase 2) (`sidebar.tsx:1311–1323`) |
| `run-workflow` | `Mod+Enter` | false | editor (2) | — |
| `accept-diff-changes` | `Mod+Shift+Enter` | true | diff view (3) | — |
| `open-workflow-search-replace` | `Mod+F` | true | editor (3) | — |
| `clear-terminal-console` | `Mod+D` | false | terminal (2) | — |
| `focus-toolbar-search` | `Mod+Alt+F` | false | toolbar (2) | — |
| `fit-to-view` | `Mod+Shift+F` | false | canvas (2) | — |

Matcher (`global-commands-provider.tsx:200–328`):
- `window.addEventListener('keydown', …, {capture: true})`; `event.isComposing` → ignore.
- Iterates the registry in insertion order; skips commands without a shortcut; skips `allowInEditable:false` commands when `document.activeElement` is an `input`, `textarea`, or has `isContentEditable` (contenteditable="false" does not count) (255–258).
- `parseShortcut`: split on `+`, last part is the key (single char lowercased), modifiers `mod`, `ctrl`, `meta|cmd|command`, `shift`, `alt|option` (200–213).
- `matchesShortcut`: `key` equals `e.key` (lowercased when single char) or `codeToKey(e.code)` (`KeyX` → `x`, `DigitN` → `N`) so dead keys / Option-letter layouts still match; **all four** modifier states must equal exactly (expected ctrl = `ctrl || (mod && !mac)`, expected meta = `meta || (mod && mac)`) (226–240).
- If the focused element or an ancestor carries `data-owned-shortcuts="Mod+K, …"` naming the same platform-resolved signature, the global command yields (265–275).
- On match: `preventDefault()`, `stopPropagation()`, run the handler (errors logged), stop (first match wins) (312–322).
- `register(commands)` assigns ids (`generateId()` when absent), default `allowInEditable: true` when the command omits it, returns an unregister function; `useRegisterGlobalCommands` registers once on mount with handlers that always call the latest closure (363–386). `invoke(id)` runs a registered handler with a synthetic `KeyboardEvent('keydown')` and returns `false` when unregistered (330–339).
- Flutter: `Mod+L` and `Mod+K` are browser-reserved (location bar / search); the web build must `preventDefault` in a capture-phase DOM listener (plan §4.2).

### Toasts (`shell.toast.stack`, `toast.tsx`)
Constants (32–64): `AUTO_DISMISS_MS 5000`; `TOAST_WIDTH 'min(100vw - 2rem, 280px)'`; `VIEWPORT_INSET_PX 16`; `BOUNDARY_INSET_PX 12`; `STACK_LIMIT 3`; `COLLAPSED_OFFSET_PX 13`; `COLLAPSED_SCALE_STEP 0.05`; `EXPAND_GAP_PX 8`; `ESTIMATED_TOAST_HEIGHT 56`; `CARD_BORDER_PX 2`; easing `[0.22, 1, 0.36, 1]`, `STACK_DURATION 0.4 s`, `RESIZE_DURATION 0.3 s`; `COMPACT_CARD_HEIGHT_PX 46` → radius 12, else 16.

API (175–252): `toast({message, description?, variant?, action?{label,onClick}, onDismiss?, onUserDismiss?, duration?, persistAcrossRoutes?})` → id; `toast.success/error/warning/info(message, options)`; `toast.dismiss(id)`, `toast.dismissAll()`; `useToast()` gives the same plus `setViewportBoundary(element)`. Calling `toast()` before the provider mounted throws.

Rules:
- `duration = input.duration ?? (input.action ? 0 : 5000)`; `duration <= 0` = persistent (600).
- Add beyond 3: evict the oldest toast with `duration > 0`, or index 0 when all are persistent; evicted toasts' `onDismiss` fires (121–127).
- Route change (`usePathname`) sweeps every toast without `persistAcrossRoutes` during render, so toasts raised by the new route's mount survive (143–150, 566–570).
- Paint order: newest first, except "ongoing status" toasts (persistent and without action, e.g. "Reconnecting...") sit behind all others (166–173).
- Geometry: collapsed card *i* has `y = −13·i`, `scale = 1 − 0.05·i`, height clamped to the front card's height, `zIndex = n − i`; expanded: `y = −(sum of previous natural heights + 8·i)`, scale 1, own height. Container height = front + 13·(min(n,3)−1) collapsed, or sum of heights + 8·(n−1) expanded (725–744).
- Expansion: mouse enter / focus within the stack → expanded; leave / blur out → collapsed. While expanded all auto-dismiss timers are cleared; they restart from the full duration when collapsed again (669–692). Stack emptying resets `expanded` (582–584).
- Per-toast timers (`setTimeout(duration)`); persistent toasts never get one.
- Dismiss (X or action): `onUserDismiss` then removal; `onDismiss` fires once for any removal (392–395, 609–622).
- Card (`ToastItem`, 408–482): `<li>` `absolute right-0 bottom-0 overflow-hidden border border-[var(--border-1)] bg-[var(--bg)]`, width `TOAST_WIDTH`, `transformOrigin: bottom`, `borderRadius` 12/16; content `flex flex-col gap-2 p-2`; row: message `RevealText` clamp 2 lines, `text-sm leading-5 text-[var(--text-body)]`, leading variant icon (`Bell`/`CircleInfo`/`CircleCheck`/`TriangleAlert`/`CircleAlert`, 16px `--text-icon`) inline before the text; right: `Button variant='quiet' size='icon'` (20px) with `X` 16px, `aria-label='Dismiss notification'`; description `RevealText` clamp 3, `text-small leading-[18px] text-[var(--text-muted)]`; action `Chip fullWidth justify-center` with `chipFilledFillTokens` (`--surface-5` light / `--surface-4` dark). Truncated text fades via a mask and reveals the hidden lines on hover (blur-in 0.3 s).
- Motion: enter `opacity 0, y = height` → `1, 0`; reshuffle 0.4 s with the easing; exit `opacity 0, scale .95` 0.15 s ease-in; `prefers-reduced-motion` → 0.
- Container (753–773): `<ol aria-live='polite' aria-label='Notifications'>` portaled to `document.body`, `fixed z-[var(--z-toast)]` (150), width `TOAST_WIDTH`; `right: 16px`, `bottom: max(16px, env(safe-area-inset-bottom))`; when a content boundary is registered (workflow pages register the pane so the stack sits inside it, inset 12px from its right/bottom): `right = clamp(12, boundary.right+12, max(12, 100vw − boundary.left − width − 12))`, `bottom = max(safe-area, clamp(12, boundary.bottom+12, max(12, 100dvh − containerHeight − 12)))` (764–769).
- The sweep uses the pathname only (query changes keep toasts).

### Modal stores (`stores/modals/*`)
- `useSearchModalStore` (`search/store.ts:66–195`, devtools name `search-modal-store`): `isOpen`, `setOpen(b)`, `open()`, `close()`, `data{blocks, tools, triggers, toolOperations, isInitialized}`, `initializeData(filterBlocks, isToolAllowed)` building palette rows from the block registry (skips `hideFromToolbar`, splits `category 'blocks'` (except `starter`) vs `'tools'`, adds `loop` (`#2FB3FF`) and `parallel` (`#FEE12B`) specials, triggers sorted Start/Schedule/Webhook Trigger first then alphabetically, tool operations filtered by the allowlists). Re-run by the Sidebar whenever the permission config, provider model lists, or the custom-block overlay version change (`sidebar.tsx:440–448`). Consumers: palette, `ProviderModelsLoader` (loads models while open), `WorkspaceChrome` (dismisses the peek), desktop `open-search` command.
- `useVariablesModalStore` (`variables/store.ts:378–410`, persisted under localStorage `variables-modal-store` with `partialize {position, width, height}`): `isOpen`, `position|null`, `width 320`, `height 320`, `setIsOpen`, `setPosition`, `setDimensions` (clamped to 320…500 × 320…600), `resetPosition`. `getVariablesPosition(stored, w, h)`: default centre of the free canvas (`innerWidth − --sidebar-width − 8 − panelWidth` by `innerHeight − 16 − terminalHeight`, offset by the sidebar width and 8px); a stored position is clamped into that box and replaced by the default when it had to move more than 100px on either axis (312–372). Phase 2 consumer; listed for the persistence key.

### Theme
- `ThemeProvider` (`theme-provider.tsx:92–120`): next-themes `attribute='class'` (`.light`/`.dark` on `<html>`), `enableSystem`, `disableTransitionOnChange`; app surface `defaultTheme 'system'`, `storageKey 'sim-theme'`; landing surface (`isLandingPath`) `defaultTheme 'light'`, `storageKey 'sim-landing-theme'` — chosen once from the first pathname. `forcedTheme='light'` when the first path segment is one of `login, signup, reset-password, sso, invite, verify, chat, resume, oauth, oauth-error, f, unsubscribe, cli, credential-groups` (51–77). next-themes' own pre-hydration script applies the stored class before paint; the `workspace-layout-dimensions` script in `app/layout.tsx:100–244` handles layout variables only (see `workspace-chrome.md`).
- `<meta name='color-scheme' content='light dark'>`; `themeColor` light `#ffffff`, dark `#0c0c0c` (`app/layout.tsx:38–41, 257`).
- Settings sync: `useGeneralSettings` (`GET /api/users/me/settings`) applies `data.theme` via `syncThemeToNextThemes` on every change (`general-settings.ts:308–310`); the helper writes `localStorage['sim-theme']` and dispatches a synthetic `StorageEvent` so next-themes updates in place (`theme.ts:12–29`). Changing the theme in settings: `useUpdateGeneralSetting({key:'theme', value})` → optimistic cache + immediate sync, `PATCH /api/users/me/settings {theme}`, rollback + re-sync on error, invalidate `['generalSettings','settings']` (`general-settings.ts:413–453`).
- Flutter: read/write `sim-theme` through `package:web` on web so the React app and the Flutter app agree (plan §4.1); `system` follows `MediaQuery.platformBrightness`; forced-light routes pin the light theme data.

### Store reset on sign-out
- `signOutAndRedirect(navigate)` (`sign-out.ts:8–21`): `Promise.all([signOut() /* Better Auth POST /api/auth/sign-out */, clearUserData()])`; if the in-memory reset succeeded navigate in-app to `/login?fromLogout=true`, else `window.location.assign` it. Called from the footer "Sign out" through the dirty guard.
- `clearUserData({preserveRecentImpersonations?})` (`stores/index.ts:23–64`): `stopAllDesktopTools('identity_boundary:clearUserData')`; remove every `localStorage` key except `next-favicon`, `sim-theme`, `sim-landing-theme` (+ `recent-impersonations` when preserving); `sessionStorage.clear()`; dynamic-import and `await resetAllStores()`; `useSettingsDirtyStore.reset()`; returns whether the in-memory reset ran.
- `resetAllStores()` (`reset-all-stores.ts:19–59`), in order: operation-queue `reset()`; `resetRegisteredUserData()` (runs every reset registered with `registerUserDataReset(storeId, fn)`, rethrows the first error after running all, `user-data-reset-registry.ts:65–80`); `await waitForConsoleHydration()`; workflow registry → `{activeWorkflowId:null, error:null, hydration:{phase:'idle', workspaceId:null, workflowId:null, requestId:null, error:null}, clipboard:null, pendingSelection:null}`; workflow store → empty blocks/edges/loops/parallels, `lastSaved: now`; subblock store `{workflowValues:{}}`; `getQueryClient().clear()`; execution store `reset()`; terminal console → empty entries, `isOpen:false`; `consolePersistence.reset()`; `clearAllExecutionPointers()`; mothership drafts `reset()`; mothership queue `reset()`; `await consolePersistence.persist({merge:false})`.
- Consequences to replicate: the sidebar width (`sidebar-state`) and every other persisted store key are wiped; the `sidebar_collapsed` cookie and theme survive; the React Query cache is emptied so the login page starts cold.
- Which stores register with the registry is open-ended (any store calling `registerUserDataReset` at module load); Phase 1 stores that must reset: session, workspaces/query cache, sidebar width, presence, modals (search `isOpen`), settings dirty, fullscreen origin.

### Session expiry
- Detection is the session query, not a 401 interceptor: `requestJson` throws `ApiClientError{status, message, body, code}` for any non-2xx and nothing global reacts to 401 (`request.ts:206–222`, `errors.ts:9–23`); `fetchWorkspacePermissions` rewraps 401 as `Error('Authentication required')` and 404 as `'Workspace not found or access denied'` (`workspace.ts:367–385`).
- `useSessionQuery` (`session.ts:589–603`): key `['session','detail']`, `staleTime` 5 min, `retry:false`, `refetchOnWindowFocus:true` (overrides the web default), `refetchInterval` 60 s while `session.impersonatedBy` (also bypasses Better Auth's cookie cache via `disableCookieCache`).
- `SessionExpired` (`session-expired.tsx:29–85`): arms once it has seen `session.user`; `expired = sawSession && !isPending && !error && !session.user` (a network error never counts). On expiry it calls `recoverFromStaleSession()` once: `signOut()` (clears cookies server-side) → on failure return false; else `clearUserData()` then `window.location.assign('/login')`. UI: `<main class="fixed inset-0 z-[var(--z-takeover)] flex flex-col items-center justify-center gap-3 bg-[var(--bg)] p-6 text-center">`, `<p class="text-sm text-[var(--text-secondary)]">` "Your session expired. Signing you out…" (or "The impersonation session expired. …"); on failure the text turns `--text-error` with ", but signing out failed." and a `Chip variant='primary'` "Try again" re-runs recovery. z 500.
- `SessionProvider` extra (`session-provider.tsx:358–436`): `?upgraded=true` in the URL → strip it (`history.replaceState`), refetch the session bypassing the cookie cache, invalidate `['organizations']` and `['subscription']`, and if the user has exactly one organization and none active, `organization.setActive` then refetch. Hosted/billing only.
- Flutter: session cubit with focus refetch; additionally treat an `ApiClientError` 401 from any request as a cue to refetch the session (the React app reaches the same end state on the next focus).

### Impersonation banner (`shell.banner.impersonation`, `impersonation-banner.tsx:100–135`)
Shown when `session.session.impersonatedBy` (platform admins). `Banner variant='destructive'`: `shrink-0 px-6 py-2.5 bg-red-50 dark:bg-red-950/30`; inner `mx-auto flex max-w-[1400px] items-center justify-between gap-3`; text `text-[13px] text-red-700 dark:text-red-300` "Impersonating {name|'this user'} ({email}). Changes will apply to this account until you switch back."; action `Button variant='destructive' className='h-[28px] shrink-0 px-2 text-[12px]'` "Stop impersonating" / "Returning..." (disabled while pending). On click: `useStopImpersonating` mutation (`hooks/queries/admin-users.ts`) → on success `clearUserData({preserveRecentImpersonations:true})` then `window.location.assign('/home')`; on error re-enable. Hosted/admin only → verified by review.

### Access-denied pages (`shell.access-denied`)
`WorkspaceAccessDenied` (`workspace-access-denied.tsx:6–27`) and `OrganizationAccessDenied` (`organization-access-denied.tsx:6–27`) are identical apart from copy: `<main class="desktop-title-bar-page flex items-center justify-center bg-[var(--surface-1)] p-6">` (min-height 100vh); `<div class="flex max-w-md flex-col items-center gap-3 text-center">`; icon disc `flex size-10 items-center justify-center rounded-full bg-[var(--surface-3)]` with `CircleAlert` 18px `--text-icon`; `<h1 class="text-[var(--text-primary)] text-lg">` "Workspace access denied" / "Organization access denied"; `<p class="text-[var(--text-muted)] text-sm">` "You do not have access to this workspace. Ask a workspace administrator for access or choose another workspace." / "You are not a member of this organization. Ask an organization admin to add you, or head back to your workspaces."; `ChipLink variant='primary' href='/workspace'` "View your workspaces". Rendered by the workspace layout when the host context is null (`layout.tsx:81–83`), by `WorkspaceHostProvider` on a 403 (`workspace-host-provider.tsx:293–295`), and by `app/o/[organizationId]/layout.tsx` for non-members.

### Deployment shape (`deployment-shape.ts`)
`DeploymentShape` (`contracts/workspaces.ts:250–284`): `hosted, billingEnabled, chatEnabled, azureConfigured, cohereConfigured, features{accessControl, auditLogs, customBlocks, dataDrains, dataRetention, inbox, sandboxes, scim, sessionPolicies, sso, usageMonitoring, whitelabeling}`. Readers: `useDeploymentShape()` (components), `getDeploymentShape()` (stores/helpers). Source: the `deployment` field of the workspace host context, seeded by `WorkspaceHostProvider` → `useSeedDeploymentShape` during render (so children never see the fallback) and re-seeded in an effect when it changes (`use-seed-deployment-shape.ts:11–16`); `seedDeploymentShape` ignores identical shapes (127–132). Fallback outside a seeded surface: `resolveDeploymentShape()` built from `env-flags` (`NEXT_PUBLIC_*` via `window.__ENV`): `isHosted` (`NEXT_PUBLIC_APP_URL` host is `sim.ai`/`*.sim.ai` or forced), `isBillingEnabled`, `isChatEnabled = !NEXT_PUBLIC_CHAT_DISABLED`, `isAzureConfigured = NEXT_PUBLIC_AZURE_CONFIGURED`, `isCohereConfigured = NEXT_PUBLIC_COHERE_CONFIGURED`, enterprise features from `NEXT_PUBLIC_*_ENABLED` twins (`env-flags.ts:65–82, 123, 339–474, 548, 608–616`). Other browser-read env flags used by Phase 1 surfaces: `NEXT_PUBLIC_STATUS_NOTICE_PREVIEW` (status notice preview), `NEXT_PUBLIC_DISABLE_INVITATIONS` / `NEXT_PUBLIC_DISABLE_PUBLIC_API` (`use-permission-config.ts:218–226`), `NEXT_PUBLIC_BRAND_NAME|LOGO_URL|WORDMARK_URL|FAVICON_URL|PRIMARY_COLOR|PRIMARY_HOVER_COLOR|ACCENT_COLOR|ACCENT_HOVER_COLOR|BACKGROUND_COLOR`, `NEXT_PUBLIC_CUSTOM_CSS_URL` (`ee/whitelabeling/branding.ts:8–38`). Flutter: `GET /api/public-env` seeds the fallback; the host context seeds the surface.

### Feature flags (`feature-flags-provider.tsx`)
`WorkspaceFeatureFlags` = `dashboards`, `workflow-tests`, `changelog`, `mothership-model-selector`, `mothership-plan-mode`, `mothership-computer-use?`, `mothership-memory-spaces?`, `projects?` (5–14). `useFeatureFlag(name)` returns `flags[name] ?? false` — the default for every flag is **false** (29–33). Resolved server-side per request by `isFeatureEnabled(name, {orgId})` (AppConfig + allowlists; `lib/*/feature-flag.ts`) and handed in by the layout (`layout.tsx:146–171`); `mothership-plan-mode` is per user and defaults to false on error (147). Flutter reads `GET /api/workspaces/[id]/feature-flags` (contract `workspaces.ts:342–357`; server addition) → `{flags: {the 7 required names}, desktopExecutor{available, registered}}`; absent keys → false. Consumers in Phase 1: Sidebar (`dashboards`, `changelog`, `workflow-tests`).

### Settings dirty guard (`SettingsNavigationGuard`, root layout)
- Store (`stores/settings/dirty/store.ts:218–262`): `guards{id → {isDirty, navigationBlocked, onDiscard?}}`, derived `isDirty`/`navigationBlocked`, `pendingLeave`; `requestLeave(leave, {discardOnConfirm=true})` runs `leave()` immediately when clean (returns true), returns false when `navigationBlocked`, otherwise stashes it; `confirmLeave` runs the stash (after `discardDrafts` when allowed); `cancelLeave`; `reset`.
- Guard (`settings-navigation-guard.tsx:10–68`): capture-phase document click on same-origin `a[href]` (not `download`, not `data-settings-navigation='managed'`, not `target≠_self`, not `aria-disabled`, not inside a button/input, not the current URL) while dirty → `preventDefault` + `requestLeave(() => router.push(dest))`. Dialog: `ChipConfirmModal` title "Unsaved changes", text "You have unsaved changes. Are you sure you want to discard them?", dismiss "Keep editing", confirm "Discard changes" (destructive). History: `use-settings-browser-navigation.ts` wraps `pushState/replaceState/go/back/forward` and `popstate` to stamp entries with an index and revert a traversal until confirmed (`discardOnConfirm:false` for history), and adds `beforeunload` prevention while dirty (209–216). Phase 1 only needs the dialog and the sidebar's `requestLeave` calls; editors register guards in Phase 5.

### Parity ids
`shell.toast.stack` · `shell.toast.item` (front card) · `shell.toast.item.action` · `shell.session-expired` · `shell.session-expired.retry` · `shell.banner.impersonation` · `shell.banner.impersonation.action` · `shell.access-denied` · `shell.access-denied.icon` · `shell.access-denied.title` · `shell.access-denied.cta` · `shell.dirty-guard.modal` · `shell.theme.root` (the `<html>` element's theme class ↔ Flutter `Theme.brightness`).

### Colour anchors
| # | Point | Light | Dark | Source |
|---|---|---|---|---|
| G1 | toast card: (card.left+4, card.top+4) | `--bg` #fefefe | #1b1b1b | `toast.tsx:426` |
| G2 | toast card border: (card.left, card.centerY) | `--border-1` = `var(--border)` #d8d8d8 (`globals.css:730`) | #444444 (`:894`) | `toast.tsx:426` |
| G3 | toast action chip: (chip.left+4, chip.centerY) | `--surface-5` #f3f3f3 | `--surface-4` #292929 | `chrome.ts:2` |
| G4 | session-expired background (720, 100) | `--bg` | #1b1b1b | `session-expired.tsx:67` |
| G5 | access-denied page (720, 100) | `--surface-1` #fbfbfb | #1e1e1e | `workspace-access-denied.tsx:143` |
| G6 | access-denied disc (disc.centerX+14, disc.centerY) | `--surface-3` #f7f7f7 | #242424 | `:146` |
| G7 | impersonation banner (banner.left+8, banner.centerY) | `red-50` #fef2f2 | `red-950/30` over `--surface-1` | `banner.tsx:12` |
| G8 | dirty-guard modal outer ring (modal.left+1, modal.top+1) | `--surface-4` #f5f5f5 | `--surface-5` #363636 | `chip-modal.tsx:234` |

## Tokens

| Element | Tokens |
|---|---|
| Toast card | bg `--bg`, border `--border-1`, radius 12/16, message `--text-body` `text-sm`/20px, description `--text-muted` `text-small`/18px, icon `--text-icon` 16px, dismiss button `--text-icon-muted` hover `--surface-active`, action chip `chipFilledFillTokens` |
| Session expired | bg `--bg`, text `--text-secondary` `text-sm`, error `--text-error`, retry `Chip primary` (`--text-primary` fill, `--text-inverse` text) |
| Impersonation banner | `red-50`/`red-950/30` bg, `red-700`/`red-300` text 13px, destructive button 28px / 12px |
| Access denied | bg `--surface-1`, disc `--surface-3`, icon `--text-icon`, title `--text-primary` `text-lg`, body `--text-muted` `text-sm`, CTA chip primary |
| Dirty guard modal | ChipConfirmModal sm (440) — chrome in `workspace-modals.md` |
| Theme root | `.dark`/`.light` class, `color-scheme: light dark` |

## States

| State | Behaviour | Source |
|---|---|---|
| Toast with action | persistent until dismissed or action | `toast.tsx:600` |
| 4th toast | oldest timed toast evicted | `121–127` |
| Hovering the stack | expanded, timers paused | `669–692, 775–782` |
| Route change | non-persistent toasts removed before the new route paints | `566–570` |
| Reduced motion | all toast motion 0 s | `400–401` |
| Session gone after being present | takeover + automatic sign-out; "Try again" on failure | `session-expired.tsx:43–84` |
| Session error (5xx/offline) | nothing (not an expiry) | `:43` |
| Impersonating | banner; session polled every 60 s | `impersonation-banner.tsx:107`, `session.ts:599–600` |
| Workspace 403 / unknown | access-denied page | `workspace-chrome.md` |
| Dirty settings editor | link clicks and history traversal ask to discard; `beforeunload` prompt | guard |
| Forced-light route | `<html class="light">` regardless of stored theme | `theme-provider.tsx:105` |
| `sim-theme` absent | `system` | `:79` |
| Hosted | consent banner, PostHog (`api_host '/ingest'`, autocapture off, exceptions on), GA page views — review only (known-gaps #4) | `posthog-provider.tsx:78–107`, `consent-provider.tsx:21–33` |
| Flags endpoint missing (older server) | all flags false; Dashboard/Changelog/Tests rows hidden | `feature-flags-provider.tsx:32` |

## Interactions

| Interaction | Behaviour | Source |
|---|---|---|
| `Mod+K` | toggle palette (also inside inputs) | `commands.ts:66–70` |
| `Mod+B` | toggle sidebar (not inside inputs) | `:96–100` |
| `Mod+L` | go to Logs (also inside inputs; `preventDefault` beats the browser's location bar) | `:61–65` |
| `Mod+Shift+P` | new workflow (not inside inputs; only with edit rights) | `:56–60` |
| `Mod+Shift+A` | add agent block (also inside inputs) | `:51–55` |
| Shortcut inside `[data-owned-shortcuts]` | yielded to the element | `global-commands-provider.tsx:265–275` |
| Toast X / action | dismisses that toast | `toast.tsx:392–395, 469–479` |
| Toast hover / focus | expands the stack and pauses timers | `775–782` |
| "Stop impersonating" | mutation → clear user data (keep recent impersonations) → `/home` | `impersonation-banner.tsx:121–132` |
| "Try again" (session expired) | re-run recovery | `session-expired.tsx:46–51, 80–82` |
| "View your workspaces" | `/workspace` | `workspace-access-denied.tsx:156` |
| Sign out (footer) | `signOutAndRedirect` → `/login?fromLogout=true` | `sign-out.ts` |
| Theme change in settings | optimistic class flip + localStorage + PATCH | `general-settings.ts:413–453` |
| OS theme change with `system` | next-themes follows `prefers-color-scheme` | `theme-provider.tsx:111` |

## Network and realtime

| Request | Key / staleTime | Notes |
|---|---|---|
| `GET /api/auth/get-session` (Better Auth client) | `['session','detail']` 5 min, focus refetch, 60 s poll while impersonating | expiry detector |
| `POST /api/auth/sign-out` (Better Auth client `signOut()`) | — | followed by `clearUserData` |
| `GET /api/users/me/settings` | `['generalSettings','settings']` 60 min | theme source |
| `PATCH /api/users/me/settings {theme}` | optimistic; invalidates the same key | |
| `GET /api/workspaces/[id]/host-context` → `deployment` | `['workspace-host','detail',id]` 30 s | shape seed |
| `GET /api/workspaces/[id]/feature-flags` | Flutter `['workspace','detail',id,'feature-flags']` 30 s | server addition |
| `GET /api/public-env` | once at boot | server addition; `NEXT_PUBLIC_*` fallback |
| stop impersonating (`hooks/queries/admin-users.ts`, `lib/api/contracts/admin.ts`) | — | admin only |
| `POST /ingest/*` (PostHog proxy), c15t consent backend `https://sim-sim.inth.app` | — | hosted only; not replicated functionally |
| `getQueryClient().clear()` on sign-out | — | every cached query dropped |

No socket events are consumed here directly; the reconnect toasts are documented in `workspace-chrome.md`.

## Parity checklist

| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | keyboard | `commands.ts:45–101` | all 11 ids with exactly these shortcuts and `allowInEditable` values exist in the Dart registry | | |
| 2 | keyboard | `global-commands-provider.tsx:226–240` | `Mod` resolves to Meta on macOS and Ctrl elsewhere; extra modifiers never match | | |
| 3 | keyboard | `:255–258` | `toggle-sidebar`/`add-workflow` ignored while an input, textarea or contenteditable is focused; `open-search`/`goto-logs`/`add-agent` still fire | | |
| 4 | keyboard | `:230–231` | `Mod+Shift+P` matches by physical key on layouts where Shift changes the character | | |
| 5 | keyboard | `:312–322` | matched shortcut is consumed (`preventDefault`); `Mod+L`/`Mod+K` never reach the browser | | |
| 6 | keyboard | `:265–275` | an element declaring `data-owned-shortcuts` (Flutter: a focused editor claiming the chord) wins | | |
| 7 | layout | `toast.tsx:35,38,426` | toast 280px wide, 16px from right/bottom, 1px border, radius 12 (≤46px tall) or 16 | | |
| 8 | layout | `:428–467` | 8px padding, 8px gaps, 16px icon inline with the message, 20px dismiss button | | |
| 9 | layout | `:733–734` | collapsed stack: 13px steps and 0.05 scale steps; expanded: 8px gaps | | |
| 10 | token | `:426` | G1/G2 anchors | | |
| 11 | token | `:475` | G3 action chip fill | | |
| 12 | state | `:600` | default auto-dismiss 5 s; action toasts persist; explicit `duration` wins | | |
| 13 | state | `:121–127` | 4th toast evicts the oldest timed one, never a persistent one while a timed one exists | | |
| 14 | state | `:566–570` | navigation clears non-`persistAcrossRoutes` toasts; "Reconnecting..." survives | | |
| 15 | state | `:166–173` | persistent status toasts are painted behind newer actionable toasts | | |
| 16 | interaction | `:669–692,775–782` | hover expands and pauses; leave collapses and restarts timers | | |
| 17 | interaction | `:392–395` | `onUserDismiss` fires for X/action, `onDismiss` for every removal | | |
| 18 | state | `theme-provider.tsx:79,104–105` | storage key `sim-theme`, default `system`, forced light on the listed segments | | |
| 19 | state | `theme.ts:12–29` | theme from settings is written to `sim-theme` and applied without reload | | |
| 20 | state | `stores/index.ts:32–39` | sign-out wipes localStorage except `next-favicon`, `sim-theme`, `sim-landing-theme` | | |
| 21 | state | `stores/index.ts:46` | sessionStorage cleared on sign-out | | |
| 22 | state | `reset-all-stores.ts:19–59` | every listed store returns to its initial state and the query cache is empty after sign-out | | |
| 23 | state | `sign-out.ts:19–20` | after sign-out the app lands on `/login?fromLogout=true` | | |
| 24 | state | `session.ts:589–603` | session refetched on window focus at most every 5 min; every 60 s while impersonating | | |
| 25 | state | `session-expired.tsx:36–43` | takeover only after a live session settles to null (not on error, not for signed-out visitors) | | |
| 26 | layout | `session-expired.tsx:66–84` | takeover covers the viewport at z 500 with the two texts and the retry chip on failure | | |
| 27 | interaction | `stale-session-recovery.ts:19–29` | recovery signs out, clears data, navigates to `/login`; failed sign-out shows the retry state | | |
| 28 | layout | `impersonation-banner.tsx:112–133`, `banner.tsx:8–75` | banner geometry, copy, action label states | | |
| 29 | interaction | `impersonation-banner.tsx:121–132` | stop → clear (keeping recent impersonations) → `/home` | | |
| 30 | layout | `workspace-access-denied.tsx:143–158` | access-denied composition and copy; organization variant differs only in copy | | |
| 31 | token | `:143,146` | G5/G6 anchors | | |
| 32 | state | `deployment-shape.ts:146–160` | readers return the host-context shape inside a workspace and the public-env fallback elsewhere | | |
| 33 | state | `feature-flags-provider.tsx:29–33` | unknown/missing flag → false | | |
| 34 | network | `contracts/workspaces.ts:342–357` | flags endpoint response shape consumed as-is | | |
| 35 | interaction | `settings-navigation-guard.tsx:59–67` | dirty guard dialog copy and buttons; cancel keeps editing | | |
| 36 | interaction | `stores/settings/dirty/store.ts:227–240` | `requestLeave` runs immediately when clean, defers when dirty, refuses when blocked | | |
| 37 | state | `use-settings-browser-navigation.ts:209–216` | `beforeunload` prompt while dirty (web) | | |
| 38 | state | `search/store.ts:72–82` | palette open state is global (toggle from shortcut, chip, desktop command) | | |
| 39 | state | `variables/store.ts:378–410` | `variables-modal-store` persistence shape `{position,width,height}` | | |
| 40 | state | `app/layout.tsx:38–41,257` | theme-color meta light `#ffffff` / dark `#0c0c0c`; `color-scheme: light dark` | | |
