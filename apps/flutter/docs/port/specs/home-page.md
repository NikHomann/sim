# Home page (new chat hero, conversation surface, resource panel)
Upstream: `app/workspace/[workspaceId]/home/**` (excluding `components/user-input/**`, covered by `chat-input.md`, and `components/message-content/**` + `hooks/use-chat.ts` stream/state machine, covered by the chat-engine and message-rendering specs), `app/workspace/[workspaceId]/chat/[chatId]/**`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1.5

Paths are relative to `apps/sim/` unless stated; `home/` means `app/workspace/[workspaceId]/home/`. Line numbers are at the commit above. The page renders inside the content pane described in `workspace-chrome.md` (`shell.content.pane`, `--bg`, 1px `--border` left edge); the sidebar "New chat" entry, the Chats section and its list query are in `workspace-sidebar.md`. The composer (`UserInput`) is specified in `chat-input.md` and referenced here only by its outer box (`chat-input.root`).

## Files

| File | Lines | Role |
|---|---|---|
| `home/page.tsx` | 37 | Route `/workspace/[id]/home`: `metadata.title='New chat'`, chat-disabled redirect, prefetch, `<Suspense fallback={HomeFallback}><Home/>` |
| `home/layout.tsx` | 23 | Chat disabled → `redirect('/workspace/{id}')`; else `flex h-full flex-1 flex-col overflow-hidden` |
| `home/error.tsx` | 15 | Error boundary "Failed to load home" |
| `home/home-fallback.tsx` | 10 | `<div class='h-full bg-[var(--bg)]'/>` |
| `home/prefetch.ts` | 27 | Seeds workspace file list after a host-context check |
| `home/home.tsx` | 507 | `Home` (restored-entry guard, `PermissionAccessBoundary configKey='hideCopilot'`) → `HomeContent`: hero vs conversation, credits chip, context→resource wiring, handoffs |
| `home/search-params.ts` | 87 | `?resource=` URL param (nuqs, `history:'replace'`, `clearOnDefault`) |
| `home/hooks/chat-url.ts` | 12 | `/workspace/{id}/chat/{chatId}[?resource=]` builder |
| `home/hooks/use-restored-chat-entry.ts` | 39 | Back/Forward onto an in-place-renamed entry → `router.replace` |
| `home/hooks/use-resource-panel.ts` | 338 | Panel controller: collapsed state, URL selection, activity set, auto-open |
| `home/hooks/use-mothership-resize.ts` | 357 | Divider drag/keyboard resize, clamps, persistence |
| `home/resource-view-policy.ts` | 108 | When a resource event reveals/activates/marks the panel |
| `home/components/chat-resource-panel.tsx` | 115 | Binds chat + panel → `ChatPanelLayout` + lazy `MothershipView` |
| `home/components/chat-panel-layout.tsx` | 139 | Row, divider, collapse toggle; `ChatPanelContent` (panel box) |
| `home/components/mothership-view/mothership-view.tsx` | 387 | Panel: tab strip + active resource content |
| `home/components/mothership-view/components/resource-tabs/resource-tabs.tsx` | 637 | emcn `TabStrip` (floating) + selection/close/reorder/drag-out |
| `home/components/mothership-view/components/resource-tabs/resource-tab-controls.ts` | 43 | Header geometry CSS vars |
| `home/components/mothership-view/components/resource-registry/resource-registry.tsx` | 335 | Per-type label/icon/dropdown row; `RESOURCE_MENU_ORDER`; `MENTION_PREVIEW_DEFAULT_LIMIT=5` |
| `home/components/mothership-view/components/add-resource-dropdown/add-resource-dropdown.tsx` | 645 | `+` picker (also reused by the composer's `+` menu) |
| `home/components/mothership-view/components/add-resource-dropdown/available-resources.ts` | 361 | Inventory hook (`useAvailableResources`) |
| `home/components/mothership-view/components/resource-content/resource-content.tsx` | 1156 | Per-type content + header actions |
| `home/components/mothership-view/components/resource-content/components/{generic-resource-content,sources-resource-content,search-resource-content}.tsx` | 8 / 61 / 29 | Small content types |
| `home/components/mothership-view/components/resource-content/components/{browser-session,terminal-session}/**` | ~3.6k | Desktop-only (never on web) |
| `home/components/credits-chip/credits-chip.tsx` | 80 | Credits chip |
| `home/components/suggested-actions/{suggested-actions.tsx,types.ts,weighted-sample.ts}` | 376 / 20 / 27 | Suggested actions |
| `components/home/home-section.tsx` | 50 | Collapsible "Suggested actions" section shell |
| `home/components/queued-messages/queued-messages.tsx` | 218 | Queue tray above the conversation composer |
| `home/components/mothership-chat/mothership-chat.tsx` | 998 | Conversation surface (layout styles, footer, skeleton) — message rows belong to the message-rendering spec |
| `home/components/mothership-chat/components/mothership-chat-skeleton/mothership-chat-skeleton.tsx` | 51 | History-loading skeleton |
| `stores/chat-panel/store.ts` | 116 | Persisted panel widths (`chat-panel-widths`) |
| `stores/constants.ts:67–82` | — | `MOTHERSHIP_WIDTH {MIN:280, MAX_PERCENTAGE:0.8, CHAT_MIN:480}` |
| `ee/access-requests/components/permission-access-boundary.tsx` | 128 | `hideCopilot` policy gate |
| `app/workspace/[workspaceId]/components/error/error.tsx` | ~100 | `ErrorShell`/`ErrorState` |
| `app/workspace/[workspaceId]/chat/[chatId]/{page,layout,error}.tsx` | 41 / 8 / 15 | Chat route |

emcn used: `pageHeadingClassName`, `Chip`, `ChipTag`, `Tooltip`, `Button` (ghost), `TabStrip`/`TabStripAction`, `DropdownMenu*` (`SearchInput`, `Sub*`, `Label`, `ItemLabel`), `Expandable`/`ExpandableContent`, `OverflowText`, `Skeleton`, `toast`, `chipHoverSurfaceClass`/`chipActiveSurfaceClass`, `IdentityTile`. Icons: `PanelLeft`, `ArrowLeft`, `ArrowRight`, `ChevronDown`, `ChevronRight`, `Credit`, `Plus`, `Pencil`, `Trash`, `X`, `ArrowUp`, `Paperclip`, `Table`, `TriangleAlert`, registry icons (`Workflow, Table, Dashboard, ShieldCheck, File/doc icons, Database, Folder, Task, Library, Connections, Search, TerminalWindow, Globe`); brand `SlackIcon`, `GmailIcon`, `BrandIcon`.

## Layout

Viewport for every number below: 1440×900, dpr 1, sidebar expanded at 224px, so the content pane is x 224..1440 with its 1px left border; content box x 225..1440 (1215px) × 900. Estimates marked "≈" are derived from classes and must be confirmed by the first capture.

### Route frame
- `home/layout.tsx:22` / `chat/[chatId]/layout.tsx:7`: `flex h-full flex-1 flex-col overflow-hidden` (`home.page`).
- Suspense fallback `home-fallback.tsx:9`: `h-full bg-[var(--bg)]` (blank, no skeleton).

### Row (`home.row`, `chat-panel-layout.tsx:45–50`)
`relative flex h-full min-h-0 min-w-0 bg-[var(--bg)]` + `RESOURCE_HEADER_CLASSES.layout` which sets CSS vars (`resource-tab-controls.ts:6`): `--resource-header-controls-height: 40px`, `--resource-header-end-inset: 16px`, `--resource-header-fixed-reserve: 52px`, `--resource-header-toggle-hit-size: 40px`, `--resource-header-toggle-size: 30px` (below 768px: 44 / 8 / 44 — mobile out of scope).
Children in order:
1. Chat column wrapper `contents` (no box) → chat column `home.chat-column` (`home.tsx:415`): `relative flex h-full min-w-0 flex-1 flex-col md:min-w-[min(480px,50%)]`.
2. Divider host (only when panel expanded, `chat-panel-layout.tsx:52–65`): `relative z-20 w-0 flex-none`; handle `home.panel.resize-handle`: `absolute inset-y-0 left-[-4px] w-[8px] cursor-ew-resize touch-none`, focus-visible `outline 2px var(--selection)`; transparent, no hover paint.
3. Panel `home.panel` (`ChatPanelContent`, `chat-panel-layout.tsx:122–137`): `relative z-10 flex h-full flex-col overflow-hidden border-[var(--border)] bg-[var(--bg)]`, transition `width,min-width,border-width 200ms cubic-bezier(0.25,0.1,0.25,1)` (none under reduced motion or when `skipResourceTransition`); collapsed `w-0 min-w-0 border-l-0` + `inert`; expanded `w-1/2 border-l` unless a stored/dragged inline `style.width` px overrides. `data-mothership-panel`.
4. Collapse toggle overlay `home.panel.toggle` (`chat-panel-layout.tsx:67–101`): `absolute top-0 z-30 flex h-[40px] items-center right-[16px]`; `Button variant=ghost` `relative size-[30px] rounded-[8px]`, hover `--surface-active`, invisible 40×40 hit area (`::after`); glyph `PanelLeft` mirrored (`-scale-x-100`) 16px `--text-icon`; when collapsed and `activityCount>0` a 6px dot `--brand-blue` at `-top-0.5 -right-0.5` of the glyph (`home.panel.toggle.dot`). At 1440: button box x 1394..1424, y 5..35.

Default panel width is **50% of the row (≈607px at 1440)**, not 50vw (`w-1/2`, `chat-panel-layout.tsx:131`). Chat column then ≈607px (min `min(480px, 50%)`).

### Panel width rules (`use-mothership-resize.ts`)
- `maxPanelWidth(vw, container) = max(min(280, container/2), min(vw·0.8, container − min(480, container/2)))` (18–26). At 1440 (container 1215): 735. At 1280 (container 1055): 575.
- `panelWidthAt(clientX, g) = max(min(280, max), min(panelRight − (clientX − grabOffset), max))` (50–56); geometry (panelRight, grabOffset, max) snapshotted at pointerdown (221–229).
- Keyboard on focused divider (`readSeparatorKey`: no modifiers, not composing): ArrowLeft +32px (wider), ArrowRight −32px, Home → min, End → max (72–91, 328–342); writes instantly (no transition) and persists.
- Stored preference: `max(280, width)` per `${userId}:${scopeId}` where scopeId = chatId, or `pending:<shortId>` for an unsaved chat (migrated to the chat id when it is created; `stores/chat-panel/store.ts:77–92`, `lib/desktop/chat-scope.ts:29–40`). localStorage key `chat-panel-widths`, zustand-persist shape `{"state":{"widths":{…}},"version":0}`, ≤200 entries, values < 280 dropped (9–34, 98–107). No persistence without a `userId`.
- Restore: on mount/scope change and on every container/window resize (rAF-coalesced) the inline width is `min(preferred, maxPanelWidth)` without a transition; no preference → inline width removed (CSS `w-1/2`) (105–113, 179–204). Collapsing removes the inline width.
- Drag: pointer capture on the handle, body `cursor: ew-resize` + `user-select: none`, panel transition off, one width write per animation frame, commit (persist) on `pointerup`/`lostpointercapture`/window `blur`, cancel (no persist) on `pointercancel`; single-flight (206–325). `aria-valuemin/max/now` mirrored on focus and after each change.

### Resource header / tab strip (`home.panel.tabs`, `resource-tabs.tsx:599–634`, emcn `tab-strip.tsx:890–1023`)
- Strip vars (`RESOURCE_HEADER_CLASSES.stripGeometry`): height `40 + 1 = 41px` (incl. 1px bottom border `--border`), tab band 26px, inline start 16px, inline end 52px (reserve under the overlaid toggle).
- Strip: `flex shrink-0 select-none gap-1 items-center`, border-b `--border`.
- Tabs (`variant='floating'`): item `min-w-28 (112px) max-w-[200px] shrink`; button `h-[26px] w-full px-2 gap-1.5 text-caption (12px) rounded-lg`, rest `--text-secondary`, hover `--surface-hover`/`--text-primary`, active `--surface-active`/`--text-primary`, multi-selected `--surface-4`; icon 16px (`renderTabIcon`, `--text-icon`); title `OverflowText` (tooltip when clipped); close `RowActions` (`X`) shown on hover/focus and always on the active tab, `pr-8` reserved; attention dot 6px `--brand-blue`; 1px×16px `--border` divider between two bare tabs at `-left-1`; drop indicator 2px×16px `--text-subtle`. Enter/exit motion opacity 0→1, scale .98→1 (none with reduced motion). Tabs row scrolls horizontally with edge fades once all tabs hit min width.
- Add control `home.panel.tabs.add` (`add-resource-dropdown.tsx:590–602`): `TabStripAction variant=subtle` 26×26, `Plus` 16px `--text-icon`, tooltip (bottom) "Add resource", `aria-label='Add resource tab'`; when there are no tabs it shifts `-translate-x-1.5` (−6px). Shown when `allowBuildControls` (true on workspace Home) — also before the chat exists.
- End actions (`ml-auto flex h-[26px] gap-1`): the active resource's `ResourceActions` (per type) and, for previewable files/tests, the "Cycle preview mode" action (tooltip shows the mode label).
- Below: content area `relative min-h-0 flex-1 overflow-hidden`.
- Empty panel (no active resource, `mothership-view.tsx:328–334`): centred `text-sm --text-muted` "Click "+" above to add a resource" (`home.panel.empty`).

### Add-resource menu (`home.panel.add-menu`, `add-resource-dropdown.tsx:604–643`)
`DropdownMenuContent align=start sideOffset=8 w-[320px] flex-col overflow-hidden`, `modal={false}`, close does not restore focus. Surface per emcn `MENU_STYLES` (`rounded-xl border --border bg --bg shadow-medium p-1`, rows 28px `text-small`). Top: `DropdownMenuSearchInput` "Search resources" (28px field). Unfiltered: one submenu per family in `RESOURCE_MENU_ORDER` (integration, task, dashboard, test, table, file, filefolder, knowledgebase, workflow, log, folder, browser, terminal, generic), excluding `sources, folder, task, integration` (`resource-tabs.tsx:69–74`) and flag-gated `dashboard` (`dashboards`) / `test` (`workflow-tests`); empty families hidden; Tables/Files/KBs/Workflows render as folder trees; trailing disabled row "Loading resources" while any list is pending. Filtered (non-empty query): flat list across families matching name (or workspace name), `ArrowUp/Down` moves the cursor (hover surface), `Enter` or `Tab` selects, empty → "No results" / "Loading resources" (`text-caption --text-tertiary`). Row renderers per registry (`resource-registry.tsx:47–140`): icon 14px `--text-icon` + `OverflowText`; logs add a 5px status square and `text-caption --text-tertiary` time.

### Empty state (hero) (`home.empty`, `home.tsx:416–469`)
Shown when `messages.length===0 && !(chatId && isChatHistoryPending)`.
- Credits chip host (`home.credits`, 416–434): `absolute top-0 z-10 flex h-[40px] items-center`, `right` = 16px + 40px + 1px = 57px while the panel is collapsed (beside the toggle), `right: 16px` while expanded (the toggle then lives in the panel corner); `right` transitions 200ms `cubic-bezier(0.25,0.1,0.25,1)` (none when the panel auto-opened).
- Scroller `home.empty.scroll` (436): `h-full overflow-y-auto [scrollbar-gutter:stable_both-edges]`.
- Cluster (438): `flex min-h-full flex-col items-center justify-center px-6 pt-[2vh] pb-[22vh]` (md; at 900 tall: pt 18, pb 198).
- Heading `home.hero.heading` (439–441): `pageHeadingClassName` = Season, 28px at ≥640 (26px below), leading 1.15 (≈32.2px), tracking −0.01em, `--text-primary`, `text-balance`; `mb-7` (28px); `max-w-chat` (704px). Text: `What should we get done, {firstName}?` where `firstName = session.user.name.split(' ')[0]`; with no name: `What should we get done?`.
- Composer host (442): `relative w-full max-w-chat` (704px) → `chat-input.root` (hero variant: `shadow-ambient`, editor min-h 56).
- Suggested actions host (460): `relative md:absolute md:inset-x-0 md:top-full` (out of flow so expanding never moves the input).
- Geometry at 1440×900 (≈, no messages, single-line composer 104px tall): cluster ≈164px tall centred in y 18..702 → heading top ≈278, composer y ≈338..442, x ≈480.5..1184.5 (column centre x 832.5), suggested section top ≈470.

### Suggested actions (`home.suggested`, `home-section.tsx:27–47`, `suggested-actions.tsx:330–358`)
- Section: `group/suggested mx-auto mt-7 (28px) w-full max-w-chat`.
- Toggle `home.suggested.toggle`: `flex w-full items-center gap-2` button, `aria-expanded`; title "Suggested actions" `text-caption` (12px) `--text-muted`; `ChevronDown` 14px `--text-icon`, opacity 0 → 1 on section hover or toggle focus-visible, rotated −90° when collapsed, 150ms.
- Body: `Expandable` (Radix Collapsible, `collapsible-down/up` 300ms `cubic-bezier(.4,0,.2,1)`; animation disabled until the first toggle) → `flex flex-col pt-1.5` (6px).
- Row `home.suggested.row`: `<button>` `flex items-center gap-2 px-2 py-2 text-left transition-colors`, `min-h-11` only below md, hover `--surface-5`; rows after the first have `border-t --border`; `BrandIcon` 16px; label `OverflowText flex-1 text-sm --text-body`; `ArrowRight` 16px `--text-icon`. Row ≈36px (+1px border). Exactly 4 rows.

### Conversation (`home.chat`, `mothership-chat.tsx` with `layout='mothership-view'`, 150–162, 858–996)
- Root: `relative flex h-full min-h-0 min-w-0 flex-col`, Inter font (`inter.className`).
- Scroll container `home.chat.scroll`: `min-h-0 flex-1 overflow-y-auto overflow-x-hidden px-6 pt-4 pb-2 [scrollbar-gutter:stable_both-edges]` + 12px scroll fades; sizer `relative mx-auto w-full max-w-chat` (virtualised rows; row contents in the message-rendering spec).
- Footer `home.chat.footer`: `shrink-0 px-[24px] pb-[16px]` (md) → inner `mx-auto max-w-chat` holding `ComputerUseActivity` (desktop only), `QueuedMessages`, then the composer (non-hero variant). After the first send from the hero, the footer plays `animate-slide-in-bottom` (400ms `cubic-bezier(.16,1,.3,1)`, translateY 20px→0, opacity 0→1) once (`home.tsx:223–225, 499–500`).
- Skeleton `home.chat.skeleton` (`mothership-chat-skeleton.tsx`): `mx-auto max-w-chat space-y-6`: right-aligned 40px×55% radius 16 bar; four 14px bars (90/75/82/40%, radius 4, `space-y-3`); right-aligned 32px×40% radius 16; three 14px bars (85/70/60%). The composer is not rendered while `isLoading` (979).

### Queued messages (`home.queue`, `queued-messages.tsx`)
Rendered only with ≥1 queued message, directly above the composer.
- Tray: `-mb-3 mx-3.5 overflow-hidden rounded-t-[16px] border border-b-0 border-[var(--border-1)] bg-[var(--surface-3)] pb-3` — inset 14px each side, tucked 12px under the composer's top edge.
- Header `home.queue.header`: button `flex w-full items-center gap-1.5 px-3.5 py-2`, hover `--surface-hover`; `ChevronDown`/`ChevronRight` 14px `--text-icon`; label `{n} Queued` `text-small` `--text-secondary`. Expanded by default.
- Row `home.queue.row`: `flex items-center gap-2 py-1.5 pr-2 pl-3.5`, hover `--surface-hover`, editing row `--surface-active`; status ring 16px slot with a 10px circle, 1.5px border `color-mix(--text-tertiary 40%, transparent)`, editing → dashed `color-mix(--text-secondary 60%)`; content `UserMessageContent compact` (truncating, chips); attachments pill `max-w-[40%] rounded-[5px] bg --surface-5 px-[5px] py-0.5 text-small --text-primary` with `Paperclip` 12px, first filename + `+N` (`--text-secondary`), or only the count when the tray is narrower than 320px (ResizeObserver).
- Actions (`flex gap-0.5`): buttons `rounded-md p-[5px]` (23×23) icon 13px `--text-icon`, hover `--surface-active`/`--text-primary`, tooltip top offset 4: Edit (`Pencil`, `aria-disabled` + opacity .4 + tooltip "Sending now" / "May already be sent; editing could send a second message" when the row is dispatching or `admissionUnknown`, else "Edit queued message"), Send now (`ArrowUp`, `disabled` while dispatching), Remove from queue (`Trash`). While editing: a single "Cancel edit" (`X`).

### Error, access and fallback surfaces
- `ErrorShell` (`components/error/error.tsx`): `flex h-full flex-1 items-center justify-center bg-[var(--bg)] px-6 py-12` → `max-w-[420px] flex-col items-center gap-5 text-center`; mark 52×52 `rounded-2xl border --border-muted bg --surface-4 (dark --surface-5) p-[3px] shadow-xs` → inner `rounded-[11px] border --border-1 bg --bg` with `TriangleAlert` 22px `--text-icon`; title `pageHeadingClassName`; text 14px `--text-tertiary` leading 1.55 `max-w-[340px]`; `Chip variant=primary` "Try again" (→ `reset`). Titles: "Failed to load home" / "Something went wrong while loading your workspace home. Please try again." and "Failed to load chat" / "Something went wrong while loading this chat. Please try again." (`home.error`).
- `PermissionAccessBoundary` states use `EmptyState` (`flex min-h-0 flex-1 flex-col items-center justify-center px-6 py-8 text-center`, title `font-medium text-small --text-primary`, body `mt-1 max-w-[240px] text-small --text-muted leading-5`, action row `mt-4 gap-2`) (`home.access`).

### Parity ids
`home.page` · `home.row` · `home.chat-column` · `home.empty` · `home.empty.scroll` · `home.hero.heading` · `home.credits` · `home.suggested` · `home.suggested.toggle` · `home.suggested.row` (first) · `home.panel` · `home.panel.toggle` · `home.panel.toggle.dot` · `home.panel.resize-handle` · `home.panel.tabs` · `home.panel.tabs.tab` (first) · `home.panel.tabs.add` · `home.panel.add-menu` · `home.panel.empty` · `home.panel.content` · `home.chat` · `home.chat.scroll` · `home.chat.footer` · `home.chat.skeleton` · `home.queue` · `home.queue.header` · `home.queue.row` (first) · `home.queue.row.edit` · `home.queue.row.send` · `home.queue.row.remove` · `home.error` · `home.access`. The composer box inside the hero is `chat-input.root` (see `chat-input.md`).

### Colour anchors (1440×900, dpr 1, seeded workspace, billing off, panel collapsed, no messages)
| # | Point | Expected light | Expected dark | Source |
|---|---|---|---|---|
| H1 | (300, 120) empty hero background left of the cluster | `--bg` #fefefe | #1b1b1b | `chat-panel-layout.tsx:47` |
| H2 | (1100, 365) inside the composer, right of the placeholder | `--white` #ffffff | `--surface-4` #292929 | `user-input.tsx:582` |
| H3 | (1409, 20) collapse toggle while hovered | `--surface-active` #ececec | #2c2c2c | `chat-panel-layout.tsx:79` |
| H4 | (1150, 470+18+6+18) first suggested row while hovered, right of the label | `--surface-5` #f3f3f3 | #363636 | `suggested-actions.tsx:344` |
| H5 | panel expanded, (1100, 500) empty panel body | `--bg` #fefefe | #1b1b1b | `chat-panel-layout.tsx:130` |
| H6 | panel expanded, 1px column at the panel's left edge (x = row right − panel width), y 450 | `--border` #d8d8d8 | #444444 | `chat-panel-layout.tsx:131` |
| H7 | queue tray, 4px inside its left edge below the header | `--surface-3` #f7f7f7 | #242424 | `queued-messages.tsx:52` |

## Tokens
| Element | Tokens |
|---|---|
| Page/row/panel background | `--bg` |
| Panel divider and tab-strip rule | `--border` (1px) |
| Collapse toggle | glyph `--text-icon`; hover `--surface-active`; activity dot `--brand-blue` |
| Divider focus ring | `--selection` 2px outline |
| Hero heading | Season 28/26px, `--text-primary`, lh 1.15, tracking −0.01em |
| Suggested title / chevron | `text-caption --text-muted` / `--text-icon` |
| Suggested row | label `text-sm --text-body`, arrow `--text-icon`, hover `--surface-5`, separators `--border` |
| Credits chip | `Chip`: 30px, icon `Credit` 16 `--text-icon`, label `text-sm --text-body`, hover `--surface-hover`; non-manager `ChipTag` mono: 20px, `rounded-md px-1 gap-[3px] text-sm`, `--surface-5` (dark `--surface-4`), `--text-primary` |
| Tabs | rest `--text-secondary`, hover `--surface-hover`, active `--surface-active` + `--text-primary`, selected `--surface-4`, attention `--brand-blue`, divider `--border`, drop line `--text-subtle` |
| Empty panel text | `text-sm --text-muted` |
| Generic content | `text-small --text-muted` "No results yet" |
| Queue | tray `--surface-3` + `--border-1`(= `--border`); header `text-small --text-secondary`; row hover `--surface-hover`, editing `--surface-active`; ring `--text-tertiary`@40%; action icons `--text-icon`, hover `--surface-active`/`--text-primary` |
| Skeleton | emcn `Skeleton` (shimmer off in `SIM_E2E`) |
| Error | mark `--surface-4`/`--surface-5` dark, `--border-muted`, inner `--bg` + `--border-1`; text `--text-tertiary` |

## States
| State | Behaviour | Source |
|---|---|---|
| Chat disabled (`NEXT_PUBLIC_CHAT_DISABLED` truthy) | `/home` server-redirects to `/workspace/{id}` (layout and page both); `/chat/{id}` → 404 (`notFound`) | `home/layout.tsx:17–20`, `home/page.tsx:21–23`, `chat/[chatId]/layout.tsx:5`, `page.tsx:26–28` |
| Suspense pending | blank `--bg` | `home-fallback.tsx:9` |
| Restored new-chat history entry (Back/Forward to a URL the new chat rewrote in place) | render fallback and `router.replace(currentUrl)` so the chat route mounts | `use-restored-chat-entry.ts:24–38`, `home.tsx:64–65` |
| Policy loading | EmptyState "Checking access" / "Loading your organization access policy." | `permission-access-boundary.tsx:52–56` |
| Policy error | "Unable to check access" / error message + Chip "Try again" (refetch) | 57–65 |
| `hideCopilot` false | Home content | 66–76 |
| `hideCopilot` true, access requests disabled | children rendered anyway (server is the enforcement point) | 90 |
| `hideCopilot` true, entry allowed since | "Access updated" / "Refreshing your permissions..." or "Refresh to load your latest permissions." + "Refresh access" | 92–104 |
| `hideCopilot` true, requestable | "Access required" + "Ask an administrator for access." / "Your request is pending." + `RequestAccessAction` (primary); otherwise the entry reason or "Your organization restricts this feature." | 105–127 |
| New chat (`/home`, no messages) | hero; credits chip; suggested actions; composer with mode selector | `home.tsx:411–469` |
| Existing chat, history pending, no messages | skeleton, composer hidden, no hero | 404, `mothership-chat.tsx:901–903, 979` |
| Existing chat loaded | conversation | 471–502 |
| History request failed | no error UI on Home (`chat.error` is not rendered); with zero messages the hero shows (verify with a 404 chat id) | `use-chat.ts:5440`, `home.tsx` |
| Billing disabled / enterprise owner / availability loading or absent | no credits chip | `credits-chip.tsx:19, 45` |
| Credits, viewer can manage billing | `Chip` (clickable) | 69–79 |
| Credits, viewer cannot | `ChipTag` + tooltip "Contact an organization admin to manage this workspace’s billing." (host org) / "Only the workspace owner can manage billing." | 52–67 |
| Credits value | `remainingDollars===null` → "Available"; ≥ 999999 → "∞"; else `round(dollars × 200).toLocaleString()` | 47–50; `lib/billing/credits/conversion.ts:9–13,133–136` |
| Suggested: no OAuth connections (or services not loaded) | fixed list: "Integrate with Slack", "Integrate with Gmail", "Create a CRM with sample data", first featured GitHub template ("Link GitHub pull requests to Jira tickets") | `suggested-actions.tsx:214–233, 290–294` |
| Suggested: ≥1 connected provider | 1 "Integrate with X" for an unconnected service (weighted by template count+1) + 3 prompts (weighted, ≤1 per block) — random each mount | 179–206 |
| Suggested collapsed | body hidden, chevron −90° | `home-section.tsx:39,43` |
| Panel collapsed (default) | width 0, `inert`; toggle in the row corner | `use-resource-panel.ts:85` |
| Panel auto-open | resources became non-empty while collapsed and the user has not collapsed it themselves (desktop only) → expands without transition | 290–303 |
| Panel auto-close | resources became empty while expanded | 305–309 |
| Chat switch / new chat | collapse ownership, selection ownership and activity reset; panel collapses when there is no resolved chat | 277–288 |
| Resource events while panel collapsed | `resolveResourceEventPresentation` decides reveal / activate / mark activity (dot on toggle + tab attention) | 96–128 |
| Active resource missing from list | `?resource=` unknown → effective selection falls back to the last resource | `search-params.ts:4–13` |
| Queue item dispatching / admission unknown | edit disabled with explanatory tooltip; send-now disabled while dispatching | `queued-messages.tsx:75–82,175` |

### Resource types in Phase 1.5
| Type | Upstream content | Phase 1.5 |
|---|---|---|
| (none active) | "Click "+" above to add a resource" | real |
| `generic` | "No results yet" | real |
| `sources` | `SourcesResourceContent`: "Sources · N" heading + `SourceCard`s from the cached chat history; "Loading sources" / "Unable to load sources. Try reopening this conversation." / "No cited sources are available for this response." | real (needs message-sources from the message-rendering spec) |
| `folder` | `EmbeddedFolder`: skeleton while folders load, "Folder not found" state, folder name (16px) + workflow rows opening `/workspace/{id}/w/{wf}` | real (Phase 1 data) |
| `workflow` | embedded editor canvas | placeholder (Phase 2) |
| `table`, `file` (+ synthetic `streaming-file` preview), `knowledgebase`, `log`, `dashboard`, `test` | full surfaces | placeholder (Phase 4) |
| `filefolder`, `task`, `integration` | no case → renders nothing | blank (match upstream) |
| `search` | organization chat only | not reachable |
| `browser`, `terminal` | desktop-only (`desktopOnly`, never persisted) | never on web; Windows → Phase 6 |
Tab header actions (`ResourceActions`) for placeholder types are omitted in Phase 1.5 (record in known-gaps).

## Interactions
- Submit from the hero composer: `handleSubmit` trims; ignores empty text without attachments; text empty with files → sends "Analyze the attached file(s)."; marks the footer for the slide-in animation; resets resource-view ownership; `sendMessage(text, files, contexts)` with `requestMode` (`agent`/`plan`) only for a new chat (`home.tsx:153, 211–231`). The chat engine moves the URL to `/workspace/{id}/chat/{chatId}` with `history.replaceState` (no remount), carrying `?resource=` (`chat-url.ts`, `use-chat.ts:1356–1365`).
- Suggested prompt row → `populatePrompt(prompt)` on the hero composer (mentionifies bare integration names, focuses, caret at end; does not send) (`home.tsx:461–465`, `user-input.tsx:377–385`). Integration row → resolves the OAuth service for the slug and opens `ConnectOAuthModal` (mode connect, origin integrations) — modal is Phase 4 (integrations); in Phase 1.5 record as gap or reuse the Phase 1 connect modal if present.
- Toggle "Suggested actions" → expand/collapse with animation from the second toggle on.
- Credits chip (manager): hover/focus prefetches; click → `/workspace/{id}/upgrade?reason=credits` (fullscreen route, Phase 5).
- Collapse toggle: collapse (user-owned) / expand (clears the active tab's activity mark).
- Divider: drag, keyboard (above).
- Tabs: click selects (single); Shift+click selects a contiguous range from the anchor; Cmd/Ctrl+click toggles membership; middle-click closes; close on the active tab moves to the nearest same-kind neighbour (right, then left); closing a member of a multi-selection closes the whole selection; drag reorders (persisted); dragging tabs out carries `application/x-sim-resources` JSON (drop target: the composer) (`resource-tabs.tsx:366–573`).
- `+` (tabs) → menu; choosing adds the resource (`addResourceFromUser`: add, select, expand) (`use-resource-panel.ts:241–250`).
- Adding a chip in the composer for a workflow / current workflow / knowledge base / table (incl. selection) / file (incl. selection) / dashboard opens that resource as a tab and expands the panel (`home.tsx:300–340`); removing the last chip that references a tab closes it (hero only, 342–355).
- Clicking a resource chip inside an assistant message resolves it (forced file-list refetch for file chips), else toasts `Couldn't find "{title}" in this workspace` / `Couldn't open "{title}" — check your connection and try again` (`home.tsx:368–401`).
- Queue: header toggles; Edit loads the message into the composer (`loadQueuedMessage`) and marks the row; Send now; Remove; Cancel edit (`mothership-chat.tsx:774–799`).
- Cross-surface events (window `CustomEvent`s): `mothership-send-message` (send now, claimed with `preventDefault`), and one-shot handoffs from `MothershipHandoffStorage` on a new chat (auto-send a message, or seed chips and open their resources) (`home.tsx:239–298`). Landing storage on first mount: a workflow seed creates a workflow and navigates to it; a landing prompt seeds the composer (127–143).
- Mark-read: `POST /api/mothership/chats/read` when the resolved chat id changes and when a send finishes (`home.tsx:193–200`).
- Find-in-chat (Mod+F inside the conversation) belongs to the message-rendering spec.

## Network and realtime
In addition to the shell calls (`workspace-chrome.md` §Network: host-context, permissions, permission config, access-request discovery, chats list, `/api/mothership/events` SSE):
| When | Request | Notes |
|---|---|---|
| Server render / first mount | `GET /api/workspaces/{id}/files?scope=active` | seeded by `prefetchHomeSurface` after the host-context check; 30s stale (`home/prefetch.ts`, `hooks/queries/workspace-files.ts:137–143`) |
| Existing chat mount | `GET /api/mothership/chats/{chatId}` | history (chat-engine spec) |
| Chat resolved / send finished | `POST /api/mothership/chats/read {chatId}` | optimistic on the list cache |
| Billing enabled, not enterprise | `GET /api/workspaces/{id}/credit-availability` → `{remainingDollars:number|null, scope:'payer'|'member'|'effective'}` | 30s stale |
| Suggested actions mount | `GET /api/credentials?workspaceId=`, `GET /api/auth/oauth/connections`, `GET /api/table?workspaceId=&scope=active`, `GET /api/knowledge?workspaceId=&scope=active&includeCounts=false` | signals only |
| Add-resource menu open (and composer focus "warm", see chat-input) | `GET /api/workflows?workspaceId=`, `GET /api/folders?workspaceId=` (+ `resourceType=table`, `knowledge_base`), `GET /api/table…`, `GET /api/workspaces/{id}/files?scope=active`, `GET /api/workspaces/{id}/files/folders?scope=active`, `GET /api/knowledge…`, `GET /api/mothership/chats?workspaceId=&scope=active`, `GET /api/logs?…limit=50&sortBy=date` (first page), `GET /api/workspaces/{id}/dashboard` (flag `dashboards`), `GET /api/workspaces/{id}/tests` (flag `workflow-tests`) | cached per React Query keys shared with other surfaces |
| Resource added / removed / reordered (chat exists, persisted types only) | `POST /api/mothership/chat/resources {chatId, resource, clearViewId?}`; `DELETE /api/mothership/chat/resources {chatId, type, id, …}`; `PATCH /api/mothership/chat/resources {chatId, resources[]}` → `{success:true, resources[]}` | queued per chat (`ResourcePersistenceQueue`); before the chat exists resources stay local |
| Hydrated workflow tabs | `GET /api/workflows?workspaceId=` then per-missing `GET /api/workflows/{id}`; 404 → remove the resource | `use-chat.ts:1556–1600` |
| Send / stream / stop | `POST /api/mothership/chat`, `GET /api/mothership/chat/stream?…`, `POST /api/mothership/chat/stop` | chat-engine spec |
L7 allow-list: PostHog `captureEvent`s (`task_request_started`, `task_message_sent`, `task_generation_aborted`, `suggested_action_clicked`, `suggested_actions_toggled`) are hosted-only analytics and not ported.

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | `home/layout.tsx:22` | route frame `flex h-full flex-1 flex-col overflow-hidden` | | |
| 2 | layout | `chat-panel-layout.tsx:45–50` | row fills the content pane, `--bg` | | |
| 3 | layout | `home.tsx:415` | chat column flex-1, min width `min(480px, 50%)` | | |
| 4 | layout | `chat-panel-layout.tsx:131` | expanded panel default width 50% of the row (≈607px at 1440), 1px `--border` left edge | | |
| 5 | layout | `chat-panel-layout.tsx:67–100` | toggle 30×30 at top-right (right 16, row height 40), 40×40 hit area | | |
| 6 | token | `chat-panel-layout.tsx:79,87–97` | toggle hover `--surface-active`, mirrored `PanelLeft` 16px `--text-icon`, 6px `--brand-blue` dot when collapsed with activity | | |
| 7 | layout | `chat-panel-layout.tsx:53–64` | divider 8px wide centred on the panel edge, only when expanded | | |
| 8 | interaction | `use-mothership-resize.ts:18–56` | drag clamps to [min(280,max), maxPanelWidth] (735 at 1440) | | |
| 9 | keyboard | `use-mothership-resize.ts:72–91,328–342` | ←/→ ±32px (← widens), Home/End to bounds, modifiers/IME ignored | | |
| 10 | state | `stores/chat-panel/store.ts:9–107` | width persisted under `chat-panel-widths` per `${userId}:${chatId}`, ≥280, ≤200 entries; pending scope migrates on create | | |
| 11 | interaction | `use-mothership-resize.ts:105–113,179–204` | stored width re-clamped on container/window resize without transition | | |
| 12 | interaction | `use-mothership-resize.ts:241–322` | drag: ew-resize cursor, no text selection, commit on up/lost-capture/blur, cancel on pointercancel | | |
| 13 | token | `chat-panel-layout.tsx:130` | panel open/close animates width 200ms `cubic-bezier(.25,.1,.25,1)`, none on auto-open / reduced motion | | |
| 14 | layout | `resource-tab-controls.ts:6,27` | tab strip 41px incl. 1px `--border` rule; band 26; inline 16 / 52 | | |
| 15 | layout | `tab-strip.tsx:63,380–390` | floating tab 112–200px wide, 26px tall, px-8 gap-6, 12px text, radius 8 | | |
| 16 | token | `tab-strip.tsx:73–104` | tab rest `--text-secondary`, hover `--surface-hover`, active `--surface-active`/`--text-primary`, multi-selected `--surface-4` | | |
| 17 | state | `tab-strip.tsx:409–476` | attention dot 6px `--brand-blue` on inactive tabs | | |
| 18 | layout | `resource-tabs.tsx:611–622` | `+` 26×26 subtle action, tooltip "Add resource", −6px offset with no tabs | | |
| 19 | state | `mothership-view.tsx:328–334` | empty panel "Click "+" above to add a resource" `text-sm --text-muted` | | |
| 20 | layout | `add-resource-dropdown.tsx:604–611` | add menu 320px, align start, offset 8, `MENU_STYLES` surface | | |
| 21 | state | `resource-tabs.tsx:69–74`, `available-resources.ts:186–190` | add menu excludes sources/folder/task/integration; dashboard/test only with their flags | | |
| 22 | interaction | `add-resource-dropdown.tsx:319–390` | search filters across families; ↑/↓ cursor; Enter/Tab selects; "No results"/"Loading resources" | | |
| 23 | state | `resource-registry.tsx:308–323` | family order integration, task, dashboard, test, table, file, filefolder, knowledgebase, workflow, log, folder, browser, terminal, generic | | |
| 24 | layout | `home.tsx:438` | hero cluster centred with pt 2vh / pb 22vh, px 24 | | |
| 25 | layout | `home.tsx:439–441` | heading Season 28px lh 1.15 tracking −0.01em, `--text-primary`, mb 28, max 704 | | |
| 26 | state | `home.tsx:78,440` | heading uses first word of the user name; no name → "What should we get done?" | | |
| 27 | layout | `home.tsx:442,460` | composer 704 max; suggested actions absolutely below it (input never moves) | | |
| 28 | layout | `home.tsx:416–434` | credits chip right 57px when panel collapsed, 16px when expanded; 200ms `right` transition | | |
| 29 | state | `credits-chip.tsx:19,45` | chip hidden without billing, for enterprise owners, while loading | | |
| 30 | state | `credits-chip.tsx:47–50` | "Available" / "∞" / credits = round($×200) with locale grouping | | |
| 31 | state | `credits-chip.tsx:52–67` | non-manager: 20px `ChipTag` with the owner/admin tooltip copy | | |
| 32 | interaction | `credits-chip.tsx:69–78` | manager click → `/workspace/{id}/upgrade?reason=credits` | | |
| 33 | layout | `home-section.tsx:27–46` | section mt 28; title 12px `--text-muted`; chevron 14px hidden until hover/focus; body pt 6 | | |
| 34 | layout | `suggested-actions.tsx:339–355` | row px 8 py 8 gap 8, 16px icon, 14px `--text-body` label, `ArrowRight` 16px; border-t between rows | | |
| 35 | token | `suggested-actions.tsx:344` | row hover `--surface-5` | | |
| 36 | state | `suggested-actions.tsx:214–233,290–294` | without connections: Slack, Gmail, CRM starter, featured GitHub template | | |
| 37 | state | `suggested-actions.tsx:179–206` | with connections: 1 integrate row + 3 prompts, ≤1 per block | | |
| 38 | interaction | `home.tsx:461–465`, `user-input.tsx:377–385` | prompt row populates the composer (mentionified), focuses, does not send | | |
| 39 | interaction | `suggested-actions.tsx:306–316` | integration row opens the OAuth connect modal for that service | | |
| 40 | interaction | `suggested-actions.tsx:255–262,318–326` | expanded by default; collapse animation only after the first toggle | | |
| 41 | state | `home.tsx:403–411` | hero only with zero messages and no pending history for a chat id | | |
| 42 | state | `mothership-chat-skeleton.tsx:27–50` | skeleton geometry while history loads; composer hidden | | |
| 43 | layout | `mothership-chat.tsx:150–162` | conversation scroll px 24 pt 16 pb 8, max-w 704; footer px 24 pb 16 | | |
| 44 | interaction | `home.tsx:223–225`, `mothership-chat.tsx:965–966` | first send from the hero slides the footer in (400ms, 20px) | | |
| 45 | interaction | `home.tsx:211–231` | empty text + files sends "Analyze the attached file(s)."; empty + no files ignored | | |
| 46 | interaction | `use-chat.ts:1356–1365`, `chat-url.ts` | new chat URL becomes `/workspace/{id}/chat/{chatId}` in place, keeping `?resource=` | | |
| 47 | state | `use-restored-chat-entry.ts:24–38` | Back to a rewritten entry re-resolves through the chat route | | |
| 48 | layout | `queued-messages.tsx:50–53` | queue tray inset 14px, 16px top radius, `--surface-3`, overlaps the composer by 12px | | |
| 49 | layout | `queued-messages.tsx:54–70` | header "{n} Queued" 13px `--text-secondary` with 14px chevron | | |
| 50 | state | `queued-messages.tsx:75–98` | editing row `--surface-active` with dashed status ring | | |
| 51 | state | `queued-messages.tsx:105–123` | attachment pill: first filename + `+N`, count only under 320px | | |
| 52 | interaction | `queued-messages.tsx:147–207` | Edit (disabled reasons via tooltip), Send now (disabled while dispatching), Remove; Cancel edit while editing | | |
| 53 | state | `home/layout.tsx:17–20`, `chat/[chatId]/layout.tsx:5` | chat disabled: `/home` redirects to `/workspace/{id}`; `/chat/{id}` 404 | | |
| 54 | state | `permission-access-boundary.tsx:52–127` | `hideCopilot` gate: checking / error+retry / access required / access updated | | |
| 55 | state | `home/error.tsx`, `chat/[chatId]/error.tsx`, `components/error/error.tsx` | error shell with 52px mark, page-heading title, "Try again" primary chip | | |
| 56 | state | `home/page.tsx:12–14`, `chat/[chatId]/page.tsx:12–14`, `ee/whitelabeling/metadata.ts:21–24` | document title "New chat \| Sim" / "Chat \| Sim" | | |
| 57 | state | `use-resource-panel.ts:290–309` | panel auto-opens on first resources (desktop), auto-closes when empty | | |
| 58 | interaction | `use-resource-panel.ts:195–216` | collapse is user-owned until the next chat; expand clears the active tab's activity | | |
| 59 | interaction | `resource-tabs.tsx:369–420` | tab click / Shift range / Cmd-Ctrl toggle selection | | |
| 60 | interaction | `resource-tabs.tsx:422–470` | close moves to nearest same-kind neighbour; multi-selection closes together | | |
| 61 | interaction | `resource-tabs.tsx:504–573` | tab drag reorders (PATCH resources) and drags out as `application/x-sim-resources` | | |
| 62 | interaction | `home.tsx:300–355` | composer chip for workflow/kb/table/file/dashboard opens its tab; last chip removal closes it (hero) | | |
| 63 | interaction | `home.tsx:368–401` | unresolved message resource chip toasts the two copy variants | | |
| 64 | state | `mothership-view.tsx:307–327`, `resource-content.tsx:315–425` | Phase 1.5: generic/sources/folder real, others placeholder, filefolder/task/integration blank | | |
| 65 | network | `home/prefetch.ts`, `workspace-files.ts:137–143` | workspace files list fetched once on Home | | |
| 66 | network | `home.tsx:193–200` | `POST /api/mothership/chats/read` on chat resolve and after each send | | |
| 67 | network | `workspace-usage.ts:34–41` | `GET /api/workspaces/{id}/credit-availability` only with billing on and non-enterprise owner | | |
| 68 | network | `suggested-actions.tsx:245–253` | credentials, OAuth connections, tables, knowledge lists on mount | | |
| 69 | network | `contracts/mothership-chats.ts:244–268` | resource add/remove/reorder bodies and responses | | |
| 70 | network | `available-resources.ts:102–170` | inventory list requests fire on menu open only | | |
