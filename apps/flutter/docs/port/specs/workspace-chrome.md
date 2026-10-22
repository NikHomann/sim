# Workspace chrome (shell layout, providers, sidebar rail geometry)
Upstream: `app/workspace/[workspaceId]/layout.tsx`, `app/workspace/[workspaceId]/components/workspace-chrome/**`, `app/_shell/**`, `app/layout.tsx`, `stores/sidebar`, `hooks/use-sidebar-width.ts`, `hooks/use-drag-resize.ts`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

Paths are relative to `apps/sim/` unless stated. Line numbers refer to the files at the commit above. The sidebar's own contents (header, sections, footer) are in `workspace-sidebar.md`; shortcuts, toasts, theme, sign-out reset, session expiry, banners and access-denied pages are in `global-behaviours.md`. This spec covers the frame those sit in, the provider tree and its network calls, and the rail geometry (width, collapse, resize, hover-peek).

## Files

| File | Lines | Role |
|---|---|---|
| `app/workspace/[workspaceId]/layout.tsx` | 214 | Server layout: auth gate, host-context gate, prefetch, provider tree |
| `app/workspace/[workspaceId]/components/workspace-chrome/workspace-chrome.tsx` | 451 | Frame: sidebar shell, content pane, fullscreen, peek, mobile bar |
| `app/workspace/[workspaceId]/components/workspace-chrome/use-sidebar-peek.ts` | 218 | Hover-peek state machine (desktop shell only) |
| `app/workspace/[workspaceId]/components/workspace-chrome/sidebar-chrome-context.tsx` | 53 | `{isCollapsed, isPeeking, onToggle}` context for the hosted sidebar |
| `app/workspace/[workspaceId]/components/workspace-chrome/workspace-viewport.tsx` | 27 | `h-dvh` viewport column, `--surface-1` background |
| `app/workspace/[workspaceId]/components/workspace-chrome/index.ts` | 4 | barrel |
| `app/workspace/[workspaceId]/prefetch.ts` | 146 | Server prefetch of sidebar data (keys/staleTimes reused by client hooks) |
| `app/workspace/[workspaceId]/prefetch-access.ts` | 72 | Server prefetch of permission-group config, integration availability, access-request discovery |
| `app/workspace/[workspaceId]/providers/feature-flags-provider.tsx` | 33 | 7 server-resolved flags, `useFeatureFlag` |
| `app/workspace/[workspaceId]/providers/workspace-host-provider.tsx` | 56 | host-context query, deployment-shape seed, 403 → access denied |
| `app/workspace/[workspaceId]/providers/workspace-permissions-provider.tsx` | 261 | permissions query, "Reconnecting..." / offline / join-blocked toasts |
| `app/workspace/[workspaceId]/providers/workspace-scope-sync.tsx` | 57 | PostHog groups + workflow registry workspace switch |
| `app/workspace/[workspaceId]/providers/settings-loader.tsx` | 12 | warms general settings (theme sync) |
| `app/workspace/[workspaceId]/providers/provider-models-loader.tsx` | 113 | 9 provider model lists → providers store |
| `app/workspace/[workspaceId]/providers/custom-blocks-loader.tsx` | 56 | custom-block registry overlay |
| `app/workspace/[workspaceId]/providers/block-visibility-loader.tsx` | 45 | preview/kill-switch visibility overlay |
| `app/workspace/[workspaceId]/providers/global-commands-provider.tsx` | 234 | shortcut registry (see `global-behaviours.md`) |
| `app/workspace/[workspaceId]/providers/desktop-oauth-connect-listener.tsx` | 12 | no-op on web |
| `app/_shell/application-loading.tsx` | 35 | loading surface |
| `app/_shell/providers/theme-provider.tsx` | 85 | next-themes config (see `global-behaviours.md`) |
| `app/_shell/public-env-script.tsx` | 97 | `window.__ENV` transport |
| `app/_shell/paste-admission-guard.tsx` | 110 | capture-phase paste size guard |
| `app/_shell/providers/session-provider.tsx` | 154 | session context, `?upgraded=true` refresh |
| `app/_shell/providers/get-query-client.ts` | 51 | React Query defaults |
| `app/_shell/providers/query-provider.tsx` | 12 | |
| `app/_shell/providers/tooltip-provider.tsx` | 11 | |
| `app/_shell/hydration-error-handler.tsx` | 64 | console.error filter (no UI) |
| `app/_shell/desktop-title-bar.tsx` | 37 | macOS lane (inert on web) |
| `app/_shell/consent/*` (10 files) | 572 | hosted-only cookie consent (c15t) |
| `app/_shell/providers/posthog-provider.tsx` | 175 | hosted analytics |
| `app/_shell/providers/browser-telemetry.tsx` | 82 | telemetry gate |
| `app/layout.tsx` | 272 | root layout, pre-hydration layout script |
| `components/branded-layout.tsx` | 43 | title/favicon/custom CSS from brand config |
| `components/settings/settings-navigation-guard.tsx` | 69 | dirty-state discard dialog (see `global-behaviours.md`) |
| `stores/sidebar/store.ts` | 141 | width/collapse store (persist) |
| `stores/sidebar/types.ts` | 23 | |
| `stores/constants.ts` | 92 | `SIDEBAR_WIDTH` and friends |
| `hooks/use-sidebar-width.ts` | 29 | rehydrate + viewport resize sync |
| `hooks/use-drag-resize.ts` | 168 | generic drag-resize (panel/terminal); sidebar uses its own copy |
| `app/workspace/[workspaceId]/w/components/sidebar/hooks/use-sidebar-resize.ts` | 98 | sidebar drag-resize |
| `hooks/use-stable-flag.ts` | 133 | anti-flicker boolean for the reconnecting toast |
| `hooks/use-is-mobile.ts` | 30 | `(width < 768px)` media query |
| `app/_styles/globals.css` | — | lines 402–452 shell variables and z-index; 578–626 sidebar width/collapse rules |

emcn components used by the chrome itself: `Chip` (mobile bar only), `SidebarTooltip` wrapper (desktop lane only), `cn`. Everything else in the frame is plain `div`s.

## Layout

### Viewport column (`shell.viewport`)
`workspace-viewport.tsx:291`: `flex h-dvh w-full flex-col overflow-hidden bg-[var(--surface-1)]` (mobile-only `max-md:fixed …` variants ignored). Children in DOM order (layout.tsx:185–207): `ImpersonationBanner` (renders nothing unless impersonating), `SessionExpired` (fixed takeover, nothing otherwise), then the chrome.

### Chrome row (`shell.chrome`)
`workspace-chrome.tsx:317–320`: `desktop-workspace-window-frame relative flex min-h-0 flex-1 flex-col md:flex-row`, attribute `data-sidebar-collapsed` when collapsed. At ≥768px this is a horizontal flex row filling the viewport height.

Children in order:
1. Mobile top bar (322–334) — `md:hidden`; `flex shrink-0 items-center border-[var(--border)] border-b bg-[var(--surface-1)] px-2` with a `Chip` (`PanelLeft`/`X` icon, label "Navigation"/"Close navigation", `mobileIconOnly`). **Out of scope** (known-gaps #5); the breakpoint that hides the sidebar and shows this bar is `(width < 768px)` (`hooks/use-is-mobile.ts:5`). Absent at the parity viewports 1440×900 and 1280×800.
2. Drag-region div (336–342): `desktop-window-drag-region desktop-workspace-window-drag-region`, `h-2` expanded / `h-[var(--desktop-title-bar-height)]` collapsed. `globals.css:532–536` sets it `position:absolute; inset:0 0 auto; display:none` outside the macOS shell, so it contributes nothing on web. Do not reproduce.
3. Sidebar shell outer (`shell.sidebar.shell`, 343–390): `sidebar-shell-outer shrink-0 overflow-hidden` + `SIDEBAR_NO_MOTION_CLASS` (`animate-none! transition-none! [&_*]:animate-none! [&_*]:transition-none!`, sidebar `constants.ts:64–65`) + width class: `w-[var(--sidebar-width)]` normally, `w-0` on a fullscreen route, `PEEK_CARD_CHROME` while peeking. Attributes: `data-collapsed` when collapsed (desktop), `data-peek` while peeking, `aria-hidden` + `inert` on a fullscreen route. Inner (`sidebar-shell-inner h-full shrink-0 [&_.sidebar-container]:w-full!`, `w-full` or `w-[var(--sidebar-width)]` while peeking) wraps `SidebarChromeProvider` → the `Sidebar` element.
4. Content shell (`shell.content`, 391–411): `workspace-content-shell flex min-h-0 min-w-0 flex-1 flex-col`, attributes `data-sidebar-collapsed`, `data-content-fullscreen`. Inner pane (`shell.content.pane`, 402–408): `min-h-0 flex-1 overflow-hidden bg-[var(--bg)] max-md:border-l-0` + `CONTENT_PANE_DIVIDER` = `border-l border-[var(--border)]` (62–63), `border-l-0` on a fullscreen route. So the only divider between rail and content is this 1px left border on the pane (0.5px at ≥2dppx, `globals.css:477–481`).
5. Title-bar toggle wrapper (412–447) and `TitleBarHistoryNav` (448): both `hidden` unless `html[data-sim-desktop-title-bar=inset]` (macOS shell). Absent on web/Windows.

### Rail widths (`stores/constants.ts:21–35`, `stores/sidebar/store.ts`)
| Constant | Value |
|---|---|
| `SIDEBAR_WIDTH.DEFAULT` | 224 |
| `SIDEBAR_WIDTH.MIN` | 224 |
| `SIDEBAR_WIDTH.COLLAPSED` | 48 (web; 0 on the macOS shell via `--sidebar-collapsed-width`, `globals.css:404,495`) |
| `SIDEBAR_WIDTH.MAX` | 400 |
| `SIDEBAR_WIDTH.MAX_PERCENTAGE` | 0.3 |
| `getMaxSidebarWidth(vw)` | `max(224, min(400, vw × 0.3))` (`store.ts:15–20`) → 400 at 1440, 384 at 1280 |
| `clampSidebarWidth(w)` | `min(max(w, 224), max)`; non-finite → 224; below 768px the ceiling is 400 (`store.ts:23–30`) |

CSS: `.sidebar-container { width: var(--sidebar-width) }` (`globals.css:578–580`); `.sidebar-shell-outer[data-collapsed] { --sidebar-width: var(--sidebar-collapsed-width) }` (590–592); `[data-collapsed][data-peek] { --sidebar-width: var(--sidebar-expanded-width) }` (602–604). `:root` defaults `--sidebar-width: 0px`, `--sidebar-collapsed-width: 48px`, `--sidebar-expanded-width: 256px` (402–405; the 256 comment is stale, the store default is 224 — the pre-paint script always overwrites it on workspace routes).

Rendered width while collapsed: 48px. Flutter: rail width = `isCollapsed ? 48 : clamp(storedWidth)`.

### Resize handle (`shell.sidebar.resize-handle`, `sidebar.tsx:1916–1930`)
- Rendered by the Sidebar (not the chrome) as a sibling of the `<aside>` inside `relative h-full` (1381); omitted while peeking.
- `absolute top-0 right-0 bottom-0 z-20 hidden w-[8px] translate-x-1/2 md:block` → an 8px-wide strip centred on the rail's right edge (4px inside, 4px over the content pane). Transparent; no hover paint.
- Cursor: `cursor-ew-resize` expanded, `cursor-e-resize` collapsed (1920).
- Expanded: `role='separator'`, `aria-orientation='vertical'`, `aria-label='Resize sidebar'`, `onPointerDown` → `useSidebarResize`. Collapsed: `role='button'`, `aria-label='Expand sidebar'`, `onClick` → toggle; `Enter`/`Space` toggles (1265–1273). `tabIndex=0` always.
- Drag (`use-sidebar-resize.ts:272–328`): on pointerdown set `data-resizing` on `.sidebar-shell-outer`, `body.cursor='ew-resize'`, `body.userSelect='none'`, pointer capture on the handle; on every pointermove compute `clamp(ev.clientX, 224, getMaxSidebarWidth(innerWidth))` and write `--sidebar-width` on the shell inside `requestAnimationFrame` (one write per frame, latest value wins); on `pointerup`/`pointercancel`/window `blur` tear down, call `setSidebarWidth(lastWidth)` (persists, re-clamps, writes `:root`), remove the scoped override and `data-resizing`. No React re-render during the drag. Note the value is the raw `clientX` (the rail starts at x=0).
- `hooks/use-drag-resize.ts` is the same mechanism generalised (`cursor`, `cssVar`, `getTarget`, `compute`, `commit`, `onApply`); it is used by the panel/terminal, not the sidebar, and is documented here only so Phase 2 reuses one Dart implementation: rAF-coalesced apply, commit once on release from the last pointer event when the target is still attached, otherwise commit the last applied value (`328–344`).

### Collapse and persistence (`stores/sidebar/store.ts`)
- `isCollapsed` is seeded from the cookie `sidebar_collapsed` (`readCollapsedCookie`, 73–76, strict `=1` match) and written back on every toggle as `sidebar_collapsed=1|0; path=/; max-age=31536000; samesite=lax` (66–69). The server layout reads the same cookie for the first render (`layout.tsx:158`).
- `sidebarWidth` is the only persisted field, under localStorage key `sidebar-state` in zustand-persist shape `{"state":{"sidebarWidth":<n>},"version":0}` (113–129). A legacy persisted `isCollapsed` is ignored by `merge` (134–138) and migrated into the cookie once by the pre-paint script (`app/layout.tsx:146–151`).
- `skipHydration: true`; rehydration is triggered in `useSidebarWidth`'s `useLayoutEffect` (`use-sidebar-width.ts:174–176`), which then sets `_hasHydrated` and calls `syncWidth` (122–127). Until hydrated the chrome uses the server/cookie prop (`workspace-chrome.tsx:233`).
- `syncWidth` (99–109): `renderedSidebarWidth = innerWidth < 768 ? innerWidth : clamped`; writes `--sidebar-expanded-width` and `--sidebar-width` (collapsed → `--sidebar-collapsed-width`) on `:root` (40–49). Re-run on window resize via rAF (`use-sidebar-width.ts:178–192`) and on every pathname change once hydrated (`workspace-chrome.tsx:261–263`).
- `setSidebarWidth` is a no-op while collapsed (87–92). `toggleCollapsed` flips, writes the cookie, syncs (93–98).
- `workspaceDropdownOpen` lives here too (81, 86) but the sidebar uses local state for the switcher.
- Pre-paint script (`app/layout.tsx:100–244`): runs only when the path contains `/workspace/` or starts with `/o/`, `/account/settings`, `/selfhost/settings`; reads cookie + `sidebar-state`, computes `max(224, min(400, innerWidth*0.3))`, writes both variables before first paint; also seeds `--panel-width` (290..40vw), `--editor-connections-height` (30..300), `--terminal-height` (30..70vh) and `data-panel-active-tab` from `panel-state`, `panel-editor-state`, `terminal-state` (Phase 2 keys, listed so the Flutter `KeyValueStore` uses the same names).

Flutter: share the cookie and the `sidebar-state` localStorage key byte-for-byte on web (plan §4.1) so both apps agree; on Windows keep them in the `KeyValueStore`.

### Collapsed rail rendering
- `aside[data-collapsed]`: every `span` and `.text-small` inside gets `opacity: 0` (`globals.css:619–622`), `.sidebar-collapse-hide` too (624–626). Labels stay in layout (width) but invisible; rows keep their height.
- Row chips shrink to 32px wide via `SIDEBAR_RAIL_CHIP_CLASS = 'group-data-[collapsed]/rail:w-[32px]'` (sidebar `constants.ts:50`): 8px gutter + 32px chip + 8px gutter = 48px rail; the 16px glyph sits at x=16..32, centred on the rail midline (24px) — the same column the expanded rows' icons occupy, so nothing moves on toggle.
- `SidebarChromeProvider` passes `isCollapsed = !isMobile && isCollapsed`, `isPeeking`, `onToggle` (382–388); the Sidebar treats `isCollapsed && !isPeeking` as collapsed (`sidebar.tsx:400–401`).

### Hover-peek flyout of the collapsed rail (`use-sidebar-peek.ts`, `workspace-chrome.tsx:196–244`)
Enabled only when `!isMobile && isCollapsed && !isFullscreen && titleBarMode === 'inset'` (240) — `titleBarMode` is read from `html[data-sim-desktop-title-bar]`, set only by the macOS Electron shell (`app/layout.tsx:108–114`). **On web and Windows the peek never activates**; the web rail keeps its own hover flyouts (see `workspace-sidebar.md`). Recorded for completeness and for Phase 6 (where Windows also does not set `inset`, so still inactive):
- Timings: `PEEK_OPEN_DELAY_MS = 90` (dwell on the title-bar toggle before opening), `PEEK_CLOSE_DELAY_MS = 180` (grace after the pointer leaves), `PEEK_POINTER_SAMPLE_MS = 16` (pointermove sampling floor), `PEEK_GAP_TOLERANCE_PX = 12` (padding around trigger and card for the hit-test) (6–19).
- Card geometry (`PEEK_CARD_CHROME`, 49–50): `absolute top-[var(--desktop-title-bar-height)] left-2 z-[var(--z-modal)] flex max-h-[calc(100%-var(--desktop-title-bar-height)-8px)] w-auto flex-col rounded-lg border border-[var(--border)]`; fill is the sidebar's own `--surface-1`; no shadow; inner shell width `--sidebar-expanded-width`; the aside's scroll region bounds itself inside the max height (`globals.css:606–612`).
- Open/close: `mouseenter` on the trigger starts the 90ms timer; `mouseleave` cancels a pending open only; once open, a document `pointermove` hit-test (card ∪ trigger ∪ any `[data-radix-popper-content-wrapper]`, padded 12px) keeps it open, otherwise a 180ms close timer starts; `Escape` closes unless an open popper exists; the search modal being open (`useSearchModalStore.isOpen`) forces it closed (208, 241–244); clicking the toggle docks the sidebar instead.
- While peeking the Sidebar suppresses its title-bar lane and the resize handle (`sidebar.tsx:1390, 1916`).

### Fullscreen routes
`FULLSCREEN_SUFFIXES = ['/upgrade']` (27, 141–143): sidebar shell `w-0`, `aria-hidden`, `inert`; content pane drops its left border; the last non-fullscreen pathname is stored in `useFullscreenOriginStore.setOrigin` (250–252) so `/upgrade`'s Back control can return (Phase 5).

### Z-order (`globals.css:441–452`)
dropdown 100 · toast 150 · modal 200 · popover 300 · tooltip 400 · takeover 500 · shell-gate 600. The resize handle is `z-20` inside the sidebar's stacking context; the peek card is `z-modal`.

### ApplicationLoading (`shell.loading`, `app/_shell/application-loading.tsx:16–33`)
`role='status'`, `aria-label='Loading {brand.name}'`, `flex w-full items-center justify-center bg-[var(--bg)]` + `desktop-title-bar-page` (`padding-top: var(--desktop-title-bar-height); min-height: 100vh`, `globals.css:509–518`) when `fullScreen` (default), else `h-full`. Centre content: `brand.wordmarkUrl` → `<img class="h-8 max-w-[240px] object-contain">`; else a non-default `brand.name` → `<span class="text-[var(--text-tertiary)] text-lg">`; else `<SimWordmark size='loading' tone='brand-muted' />`. Shown as the Suspense fallback while the workspace content resolves (`layout.tsx:90, 104–107`) and by workflow navigation.

### Parity ids
| id | element |
|---|---|
| `shell.viewport` | `WorkspaceViewport` root |
| `shell.chrome` | chrome row |
| `shell.sidebar.shell` | `.sidebar-shell-outer` |
| `shell.sidebar` | `<aside.sidebar-container>` (also the root id of `workspace-sidebar.md`) |
| `shell.sidebar.resize-handle` | the 8px strip |
| `shell.content` | `.workspace-content-shell` |
| `shell.content.pane` | inner `bg-[var(--bg)]` pane |
| `shell.loading` | `ApplicationLoading` |
| `shell.banner.impersonation` | see `global-behaviours.md` |
| `shell.session-expired` | see `global-behaviours.md` |
| `shell.toast.stack` | see `global-behaviours.md` |
| `shell.consent.banner` | hosted only |

### Colour anchors (sampled at 1440×900 and 1280×800, dpr 1, placeholder page in the content pane; coordinates are viewport px)
| # | Point | Expected light | Expected dark | Source |
|---|---|---|---|---|
| C1 | (4, 450) — rail gutter left of the chips | `--surface-1` #fbfbfb | #1e1e1e | `sidebar.tsx:1383` |
| C2 | (224, 450) — the content pane's left border (expanded, default width) | `--border` #d8d8d8 | #444444 | `workspace-chrome.tsx:62,405` |
| C3 | (236, 890) — content pane bottom-left corner | `--bg` #fefefe | #1b1b1b | `workspace-chrome.tsx:404` |
| C4 | (4, 450) with `sidebar_collapsed=1` | `--surface-1` | #1e1e1e | `globals.css:590` |
| C5 | (48, 450) with `sidebar_collapsed=1` — collapsed border column | `--border` | #444444 | `stores/constants.ts:27` |
| C6 | (220, 450) — rail right gutter (inside the handle strip, which is transparent) | `--surface-1` | #1e1e1e | `sidebar.tsx:1919` |
| C7 | (720, 40) on `ApplicationLoading` | `--bg` | #1b1b1b | `application-loading.tsx:21` |
| C8 | (720, 40) on `WorkspaceAccessDenied` | `--surface-1` | #1e1e1e | `workspace-access-denied.tsx:143` |

## Tokens

| Element | Tokens |
|---|---|
| Viewport | bg `--surface-1` |
| Sidebar aside | bg `--surface-1`; width `--sidebar-width` |
| Content pane | bg `--bg`; `border-l` 1px `--border` (`--border-width` 1px / 0.5px at 2dppx) |
| Peek card (desktop only) | `rounded-lg` (8px), 1px `--border`, `z-[var(--z-modal)]` |
| Mobile bar (out of scope) | bg `--surface-1`, `border-b` `--border`, `px-2` |
| ApplicationLoading | bg `--bg`; brand-name text `--text-tertiary` `text-lg` (18px) |
| Resize handle | none (transparent); cursors `ew-resize` / `e-resize` |
| Collapsed labels | opacity 0 (`globals.css:619–626`) |

## States

| State | Behaviour | Source |
|---|---|---|
| No session | server `redirect('/login')` | `layout.tsx:73–76` |
| Host context null (no access / unknown workspace) | render `WorkspaceAccessDenied` in place of the whole shell | `layout.tsx:80–83` |
| Host context 403 later (access revoked) | `WorkspaceHostProvider` swaps the tree for `WorkspaceAccessDenied` | `workspace-host-provider.tsx:293–295` |
| Loading | `ApplicationLoading` with merged org brand | `layout.tsx:90,104–107` |
| Collapsed | rail 48px, labels invisible, chips 32px, handle becomes "Expand sidebar" button | `globals.css:590–626`, `sidebar.tsx:1916–1930` |
| Fullscreen route (`/upgrade`) | sidebar `w-0` + inert; pane border removed | `workspace-chrome.tsx:321,350,406` |
| Peeking | desktop shell only; see above | `use-sidebar-peek.ts` |
| Mobile (<768px) | top bar + full-screen navigation; out of scope | `workspace-chrome.tsx:177–192,322–334` |
| Reconnecting (socket) | persistent error toast "Reconnecting..." after 2000ms continuous disconnect, min visible 1500ms | `workspace-permissions-provider.tsx:29–30,139–152` |
| Retrying workflow join | persistent error toast "Joining workflow..." (not on file viewer routes) | `143–152` |
| Offline mode (`hasOperationError`) | persistent toast "Connection unavailable" + description "Recent changes may not have been saved. Refresh to resync." + action "Refresh" (`window.location.reload`); `canEdit/canAdmin` forced false | `155–158, 191–206` |
| Join blocked for the URL workflow | persistent toast "Unable to connect to workflow" + "Changes cannot be saved. Refresh to retry." + "Refresh"; edit rights forced false | `138, 159–162` |
| Impersonating | banner above the chrome | `global-behaviours.md` |
| Session expired | takeover | `global-behaviours.md` |
| Hosted only | consent banner, PostHog, status notice; verified by review (known-gaps #4) | `app/layout.tsx:53,261,267` |
| Branded (whitelabel) | org theme `<style>` injected by `BrandingProvider`; title/favicon/custom CSS by `BrandedLayout` | `ee/whitelabeling/components/branding-provider.tsx:54–64`, `components/branded-layout.tsx:273–302` |

All three persistent toasts use `toast.error(message, { duration: 0, persistAcrossRoutes: true, description?, action? })` and are replaced when the message changes, dismissed when it becomes null or the provider unmounts (`42–84`).

## Interactions

| Interaction | Behaviour | Source |
|---|---|---|
| Drag the handle | see Resize handle; clamp [224, max(224, min(400, 0.3·vw))]; persisted once on release | `use-sidebar-resize.ts` |
| Click the handle while collapsed | expands | `sidebar.tsx:1923` |
| Enter/Space on the focused handle while collapsed | expands | `sidebar.tsx:1265–1273` |
| `Mod+B` | `toggle-sidebar` command (not in editable targets) | `utils/commands.ts:96–100`, `sidebar.tsx:1355–1360` |
| Header "Collapse sidebar" chip / collapsed workspace chip | toggle | `workspace-sidebar.md` |
| Window resize | `syncWidth` in rAF: re-clamp to the new max, rewrite variables | `use-sidebar-width.ts:178–192` |
| Soft navigation | `syncWidth` re-applied (guards against a stuck `0px`) | `workspace-chrome.tsx:261–263` |
| Toggle / resize animation | none: `SIDEBAR_NO_MOTION_CLASS` disables all transitions in the shell and its portaled flyouts | `constants.ts:64–65`, `workspace-chrome.tsx:348` |
| Paste anywhere editable | `PasteAdmissionGuard` capture listener: targets matching `input` (non file/checkbox/radio/button/submit/hidden), `textarea`, `[contenteditable]`, `.monaco-editor`, `.xterm`; reads `data-paste-max-bytes` / `data-paste-max-characters` / `data-paste-max-html-bytes` from the nearest ancestor, default `PASTE_LIMITS.DEFAULT_BYTES` (`@sim/utils/paste`); over the limit → `preventDefault` + `stopImmediatePropagation` + warning toast "Paste is too large for this editor" / "The clipboard content was left unchanged. This editor supports up to {limit}." ; skipped when the target accepts a selection-context payload or handles image files | `paste-admission-guard.tsx:225–324` |
| Click an in-app link while a settings editor is dirty | `SettingsNavigationGuard` intercepts and shows the discard dialog | `global-behaviours.md` |
| Focus order | sidebar (header chips → nav → sections → footer) → resize handle → content | DOM order `sidebar.tsx:1381–1931` |

## Network and realtime

Order on a cold workspace entry. In React most of these are server prefetches dehydrated into the query cache (`prefetch.ts`, `prefetch-access.ts`); the Flutter app issues them from the client with the same keys and staleTimes. Keys are React Query keys (`hooks/queries/**`).

| # | Call | React Query key | staleTime | Consumer |
|---|---|---|---|---|
| 1 | Better Auth `getSession` (client SDK, `/api/auth/get-session`) | `['session','detail']` | 5 min; `retry:false`; `refetchOnWindowFocus:true`; 60 s poll while impersonating (`disableCookieCache`) | `SessionProvider` (`hooks/queries/session.ts:526–603`) |
| 2 | `GET /api/workspaces/[id]/host-context` → `{workspace{id,name,workspaceMode,billedAccountUserId,allowPersonalApiKeys?}, hostOrganizationId, ownerBilling, viewer{permission,isHostOrganizationMember,isHostOrganizationAdmin,organizationRole?}, features?{credentialGroups,organizationSearch?,knowledgeMemberAccess?,knowledgeSourceMirroredAccess?}, deployment?}` | `['workspace-host','detail',id]` | 30 s | `WorkspaceHostProvider` (`workspace-host.ts:489–518`, contract `workspaces.ts:286–330`); 403 → access denied; `deployment` seeds the deployment-shape store |
| 3 | `GET /api/workspaces/[id]/feature-flags` → `{flags{dashboards,'workflow-tests',changelog,'mothership-model-selector','mothership-computer-use','mothership-plan-mode',projects}, desktopExecutor{available,registered}}` (server addition, plan §5) | Flutter key `['workspace','detail',id,'feature-flags']` (no React key: resolved in the server layout `layout.tsx:146–157`) | 30 s (match host-context) | `FeatureFlagsProvider`, Sidebar `desktopExecutor` prop |
| 4 | `GET /api/organizations/[id]/whitelabel` (only when `viewer.isHostOrganizationMember` and `hostOrganizationId`) | `useWhitelabelSettings` | — | `BrandingProvider` (`branding-provider.tsx:41–44`) |
| 5 | `GET /api/workflows?workspaceId=&scope=active` | `['workflows','list',ws,'active']` | 60 s (`WORKFLOW_LIST_STALE_TIME`) | sidebar (`prefetch.ts:82–89`) |
| 6 | `GET /api/mothership/chats` (when `chatEnabled`) | `['mothership-chats', … list(ws,'active')]` | 60 s | sidebar Chats (`prefetch.ts:90–101`) |
| 7 | `GET /api/folders?workspaceId=&scope=active&resourceType=workflow` | `folderKeys.list(ws,'active','workflow')` | 60 s | sidebar tree (`prefetch.ts:102`) |
| 8 | `GET /api/workspaces/[id]/permissions` → `{users[], viewer?{permissionType}}` | `['workspace','detail',id,'permissions']` | 30 s | `WorkspacePermissionsProvider` (`workspace.ts:391–398`); 404 → "Workspace not found or access denied", 401 → "Authentication required" |
| 9 | `GET /api/users/me/profile` → `{user{id,name,email,image}}` | `['userProfile','profile']` | 5 min | footer (`user-profile.ts:186–192`) |
| 10 | `GET /api/workspaces?scope=active` → `{workspaces[], lastActiveWorkspaceId, pinnedWorkspaceIds[], creationPolicy{canCreate,reason}}` | `['workspace','list','user','active']` | 30 s; `placeholderData: keepPreviousData` | switcher (`workspace.ts:40–146`) |
| 11 | `GET /api/permission-groups/user` | `permissionGroupKeys.userConfig(ws)` | 60 s | `usePermissionConfig` (nav gating) (`prefetch-access.ts:180–187`) |
| 12 | `GET /api/settings/allowed-integrations` | `integrationAvailabilityKeys.environments()` | 5 min | `usePermissionConfig` (`prefetch-access.ts:188–196`) |
| 13 | access-request discovery (only when a platform feature is hidden by the policy) | `accessRequestKeys.discovery(q)` | `ACCESS_REQUESTS_STALE_TIME` | `useWorkspaceAccessRequestFeatures` (`prefetch-access.ts:198–218`) |
| 14 | fork availability (admins only) | `forkAvailabilityKeys.detail(ws)` | `FORK_AVAILABILITY_STALE_TIME` | settings sidebar (Phase 5) (`prefetch.ts:129–146`) |
| 15 | `GET /api/users/me/settings` → `{data{theme,…}}` | `['generalSettings','settings']` | 60 min | `SettingsLoader`; `theme` is written to localStorage `sim-theme` (`general-settings.ts:305–313`) |
| 16 | `GET /api/providers/{base,ollama,vllm,openrouter,…}/models` ×9 (`base, ollama, ollama-cloud, vllm, litellm, openrouter, fireworks, together, baseten`; the last four take `workspaceId`) — only on `/workspace/{id}`, `/home`, `/w`, `/w/*`, `/chat`, `/chat/*` or while the search palette is open | `providerKeys…` | 5 min | `ProviderModelsLoader` (`provider-models-loader.tsx:67–157`) |
| 17 | `GET /api/custom-blocks` (workspace scoped) | `customBlockKeys.list(ws)` | 60 s | `CustomBlocksLoader`; disabled blocks stay resolvable but `hideFromToolbar` |
| 18 | `GET /api/blocks/visibility` → `{revealed[], disabled[], previewTagged[]}` | `blockVisibilityKeys.list(ws)` | 60 s | `BlockVisibilityLoader`; on workspace switch reset fail-closed keeping kill-switch entries |
| 19 | `POST /api/workspaces/[id]/visit` (fire-and-forget, serialised, optimistic reorder of the list cache) | mutation key `['workspace','record-visit']` | — | `useWorkspaceManagement` (`workspace.ts:156–186`) |
| 20 | Socket.IO: join workspace room `workspace-workflows` (`workspaceId`) → on `workspace-workflows-changed` invalidate workflow lists (active+archived) and folder lists | — | — | `use-workspace-workflows-room.ts:22–29` |
| 21 | `GET /api/mothership/events?…` named SSE (rotating `EventSource`) when `chatEnabled && !hideCopilot` | — | — | `use-mothership-chat-events.ts:284–288` (Phase 4 detail; the sidebar only needs the `task_status` → chat list invalidation) |
| 22 | `GET https://status.sim.ai/api/v2/status.json` (hosted only) | `['status-page','summary','sim']` | 30 s, poll 60 s, `refetchOnWindowFocus`, `retry:false` | `StatusNotice` |

React Query client defaults (`get-query-client.ts:497–527`): `staleTime` 30 s, `refetchOnWindowFocus` only in the desktop app, `retry` 1 in the browser (0 on the server), `retryOnMount: false`, mutations `retry: false`. The `Query<T>` layer in `sim_api` must mirror these.

Socket consumption in the chrome: `isReconnecting`, `isRetryingWorkflowJoin`, `blockedJoinWorkflowId` from `useSocket()` (`app/workspace/providers/socket-provider.tsx:115–123`) drive the toasts above. Operation-queue `hasOperationError` drives offline mode.

Public env: React reads `window.__ENV` (inline script, `public-env-script.tsx:182–189`) and the `<html>` attribute `PUBLIC_ENV_ATTRIBUTE`; Flutter reads `GET /api/public-env` (plan §3) before login and seeds the deployment-shape fallback from it.

## Parity checklist

| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | `workspace-viewport.tsx:291` | `shell.viewport` fills the window (h-dvh), column, bg `--surface-1` | | |
| 2 | layout | `workspace-chrome.tsx:317–320` | `shell.chrome` is a horizontal row at ≥768px, `min-h-0 flex-1` | | |
| 3 | layout | `stores/constants.ts:21–24` | `shell.sidebar` width 224px on first run (no stored width) | | |
| 4 | layout | `store.ts:15–20` | max width 400 at 1440, 384 at 1280; dragging beyond stops there | | |
| 5 | layout | `store.ts:23–30` | widths below 224 clamp to 224 | | |
| 6 | layout | `stores/constants.ts:27`, `globals.css:590` | collapsed rail exactly 48px | | |
| 7 | layout | `sidebar.tsx:1919` | handle 8px wide, centred on the rail's right edge (4px overlap into content), full height | | |
| 8 | layout | `workspace-chrome.tsx:62,404–405` | content pane has a 1px `--border` left border and `--bg` fill; no other divider | | |
| 9 | layout | `workspace-chrome.tsx:350,406` | `/upgrade`: sidebar width 0 and no pane border | | |
| 10 | layout | `application-loading.tsx:17–33` | loading surface centred wordmark on `--bg`, fills the viewport | | |
| 11 | layout | `workspace-chrome.tsx:336–342`, `globals.css:532` | no visible drag region / title-bar lane on web and Windows | | |
| 12 | token | `sidebar.tsx:1383` | anchor C1 = `--surface-1` | | |
| 13 | token | `workspace-chrome.tsx:405` | anchor C2 = `--border` | | |
| 14 | token | `workspace-chrome.tsx:404` | anchor C3 = `--bg` | | |
| 15 | token | `globals.css:619–626` | collapsed: all labels at opacity 0 but rows keep height | | |
| 16 | token | `sidebar.tsx:1920` | cursor `ew-resize` expanded, `e-resize` collapsed over the handle | | |
| 17 | state | `store.ts:73–76,66–69` | cookie `sidebar_collapsed=1` → first paint collapsed; toggling writes `=1`/`=0` with `path=/; max-age=31536000; samesite=lax` | | |
| 18 | state | `store.ts:113–129` | width persisted to localStorage `sidebar-state` as `{"state":{"sidebarWidth":n},"version":0}`; nothing else persisted there | | |
| 19 | state | `app/layout.tsx:146–151` | legacy `isCollapsed` in `sidebar-state` migrates into the cookie once when the cookie is absent | | |
| 20 | state | `store.ts:87–92` | resizing is ignored while collapsed | | |
| 21 | state | `use-sidebar-width.ts:178–192` | shrinking the window below `width/0.3` re-clamps the rail | | |
| 22 | state | `workspace-permissions-provider.tsx:29–30,139–142` | socket disconnect < 2 s shows no toast; ≥ 2 s shows "Reconnecting..." which stays ≥ 1.5 s | | |
| 23 | state | `workspace-permissions-provider.tsx:155–162` | offline / join-blocked toasts with their descriptions and a "Refresh" action; edit rights off | | |
| 24 | state | `workspace-host-provider.tsx:293–295` | host-context 403 replaces the shell with the access-denied page without navigating | | |
| 25 | state | `layout.tsx:80–83` | unknown workspace id → access-denied page (no sidebar) | | |
| 26 | interaction | `use-sidebar-resize.ts:288–297` | drag updates width every frame without React rebuilds; release persists once | | |
| 27 | interaction | `use-sidebar-resize.ts:299–327` | pointercancel / window blur ends the drag and restores cursor + selection | | |
| 28 | interaction | `sidebar.tsx:1923,1265–1273` | click / Enter / Space on the collapsed handle expands | | |
| 29 | interaction | `constants.ts:64–65` | collapse/expand snaps in one frame (no animation) | | |
| 30 | interaction | `workspace-chrome.tsx:240` | hover-peek never activates on web/Windows | | |
| 31 | interaction | `paste-admission-guard.tsx:311–319` | oversized paste is blocked with the warning toast and the field is unchanged | | |
| 32 | keyboard | `commands.ts:96–100` | `Mod+B` toggles (not while an input/textarea/contenteditable is focused) | | |
| 33 | network | `prefetch.ts:81–120` | on entry the sidebar data (workflows, chats, folders, permissions, profile, workspaces) is requested together, not as a waterfall | | |
| 34 | network | `workspace-host.ts:489–518` | host-context key `['workspace-host','detail',id]`, staleTime 30 s | | |
| 35 | network | `workspace.ts:391–398` | permissions key `['workspace','detail',id,'permissions']`, staleTime 30 s | | |
| 36 | network | `provider-models-loader.tsx:67–84` | provider model lists are requested only on the listed routes or with the palette open | | |
| 37 | network | `get-query-client.ts:497–527` | query defaults: staleTime 30 s, retry 1, retryOnMount false, no focus refetch on web; mutations never retry | | |
| 38 | network | `use-workspace-workflows-room.ts:22–29` | `workspace-workflows-changed` invalidates workflow + folder lists for that workspace only | | |
| 39 | state | `branded-layout.tsx:273–302` | brand name ≠ "Sim" sets the document title; `faviconUrl` swaps the icon; `customCssUrl` is loaded once | | |
| 40 | state | `workspace-chrome.tsx:250–252` | entering `/upgrade` records the previous pathname as the fullscreen origin | | |
