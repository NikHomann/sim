# Workspace sidebar
Upstream: `app/workspace/[workspaceId]/w/components/sidebar/sidebar.tsx` and `components/{workspace-header, sidebar-section, sidebar-nav-chip, sidebar-footer, collapsed-sidebar-menu, rail-resource-flyout, sidebar-tooltip, status-notice, chat-navigation-link, help-modal, nav-item-context-menu}`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

Paths relative to `apps/sim/`; `sidebar/` means `app/workspace/[workspaceId]/w/components/sidebar/`. The rail's outer geometry (width, collapse cookie, resize handle, peek) is in `workspace-chrome.md`; the workflow/folder tree (`components/workflow-list/**`, `hooks/use-drag-drop.ts`, `use-folder-*`, `use-item-*`) is in `sidebar-workflow-tree.md` — only its mount point is recorded here. The workspace switcher dropdown is also covered in depth by `workspace-switcher.md`; where the two disagree the React source wins (README rule). The search palette (`components/search-modal/**`) is in `search-palette.md`; the settings sidebar (`components/settings-sidebar/`, shown on `/settings/*`) is Phase 5.

## Files

| File | Lines |
|---|---|
| `sidebar/sidebar.tsx` | 1958 |
| `sidebar/constants.ts` | 65 |
| `sidebar/utils.ts` | 172 |
| `sidebar/components/workspace-header/workspace-header.tsx` | 888 |
| `sidebar/components/workspace-header/components/create-workspace-modal/create-workspace-modal.tsx` | 87 (see `workspace-modals.md`) |
| `sidebar/components/workspace-header/components/pending-invitations/view-invitations-menu-item.tsx` | 30 |
| `sidebar/components/workspace-header/components/pending-invitations/view-invitations-modal.tsx` | 222 (see `workspace-modals.md`) |
| `sidebar/components/sidebar-section/sidebar-section.tsx` | 108 |
| `sidebar/components/sidebar-nav-chip/sidebar-nav-chip.tsx` | 99 |
| `sidebar/components/sidebar-footer/sidebar-footer.tsx` | 339 |
| `sidebar/components/collapsed-sidebar-menu/collapsed-sidebar-menu.tsx` | 575 |
| `sidebar/components/rail-resource-flyout/rail-resource-flyout.tsx` | 104 |
| `sidebar/components/sidebar-tooltip/sidebar-tooltip.tsx` | 35 |
| `sidebar/components/status-notice/status-notice.tsx` | 57 |
| `sidebar/components/chat-navigation-link/chat-navigation-link.tsx` | 170 |
| `sidebar/components/help-modal/help-modal.tsx` | 365 |
| `sidebar/components/nav-item-context-menu/nav-item-context-menu.tsx` | 65 |
| `sidebar/components/sidebar-row-actions.tsx` | 20 |
| `sidebar/components/sidebar-rename-row.tsx` | 39 |
| `sidebar/components/workflow-list/components/context-menu/context-menu.tsx` | 456 (shared menu used for chats and workspaces) |
| `sidebar/components/workflow-list/components/delete-modal/delete-modal.tsx` | 241 (chats, workspace) |
| `sidebar/components/workflow-list/components/workflow-item/avatars/avatars.tsx` | 55 |
| `app/workspace/[workspaceId]/components/presence/presence-avatars.tsx` | 113 |
| `app/workspace/[workspaceId]/components/conversation-list-item/conversation-list-item.tsx` | 39 |
| `components/workspaces/workspace-context-menu.tsx` | 47 |
| `components/identity-tile/identity-tile.tsx` | 71 |
| `sidebar/hooks/use-workspace-management.ts` | 247 |
| `sidebar/hooks/use-workspace-logo-upload.ts` | 142 |
| `sidebar/hooks/use-hover-menu.ts` | 111 |
| `sidebar/hooks/use-flyout-inline-rename.ts` | 116 |
| `sidebar/hooks/use-chat-selection.ts` | 47 |
| `sidebar/hooks/use-workspace-workflows-room.ts` | 29 |
| `sidebar/hooks/use-workflow-operations.ts` | 57 |
| `sidebar/hooks/use-folder-operations.ts` | 51 |
| `hooks/queries/workspace.ts` | 530 |
| `hooks/queries/pinned-items.ts` | 154 |
| `hooks/queries/invitations.ts` | 468 |
| `hooks/queries/user-profile.ts` | 104 |
| `hooks/queries/status-page.ts` / `lib/status-page.ts` | 28 / 35 |
| `hooks/queries/mothership-chats.ts` | 895 |
| `hooks/use-context-menu.ts` / `lib/core/utils/context-menu.ts` | 93 / 10 |
| `stores/presence/store.ts` / `types.ts` | 24 / 23 |
| `stores/folders/store.ts` | chat/workflow selection (`selectedChats`, `selectChatOnly`, `selectChatRange`, `toggleChatSelection`, `clearChatSelection`, `selectOnly`, `clearAllSelection`) |
| `lib/workspaces/initials.ts` / `constants.ts` / `colors.ts` | 8 / 2 / 53 |
| `lib/help-links.ts` | 7 (`DOCS_URL = https://docs.sim.ai`, `SLACK_COMMUNITY_URL = https://join.slack.com/t/sim-ott9864/shared_invite/zt-43lp8tc5v-0qrrqHGBKUsvQlpoouH~TA`) |

emcn components: `Chip`, `ChipLink`, `chipVariants`, `Button` (quiet/icon), `DropdownMenu*` (`Content`, `Item` with `size='lg'`, `active`, `action`, `actionIndicator`, `actionOpen`; `ItemAction`, `ItemLabel`, `Separator`, `Sub*`), `Tooltip` (`Root/Trigger/Content/Shortcut`), `OverflowText`, `RowActions` + `rowActionsGroupClass`, `Skeleton`, `Loader`, `ChipInput`, `ChipConfirmModal`, `ChipModal*`, `Expandable/ExpandableContent`, `scrollFadeClass/scrollFadeAttributes/useScrollEdges`, `Avatar/AvatarImage/AvatarFallback` (presence). Icons (`@sim/emcn/icons`): `Home, Plus, Dashboard, Rss, Integration, Table, Files, Database, ShieldCheck, Library, Task, Workflow, Search, PanelLeft, MoreHorizontal, Pin, PinOff, Pencil, Trash, LogOut, Settings, BookOpen, HelpCircle, Mail, Send, ArrowLeft, SquareArrowUpRight, Duplicate, Lock, ChevronDown, CircleAlert, Upload, FolderPlus, ImageUp`; `SlackIcon` from `components/icons.tsx`.

## Layout

Vertical structure of `<aside.sidebar-container>` (`sidebar.tsx:1382–1912`), expanded, default width 224px. All horizontal gutters are `px-2` (8px) so chips span x = 8..216.

| # | Block | Classes / geometry | Source |
|---|---|---|---|
| 0 | `<aside>` | `group/rail sidebar-container relative h-full overflow-hidden bg-[var(--surface-1)]`, `data-collapsed` when collapsed, `aria-label='Workspace sidebar'`; column `flex h-full flex-col` | 1382–1388 |
| 1 | Title-bar lane | `h-[var(--desktop-title-bar-height)]` = 0px on web, `display:none` | 1390–1395 |
| 2 | Header row (`shell.sidebar.header`) | `relative flex shrink-0 items-center px-2 pt-2` → 8px top padding, 30px tall content (38px total) | 1396–1486 |
| 2a | Workspace switcher chip (`shell.sidebar.header.workspace`) | wrapper `min-w-0 flex-1`; `Chip` `min-w-0 max-w-full`: 30px tall, `px-2`, `gap-1.5` (6px), `rounded-lg`, label `text-sm` 14px `--text-body`; `leftAdornment` `IdentityTile` 16×16 `rounded-sm` (4px) `bg-[var(--surface-6)]` with the initial at `text-micro` 10px `--text-icon` (dark: `--text-secondary`) or the logo `object-cover`; `rightAdornment` `ChipChevronDown` | header 448–520, identity-tile 17–20, 59–70 |
| 2b | Trailing cluster (`shell.sidebar.header.actions`) | `flex h-[30px] items-center gap-[1px] overflow-hidden`; expanded `w-[65px]` (2 × 32px icon chips + 1px gap); collapsed `w-0 opacity-0` + `inert` | 1443–1450 |
| 2c | Search chip (`shell.sidebar.header.search`) | `Chip leftIcon={Search}` icon-only: 32×30, glyph 16px `--text-icon`; tooltip side bottom "Search" + `⌘K`/`Ctrl+K` | 1452–1467 |
| 2d | Collapse chip (`shell.sidebar.header.collapse`) | `Chip leftIcon={PanelLeft}` 32×30; tooltip "Collapse sidebar" + `⌘B`/`Ctrl+B` | 1468–1484 |
| 3 | Pinned top nav (`shell.sidebar.nav`) | `mt-4 gap-[1px] pb-2 flex shrink-0 flex-col border-b px-2 transition-colors duration-150`; border colour `--border` only while the scroll region below is scrolled (`scrollEdges.top`), else `border-transparent`. 16px above (from header), rows 30px with 1px gaps, 8px below, 1px rule | 1498–1516, constants 10,20,32 |
| 3a | Nav row (`shell.sidebar.nav.{home|dashboards|changelog|integrations}`) | `SidebarNavChip`: `ChipLink fullWidth active={…}` (`flex w-full h-[30px] px-2 gap-1.5 rounded-lg text-sm`), `leftIcon` 16px `--text-icon`, label `--text-body`, `rightIcon={Lock}` when `restricted`; hover `--surface-hover`, active `--surface-active`; `data-item-id` | nav-chip 416–469 |
| 4 | Scroll region (`shell.sidebar.scroll`) | `pt-2 pb-2 scrollFadeClass flex min-h-0 flex-1 flex-col overflow-y-auto overflow-x-hidden`; 12px edge fade bands when scrollable (`SCROLL_FADE_BAND_PX`) | 1518–1527, emcn scroll-fade 16 |
| 4a | Section (`SidebarSection`) | wrapper `group/section flex flex-col` + caller class; title row `flex h-[18px] shrink-0 items-center` containing a `<button>` `flex h-full min-w-0 flex-1 items-center gap-2 px-4` (label `OverflowText` `text-caption` 12px `--text-muted`, class `sidebar-collapse-hide`; `ChevronDown` 14px `--text-icon`, `opacity-0`, visible on section hover / toggle focus, `-rotate-90` when collapsed, 150ms); optional `action` slot `flex shrink-0 items-center pr-4`; body `Expandable` with `animate-none!` and inner `pt-1.5` (6px) | section 482–575 |
| 4b | "Chats" section (`shell.sidebar.chats`) | `chats-section shrink-0`, first in the scroll region (no `mt-4`); only when `chatEnabled && !hideCopilot` | 1529–1651 |
| 4c | Chat rows container | `gap-[1px] flex flex-col px-2` | 1570 |
| 4d | Chat row (`shell.sidebar.chats.item`) | `ChatNavigationLink` (`<a>`) with `chipVariants({active, fullWidth})` + `group/row-actions`; `OverflowText flex-1 text-[var(--text-body)]`; trailing `RowActions` slot: indicator 6px dot (`#EAB308` while `isActive`, `--brand-accent` while unread and not current) or `Pin` 12px `--text-icon` when pinned; on hover/focus the indicator fades and an 18×18 `rounded-sm` `SidebarRowAction` with `MoreHorizontal` 14px appears | 278–335, row-actions 40–67 |
| 4e | Empty chats | `flex h-[30px] items-center px-2 text-[var(--text-muted)] text-small` "No chats yet" | 1573–1577 |
| 4f | See more / See less | `chipVariants({fullWidth})` + `text-[var(--text-muted)] text-small`; shown when > 5 chats; label "See more" while hidden chats remain else "See less" | 1630–1645 |
| 4g | "Workspace" section (`shell.sidebar.workspace`) | `mt-4 shrink-0`; rows container `gap-[1px] flex flex-col px-2` | 1653–1688 |
| 4h | "Workflows" section (`shell.sidebar.workflows`) | `mt-4 workflows-section relative`; action cluster `flex items-center justify-center gap-2` (expanded only): More `Button variant='quiet' size='icon'` (20×20 `rounded-sm`, `MoreHorizontal` 14px / `Loader` 16px) + New `Button quiet icon` (`Plus` 16px); body `px-2` → `WorkflowList` | 1690–1845 |
| 5 | Status notice (`shell.sidebar.status`) | wrapper `shrink-0 px-2 py-2`; alert `flex w-full flex-col gap-2 rounded-xl border border-[var(--terminal-status-error-border)] bg-[var(--terminal-status-error-bg)] p-2`; first line `flex min-w-0 items-center gap-1.5` with `CircleAlert` 16px `--text-icon` + `<p class="min-w-0 text-[var(--text-body)] text-sm leading-5">Sim is having issues`; `ChipLink variant='border' fullWidth justify-center` "View status" → `https://status.sim.ai` new tab | status-notice 594–633 |
| 6 | Footer (`shell.sidebar.footer`) | `flex shrink-0 border-t px-2 pt-[9px] pb-2 transition-colors duration-150`; border `--border` only while the scroll region hides rows below (`scrollEdges.bottom`), else transparent; expanded `items-center`, collapsed `gap-[1px] flex-col-reverse`. Height 1 + 9 + 30 + 8 = 48px expanded; collapsed 1 + 9 + 30 + 1 + 30 + 8 = 79px | footer 321–337 |
| 6a | Profile chip (`shell.sidebar.footer.profile`) | wrapper `flex min-w-0` (+ `flex-1` expanded); `<button>` `chipVariants({fullWidth: isCollapsed})` + `max-w-full` (expanded) / `min-w-0` (collapsed) + rail class; avatar 16px round: `img object-cover` / `div text-[9px] text-white` with `getUserColor(id)` / `Skeleton size-[16px] rounded-full`; name `OverflowText` `chipContentLabelClass` (`text-sm --text-body`) + `sidebar-collapse-hide`; loading: `Skeleton h-[14px] w-[96px] rounded-sm` | 148–215 |
| 6b | Help chip (`shell.sidebar.footer.help`) | `Chip leftIcon={HelpCircle}` icon-only 32×30, `fullWidth` when collapsed, `shrink-0` + rail class; lands hard right (expanded) | 271–290 |

Row geometry recap: every row is a 30px chip (`h-[30px] px-2 gap-1.5 rounded-lg text-sm`, chip `chrome.ts:58–66`), icons 16px (`chrome.ts:68`), 1px vertical gap between rows, 16px between sections, 6px between a section title and its first row, 8px side gutters.

### Collapsed rail (`sidebar-container[data-collapsed]`, 48px)
- Header: the switcher is replaced by `Chip aria-label='Expand sidebar' fullWidth` with the rail class (32px) whose `leftAdornment` is a 16px box holding the `IdentityTile` (`group-hover:invisible`) and a `PanelLeft` rotated 180° (`invisible … group-hover:visible`) — hovering swaps logo → expand glyph; a `Skeleton size-[16px] rounded-sm` while loading; click expands (header 449–475). The trailing cluster collapses to `w-0 opacity-0 inert` (1444–1449).
- Nav rows keep their 30px height; width 32px (`group-data-[collapsed]/rail:w-[32px]`); labels opacity 0.
- Section titles become static divs (no chevron, no button) and sections are forced open (section 535–536, 565).
- Chats / Workflows sections render a single `CollapsedSidebarMenu` trigger chip (`px-2` wrapper, `Chip leftAdornment={icon} fullWidth` + rail class; icons `Task` / `Workflow` 16px `--text-icon`) whose hover flyout is a `DropdownMenuContent side='right' align='start' sideOffset={8} className='w-[220px]'` with `SIDEBAR_NO_MOTION_CLASS` (collapsed-sidebar-menu 219–283; sidebar 1249–1253, 1535–1568, 1768–1827). Surface = `MENU_STYLES.surface` (`rounded-xl border --border bg --bg shadow-medium`) `p-1`, rows 28px `text-small` (`dropdown-menu/styles.ts:10–18`).
  - Workflows flyout: first item `Plus` "New workflow" (`primaryAction`) + separator (271–279); then root items interleaved by `sortOrder` (folders as `DropdownMenuSub` submenus, empty folders disabled; workflows as `CollapsedWorkflowFlyoutItem` = `DropdownMenuItem asChild` wrapping a `Link`, `active` when current, with an `ItemAction` `MoreHorizontal` opening a submenu "Open in new tab" / "Rename" (disabled unless `canEdit`); right-click opens the same submenu) (370–480, 505–575); "No workflows yet" disabled item when empty (1779); nothing while loading (1777–1778).
  - Chats flyout: `CollapsedChatFlyoutItem` rows (`ChatNavigationLink` + `ConversationListItem` with the same 6px dot rules; `ItemAction` opens the chat context menu) (286–368); "No chats yet" disabled item (1544).
  - Tables / Files nav rows become `CollapsedSidebarMenu navLink` triggers: the chip stays the nav link (click navigates, `Enter` activates the link, right-click → nav context menu) and hover opens `TablesRailFlyout` / `FilesRailFlyout` (rail-resource-flyout 619–679): "Loading..." disabled item with `Loader` 14px while either the resource list or its folders is pending/placeholder; "No tables yet" / "No files yet" when empty; else folders as submenus (empty folders disabled) and items as `Link` rows (`active` when `params.tableId` / `params.fileId` matches), pinned rows carry `Pin` 12px `--text-icon` (`role='img'`, "Pinned") (57–129). Restricted (locked) rows get no flyout (1661–1662). Knowledge bases, Tests, Logs have no flyout.
- Inline rename inside a flyout: `EDIT_ROW_CLASS` = `chipVariants({active:true, fullWidth:true}) min-w-0 cursor-default select-none text-small` with a bare `<input>` (`text-small`, `maxLength=100`) (199–202, 305–331); the hover menu is locked open while editing (`setLocked`) (1017–1023).
- Footer: `flex-col-reverse` → help chip on top, profile chip at the bottom, both 32px rail chips; tooltips side right (profile: the name; help: "Help") (190, 273–276).
- Tooltips: `SidebarTooltip enabled={isCollapsed}` on every nav row, section trigger and footer chip; `Tooltip.Content side='right'` (default); the tooltip is emcn's cursor-following floating tooltip: `w-fit max-w-[min(16rem,calc(100vw-2rem))] rounded-lg border border-[var(--border)] bg-[var(--bg)] text-[var(--text-body)] text-caption shadow-xs`, `px-2 py-1.5`, 16px offset from the cursor, no delay, 150ms ease-out fade (tooltip `styles.ts:5–6`, `tooltip.tsx:430,459`). With `shortcut`, content is `Tooltip.Shortcut` = `flex items-center gap-2` label + keys at `opacity-70` (700–705).

### Workspace switcher dropdown (`shell.sidebar.header.workspace.menu`, header 477–789)
- `DropdownMenuContent align='start' side='bottom' sideOffset={8}` (collapsed: `side='right' sideOffset={16}` — unreachable on web because the collapsed header shows the expand chip instead), class `flex max-h-[var(--radix-dropdown-menu-content-available-height,400px)] w-64 max-w-[calc(100vw-24px)] flex-col overflow-y-auto` → 256px wide, capped at the available height, `rounded-xl border --border bg --bg shadow-medium p-1`, `z-[var(--z-popover)]` (dropdown-menu 128).
- Contents, in order:
  1. "Back to organization" (`ArrowLeft` 14px, `DropdownMenuItem size='lg'` = 30px chip geometry, `SettingsGuardedLink href={organizationHref}`) only when `organizationHref`; followed by a separator when the search field is absent or the list is loading (531–543).
  2. While `isWorkspacesLoading`: nothing else (544).
  3. Search `ChipInput` (`icon={Search}`, placeholder "Search workspaces...", `shrink-0`, `mt-2` after the org link) only when `workspaces.length >= 6` (`WORKSPACE_SEARCH_THRESHOLD`); auto-focused on open via rAF (495–497, 546–586).
  4. List `-mx-1.5 flex max-h-[200px] flex-col gap-0.5 overflow-y-auto px-1.5 pb-1` (+ `pt-1.5` with search), scroll-fade edges (588–599). Rows: `DropdownMenuItem size='lg'` (30px, `px-2 gap-1.5 rounded-lg text-sm`) with `IdentityTile` + `DropdownMenuItemLabel`; `active` when current workspace, when its context menu is open, or when keyboard-highlighted; `actionIndicator` `Pin` 12px (`aria-label='Pinned'`) when pinned; `action` = `DropdownMenuItemAction` (18×18) `MoreHorizontal` "Workspace options" (605–738). A row being renamed shows `SidebarRenameRow` instead (chip `active fullWidth`, leading `IdentityTile`, `<input text-sm maxLength=100>`) (631–680). Empty filter: `px-2 py-[5px] text-[var(--text-muted)] text-caption` "No results for "{q}"" (600–604).
  5. `DropdownMenuSeparator className='mx-0 mt-0 shrink-0'` (741).
  6. Footer `flex shrink-0 flex-col gap-0.5` (743–785): "New workspace" (`Plus` 14px; disabled while creating or `creationPolicy.canCreate === false`, then wrapped in a tooltip showing `creationPolicy.reason`); "Invite teammates" (`Send` 14px; only when `userPermissions.canAdmin`; tooltip `inviteDisabledReason` when set); "View invitations" (`Mail` 14px; only when `GET /api/invitations` returns ≥1 pending).
- Ordering: pinned workspaces first (stable), then the server's recency order (`workspace.ts:115–119`).
- Loading / not-ready header: a disabled `<button>` with `chipGeometryClass` holding the tile (or `Skeleton size-[16px] rounded-sm`) + name + chevron, so the trigger's box never shifts (790–819).

### Context menus
All are emcn `DropdownMenu` anchored to a 1×1 fixed trigger at the click point (`NavItemContextMenu` 363–375; the shared `ContextMenu` does the same), `align='start' side='bottom' sideOffset={4}`, `modal={false}`, `onCloseAutoFocus` prevented; opened via `useContextMenu` (`getContextMenuPosition`: client point, or the control's bottom-left when invoked by keyboard, `lib/core/utils/context-menu.ts:4–10`); closed on outside click after a 0ms timer (`use-context-menu.ts:61–82`).
- Nav row (`shell.sidebar.nav.menu`): "Open in new tab" (`SquareArrowUpRight`) → `window.open(href,'_blank','noopener,noreferrer')`; "Copy link" (`Duplicate`) → clipboard `origin + href` (sidebar 614–642; nav-item-context-menu 383–400). Only for rows with an `href` (not the "New workflow" button).
- Chat row (`shell.sidebar.chats.menu`, sidebar 1874–1899 using `ContextMenu`): "Open in new tab" (single only), "Mark as read" (single, unread) / "Mark as unread" (single, read), "Pin"/"Unpin" (`Pin`/`PinOff`), "Rename" (`Pencil`, disabled unless `canEdit`), separator, "Delete" (`Trash`, disabled unless `canEdit`; label "Delete N chats"-style via `selectionActionLabel` for a multi-selection). Right-click on a row that is part of the current multi-selection acts on the whole selection; otherwise it selects that row only (674–696). The `MoreHorizontal` row action opens the same menu at the button's top-right (704–728).
- Workspace row / header chip (`shell.sidebar.header.workspace.row.menu`, `WorkspaceContextMenu` → `ContextMenu`): "Pin"/"Unpin", "Rename" (disabled unless `permissions === 'admin'`), "Upload logo" (`ImageUp`, disabled unless admin), separator, "Leave" (`LogOut`, only when `sessionUserId !== ownerId && !isOrgAdmin`), "Delete" (disabled unless admin and `workspaceCount > 1`) (workspace-context-menu 30–45; context-menu 284–415). Rename and pin keep the switcher open (`keepWorkspaceMenuOpenRef`), delete/leave close it and open their modals (header 359–402).

### Parity ids
`shell.sidebar` (aside) · `shell.sidebar.header` · `shell.sidebar.header.workspace` · `shell.sidebar.header.workspace.menu` · `shell.sidebar.header.workspace.menu.row` (first row) · `shell.sidebar.header.actions` · `shell.sidebar.header.search` · `shell.sidebar.header.collapse` · `shell.sidebar.nav` · `shell.sidebar.nav.home` · `shell.sidebar.nav.dashboards` · `shell.sidebar.nav.changelog` · `shell.sidebar.nav.integrations` · `shell.sidebar.scroll` · `shell.sidebar.chats` · `shell.sidebar.chats.title` · `shell.sidebar.chats.item` (first) · `shell.sidebar.chats.more` · `shell.sidebar.workspace` · `shell.sidebar.workspace.title` · `shell.sidebar.nav.tables` · `shell.sidebar.nav.files` · `shell.sidebar.nav.knowledge` · `shell.sidebar.nav.tests` · `shell.sidebar.nav.logs` · `shell.sidebar.workflows` · `shell.sidebar.workflows.title` · `shell.sidebar.workflows.more` · `shell.sidebar.workflows.new` · `shell.sidebar.workflows.list` (mount point) · `shell.sidebar.status` · `shell.sidebar.footer` · `shell.sidebar.footer.profile` · `shell.sidebar.footer.profile.menu` · `shell.sidebar.footer.help` · `shell.sidebar.footer.help.menu` · `shell.sidebar.rail.chats` · `shell.sidebar.rail.workflows` · `shell.sidebar.rail.flyout` · `shell.sidebar.tooltip` · `shell.sidebar.help-modal`.

### Colour anchors (viewport px at 1440×900, default width, seeded workspace with ≥1 chat and ≥1 workflow; dpr 1)
| # | Point | Expected light | dark | Source |
|---|---|---|---|---|
| S1 | (4, 24) — header gutter | `--surface-1` #fbfbfb | #1e1e1e | sidebar 1383 |
| S2 | (112, 23) — centre of the switcher chip, hovered | `--surface-hover` #f2f2f2 | #262626 | chip `chrome.ts:83` |
| S3 | (16, 23) — IdentityTile fill (initial variant, sample 2px off-centre to avoid the glyph: (12, 19)) | `--surface-6` #e5e5e5 | #454545 | identity-tile 63 |
| S4 | (200, 69) — right end of the first nav row ("New chat"), x inside the chip past the label, while on `/home` (header 8 + 30, section gap 16 → row spans y 54..84) | `--surface-active` #ececec | #2c2c2c | chip `chrome.ts:85` |
| S5 | (112, nav.bottom) — the nav block's bottom rule while the scroll region is scrolled | `--border` #d8d8d8 | #444444 | sidebar 1503–1504 |
| S6 | (112, footer.top) — footer top rule while rows are hidden below | `--border` | #444444 | footer 324–325 |
| S7 | (112, footer.top) — footer rule when everything fits | `--surface-1` (transparent border) | #1e1e1e | footer 325 |
| S8 | (212, chatRow.centerY) — the 6px unread dot | `--brand-accent` #33c482 | #33c482 | sidebar 313 |
| S9 | menu: (switcherMenu.left+4, switcherMenu.top+4) | `--bg` #fefefe | #1b1b1b | dropdown `styles.ts:12` |
| S10 | status notice (hosted/preview only): (16, notice.top+4) | `--terminal-status-error-bg` #fef2f2 | #491515 | status-notice 598 |

## Tokens

| Element | Tokens |
|---|---|
| aside | `--surface-1` |
| Rows (nav, chats, profile) | rest transparent; hover `--surface-hover`; active/selected/menu-open `--surface-active`; label `--text-body` `text-sm`; icon `--text-icon` 16px; radius 8 (`rounded-lg`) |
| Restricted row | `Lock` right icon `--text-icon`; `aria-label="{label}: access required"` |
| Section title | `--text-muted` `text-caption` 12px; chevron `--text-icon` 14px |
| Dividers (nav bottom, footer top) | `--border` 1px (`--border-width`), transparent when idle |
| Chat dots | active `#EAB308` (literal), unread `--brand-accent`; pin glyph `--text-icon` |
| Empty text / See more | `--text-muted` `text-small` 13px |
| IdentityTile | fill `--surface-6`, letter `--text-icon` (dark `--text-secondary`), `text-micro`, radius 4 |
| Avatar (profile) | `getUserColor(id)` from `USER_COLORS` = [`--indicator-active`, `--color-pink-400`, `--brand-secondary`, `--color-orange-400`, `--color-purple-400`, `--color-amber-300`] by char-code sum mod 6 (`lib/workspaces/colors.ts:7–53`); letter white 9px |
| Presence avatars | emcn `Avatar size='xs'` 14px (`size-3.5`), fallback `getUserColor`, `font-semibold text-white`, overlap `-space-x-1`; overflow chip `bg-gray-700 text-[7px] text-white` |
| Menus | `rounded-xl`, `--border`, `--bg`, `shadow-medium`, `p-1`; rows 28px `text-small` (`size='lg'` rows 30px `text-sm`); separator `mx-2 my-1 border-t --border` |
| Flyout rename input | `text-small`, `--text-body`, transparent |
| Tooltip | `--bg`, `--border`, `--text-body`, `text-caption`, `shadow-xs`, radius 8 |
| Status alert | `--terminal-status-error-bg` / `-border`, `rounded-xl`, text `--text-body`, icon `--text-icon`; hover tint `color-mix(--text-error 8%)` |
| Buttons (quiet icon) | 20px, `rounded-sm`, `--text-secondary` (icon-muted when `size='icon'`), hover `--surface-active`, svg stroke 1.25 |
| Help modal | ChipModal md (500px) — see `workspace-modals.md` for the modal chrome tokens |

## States

### Navigation entries (sidebar 754–865)
| Entry | Label / icon / href | Hidden when | Restricted (Lock) when | Active when |
|---|---|---|---|---|
| home | `chatEnabled` ? "New chat" `Home` → `/workspace/{id}/home` : "New workflow" `Plus` (button → create workflow) | chat off and viewer cannot edit (once permissions loaded); chat on and `hideCopilot` without access requests | chat on and `hideCopilot` | pathname === href or startsWith `href/` |
| dashboards | "Dashboard" `Dashboard` → `/dashboards` | flag `dashboards` false; or `hideFilesTab` without access requests | `hideFilesTab` | same rule |
| changelog | "Changelog" `Rss` → `/changelog` | flag `changelog` false; or `hideFilesTab` w/o access requests | `hideFilesTab` | same rule |
| integrations | "Integrations" `Integration` → `/integrations`, also active on `/skills` | `hideIntegrationsTab` w/o access requests | `hideIntegrationsTab` | href or `/skills` prefix |
| tables | "Tables" `Table` → `/tables` (rail flyout) | `hideTablesTab` w/o access requests | `hideTablesTab` | |
| files | "Files" `Files` → `/files` (rail flyout) | `hideFilesTab` w/o access requests | `hideFilesTab` | |
| knowledge-base | "Knowledge bases" `Database` → `/knowledge` | `hideKnowledgeBaseTab` w/o access requests | `hideKnowledgeBaseTab` | |
| tests | "Tests" `ShieldCheck` → `/tests` | flag `workflow-tests` false; or `hideFilesTab` w/o access requests | `hideFilesTab` | |
| logs | "Logs" `Library` → `/logs` | never | never | |

`isNavItemActive` matches at a segment boundary (`/foo` never lights for `/foo-bar`) (nav-chip 393–398). `permissionConfig.*` comes from `GET /api/permission-groups/user`; `accessRequestsEnabled` from the access-request discovery query (`useWorkspaceAccessRequestFeatures`).

### Other states
| State | Behaviour | Source |
|---|---|---|
| Workspaces loading | switcher is a disabled chip-shaped button with the tile (or skeleton) and name; menu not openable | header 790–819 |
| Profile loading | 16px round skeleton + `h-[14px] w-[96px]` skeleton label | footer 148–149, 211 |
| Workflows loading with no cached rows | nothing rendered in the section body (no skeleton) | 1830, 1777–1778 |
| Chats loading | section body empty (`!chatsLoading` guard) | 1571 |
| Chats empty | "No chats yet" row | 1573–1577 |
| Chat disabled (`NEXT_PUBLIC_CHAT_DISABLED` / `hideCopilot`) | no Chats section; home entry becomes "New workflow"; chat list query not run; palette's Chats group empty | 762–771, 907–910, 1529 |
| Read-only member (`!canEdit`) | "New workflow"/"More actions"/"Import"/"Create folder" disabled; `add-workflow` shortcut no-op; rename/delete in chat menu disabled; `canReorder=false` passed to the list | 1705, 1726–1736, 1749, 1351, 1896–1897, 1836 |
| Not admin | "Invite teammates" absent | header 761 |
| `creationPolicy.canCreate === false` | "New workspace" disabled with reason tooltip | header 279–281, 744–760 |
| Invitations disabled | selecting "Invite teammates" navigates to Billing settings when `billingEnabled`, else does nothing | header 765–772 |
| Hosted / `NEXT_PUBLIC_STATUS_NOTICE_PREVIEW` | status notice polls; rendered only for indicator `major`/`critical`; preview forces "Major Service Outage" | 1849–1851, status-notice 585–624 |
| Desktop executor registered (desktop app or `desktopExecutor.registered`) | chat rows show a desktop activity dot (`running` `#EAB308`, `needs_input` `--warning`, `blocked` `--text-error`) with tooltip; polls `GET /api/desktop/…` activity | 189–218, 912–925 — desktop-only; web shows nothing unless the user registered a desktop |
| On `/workspace/{id}/settings/*` | nav, sections, status and footer are replaced by `SettingsSidebar` (Phase 5); header stays | 1082, 1488–1492 |
| Collapsed | see Layout | |
| Peeking (desktop shell) | rendered expanded, no lane, no handle | 400–401, 1390, 1916 |
| Presence | avatars appear on the workflow row of the joined workflow only, excluding own socket; `maxVisible = clamp(4 + floor((renderedSidebarWidth − 224) / 20), 4, 12)` | avatars 13–54 |

## Interactions

| Interaction | Behaviour | Source |
|---|---|---|
| Click Search chip | `useSearchModalStore.open()` (palette; other spec) | 1463 |
| Click Collapse chip / collapsed expand chip | `onToggle` from the chrome (writes cookie) | 1477, header 452 |
| Click workspace chip | opens switcher; on open refetches stale `['workspace','list']` and `['invitations','mine']` | header 479–498 |
| Right-click workspace chip | workspace context menu for the active workspace | header 504–508 |
| Switcher row click | `onWorkspaceSwitch`: close menu → `requestLeave` (settings dirty guard) → `switchToWorkspace(id)` (registry) + `router.push(resolveWorkspaceSwitchHref)`: `/workspace/{target}` or, from `/workspace/{cur}/settings/{section}/…`, `/workspace/{target}/settings/{section}` | sidebar 1192–1205; management 36–51, 132–153 |
| Switcher row Cmd/Ctrl-click or middle-click | `window.open('/workspace/{id}','_blank')` | header 713–725 |
| Switcher keyboard | `ArrowDown`/`ArrowUp` cycle (wrap) the highlighted row; typing filters by case-insensitive substring; `Enter` switches to the highlighted row only after keyboard navigation began; `mousemove` re-targets the highlight and exits keyboard mode; highlighted row scrolls into view | header 229–256, 559–583, 622–629 |
| Switcher closes | search text, highlight and keyboard mode reset; a pending inline rename is saved if changed | header 267–272, 301–309 |
| "New workspace" | closes switcher, opens `CreateWorkspaceModal` | header 745–759 |
| "Invite teammates" | closes switcher, opens `InviteModal` (or billing redirect) | header 763–777 |
| "View invitations" | closes switcher, opens `ViewInvitationsModal` | header 779–784 |
| Workspace menu → Rename | switcher reopens/stays with the row as `SidebarRenameRow`, input focused + selected; `Enter` saves (trimmed), `Escape` cancels, blur saves if changed; disabled while saving | header 359–367, 631–680 |
| Workspace menu → Pin/Unpin | optimistic toggle; row moves to/from the pinned group; switcher stays open | header 397–402; workspace.ts 213–280 |
| Workspace menu → Upload logo | triggers the hidden `<input type=file accept="image/png,image/jpeg,image/jpg,image/gif,image/svg+xml,image/webp">`; validation: ≤5 MB and one of those types, else `onError` (logged only, no toast); upload via signed session (`purpose: 'workspace_logo'`), then `PATCH /api/workspaces/[id] {logoUrl: path}` | sidebar 1220–1227, 1366–1372; logo-upload 300–346; logo-file 1–24 |
| Workspace menu → Delete | closes switcher, opens `DeleteModal itemType='workspace'`; on confirm `DELETE`, then if it was the current workspace switch to the first remaining one | header 372–381, 436–445; management 172–196 |
| Workspace menu → Leave | `ChipConfirmModal` "Leave workspace"; on error `toast.error("Couldn't leave workspace", {description})` | header 386–395, 412–431, 867–883 |
| Nav row click | navigation (`ChipLink`); the "New workflow" variant calls `createWorkflow` unless Ctrl/Meta/Shift | nav-chip 434–441 |
| Nav row right-click | nav context menu (Open in new tab / Copy link) | sidebar 1507–1515, 1865–1872 |
| Section title click | toggles the section body (local state, not persisted); chevron rotates −90° | section 519–523, 551–557 |
| Chat row click | selects it (`selectChatOnly`) and navigates; `Shift`+click toggles / range-selects without navigating (`preventDefault`); Ctrl/Meta leave the browser default | chat-navigation-link 511–532; use-chat-selection 22–41 |
| Chat row hover ≥80 ms / focus / pointerdown | prefetches the chat history query (`mothershipChatHistoryQueryOptions`) once per uncached chat | chat-navigation-link 380, 441–463 |
| Chat row drag | HTML5 drag with `application/x-sim-resources` payload `[{type:'task', id, title}]`, `effectAllowed='copyMove'`, custom ghost pill (`surface-active` fill, `border 1px rgba(255,255,255,.08)`, radius 8, 13px, 4px 10px padding, 14px leading circle for tasks, `box-shadow 0 4px 12px rgba(0,0,0,.4)`) removed on dragend | sidebar 259–276; utils 119–173 |
| Chat row "…" / right-click | chat context menu (see above) | 687–728 |
| Chat menu → Rename | inline rename row in place (`useFlyoutInlineRename`): input focused+selected; `Enter` saves, `Escape` cancels, blur saves; no-op if empty or unchanged; failure restores the old name | 1043–1051, 1591–1609; flyout-rename 61–132 |
| Chat menu → Delete | `DeleteModal itemType='task'` (title "Delete chat"/"Delete chats", single confirm is the default action); on success clears selection and, if the open chat was deleted, `router.push('/workspace/{id}/home')` | 954–996, 1901–1908 |
| "See more"/"See less" | visible chat count +5 / reset to 5 | 998, 1260–1261 |
| "New workflow" button / `Mod+Shift+P` | `createWorkflow` (optimistic navigation to the new workflow) then dispatches `sidebar-scroll-to-item` for it | 1170–1177; use-workflow-operations 26–47 |
| "More actions" menu | "Import workflow" (opens hidden `<input type=file accept=".json,.zip" multiple>`; label "Importing..." while busy) / "Create folder" ("Creating folder..." while busy) | 1697–1739, 1373–1380 |
| `sidebar-scroll-to-item` window event `{itemId}` | up to 10 rAF retries to find `[data-item-id=…]`; if outside the scroll region, `scrollIntoView({behavior:'smooth', block:'center'})`; dispatched once for the URL workflow after the list loads | 468–497, 1160–1168 |
| Click sidebar background (not a control/link/input) | selects the current workflow only or clears all selection | 1207–1211; utils 74–82 |
| Hover a rail chip (collapsed) | flyout opens immediately; closes 150 ms after the pointer leaves both chip and menu unless locked (context menu open or inline rename) | use-hover-menu 2, 712–768 |
| `Enter` on a rail nav chip with flyout | activates the link instead of toggling the menu | collapsed-sidebar-menu 209–213 |
| Profile menu items | Settings (general) / Teammates / Recently deleted / Billing (gated) / Organization: `requestLeave` → `rememberSettingsReturnUrl(href)` (sessionStorage `settings-return-url`, only when entering settings from inside the same owner surface) → navigate | footer 216–241; settings-return 8–15 |
| Sign out | `requestLeave` → `signOutAndRedirect(router.push)` (see `global-behaviours.md`) | footer 242–253 |
| Help menu | Docs → `window.open(DOCS_URL)` + PostHog `docs_opened`; Join Slack → `window.open(SLACK_COMMUNITY_URL)` + `slack_community_opened`; Contact support → opens `HelpModal`; also opened by the window event `open-help-modal` | 1275–1285, 461–465 |
| Global commands registered here | `add-agent`, `goto-logs`, `open-search`, `add-workflow`, `toggle-sidebar` (details in `global-behaviours.md`) | 1308–1362 |
| Focus order (expanded) | workspace chip → Search → Collapse → nav rows → section toggles/rows → Workflows "More" → "New workflow" → tree → profile → help → resize handle | DOM order |

### Help modal (`shell.sidebar.help-modal`, help-modal 118–365)
`ChipModal size='md'` (500px) `srTitle='Contact support'`; header "Contact support" with close; body `max-h-[60vh]` scrolls; fields (each a `ChipModalField`): "Request" dropdown (Bug report `bug` default / Feedback `feedback` / Feature request `feature_request` / Other `other`, placeholder "Select a request type"); "Subject" input placeholder "Brief description of your request"; "Message" textarea `rows={6}` placeholder "Please provide details about your request..."; "Attach images (optional)" file drop zone (label "Drop images here or click to browse", description "PNG, JPEG, WebP, GIF (max 20MB each)", `accept` jpeg/jpg/png/webp/gif, multiple); when images exist a custom field "Uploaded images" with a `grid grid-cols-2 gap-3` of previews (`rounded-sm border`, image box `max-h-[120px] min-h-[80px] object-contain`, hover overlay `bg-black/50` with white `X` 18px "Remove image", filename `truncate p-1.5 text-caption`). Footer: Cancel (disabled while submitting) + primary "Submit" / "Submitting..." / "Error" / "Success" (success label resets after 2000 ms; form resets and previews are revoked on success). Validation (zod, on submit): subject and message required ("Subject is required" / "Message is required"); type enum. Files > 20 MB or wrong type are rejected silently (the whole batch is dropped when any file fails); files ≥ 2 MB (not GIF) are compressed client-side to ≤2 MB, max 1920px, quality 0.8 — a Flutter equivalent may use any image codec; parity is by review. Submit: `POST /api/help` multipart `subject, message, type, workspaceId?, userAgent, workflowId?, image_0…` (`!response.ok` → `{error}` message). Opening resets status and form; closing revokes previews.

## Network and realtime

In addition to the shell calls in `workspace-chrome.md` §Network (host-context, permissions, profile, workspaces, workflows, folders, chats, permission config), the sidebar issues:

| Trigger | Request | Key / staleTime | After |
|---|---|---|---|
| Mount | `POST /api/workspaces/[id]/visit` | mutation `['workspace','record-visit']`, serialised (`scope: 'workspace-visit'`); optimistic move to the front of the list cache | invalidate `['workspace','list']` once no later visit is queued (`workspace.ts:156–186`) |
| Mount (hosted) | `GET https://status.sim.ai/api/v2/status.json` | `['status-page','summary','sim']`, 30 s, poll 60 s, retry 0 | — |
| Mount (chat on) | `GET /api/mothership/chats?workspaceId=&scope=active` → `{success:true, data:[{id,title,mode,updatedAt,activeStreamId,lastSeenAt,pinned,deletedAt,…}]}` mapped to `{id, name: title ?? 'New chat', isActive: activeStreamId!==null, isUnread: activeStreamId===null && (lastSeenAt===null || updatedAt>lastSeenAt), isPinned, updatedAt}` | `['mothership-chats','list',ws,'active']`, 60 s, `keepPreviousData` | — |
| Mount (chat on) | SSE `GET /api/mothership/events?workspaceId=` (rotating `EventSource`; `task_status` events invalidate the chat list) | — | — |
| Mount | socket join `workspace-workflows:{ws}`; on `workspace-workflows-changed` invalidate workflow lists (active, archived) + folders (active, archived) | — | — |
| Mount (desktop executor) | `useDesktopActivity` polling (`hooks/queries/desktop-activity.ts`) | `desktopActivityKeys.list(ws)` | desktop only |
| Switcher open | refetch stale `['workspace','list']` and `['invitations','mine']` | — | — |
| Switcher content mounted | `GET /api/invitations` → `MyInvitation[]` | `['invitations','mine']`, 30 s | shows "View invitations" when non-empty |
| Pin / unpin workspace | `POST /api/pinned-items {workspaceId, resourceType:'workspace', resourceId}` / `DELETE /api/pinned-items/workspace/{id}`; 409 (already pinned) / 404 (already unpinned) treated as success; optimistic `pinnedWorkspaceIds` update, undone on error | mutation `['workspace','toggle-pin']` serialised | invalidate `['workspace','list']` when last in queue |
| Rename workspace | `PATCH /api/workspaces/[id] {name: trimmed}` | — | invalidate `['workspace','list']`, `['workspace','detail',id]` (`workspace.ts:352–365`) |
| Upload logo | `POST /api/files/uploads` (create session, `purpose:'workspace_logo', workspaceId`) → signed `PUT` (`transfer.method === 'put'`) or multipart parts `POST /api/files/uploads/[uploadId]/parts` + `POST …/complete`; `DELETE /api/files/uploads/[uploadId]` on abort; `MAX_RETRIES = 3` with `backoffWithJitter`; then `PATCH /api/workspaces/[id] {logoUrl: result.path}` | — | as rename |
| Delete workspace | `DELETE /api/workspaces/[id]` body `{}` | — | `onSettled` invalidate lists + detail; then switch |
| Leave workspace | `DELETE /api/workspaces/members/[userId]` body `{workspaceId}` | — | invalidate permissions(ws), lists, detail(ws) (`invitations.ts:400–425`) |
| Create workspace | see `workspace-modals.md` | | |
| Chat rename | `PATCH /api/mothership/chats/[chatId] {title}` (optimistic, rollback on error) | — | invalidate owner lists |
| Chat pin | `PATCH /api/mothership/chats/[chatId] {pinned}` (optimistic) | — | invalidate owner lists |
| Chat mark unread | `PATCH /api/mothership/chats/[chatId] {isUnread:true}` (optimistic) | — | invalidate |
| Chat mark read | `POST /api/mothership/chats/read` (optimistic) | — | invalidate |
| Chat delete (single / many) | `DELETE /api/mothership/chats/[chatId]` (one per id; `MothershipChatDeleteError.deletedChatIds` reports partial success) | — | invalidate `mothershipChatKeys.ownerLists(ws)` |
| Chat hover | prefetch chat history (Phase 4 query) | — | — |
| New workflow | `POST /api/workflows` (`hooks/queries/workflows.ts:184`) then `router.push('/workspace/{ws}/w/{id}')` | — | invalidate workflow lists; scroll-to-item |
| Create folder | `POST /api/folders {name, workspaceId, resourceType:'workflow', …}` | — | invalidate `folderKeys.list(ws,'active','workflow')`; scroll-to-item |
| Import workflow | `.json` files / one `.zip` → import endpoints (`app/workspace/[workspaceId]/w/hooks/use-import-workflow.ts`; Phase 2 detail) | — | invalidate workflow lists + folders |
| Help | `POST /api/help` multipart | — | — |
| Presence | socket `join-workflow-success` / `presence-update` / cursor deltas → `usePresenceStore.presenceUsers` (`{socketId,userId,userName,avatarUrl?,cursor?,selection?}`), cleared on leave | — | consumed by `Avatars` |

## Parity checklist

| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | `sidebar.tsx:1397–1401` | header row: 8px top padding, 8px side gutters, 30px chips | | |
| 2 | layout | `workspace-header.tsx:501–519` | switcher chip hugs content, max full width, tile 16px + name + chevron, 6px gaps | | |
| 3 | layout | `sidebar.tsx:1443–1450` | trailing cluster exactly 65px wide expanded (32 + 1 + 32), 0 collapsed | | |
| 4 | layout | `sidebar.tsx:1498–1505` | nav block 16px below header, rows 30px with 1px gaps, 8px bottom padding, 1px rule | | |
| 5 | layout | `sidebar-nav-chip.tsx:422–449` | nav rows full width, 16px icon, label, Lock on the right when restricted | | |
| 6 | layout | `sidebar.tsx:1518–1527` | scroll region `pt-2 pb-2` with 12px edge fades only when scrollable | | |
| 7 | layout | `sidebar-section.tsx:534,572` | section title row 18px, `px-4`, body offset 6px | | |
| 8 | layout | `sidebar-section.tsx:551–557` | chevron 14px, hidden until the section is hovered, rotates −90° when closed | | |
| 9 | layout | `sidebar.tsx:1656,1693`, `constants.ts:10` | 16px between sections | | |
| 10 | layout | `sidebar.tsx:1574` | "No chats yet" row 30px, 8px padding, muted 13px | | |
| 11 | layout | `sidebar.tsx:1696–1764` | Workflows actions: two 20px quiet icon buttons, 8px apart, 16px right inset | | |
| 12 | layout | `sidebar-footer.tsx:322–337` | footer `pt-[9px] pb-2 px-2`, 1px top rule; profile left, help hard right | | |
| 13 | layout | `sidebar-footer.tsx:148–164` | avatar 16px round; initial 9px white on user colour | | |
| 14 | layout | `sidebar-footer.tsx:326` | collapsed footer stacks help above profile with 1px gap | | |
| 15 | layout | `constants.ts:50` | collapsed rows are 32px wide, glyph centred at x=24 | | |
| 16 | layout | `workspace-header.tsx:449–475` | collapsed header chip shows the tile, swaps to a flipped PanelLeft on hover | | |
| 17 | layout | `workspace-header.tsx:521–529` | switcher menu 256px wide, `sideOffset` 8, below the chip, aligned to its start | | |
| 18 | layout | `workspace-header.tsx:588–598` | switcher list capped at 200px, rows 30px, 2px gaps | | |
| 19 | layout | `collapsed-sidebar-menu.tsx:262–267` | rail flyouts 220px wide, to the right, 8px offset, 28px rows | | |
| 20 | layout | `status-notice.tsx:596–614` | status card: rounded 12, 8px padding, icon+text line, full-width "View status" chip | | |
| 21 | layout | `presence-avatars.tsx:89–110`, `avatars.tsx:38–43` | 14px avatars overlapping by 4px; 4 visible at 224px, +1 per 20px of width, max 12; "+N" chip for overflow | | |
| 22 | token | `sidebar.tsx:1383` | S1 = `--surface-1` | | |
| 23 | token | `chip/chrome.ts:83,85` | S2 hover = `--surface-hover`; S4 active = `--surface-active`; active rows ignore hover | | |
| 24 | token | `identity-tile.tsx:63` | S3 tile = `--surface-6` | | |
| 25 | token | `sidebar.tsx:1503–1504`, `sidebar-footer.tsx:324–325` | S5/S6 rules are `--border` only while content is hidden past that edge; S7 otherwise invisible | | |
| 26 | token | `sidebar.tsx:313` | S8 unread dot `--brand-accent`; active dot `#EAB308` | | |
| 27 | token | `dropdown-menu/styles.ts:10–21` | S9 menu surface `--bg`, 1px `--border`, radius 12, `shadow-medium`, 4px padding | | |
| 28 | token | `tooltip/styles.ts:5–6` | collapsed tooltips: `--bg` surface, `--border`, caption text, radius 8 | | |
| 29 | state | `sidebar.tsx:762–771` | chat on → "New chat" (Home icon, link); chat off → "New workflow" (Plus, button) | | |
| 30 | state | `sidebar.tsx:778,786,846` | Dashboard / Changelog / Tests rows appear only with their flags | | |
| 31 | state | `sidebar.tsx:768–771,778–797,822–847` | hidden vs restricted-with-Lock per the permission-group config and access-requests availability | | |
| 32 | state | `sidebar.tsx:1529` | Chats section absent when chat disabled or `hideCopilot` | | |
| 33 | state | `sidebar.tsx:1583,1630–1645` | 5 chats visible by default; "See more" adds 5; "See less" resets | | |
| 34 | state | `sidebar.tsx:1705,1749,1726–1736` | read-only member: create/import/folder actions disabled | | |
| 35 | state | `workspace-header.tsx:761` | "Invite teammates" only for admins | | |
| 36 | state | `workspace-header.tsx:744–760` | "New workspace" disabled with the policy reason tooltip when `canCreate` is false | | |
| 37 | state | `workspace-header.tsx:213,546` | search field in the switcher only with ≥6 workspaces | | |
| 38 | state | `workspace.ts:115–119` | pinned workspaces listed first, then server order | | |
| 39 | state | `workspace-header.tsx:790–819` | loading switcher is a same-size disabled chip with skeleton tile | | |
| 40 | state | `sidebar-footer.tsx:148–149,211` | profile skeletons: 16px circle + 96×14 bar | | |
| 41 | state | `status-notice.tsx:623–625` | notice only for `major`/`critical`; never on self-hosted | | |
| 42 | state | `sidebar.tsx:1849` | status notice hidden while collapsed | | |
| 43 | state | `sidebar.tsx:1082,1488` | on `/settings/*` the body switches to the settings sidebar (Phase 5), header unchanged. *Deferred (recorded 2026-10-22, review v1 finding 29): not implemented in Phase 1; the settings sidebar arrives with Phase 5.* | | |
| 44 | state | `avatars.tsx:49–52` | presence shown only for the joined workflow, own socket excluded | | |
| 45 | interaction | `workspace-header.tsx:479–498` | opening the switcher refetches stale workspace list and invitations; focuses search | | |
| 46 | interaction | `workspace-header.tsx:559–583` | ArrowUp/Down wrap; Enter switches only after keyboard nav | | |
| 47 | interaction | `use-workspace-management.ts:36–51` | switching from a settings section lands on the same section in the target workspace | | |
| 48 | interaction | `workspace-header.tsx:713–725` | Cmd/Ctrl/middle click on a workspace row opens a new tab | | |
| 49 | interaction | `workspace-header.tsx:631–680` | inline workspace rename: focus+select, Enter saves, Escape cancels, blur saves when changed | | |
| 50 | interaction | `workspace.ts:213–280` | pin toggle is optimistic, serialised, tolerant of 409/404 | | |
| 51 | interaction | `use-workspace-logo-upload.ts:316–346`, `logo-file.ts:16–23` | logo: 5 MB / type validation, preview, session upload, PATCH with the returned path, revert on failure | | |
| 52 | interaction | `use-workspace-management.ts:172–196` | deleting the current workspace switches to the next one | | |
| 53 | interaction | `workspace-header.tsx:412–431` | leave failure shows the server reason as a toast; modal stays open | | |
| 54 | interaction | `chat-navigation-link.tsx:511–532` | Shift+click selects without navigating; plain click selects and navigates | | |
| 55 | interaction | `chat-navigation-link.tsx:380,457–463` | 80 ms hover dwell prefetches the chat history once. *Deferred (recorded 2026-10-22, review v1 finding 29): the chat history query is Phase 4.* | | |
| 56 | interaction | `sidebar.tsx:259–276`, `utils.ts:119–173` | chat drag payload and ghost pill. *Deferred (recorded 2026-10-22, review v1 finding 29): chat drag targets (the chat composer) are Phase 4.* | | |
| 57 | interaction | `sidebar.tsx:674–696,1874–1899` | chat context menu items and gating; multi-selection acts on all | | |
| 58 | interaction | `use-flyout-inline-rename.ts:79–132` | chat inline rename semantics (no-op when unchanged, restore on failure) | | |
| 59 | interaction | `sidebar.tsx:962–996` | deleting the open chat navigates home | | |
| 60 | interaction | `sidebar.tsx:614–642`, `nav-item-context-menu.tsx:383–400` | nav right-click: Open in new tab / Copy link (absolute URL) | | |
| 61 | interaction | `use-hover-menu.ts:2,712–722` | rail flyout opens on hover, closes 150 ms after leaving, stays while a context menu/rename is open | | |
| 62 | interaction | `collapsed-sidebar-menu.tsx:209–213` | Enter on a rail nav chip navigates instead of opening the flyout | | |
| 63 | interaction | `rail-resource-flyout.tsx:615–617` | Tables/Files flyouts wait for both the list and its folders before rendering rows | | |
| 64 | interaction | `sidebar.tsx:468–497,1160–1168` | current workflow scrolled into view (centre) once after load; new items scrolled into view | | |
| 65 | interaction | `sidebar.tsx:1207–1211` | background click selects the current workflow / clears selection | | |
| 66 | interaction | `sidebar-section.tsx:519–523` | section collapse is per-session UI state, not persisted | | |
| 67 | interaction | `sidebar-footer.tsx:216–253`, `components/settings/navigation.ts:448, 474, 665` | profile menu in the settings registry order: Settings, [Subscription], Teammates, Recently deleted, [Organization], Sign out (not for the anonymous principal `ANONYMOUS_USER_ID`); each goes through the dirty guard. *Corrected 2026-10-22 (review v1 finding 29): the earlier row put Billing after Recently deleted and showed Sign out to the anonymous principal.* | | |
| 68 | interaction | `sidebar-footer.tsx:292–317` | help menu: Docs, Join Slack, Contact support; anchored to the chip's end edge (start when collapsed) | | |
| 69 | interaction | `help-modal.tsx:246–361` | help modal fields, validation, multipart POST, success/error labels | | |
| 70 | keyboard | `sidebar.tsx:1456,1472` | tooltips show `⌘K`/`⌘B` on macOS and `Ctrl+K`/`Ctrl+B` elsewhere | | |
| 71 | keyboard | `sidebar.tsx:1758` | "New workflow" tooltip shows `⌘⇧P` / `Ctrl+Shift+P` | | |
| 72 | network | `workspace.ts:156–186` | visit recorded on mount, optimistic reorder, list invalidated once | | |
| 73 | network | `use-workspace-workflows-room.ts:22–29` | realtime invalidation of workflow + folder lists | | |
| 74 | network | `invitations.ts:155–160` | `/api/invitations` fetched when the switcher content mounts, 30 s stale | | |
| 75 | network | `mothership-chats.ts:301–315` | chat list mapping (`New chat` fallback, unread rule) | | |
