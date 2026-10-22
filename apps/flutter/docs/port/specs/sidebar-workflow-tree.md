# Sidebar: Workflows tree
Upstream: `apps/sim/app/workspace/[workspaceId]/w/components/sidebar/` (the "Workflows" `SidebarSection` of `sidebar.tsx` and `components/workflow-list/**`), commit `27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c`
Phase: 1

Scope: the Workflows section header and its actions, the folder/workflow tree (expanded rail), the collapsed-rail flyout variant, inline rename, context menus, drag and drop, duplicate, delete, restore, selection, and the data layer behind them. The sidebar shell (resize, collapse, hover-peek, header chips) and the Chats/Workspace sections are covered by `workspace-chrome.md` and `workspace-sidebar.md`; the search palette and the workspace switcher have their own specs (`search-palette.md`, `workspace-switcher.md`). All paths below are relative to `apps/sim/` unless they start with `packages/`.

## Files

React (sidebar folder `app/workspace/[workspaceId]/w/components/sidebar/`):
| File | Lines | Role |
|---|---|---|
| `sidebar.tsx` | 1958 | Workflows section (1690–1845), header actions (1694–1766), collapsed flyout (1768–1827), create handlers (1170–1184), scroll-to-item event (365, 468–497, 1160–1168), background-click selection reset (1207–1211), global commands (1308–1362), collapsed root ordering (559–603), flyout rename (1006–1015, 1062–1075) |
| `components/workflow-list/workflow-list.tsx` | 619 | Tree renderer, drop zones, indicators, empty-area menu, selection order lists |
| `components/workflow-list/components/folder-item/folder-item.tsx` | 625 | Folder row |
| `components/workflow-list/components/workflow-item/workflow-item.tsx` | 515 | Workflow row |
| `components/workflow-list/components/workflow-item/avatars/avatars.tsx` | 55 | Presence avatars on the active workflow row |
| `components/workflow-list/components/context-menu/context-menu.tsx` | 456 | Shared row context menu (also used by chats and workspaces) |
| `components/workflow-list/components/delete-modal/delete-modal.tsx` | 241 | Delete confirmation |
| `components/workflow-list/components/empty-area-context-menu/empty-area-context-menu.tsx` | 87 | Right-click on empty tree area |
| `components/nav-item-context-menu/nav-item-context-menu.tsx` | 65 | Nav chip menu (Open in new tab / Copy link); not used by tree rows |
| `components/collapsed-sidebar-menu/collapsed-sidebar-menu.tsx` | 575 | Rail flyout: `CollapsedSidebarMenu`, `CollapsedWorkflowFlyoutItem`, `CollapsedFolderItems` |
| `components/sidebar-section/sidebar-section.tsx` | 108 | Section header + collapsible body |
| `components/sidebar-row-actions.tsx` | 20 | 18px row action button |
| `components/sidebar-rename-row.tsx` | 39 | Rename row (used by workspace switcher, not the tree) |
| `constants.ts` | 65 | Spacing classes |
| `utils.ts` | 172 | `compareByOrder`, `interleaveSiblings`, `groupWorkflowsByFolder`, `createSidebarDragGhost`, `buildDragResources`, `isSidebarBackgroundClick` |
| `hooks/use-drag-drop.ts` | 820 | DnD state machine |
| `hooks/use-item-drag.ts` | 58 | Per-row drag state, invisible default drag image |
| `hooks/use-item-rename.ts` | 138 | Inline rename state |
| `hooks/use-flyout-inline-rename.ts` | 116 | Rename inside the collapsed flyout |
| `hooks/use-folder-expand.ts` | 55 | Expand/collapse + Enter/Space |
| `hooks/use-folder-selection.ts` | 162 | Folder multi-select |
| `hooks/use-workflow-selection.ts` | 100 | Workflow multi-select |
| `hooks/use-sidebar-list-context.ts` | 93 | Context shared by rows |
| `hooks/use-folder-operations.ts` | 51 | Root "Create folder" |
| `hooks/use-workflow-operations.ts` | 57 | Workflow list + "New workflow" |
| `hooks/use-hover-menu.ts` | 111 | Rail flyout hover (150 ms close delay) |
| `hooks/use-workspace-workflows-room.ts` | 29 | Realtime invalidation room |

Shared hooks / stores / lib:
| File | Lines | Role |
|---|---|---|
| `hooks/use-context-menu.ts` | 93 | Position + outside-click close |
| `hooks/use-resource-list-preferences.ts` | 238 | **Not used by the tree** (sort/filter preferences for resource tables); listed because the brief named it. The tree has no sort/filter preference |
| `stores/folders/store.ts` | 293 | `expandedFolders`, `selectedWorkflows`, `selectedFolders`, `selectedChats` (in-memory, `devtools` only, not persisted) |
| `stores/folders/types.ts` | 30 | `WorkflowFolder`, `FolderTreeNode` |
| `stores/workflows/registry/store.ts` | 427 | `markWorkflowCreating`/`markWorkflowCreated`, `switchToWorkspace` |
| `stores/workflows/registry/types.ts` | 67 | `WorkflowMetadata` (13–26) |
| `stores/workflows/registry/utils.ts` | 216 | `generateCreativeWorkflowName` |
| `hooks/queries/folders.ts` | 459 | Folder queries + mutations |
| `hooks/queries/workflows.ts` | 708 | Workflow queries + mutations |
| `hooks/queries/utils/folder-keys.ts` | 51 | `folderKeys`, `FOLDER_LIST_STALE_TIME`, `mapFolder` |
| `hooks/queries/utils/workflow-keys.ts` | 22 | `workflowKeys` |
| `hooks/queries/utils/workflow-list-query.ts` | 49 | `WORKFLOW_LIST_STALE_TIME`, `mapWorkflow` |
| `hooks/queries/utils/invalidate-workflow-lists.ts` | 25 | `invalidateWorkflowLists` |
| `hooks/queries/utils/top-insertion-sort-order.ts` | 44 | `getTopInsertionSortOrder` |
| `hooks/queries/utils/folder-tree.ts` | 161 | Lock inheritance helpers |
| `hooks/queries/utils/workflow-cache.ts`, `folder-cache.ts` | 48, 26 | Cache readers |
| `lib/folders/tree.ts` | 103 | `buildFolderTree`, `getFolderPath`, `getFolderPathNames` |
| `lib/api/contracts/folders.ts` | 225 | Folder contracts |
| `lib/api/contracts/workflows.ts` | 996 | Workflow contracts (list 691–701, create 781–789, duplicate 791–800, update 802–813, delete 815–823, reorder 825–835, restore 837–845) |
| `lib/workspaces/naming.ts` | 66 | `generateFolderName`, `generateSubfolderName` |
| `app/workspace/[workspaceId]/w/hooks/use-can-delete.ts` | 128 | Last-workflow guard |
| `.../w/hooks/use-delete-workflow.ts`, `use-delete-folder.ts`, `use-delete-selection.ts` | 137, 70, 169 | Delete flows |
| `.../w/hooks/use-duplicate-workflow.ts`, `use-duplicate-folder.ts`, `use-duplicate-selection.ts` | 110, 118, 155 | Duplicate flows |
| `.../w/hooks/use-export-workflow.ts`, `use-export-folder.ts`, `use-export-selection.ts` | 136, 197, 217 | Export (download) flows — behaviour out of scope here except the menu item |
| `app/workspace/[workspaceId]/components/presence/presence-avatars.tsx` | 113 | Avatar stack |
| `app/workspace/[workspaceId]/components/resource/selection-label.ts` | 43 | `selectionActionLabel` |
| `lib/core/utils/context-menu.ts` | 10 | `getContextMenuPosition` |
| `app/_styles/globals.css` | — | `.sidebar-container` rules 578–626 |

emcn components used (`packages/emcn/src/components/`): `chip/chip.tsx` (`chipVariants` 65–95), `chip/chrome.ts` (`chipGeometryUnroundedClass` 58, `chipRadiusClass` 19, `chipContentIconClass` 68, `chipHoverSurfaceClass` 83, `chipActiveSurfaceClass` 85, `disclosureChevronClass` 110–111), `row-actions/row-actions.tsx`, `dropdown-menu/dropdown-menu.tsx` + `styles.ts` (`MENU_STYLES`), `popover/popover.tsx` (size `sm`), `overflow-text/overflow-text.tsx`, `avatar/avatar.tsx` (size `xs` = 14 px, line 15), `tooltip/tooltip.tsx` (`Tooltip.Shortcut` 700–703), `expandable/expandable.tsx`, `scroll-fade/*`, `button/button.tsx` (`variant='quiet' size='icon'` = 20 px, line 55), `chip-modal/chip-modal.tsx` (`ChipConfirmModal`). Icons from `packages/emcn/src/icons`: `ChevronRight`, `Folder`, `FolderOpen`, `Lock`, `Unlock`, `MoreHorizontal`, `Plus`, `FolderPlus`, `Upload`, `Workflow`, `Pencil`, `Duplicate`, `Download`, `Trash`, `SquareArrowUpRight`, `ChevronDown`.

## Layout

All measurements are from Tailwind classes; px values assume the 4 px spacing scale and `1rem = 16px`.

### Section ("Workflows")
`sidebar.tsx:1690–1693` → `SidebarSection title='Workflows' className='mt-4 workflows-section relative'` (`SIDEBAR_SECTION_GAP_CLASS` = `mt-4` = 16 px, `constants.ts:10`).
- Header row (`sidebar-section.tsx:65`): `h-[18px]` (18 px), full width; title area `flex h-full min-w-0 flex-1 items-center gap-2 px-4` (16 px gutters, line 13). Title: `OverflowText` `text-caption` (12 px) `text-[var(--text-muted)]`, class `sidebar-collapse-hide` (line 56–61). Toggle button (`aria-expanded`) with `ChevronDown` 14 px `disclosureChevronClass`, `opacity-0`, visible on `group-hover/section` or focus-visible (82–87); rotates `-rotate-90` when collapsed. Collapsing only hides this section's body; state is local `useState(true)` (line 50) and not persisted.
- Action cluster (`sidebar-section.tsx:92`): `flex shrink-0 items-center pr-4`; contents from `sidebar.tsx:1696–1764`: `div.flex.items-center.justify-center.gap-2` holding (1) `DropdownMenuTrigger` → `Button variant='quiet' size='icon' aria-label='More actions'` (20 × 20 px, `rounded-sm` 4 px, icon `MoreHorizontal` 14 px; `Loader` 16 px while `isImporting || isCreatingFolder`, 1707–1711) and (2) `Button variant='quiet' size='icon' aria-label='New workflow'` with `Plus` 16 px (1742–1752). Both `disabled` when `!permissionsLoading && !canEdit` (1705, 1749); Plus also disabled while `isCreatingWorkflow`.
- Tooltips: "More actions" (1715–1717); "New workflow" with `Tooltip.Shortcut keys='⌘⇧P' | 'Ctrl+Shift+P'` (1758–1760) or "Creating workflow..." (1756).
- "More actions" menu (1719–1738): `DropdownMenuContent align='start' sideOffset={8} className='min-w-[160px]'`; items `Upload` "Import workflow" / "Importing..." (disabled `!canEdit || isImporting`) and `FolderPlus` "Create folder" / "Creating folder..." (disabled `!canEdit || isCreatingFolder`). No separator. Menu rows are `MENU_STYLES.sizes.md` = 28 px, `text-small` 13 px, `rounded-lg`, `px-2`, gap 6 px (`styles.ts:14–17`); surface `rounded-xl border --border bg --bg shadow-medium`, `p-1` (11–13).
- Body (`sidebar-section.tsx:96–105`): `Expandable` (Radix Collapsible, `animate-none!` so it opens/closes in one frame) → `div.pt-1.5` (6 px) → children. Children for the expanded rail (`sidebar.tsx:1829–1843`): `div.px-2` (8 px) → `WorkflowList`.
- Loading gate: while `workflowsLoading && regularWorkflows.length === 0` the body renders nothing (1830).

### Tree container (`workflow-list.tsx:557–603`)
- `div[role=tree][aria-label=Workflows].flex.min-h-full.flex-col` (`data-empty-area`).
- Root drop zone: `div.relative.flex-1.rounded-sm` + `min-h-[26px]` when there are no root items (573).
- Root "inside" overlay: `absolute inset-0 z-10 rounded-sm bg-[var(--text-subtle)] opacity-10` when `dropIndicator.targetId==='root' && position==='inside' && isDragging`, else `hidden` (577–582).
- Edge drop zones while dragging and root has items: `absolute top-0 inset-x-0 z-30 h-[12px]` (before first root item) and `absolute bottom-0 inset-x-0 z-30 h-[12px]` (after last) (583–601).
- Item list: `div.space-y-0.5` (2 px between root rows, 589).

### Rows
- Row height: every row is a chip pill: `chipVariants({ fullWidth: true })` → `group cursor-pointer h-[30px] items-center gap-1.5 px-2 text-left text-sm rounded-lg flex w-full` (`chip.tsx:65–95`, `chrome.ts:58,19`). 30 px tall, 8 px horizontal padding, 6 px gap, 14 px text, 8 px radius. Sidebar `aside` sets `[&_.group.cursor-pointer]:duration-0` so hover/active fills switch instantly (`sidebar.tsx:1383`).
- Indentation: wrapper `style={{ paddingLeft: level * 20 }}` (`TREE_SPACING.INDENT_PER_LEVEL = 20`, `workflow-list.tsx:27–29`, applied at 385 and 454). Level 0 = 0 px; each nested level adds 20 px to the row's left edge (the row's own `px-2` is inside that).
- Folder children container (`workflow-list.tsx:461–477`): rendered only when `isExpanded && (hasChildren || isDragging)`: `div.relative` (folder content drop zone) → vertical guide `absolute top-0 bottom-0 w-px bg-[var(--border)]` at `left: level*20 + 12` px (463–466) → `div.mt-0.5.space-y-0.5.pl-0.5` (2 px top margin, 2 px between children, 2 px left padding). Note: child rows therefore sit at `(level+1)*20 + 2` px from the parent container's left edge.
- Empty-folder drop zone (473–475): while dragging into an expanded folder with no children, a `div.h-[24px]` row-sized target.
- Drop indicator line (`DropIndicatorLine` 43–64): `absolute inset-x-0 z-20 pointer-events-none`, `top:-2px` (before) or `bottom:-2px` (after), `paddingLeft: level*20`; inner `h-[2px] rounded-full bg-[var(--text-subtle)]`.
- Folder "inside" overlay (447–452): `absolute inset-0 z-10 rounded-sm bg-[var(--text-subtle)] opacity-10` over the folder row wrapper while `showInside && isDragging`.

#### Folder row (`folder-item.tsx:498–576`)
`div[role=button][tabIndex=0][data-item-id=<folderId>][aria-expanded][aria-label='<name> folder, expanded|collapsed']` with `chipVariants({ active: isSelected || isContextMenuOpen, fullWidth: true }) + rowActionsGroupClass`, `opacity-50` while this row is dragging or any drag is active and the row is selected (507). Children in order:
1. `ChevronRight` `disclosureChevronClass` (14 px, `--text-icon`, `transition-[opacity,transform] duration-150`), `rotate-90` when expanded (516–519).
2. `FolderOpen` (expanded) or `Folder` (collapsed), `chipContentIconClass` = 16 px `--text-icon` (520–524).
3. Either the rename `<input>` (525–543; `min-w-0 flex-1 border-0 bg-transparent p-0 text-[var(--text-body)] text-sm`, `maxLength=50`, `disabled` while saving, autocomplete/autocorrect/autocapitalize/spellcheck off) or `div.flex.min-w-0.flex-1.items-center.gap-2` → (a) `div.flex.min-w-0.flex-1.items-center.gap-1` (double-click target) → `OverflowText label=name className='flex-1 text-[var(--text-body)]'` and (b) `RowActions` (552–573).
4. `RowActions` (`row-actions.tsx`): `size='sm'` → 18 × 18 px slot; `hidden` unless an indicator exists or the menu is open; reveals (`flex`) on row hover/focus-within when `revealOnHover` (= `!isAnyDragActive`). Indicator: `Lock` 14 px `--text-icon` (`role=img aria-label='Folder is locked'`) when `folder.locked` (own lock only; inherited lock shows no icon). Indicator fades to `opacity-0` on hover and the action layer (`SidebarRowAction` 18 × 18 px `rounded-sm`, `aria-label='Folder options'`, `MoreHorizontal` 16 px `--text-icon`) fades in (`row-actions.tsx:46–71`).
- No counts, no badges, no "running" indicator on folder rows (none exist in source).

#### Workflow row (`workflow-item.tsx:406–476`)
`Link[href=/workspace/{ws}/w/{id}][data-item-id=<workflowId>]` with `chipVariants({ active: active || isContextMenuOpen || (isSelected && selectedWorkflows.size > 1), fullWidth: true }) + rowActionsGroupClass`, `opacity-50` under the same drag rule (415), `draggable` unless editing / drag disabled / effectively locked (417). Children:
1. `div.min-w-0.flex-1` → `div.flex.min-w-0.items-center.gap-2` → rename `<input>` (426–443, `w-full min-w-0 border-0 bg-transparent p-0 text-[var(--text-body)] text-sm`, `maxLength=100`) **or** `div.min-w-0` (double-click target) → `OverflowText label=name className='block text-[var(--text-body)]'`; then `<Avatars workflowId>` when not editing (449).
2. `RowActions` (453–475) as on folders: indicator `Lock` 14 px (`aria-label='Workflow is locked'`) when `workflow.locked`; action `SidebarRowAction aria-label='Workflow options'` with `MoreHorizontal` 16 px.
- No leading icon on workflow rows (the row is text-first; the `Workflow` glyph is only used in the collapsed-rail chip and the palette).
- There is no deployed/running indicator on workflow rows in this file. (`isDeployed` is on `WorkflowMetadata` but is not rendered here.)

#### Presence avatars (`avatars.tsx`, `presence-avatars.tsx`)
- Rendered only for the workflow whose id equals `useSocket().currentWorkflowId` (i.e. the open workflow), excluding the viewer's own socket (`avatars.tsx:49–52`).
- `maxVisible = clamp(4 + floor((renderedSidebarWidth − 224) / 20), 4, 12)` (`avatars.tsx:13–17, 38–43`; `SIDEBAR_WIDTH.DEFAULT = 224`, `stores/constants.ts:163`).
- Stack: `div.-space-x-1.flex.shrink-0.items-center` (4 px overlap); each `Avatar size='xs'` = `size-3.5` (14 px), `zIndex = index+1`, visible users reversed so the rightmost stays stable (`presence-avatars.tsx:79–82, 88–111`). Fallback: `rounded-full border --border bg --surface-4`, user colour background (`getUserColor(userId)`), initial `text-[8px]` white `font-semibold`. Overflow chip: `+N` on `bg-gray-700 text-[7px]` with tooltip "N more user(s)". Name tooltip `side='bottom'` per avatar.

### Collapsed rail variant (`sidebar.tsx:1768–1827`, `collapsed-sidebar-menu.tsx`)
- Section header still 18 px (title faded via `.sidebar-container[data-collapsed] .sidebar-collapse-hide { opacity: 0 }`, `globals.css:624–626`); no action buttons (`action={isCollapsed ? undefined : …}`, 1694).
- Body: `div.px-2` → `CollapsedSidebarMenu icon=<Workflow 16px --text-icon> ariaLabel='Workflows' primaryAction={label:'New workflow'}`: trigger is a `Chip fullWidth leftAdornment={icon}` with `SIDEBAR_RAIL_CHIP_CLASS` = `group-data-[collapsed]/rail:w-[32px]` (`constants.ts:50`): 32 px wide chip centred in the 48 px rail (8 px gutters).
- Flyout: `DropdownMenuContent side='right' align='start' sideOffset={8} className='w-[220px]'` + `SIDEBAR_NO_MOTION_CLASS` (no animation) (262–267). Opens on hover (`useHoverMenu`: open immediately on trigger `mouseenter`, close after 150 ms once the pointer has left both trigger and content; `use-hover-menu.ts:3, 33–43`), `modal={false}`.
- Rows: `DropdownMenuItem` "New workflow" with `Plus` 14 px, then `DropdownMenuSeparator` (`mx-2 my-1 border-t --border`), then either `DropdownMenuItem disabled` "No workflows yet" (1779) or the root items interleaved by `compareByOrder` (`collapsedRootItems`, 569–603): folders → `CollapsedFolderItems`; workflows → `CollapsedWorkflowFlyoutItem`.
- `CollapsedFolderItems` (505–575): a folder with no children renders `DropdownMenuItem disabled` with its name; otherwise `DropdownMenuSub` whose `DropdownMenuSubTrigger` shows the name + `ChevronRight` 14 px `ml-auto`, and whose `DropdownMenuSubContent` (`max-w-[280px]`, no motion) lists `interleaveSiblings(folder.children, folderWorkflows)` recursively.
- `CollapsedWorkflowFlyoutItem` (370–480): `DropdownMenuItem asChild active={isCurrentRoute || actionsOpen} action=<DropdownMenuSub …>` wrapping `Link` → `OverflowText` name. The action is a `DropdownMenuItemAction` (18 px, `MoreHorizontal` 16 px) that opens a sub-menu with "Open in new tab" (`SquareArrowUpRight` 14 px) and "Rename" (`Pencil` 14 px, `disabled={!canRename}`). Right-click on the link opens that same sub-menu (`onContextMenu` → `setActionsOpen(true)`, 467–474). While editing, the row is replaced by `EDIT_ROW_CLASS` (`chipVariants({active:true, fullWidth:true}) min-w-0 cursor-default select-none text-small`) holding an `<input maxLength=100 text-small>` (388–415).
- Menu rows in the flyout are the default 28 px `text-small` rows (`MENU_STYLES.sizes.md`), max width 220 px for the root content and 280 px for sub-contents.

### Parity ids
Assign `data-parity` in the capture script via the selectors in the third column; Flutter uses `Semantics(identifier:)` with the same id.
| id | element | React selector |
|---|---|---|
| `sidebar.workflows.section` | section wrapper | `.workflows-section` |
| `sidebar.workflows.header` | 18 px header row | `.workflows-section > div:first-child` |
| `sidebar.workflows.header.title` | title text | `.workflows-section .sidebar-collapse-hide` |
| `sidebar.workflows.header.more` | More actions button | `button[aria-label="More actions"]` |
| `sidebar.workflows.header.new` | New workflow button | `button[aria-label="New workflow"], button[aria-label="Creating workflow..."]` |
| `sidebar.workflows.header.menu` | More actions dropdown | `[role=menu]` opened from the above |
| `sidebar.tree` | tree root | `[role=tree][aria-label=Workflows]` |
| `sidebar.tree.root-zone` | root drop zone | `[role=tree] > div` |
| `sidebar.tree.folder-row` | folder row (per folder: suffix `.<folderId>`) | `[role=tree] [role=button][data-item-id]` |
| `sidebar.tree.folder-row.chevron` | chevron | first `svg` in the folder row |
| `sidebar.tree.folder-row.icon` | Folder/FolderOpen icon | second `svg` |
| `sidebar.tree.folder-row.label` | name | `[data-overflow-text]` inside |
| `sidebar.tree.folder-row.actions` | RowActions slot | `[data-row-actions]` inside |
| `sidebar.tree.folder-row.lock` | lock indicator | `[data-row-action-indicator]` inside |
| `sidebar.tree.folder-row.expanded` | expanded state | `[aria-expanded=true]` |
| `sidebar.tree.folder-row.active` | selected/menu-open state | row with `bg-[var(--surface-active)]` |
| `sidebar.tree.folder-row.rename-input` | rename input | `input` inside |
| `sidebar.tree.folder.children` | children container | `[role=tree] [data-item-id] + …` the `.space-y-0.5` sibling of the folder row wrapper |
| `sidebar.tree.folder.guide` | vertical guide line | `.w-px.bg-\[var\(--border\)\]` |
| `sidebar.tree.workflow-row` | workflow row (suffix `.<workflowId>`) | `[role=tree] a[data-item-id]` |
| `sidebar.tree.workflow-row.label` | name | `[data-overflow-text]` inside |
| `sidebar.tree.workflow-row.active` | current route row | `a[data-item-id]` with `--surface-active` fill |
| `sidebar.tree.workflow-row.avatars` | presence stack | `.-space-x-1` inside |
| `sidebar.tree.workflow-row.actions` | RowActions slot | `[data-row-actions]` |
| `sidebar.tree.workflow-row.lock` | lock indicator | `[data-row-action-indicator]` |
| `sidebar.tree.workflow-row.rename-input` | rename input | `input` inside |
| `sidebar.tree.drop-line` | drop indicator line | `.h-\[2px\].rounded-full` |
| `sidebar.tree.drop-inside` | inside overlay | `.opacity-10.bg-\[var\(--text-subtle\)\]` |
| `sidebar.tree.edge-zone.top` / `.bottom` | 12 px edge zones | `.h-\[12px\].z-30` |
| `sidebar.tree.context-menu` | row context menu | `[role=menu]` from `ContextMenu` |
| `sidebar.tree.context-menu.item.<id>` | each item (`open-new-tab`, `rename`, `create-workflow`, `create-folder`, `lock`, `duplicate`, `export`, `delete`) | `[role=menuitem]` by label |
| `sidebar.tree.context-menu.separator` | separator | `[role=separator]` |
| `sidebar.tree.empty-menu` | empty-area popover | `[data-radix-popper-content-wrapper]` from `EmptyAreaContextMenu` |
| `sidebar.tree.delete-modal` | delete confirm | `[role=dialog]` |
| `sidebar.tree.drag-ghost` | drag image pill | the body-appended `div` from `createSidebarDragGhost` |
| `sidebar.rail.workflows.chip` | 32 px rail chip | `button[aria-label=Workflows]` |
| `sidebar.rail.workflows.flyout` | 220 px flyout | `[role=menu]` beside it |
| `sidebar.rail.workflows.flyout.new` | "New workflow" row | first `[role=menuitem]` |
| `sidebar.rail.workflows.flyout.folder.<id>` | folder sub-trigger | `[role=menuitem][aria-haspopup=menu]` |
| `sidebar.rail.workflows.flyout.workflow.<id>` | workflow link row | `[role=menuitem] a` |

### Colour anchors (sample in non-text areas; ΔE76 ≤ 2)
| anchor | point | expected token (light / dark) |
|---|---|---|
| A1 | sidebar background: 4 px left of the tree, vertically in the 16 px section gap above "Workflows" | `--surface-1` #fbfbfb / #1e1e1e |
| A2 | active workflow row fill: 4 px from the row's left edge, vertical centre | `--surface-active` #ececec / #2c2c2c |
| A3 | hovered (non-active) row fill, same point, pointer on the row | `--surface-hover` #f2f2f2 / #262626 |
| A4 | folder vertical guide line (1 px at `left: level*20+12`) | `--border` #d8d8d8 / #444444 |
| A5 | drop indicator line (2 px) during a drag | `--text-subtle` #8c8c8c / #7d7d7d |
| A6 | "inside" overlay over a folder row during a drag | `--text-subtle` at 10 % over A1 |
| A7 | context-menu surface, 2 px inside its top-left corner | `--bg` #fefefe / #1b1b1b; border `--border` |
| A8 | presence avatar fallback disc centre on the active row | `getUserColor(userId)` (per user; fixed per seed user) |

## Tokens
| Element | Tokens |
|---|---|
| Section title | `text-caption` (12 px), `--text-muted` |
| Section chevron | `--text-icon`, 14 px, 150 ms opacity/transform |
| Header buttons | `Button quiet icon`: 20 px, `rounded-sm`, text `--text-icon-muted`, hover `--surface-active`, `[&_svg]:[stroke-width:1.25]` (`button.tsx:50,55,69`) |
| Row (rest) | transparent; hover `--surface-hover` (`hover-hover:` media query only); focus-visible `--surface-hover` |
| Row (active/selected/menu open) | `--surface-active`, held through hover |
| Row text | `--text-body`, `text-sm` 14 px |
| Row icons | `--text-icon` (chevron 14 px, folder 16 px, more 16 px, lock 14 px) |
| Rename input | transparent, `--text-body`, `text-sm`, no outline/ring |
| Guide line | `--border`, 1 px |
| Drop line | `--text-subtle`, 2 px, `rounded-full` |
| Inside overlay | `--text-subtle` @ `opacity-10`, `rounded-sm` |
| Drag ghost (`utils.ts:56–74`) | `position:fixed; top:-500px; inline-flex; gap:6px; padding:4px 10px; background:var(--surface-active); border:1px solid rgba(255,255,255,0.08); border-radius:8px; font: system-ui 13px; color:var(--text-body); box-shadow:0 4px 12px rgba(0,0,0,.4); z-index:9999`; label `max-width:200px` ellipsis; leading 14 px folder/workflow SVG in `--text-icon` only when a single item is dragged |
| Context menu | `MENU_STYLES.surface` (`rounded-xl`, `--border`, `--bg`, `shadow-medium`), `p-1`; rows 28 px `text-small` `--text-body`, icons 14 px `--text-icon`, hover `--surface-hover`, disabled `opacity-50`; separator `mx-2 my-1 border-t --border`; `max-w-[220px]`; `sideOffset=4` |
| Empty-area popover | emcn `Popover size='sm'`: rows 24 px `text-caption` (`MENU_STYLES.sizes.sm`), `sideOffset=4` |
| Rail chip | 32 × 30 px, icon 16 px `--text-icon` |
| Flyout | `w-[220px]`, `sideOffset=8`, rows 28 px, sub-content `max-w-[280px]` |
| Avatars | 14 px discs, 4 px overlap, border `--border`, fallback `--surface-4`/user colour, `+N` `bg-gray-700` |
| Delete modal | `ChipConfirmModal`: title "Delete workflow|workflows|folder|folders|items", text segments with `bold` names and `error` warning, confirm "Delete"/"Deleting...", `defaultAction='dismiss'` |

## States
| State | Behaviour | Source |
|---|---|---|
| Loading (first load) | `useWorkflowMap` pending and no cached workflows → section body empty (no skeleton). `useFolders` pending with cached workflows → rows render; folder-dependent effects (`activeWorkflowFolderId`, auto-expand) wait for `foldersLoading=false` | `sidebar.tsx:1830`, `workflow-list.tsx:120–124, 360–372` |
| Empty | Root drop zone keeps `min-h-[26px]`; no text. Rail flyout shows "No workflows yet" (disabled row) | `workflow-list.tsx:573`, `sidebar.tsx:1778–1779` |
| Error | List queries have no error UI; `placeholderData: keepPreviousData` keeps the last list. Mutation errors: create folder in folder → `toast.error(message)`; drop → `toast.error('Failed to move items' \| 'Only some items moved')`; rename → value resets to the original (no toast); delete/duplicate → logged and re-thrown (modal stays open with the pending flag cleared) | `folder-item.tsx:200–203`, `use-drag-drop.ts:526–539`, `use-item-rename.ts:81–92` |
| Read-only member (`!canEdit`) | Header buttons disabled; `canReorder=false` → `useDragDrop({disabled:true})` returns no-op handlers and `dragDisabled=true` so rows are not `draggable`; context-menu Rename/Create/Duplicate/Export disabled and Delete hidden (`showDelete={canEdit}`); empty-area items disabled (`disableCreate`) | `sidebar.tsx:1705,1749,1836,1840`, `use-drag-drop.ts:789–804`, `folder-item.tsx:595–607`, `workflow-item.tsx:493–497` |
| Permissions loading | Buttons enabled until `permissionsLoading` resolves (`!permissionsLoading && !canEdit`) | `sidebar.tsx:1705, 1749` |
| Locked folder/workflow | `effectiveLocked` = own `locked` or any ancestor folder locked (`folder-tree.ts:139–161`). Locked rows: not draggable, no double-click rename, Rename/Create/Create folder/Delete disabled; Lock item shows "Unlock"; Lock item disabled when `!canAdmin` or an ancestor is locked (`inheritedFolderLocked`) | `folder-item.tsx:361, 512, 595–611`, `workflow-item.tsx:376, 417, 493–501` |
| Active workflow | Row `active` when `workflow.id === params.workflowId`; its folder path is force-expanded and `selectOnly(workflowId)` is applied whenever the route changes (after loading) | `workflow-list.tsx:358, 360–372` |
| Multi-selection | Workflow rows show `active` only when selected **and** `selectedWorkflows.size > 1`; folder rows show `active` whenever selected | `workflow-item.tsx:411`, `folder-item.tsx:505` |
| Dragging | Dragged row(s) and any selected rows get `opacity-50`; `RowActions.revealOnHover=false` for every row; edge zones mount; empty expanded folders get a 24 px zone | `folder-item.tsx:507,554`, `workflow-list.tsx:461–475, 583–601` |
| Context menu open | Row `active`; `RowActions.open=true` keeps the action visible and hides the indicator | `folder-item.tsx:505,553`, `workflow-item.tsx:411,454` |
| Renaming | Input replaces the label; `Avatars`/`RowActions` hidden on workflow rows; row not draggable; `disabled` while the PUT is pending | `workflow-item.tsx:425–452, 417`, `folder-item.tsx:525–543, 512` |
| Creating (optimistic) | New workflow/folder appears immediately with the client-generated id (no "temp" visual); `markWorkflowCreating(id)` puts the registry in `hydration.phase='creating'` until the POST resolves | `hooks/queries/workflows.ts:209–253`, `registry/store.ts:259–303` |
| Collapsed rail | Flyout variant (above); hover-peek card renders the expanded layout (`isCollapsed = isCollapsedProp && !isPeeking`) | `sidebar.tsx:400–401` |
| Hosted-only / feature flags | None for this surface |
| Offline / reconnecting | No special UI; realtime room re-joins on `connect` (`use-workspace-invalidation-room.ts:44–49, 69–70`) |

## Interactions

### Ordering (single rule everywhere)
`compareByOrder(a, b)`: `sortOrder` ascending, then `createdAt` ascending, then `id.localeCompare` (`utils.ts:110–119`). Folders and workflows at one level are **interleaved** into one list (`interleaveSiblings` 132–154; `workflow-list.tsx:417–442, 498–525`; `sidebar.tsx:569–603`). `buildFolderTree` itself sorts children by `sortOrder || name.localeCompare` (`lib/folders/tree.ts:14`) but the renderer re-sorts with `compareByOrder`. `regularWorkflows` from `useWorkflowOperations` is sorted newest-first (`use-workflow-operations.ts:18–24`) but that order is only used for the search palette; the tree re-sorts.

New items get `sortOrder = min(sibling sortOrders) − 1` (or 0 when no siblings), i.e. **top of their level** (`top-insertion-sort-order.ts:17–44`); the server receives no `sortOrder` for creates (undefined) and the optimistic entry uses the computed value.

### Pointer
| Target | Action | Result | Source |
|---|---|---|---|
| Folder row | click | `clearFolderSelection()` then `toggleExpanded(folderId)`; ignored while editing or right after a drag (`shouldPreventClickRef`) | `folder-item.tsx:368–389` |
| Folder row | Shift+click | `selectFolderRange(orderedFolderIds, lastSelectedFolderId, id)` (or `selectFolderOnly` without an anchor), then dedupe ancestor/descendant pairs (keep ancestor) and deselect workflows inside selected folders; no expand | `use-folder-selection.ts:128–145` |
| Folder row | Cmd/Ctrl+click | `toggleFolderSelection(id)`, deselect its ancestors/descendants, deselect conflicting workflows | same |
| Folder row | double-click on label | start rename unless `effectiveLocked` | `folder-item.tsx:357–366` |
| Folder row | right-click | capture selection (if the row is not selected: clear all + select it), open `ContextMenu` at cursor | `folder-item.tsx:283–331` |
| Folder row | "…" button click | same capture; menu anchored at the button's `rect.right, rect.top`; a second click closes | `folder-item.tsx:405–425` |
| Workflow row | click | `selectOnly(workflowId)` and navigate via `Link` (`/workspace/{ws}/w/{id}`) | `workflow-item.tsx:382–402`, `use-workflow-selection.ts:80–92` |
| Workflow row | Shift+click | `preventDefault` (no navigation); `selectRange(orderedWorkflowIds, activeWorkflowId, id)` anchored on the **active route workflow**, or `toggleWorkflowSelection` when no anchor / same id; deselect ancestor folders | same |
| Workflow row | Cmd/Ctrl+click | handler returns early → browser opens the link in a new tab | `workflow-item.tsx:391–393` |
| Workflow row | double-click on label | start rename unless locked | `workflow-item.tsx:372–380` |
| Workflow row | right-click / "…" | as folder | `workflow-item.tsx:208–286` |
| Tree background (`e.target === e.currentTarget`) | click | `selectOnly(activeWorkflowId)` or `clearAllSelection()` | `workflow-list.tsx:532–539` |
| Tree background / `.space-y-0.5` / `[data-empty-area]` | right-click | `EmptyAreaContextMenu` ("Create workflow", "Create folder") | `workflow-list.tsx:541–553, 605–616` |
| Sidebar `aside` background (not a control) | click | same selection reset as above | `sidebar.tsx:1207–1211`, `utils.ts:9–17` |
| Header "+" | click | `handleCreateWorkflow` (below) | `sidebar.tsx:1748` |
| Header "…" → Create folder | select | `handleCreateFolder` | `sidebar.tsx:1732` |
| Header "…" → Import workflow | select | opens hidden `<input type=file accept='.json,.zip' multiple>` | `sidebar.tsx:1186–1188, 1373–1380` |

### Create
- **New workflow** (`use-workflow-operations.ts:30–47`): `clearDiff()`; `name = generateCreativeWorkflowName()`; `id = generateId()` (UUID v4); `createWorkflow.mutate({ workspaceId, name, id, deduplicate: true })`; `markWorkflowCreating(id)`; `router.push('/workspace/{ws}/w/{id}')` **before** the POST resolves; then `sidebar.tsx:1170–1177` dispatches `sidebar-scroll-to-item` with the id. Also bound to `Mod+Shift+P` (`add-workflow`, `allowInEditable:false`) guarded by `canEdit && !isCreatingWorkflow` (`sidebar.tsx:1349–1354`).
- **Create workflow in folder** (`folder-item.tsx:158–175`): same, plus `folderId`, `expandFolder()`, scroll event. Guarded by `effectiveLocked`.
- **Create folder (root)** (`use-folder-operations.ts:24–42`): `name = await generateFolderName(ws)` → `GET /api/folders?workspaceId` then "Folder N" where N = max existing `^Folder (\d+)$` + 1 among root folders (`naming.ts:20–52`); `createFolder.mutateAsync({ name, workspaceId, id: generateId() })`; on success scroll-to-item.
- **Create folder in folder** (`folder-item.tsx:177–204`): `generateSubfolderName(ws, parentId)` → "Subfolder N" among that parent's children; `mutateAsync({ workspaceId, name, parentId, id })`; `expandFolder()`; scroll; error → toast.
- New folders are **not** auto-expanded and do **not** enter rename mode.

### Scroll-to-item
`window` event `sidebar-scroll-to-item` `{ itemId }` → up to 10 rAF retries to find `[data-item-id=itemId]`; if it is outside the scroll container, `scrollIntoView({ behavior:'smooth', block:'center' })` (`sidebar.tsx:468–497`). Fired on initial mount for the route workflow once workflows have loaded (1160–1168), after create (1170–1184), after palette workflow selection, and after in-folder creates.

### Expand / collapse
- Store: `expandedFolders: Set<string>` in `useFolderStore` (`stores/folders/store.ts:50, 57–77`); **in memory only** — not persisted to localStorage/cookie/server; resets on reload.
- Toggle on folder-row click; Enter/Space on a focused folder row (`use-folder-expand.ts:39–47`, only when `e.target === e.currentTarget`, `folder-item.tsx:391–397`).
- Auto-expand: the active workflow's ancestor chain is set expanded on every route/data change (`workflow-list.tsx:360–366`); drag hover (see DnD); in-folder create (`expandFolder`).
- Section-level collapse (header chevron) is separate local state.

### Inline rename (`use-item-rename.ts`)
- Trigger: double-click on the label, or context menu "Rename" (menu `onCloseAutoFocus` refocuses + selects the input only when Rename was the chosen item, `context-menu.tsx:198, 227–236, 299`).
- On start: `editValue = current name`; input focused and fully selected (`48–53`).
- Enter → save; Escape → cancel; blur → save (`106–124`). Clicks inside the input are stopped (`folder-item.tsx:535–538`).
- Save (`66–93`): `trim()`; empty or unchanged → exit edit mode without a request; else `isRenaming=true`, `PUT`, on success exit edit, on error keep editing with the value reset to the original name; `finally isRenaming=false`.
- Limits: folder input `maxLength=50`, workflow input `maxLength=100` (server: folder name ≤ 255 trimmed non-empty, `contracts/folders.ts:90`; workflow name non-empty, `contracts/workflows.ts:311`).
- Workflow rename: `useUpdateWorkflow().mutateAsync({ workspaceId, workflowId, metadata:{ name } })` — optimistic update of the active list, rollback on error, `invalidateWorkflowLists` on settle (`hooks/queries/workflows.ts:479–524`).
- Folder rename: `useUpdateFolder().mutateAsync({ workspaceId, id, updates:{ name } })` — **not optimistic**; `onSettled` invalidates `folderKeys.resource('workflow')` (`hooks/queries/folders.ts:254–277`).
- Collapsed flyout rename (`use-flyout-inline-rename.ts`): same keys; while editing the hover menu is locked open (`sidebar.tsx:1021–1023`) and pointer moves do not steal focus (`collapsed-sidebar-menu.tsx:195–197, 268–269`).

### Context menus (`context-menu.tsx`)
Common chrome: `DropdownMenu modal={false}` anchored to a 1 × 1 px fixed trigger at `{x,y}` (`getContextMenuPosition`: cursor, or `left,bottom` of the control for keyboard activation, `lib/core/utils/context-menu.ts:4–10`); `DropdownMenuContent align='start' side='bottom' sideOffset={4}`, `max-h-[var(--radix-dropdown-menu-content-available-height,400px)]`; closes on outside click (listener attached after a `setTimeout(0)`, `use-context-menu.ts:61–82`), Escape, selection, or focus leaving to a non-menu element. Every item calls its handler then `onClose()`.

Full render order inside `ContextMenu` (238–452), each gated by its `show*`/handler: Open in new tab (`SquareArrowUpRight`, when `openInNewTabPosition='first'`) · Copy link (`Duplicate`) · Mark as read (`Eye`) · Mark as unread (`Mail`) · Pin/Unpin (`Pin`/`PinOff`) · Rename (`Pencil`) · Create workflow (`Plus`) · Create folder (`FolderPlus`) · Upload logo (`ImageUp`) · Lock/Unlock (`Lock`/`Unlock`) · Duplicate (`Duplicate`, label via `selectionActionLabel`) · Export (`Download`) · Open in new tab (when `'last'`) · **separator** · Leave (`LogOut`) · Delete (`Trash`) · Close / Close Others / Close Tabs to the Right (`X`).
Separator rule (`173–193`): rendered only when at least one item above **and** at least one destructive item (Leave/Delete/Close*) are shown.
Labels with `selectionActionLabel(action, selectedCount)` (`selection-label.ts:11–22`): `selectedCount <= 1` → "Duplicate" / "Export" / "Delete"; else "Duplicate N items" / "Export N items" / "Delete N items".
No shortcut hints are shown in these menus.

**Workflow row menu** (`workflow-item.tsx:478–503`) — `selectedCount = workflowIds + folderIds` in the captured selection:
1. Open in new tab — shown when not mixed and ≤ 1 workflow selected; `window.open('/workspace/{ws}/w/{id}', '_blank')` (175–177).
2. Rename — same visibility; disabled `!canEdit || effectiveLocked`.
3. Lock / Unlock — same visibility; disabled `!canAdmin || inheritedFolderLocked`; `PUT /api/workflows/{id}` `{ locked: !locked }` via `useUpdateWorkflow` (179–186).
4. Duplicate — always shown; disabled `!canEdit || isDuplicatingSelection`.
5. Export — always shown; disabled `!canEdit`.
6. — separator —
7. Delete — shown when `canEdit`; disabled `!canDeleteSelection || effectiveLocked`.

**Folder row menu** (`folder-item.tsx:578–613`):
1. Rename — shown when not mixed and ≤ 1 folder selected; disabled `!canEdit || effectiveLocked`.
2. Create workflow — same visibility; disabled `!canEdit || effectiveLocked || createWorkflow.isPending`.
3. Create folder — same; disabled `!canEdit || effectiveLocked || createFolder.isPending`.
4. Lock / Unlock — same visibility; disabled `!canAdmin || inheritedFolderLocked`; `PUT /api/folders/{id}?resourceType=workflow` `{ locked }` (206–213).
5. Duplicate — always; disabled `!canEdit || isDuplicatingSelection || !hasExportableContent` (folder has no workflows and selection has none).
6. Export — always; disabled `!canEdit || isExporting || !hasExportableContent`.
7. — separator —
8. Delete — shown when `canEdit`; disabled `effectiveLocked || !canDeleteSelection`.
Folder rows have no "Open in new tab".

**Empty area** (`empty-area-context-menu.tsx`): emcn `Popover size='sm'` with `PopoverItem` "Create workflow" and "Create folder" (both disabled by `disableCreate = !canEdit || isCreatingWorkflow || isCreatingFolder`, `sidebar.tsx:1840`). No icons, no separator.

**Nav chip menu** (`nav-item-context-menu.tsx`, for the nav chips above the tree, not tree rows): "Open in new tab", "Copy link" (`navigator.clipboard.writeText(origin + href)`), `sideOffset=4`, no separator.

Selection capture for menus (`folder-item.tsx:283–323`, `workflow-item.tsx:208–250`): if the right-clicked row is not in the selection, the selection is replaced by that row (Finder pattern); otherwise the whole selection is the target. `isMixed = folders>0 && workflows>0`. `canDeleteSelection` is computed via `useCanDelete`: a delete is refused when it would remove **every** workflow in the workspace (`use-can-delete.ts:99–121`; empty folders are always deletable).

### Delete → Recently deleted → Restore
- Delete modal (`delete-modal.tsx`): `ChipConfirmModal` titled "Delete workflow" / "Delete workflows" / "Delete folder" / "Delete folders" / "Delete items" (mixed); text "Are you sure you want to delete **name[, name…]**? " + red warning ("All associated blocks, executions, and configuration will be removed." for workflows; "All associated workflows and contents will be archived." / "…within these folders will be archived." for folders; "All selected workflows and folders, including their contents, will be archived." mixed) + " You can restore it from Recently deleted in Settings." (all tree item types are restorable, line 36); confirm button "Delete" (`pendingLabel 'Deleting...'`); `defaultAction='dismiss'` (Enter does not confirm).
- Workflow delete (`use-delete-workflow.ts:49–131`): if the active workflow is among the ids, navigate first — to the next workflow after the current one in `useWorkflows` order (filtered to the workspace, i.e. server order), else the first remaining, else `/workspace/{ws}`; then `DELETE /api/workflows/{id}` for each id in parallel (`Promise.all`), each with optimistic removal from the active list and rollback on error; `clearSelection()`; `onSuccess` closes the modal.
- Folder delete (`use-delete-folder.ts:36–64`): `DELETE /api/folders/{id}?resourceType=workflow` sequentially; `onSettled` invalidates the folder resource key and `invalidateWorkflowLists(ws, ['active','archived'])` (the cascade archives contained workflows). No navigation if the active workflow was inside (ambiguity noted below).
- Mixed / multi-folder delete (`use-delete-selection.ts:57–163`): computes `allWorkflowsToDelete = selected ∪ workflows directly in selected folders` (direct children only, not nested folders), navigates if the active workflow is among them (same next-item rule), deletes folders sequentially, then standalone workflows in parallel, clears both selections.
- Restore happens in Settings → Recently deleted (`app/workspace/[workspaceId]/settings/components/recently-deleted/recently-deleted.tsx:229–230, 307–316`): `POST /api/workflows/{id}/restore` (`useRestoreWorkflow`, invalidates `recentlyDeletedKeys.lists()` + workflow lists active/archived) and `POST /api/folders/{id}/restore` body `{ workspaceId, resourceType:'workflow' }` (`useRestoreFolder`, additionally invalidates `folderKeys.resource('workflow')`). The tree picks the restored rows up through those invalidations (and through the realtime room). The Recently-deleted page itself is Phase 5.

### Duplicate
- Workflow (`use-duplicate-workflow.ts:49–104`): for each id, `POST /api/workflows/{id}/duplicate` body `{ name: '<name> (Copy)', description, workspaceId, folderId: source.folderId, newId: generateId() }`; optimistic entry at top of the same folder; `clearSelection()`; if exactly one was duplicated, `router.push` to it.
- Folder (`use-duplicate-folder.ts:30–41, 46–112`): name `'<name> Copy'`, then `'<name> Copy 2'`, `3`… avoiding sibling names; `POST /api/folders/{id}/duplicate` body `{ workspaceId, name, parentId: source.parentId, newId }`; optimistic folder at top of the parent; `onSettled` invalidates `folderKeys.list(ws)` and workflow lists (the server copies the workflows inside). No navigation.
- Mixed selection (`use-duplicate-selection.ts:60–149`): folders first (sequential), then workflows (sequential); navigates only when exactly one workflow and zero folders were duplicated.

### Drag and drop (`use-drag-drop.ts`, native HTML5 DnD)
What can be dragged: any folder or workflow row that is not editing, not `dragDisabled` (`!canEdit`), and not `effectiveLocked` (`folder-item.tsx:512`, `workflow-item.tsx:417`). If the dragged row is part of the current selection, the whole selection moves; otherwise only that row (`folder-item.tsx:222–233`, `workflow-item.tsx:319–330`).

Drag start (row): `useItemDrag.handleDragStart` sets `shouldPreventClickRef=true`, swaps the default drag image for a 1 × 1 transparent GIF (`use-item-drag.ts:7–12, 28–40`); the row handler then writes `dataTransfer['sidebar-selection'] = JSON {workflowIds, folderIds}`, `effectAllowed='copyMove'`, `dataTransfer['application/x-sim-resources'] = JSON [{type:'workflow'|'folder', id, title}]` (for dropping into the Home chat, `utils.ts:23–42`), creates the ghost pill (label = name, or `'<name> +N more'` when N+1 items, icon only for a single item) and `setDragImage(ghost, w/2, h/2)`, then `onItemDragStart(sourceParentFolderId)` → `draggedSourceFolderRef`, `isDragging=true` (`use-drag-drop.ts:709–713`). Drag end removes the ghost, resets after one rAF so the synthetic click after drop is swallowed (`use-item-drag.ts:45–50`).

Drop targets and the indicator they set (`DropIndicator = { targetId, position:'before'|'after'|'inside', folderId }`):
| Target (handler) | Same scope as source? | Indicator |
|---|---|---|
| Workflow row (`597–617`) | yes (`draggedSourceFolderRef === folderId`) | `before`/`after` by vertical midpoint (`98–102`) |
| Workflow row | no | `{ targetId: folderId ?? 'root', position:'inside' }` → drop at the **end** of that folder |
| Folder row (`619–647`) | yes | top 25 % → `before`, bottom 25 % → `after`, middle 50 % → `inside` (`108–118`); `inside` arms the hover-expand timer |
| Folder row | no | `inside` (+ hover-expand) |
| Empty-folder 24 px zone (`649–659`) | — | `inside` that folder |
| Folder children area, pointer on the container itself (`661–673`) | source not already in that folder | `inside` that folder |
| Root zone, pointer on the container itself (`675–689`) | — | `inside root`; leaving the root container clears the indicator |
| 12 px edge zones (`691–707`) | — | `before` first root item / `after` last root item (written directly, not normalised) |
Normalisation (`386–424`): an `after X` indicator is rewritten to `before next-sibling(X)` when a next sibling exists, so the line is always drawn above a row except after the last sibling. Identical consecutive indicators do not re-render.

Hover auto-expand: while dragging over a collapsed folder's middle band, a 400 ms timer (`HOVER_EXPAND_DELAY`, line 18) expands it (`250–271`); folders opened this way are remembered and **closed again on drag end**, except the drop destination and its ancestors (`721–746`, `562–577`). Leaving the folder row (true leave, `85–95`) cancels the timer.

Auto-scroll (`196–248`): while dragging, each animation frame scrolls the sidebar scroll container by up to 8 px (`SCROLL_SPEED`) when the pointer is within 60 px (`SCROLL_THRESHOLD`) of its top/bottom edge, scaled linearly by proximity.

Invalid drops: a folder cannot be dropped into itself or any of its descendants (`canMoveFolderTo` 426–435 — such folders are silently excluded; if nothing valid remains the drop is a no-op); locked rows never start a drag; no visual "forbidden" state is drawn. Dropping outside the list (`window` `drop` outside the container, or `dragend` anywhere) resets all drag state (`748–783`).

Drop (`552–595`): reads the indicator from a ref (not state), clears state, parses `sidebar-selection`, then `handleSelectionDrop` (489–550):
1. `destinationFolderId = position==='inside' ? (targetId==='root' ? null : targetId) : indicator.folderId`.
2. `siblings = all folders with parentId===dest ∪ all workflows with folderId===dest`, sorted by `compareByOrder` (read live from the query caches, 358–384).
3. `remaining = siblings − moving`; `insertAt` = number of remaining items before the target (`before`) / through the target (`after`) / `remaining.length` (`inside`) (135–154).
4. `newOrder = remaining[0..insertAt) ++ movingFromSameScope (sorted) ++ movingFromOtherScopes (sorted) ++ remaining[insertAt..)`.
5. Re-index `sortOrder = index` over the whole level, then split: folders → `PUT /api/folders/reorder`, workflows → `PUT /api/workflows/reorder`; both sent concurrently with `Promise.allSettled` (273–328). Every sibling at the destination level is included in the payload (not just the moved ones).
6. On success `clearSelection(); clearFolderSelection()`. On any rejection: toast ("Only some items moved" if one of two requests failed, else "Failed to move items"); each mutation rolls back its own cache slice and re-fetches.

Keyboard: there is no keyboard DnD.

### Keyboard
| Key | Context | Effect | Source |
|---|---|---|---|
| Tab / Shift+Tab | tree | Native focus order: folder rows (`tabIndex=0`), workflow links, and the revealed "…" buttons (focus-within reveals them) | `folder-item.tsx:500`, `row-actions.tsx:41–42` |
| Enter / Space | focused folder row | toggle expand | `use-folder-expand.ts:39–47` |
| Enter | focused workflow link | native link activation (navigate) | — |
| Enter / Space | focused tree container itself | reset selection to the active workflow / clear | `workflow-list.tsx:563–569` |
| Enter / Escape | rename input | save / cancel | `use-item-rename.ts:106–117` |
| Arrow keys | tree | **none** (no roving focus / arrow navigation exists) | — |
| Arrow Up/Down, Enter, Escape | open context menu | Radix menu navigation | emcn |
| ArrowRight / ArrowLeft | flyout row ↔ its "…" action | moves focus between row and action | `dropdown-menu.tsx:324–350` |
| Mod+Shift+P | anywhere except editable targets | New workflow | `commands.ts:56–60`, `sidebar.tsx:1349–1354` |
| Mod+B | not in editable targets | toggle sidebar (affects which variant renders) | `commands.ts:96–100` |
| Enter | rail nav chip (`SidebarNavChip`) | activates the link instead of toggling the flyout | `collapsed-sidebar-menu.tsx:209–213` |
Editable-target rule: a command with `allowInEditable:false` is skipped when `document.activeElement` is an `input`, `textarea`, or `isContentEditable` (`global-commands-provider.tsx:103–106, 158`); listeners are on `window` keydown in the capture phase.

Focus order after menu actions: Rename → input focused and selected via `onCloseAutoFocus`; other actions → `preventDefault` on close-autofocus so focus stays where it was (`context-menu.tsx:227–236`).

## Network and realtime

React Query keys (`workflow-keys.ts:3–22`, `folder-keys.ts:41–51`):
- `['workflows','list', workspaceId, 'active'|'archived'|'all']`, `staleTime` `WORKFLOW_LIST_STALE_TIME = 60 000` ms, `placeholderData: keepPreviousData`.
- `['folders','list','workflow', workspaceId, 'active'|'archived']`, `staleTime` `FOLDER_LIST_STALE_TIME = 60 000` ms, `keepPreviousData`. `useFolderMap` shares the key and `select`s a `Record<id, folder>`.
- `invalidateWorkflowLists(qc, ws, scopes=['active'])` also invalidates `selectorKeys.all` (`invalidate-workflow-lists.ts:11–25`).

Requests in order on mount (sidebar on a workflow route):
1. `GET /api/workflows?workspaceId={ws}&scope=active` → `{ data: WorkflowListItem[] }` fields used: `id, name, description, workspaceId, folderId, sortOrder, createdAt, updatedAt, archivedAt, locked, forkSyncExcluded, isDeployed` (`contracts/workflows.ts:244–258`, mapped by `mapWorkflow` to `WorkflowMetadata` with `Date`s).
2. `GET /api/folders?workspaceId={ws}&resourceType=workflow&scope=active` → `{ folders: Folder[] }` fields used: `id, resourceType, name, userId, workspaceId, parentId, locked, sortOrder, createdAt, updatedAt, deletedAt` (`contracts/folders.ts:36–60, 135–145`).
3. Socket: `emit('join-workspace-workflows', { workspaceId })`; on `join-workspace-workflows-success`/`-error` (retry up to 3× with 1000·n ms backoff when `retryable`); on `workspace-workflows-changed { workspaceId }` → invalidate workflow lists (active+archived) and folder lists (active+archived) for that workspace; `emit('leave-workspace-workflows')` on unmount (`use-workspace-invalidation-room.ts:34–83`, `use-workspace-workflows-room.ts:22–29`). The server fans this event out from every workflow/folder mutation on any surface (`lib/realtime/notify.ts:102`).
4. Presence for avatars comes from the workflow room the editor joins (`usePresenceStore.presenceUsers`, `useSocket().currentWorkflowId`) — Phase 2 dependency; in Phase 1 the stack renders empty.

Mutations (all via `requestJson(contract)`; bodies are the zod `body` schemas):
| Action | Request | Body | Optimistic / rollback | Invalidation |
|---|---|---|---|---|
| New workflow | `POST /api/workflows` | `{ id, name, description?, workspaceId, folderId: null\|id, sortOrder?: undefined, deduplicate: true }` | append `{id, name, createdAt:now, folderId, sortOrder: top-insertion, locked:false}` to active list; on success replace by response (`id,name,description,workspaceId,folderId,sortOrder`) and move selection from tempId; `subBlockValues` seeded into the subblock store; `markWorkflowCreated(id)`; on error restore snapshot + `markWorkflowCreated(null)` | `onSettled`: workflow lists active+archived |
| Create folder | `POST /api/folders` | `{ id, name, workspaceId, parentId?, sortOrder?: undefined, resourceType:'workflow' }` | optimistic folder appended (`createOptimisticMutationHandlers`), replaced by `mapFolder(response.folder)`; rollback to snapshot | folder list (per handler) |
| Rename workflow / lock | `PUT /api/workflows/{id}` | `Partial<{ name, description, folderId, sortOrder, locked, forkSyncExcluded }>` | map over active list, `lastModified: now`; rollback | workflow lists (active) |
| Rename folder / lock | `PUT /api/folders/{id}?resourceType=workflow` | `{ name? \| locked? \| parentId? \| sortOrder? }` | none | `['folders','list','workflow']` |
| Reorder workflows | `PUT /api/workflows/reorder` | `{ workspaceId, updates: [{ id, sortOrder (int ≥0), folderId: string\|null }] }` → `{ success:true, updated:n }` | apply `sortOrder`/`folderId` to matching rows; rollback | workflow lists (active) |
| Reorder folders | `PUT /api/folders/reorder` | `{ workspaceId, resourceType:'workflow', updates: [{ id, sortOrder (int ≥0), parentId: string\|null }] }` (1–1000 items) → `{ success:true, updated:n }` | apply `sortOrder`/`parentId`; rollback | folder list active |
| Duplicate workflow | `POST /api/workflows/{id}/duplicate` | `{ name, description?, workspaceId, folderId, newId }` → `{ id, name, description, workspaceId, folderId, sortOrder, locked, blocksCount, edgesCount, subflowsCount }` | optimistic entry with `newId` at top of folder; replaced on success; rollback | workflow lists (active) |
| Duplicate folder | `POST /api/folders/{id}/duplicate` | `{ workspaceId, name, parentId, newId }` → `{ folder }` | optimistic folder with `newId`; rollback | `folderKeys.list(ws)` + workflow lists (active) |
| Delete workflow | `DELETE /api/workflows/{id}` | — → `{ success:true }` | remove from active list; rollback | workflow lists active+archived |
| Delete folder | `DELETE /api/folders/{id}?resourceType=workflow` | — → `{ success:true, deletedItems?: { folders, workflows? } }` | none | folder resource key + workflow lists active+archived |
| Restore workflow | `POST /api/workflows/{id}/restore` | — | none | `recentlyDeletedKeys.lists()` + workflow lists active+archived |
| Restore folder | `POST /api/folders/{id}/restore` | `{ workspaceId, resourceType:'workflow' }` → `{ success, restoredItems? }` | none | recently-deleted + folder resource key + workflow lists active+archived |
| Folder naming | `GET /api/folders?workspaceId={ws}` (default `resourceType=workflow`, `scope=active`) | — | — | — (plain fetch, not cached) |
| Import | handled by `use-import-workflow.ts` (creates folders/workflows through the same mutations) | | | |

Limits/pagination: the workflow and folder lists are unpaginated (whole workspace). Reorder folders payload ≤ 1000 entries. No list limit for workflows.

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | sidebar.tsx:1690–1693, constants.ts:10 | Workflows section has 16 px top margin (`mt-4`) from the previous section | | |
| 2 | layout | sidebar-section.tsx:65,13 | Section header row is 18 px tall; title inset 16 px (`px-4`) | | |
| 3 | token | sidebar-section.tsx:56–61 | Title "Workflows" is 12 px `--text-muted` | | |
| 4 | interaction | sidebar-section.tsx:50–54,82–87 | Header click collapses the section body; chevron 14 px appears on section hover, rotates −90° when collapsed; state not persisted | | |
| 5 | layout | sidebar-section.tsx:92, sidebar.tsx:1696 | Action cluster right-aligned with 16 px right gutter, two 20 px buttons 8 px apart | | |
| 6 | token | button.tsx:50,55,69 | Header buttons: 20 px, radius 4 px, icon colour `--text-icon-muted`, hover fill `--surface-active` | | |
| 7 | layout | sidebar.tsx:1707–1711,1751 | "…" shows `MoreHorizontal` 14 px (Loader 16 px while importing/creating folder); "+" shows `Plus` 16 px | | |
| 8 | state | sidebar.tsx:1705,1749 | Both header buttons disabled for `!canEdit` once permissions resolved; "+" also disabled while creating | | |
| 9 | interaction | sidebar.tsx:1719–1738 | "…" menu: `min-w-[160px]`, `sideOffset 8`, items "Import workflow", "Create folder" (no separator), rows 28 px | | |
| 10 | keyboard | sidebar.tsx:1758, commands.ts:56–60 | "+" tooltip shows shortcut `⌘⇧P`/`Ctrl+Shift+P`; shortcut skipped in editable targets | | |
| 11 | layout | sidebar-section.tsx:104, sidebar.tsx:1829 | Body: 6 px gap under the header, then 8 px side padding around the tree | | |
| 12 | layout | workflow-list.tsx:589 | Root rows spaced 2 px (`space-y-0.5`) | | |
| 13 | layout | chip.tsx:65–95, chrome.ts:58 | Every row 30 px tall, `px-2`, gap 6 px, radius 8 px, 14 px text | | |
| 14 | layout | workflow-list.tsx:27–29,385,454 | Nested rows indented 20 px per level via wrapper padding | | |
| 15 | layout | workflow-list.tsx:463–467 | Expanded folder children: 2 px top margin, 2 px left padding, 2 px row gap, 1 px guide at `level*20+12` | | |
| 16 | token | workflow-list.tsx:464 | Guide line colour `--border` | | |
| 17 | layout | folder-item.tsx:516–524 | Folder row: chevron 14 px, then folder icon 16 px, then label; chevron rotates 90° when expanded; icon switches Folder→FolderOpen | | |
| 18 | token | chrome.ts:110–111 | Chevron `--text-icon`, 150 ms opacity/transform transition | | |
| 19 | layout | workflow-item.tsx:423–451 | Workflow row has no leading icon; label then presence avatars with 8 px gap | | |
| 20 | token | chrome.ts:83,85, sidebar.tsx:1383 | Row hover `--surface-hover`, active `--surface-active`, transitions 0 ms inside the sidebar | | |
| 21 | state | workflow-item.tsx:411 | Route workflow row is active; selected rows are active only in multi-select (>1) | | |
| 22 | state | folder-item.tsx:505 | Folder row active when selected or its menu is open | | |
| 23 | layout | row-actions.tsx:32–69, sidebar-row-actions.tsx:15 | Actions slot 18 px; hidden at rest unless indicator; "…" 16 px revealed on hover/focus-within; indicator fades out while revealed | | |
| 24 | state | folder-item.tsx:556–563, workflow-item.tsx:457–464 | Lock indicator 14 px `--text-icon` only for the row's own `locked` flag | | |
| 25 | state | folder-tree.ts:139–161 | Inherited lock disables rename/create/delete/drag but shows no icon | | |
| 26 | layout | presence-avatars.tsx:30,89, avatar.tsx:15 | Avatars 14 px, 4 px overlap, reversed order, `+N` overflow chip | | |
| 27 | layout | avatars.tsx:13–17,38–43 | Max visible avatars = 4 + floor((width−224)/20), clamped 4..12 | | |
| 28 | state | avatars.tsx:49–52 | Avatars only on the socket's current workflow, excluding own socket | | |
| 29 | interaction | utils.ts:110–119, workflow-list.tsx:498–525 | Folders and workflows interleaved by `sortOrder`, `createdAt`, `id` | | |
| 30 | interaction | top-insertion-sort-order.ts:17–44 | New/duplicated items land at the top of their level | | |
| 31 | interaction | folder-item.tsx:368–389 | Plain click on a folder toggles expand and clears folder selection; no navigation | | |
| 32 | interaction | use-folder-selection.ts:128–145 | Shift-click range from `lastSelectedFolderId`, Cmd/Ctrl toggle; ancestor/descendant conflicts resolved | | |
| 33 | interaction | use-workflow-selection.ts:80–92, workflow-item.tsx:382–402 | Shift-click ranges from the active workflow without navigating; Cmd/Ctrl-click opens new tab | | |
| 34 | interaction | workflow-list.tsx:360–372 | Changing route expands the active workflow's folder path and selects it | | |
| 35 | state | stores/folders/store.ts:50,291 | Expanded set is in-memory only; reload collapses everything (except the active path) | | |
| 36 | interaction | use-folder-expand.ts:39–47 | Enter/Space on a focused folder row toggles it | | |
| 37 | interaction | workflow-list.tsx:532–539, sidebar.tsx:1207–1211 | Clicking empty tree/sidebar background resets selection to the active workflow | | |
| 38 | interaction | folder-item.tsx:357–366, workflow-item.tsx:372–380 | Double-click on the label starts rename unless locked | | |
| 39 | interaction | use-item-rename.ts:48–53 | Rename input is focused with all text selected | | |
| 40 | keyboard | use-item-rename.ts:106–124 | Enter saves, Escape cancels, blur saves; empty/unchanged exits silently | | |
| 41 | state | use-item-rename.ts:76–92 | Input disabled while saving; on error value resets to original and stays in edit mode | | |
| 42 | layout | folder-item.tsx:533, workflow-item.tsx:433 | Folder input maxLength 50, workflow input maxLength 100 | | |
| 43 | interaction | context-menu.tsx:201–237, use-context-menu.ts:38–48 | Right-click opens the menu at the cursor; "…" opens it at the button's top-right; second "…" click closes | | |
| 44 | interaction | workflow-item.tsx:478–503 | Workflow menu order: Open in new tab, Rename, Lock/Unlock, Duplicate, Export, ─, Delete | | |
| 45 | interaction | folder-item.tsx:578–613 | Folder menu order: Rename, Create workflow, Create folder, Lock/Unlock, Duplicate, Export, ─, Delete | | |
| 46 | interaction | context-menu.tsx:173–193,393 | Separator only when a non-destructive item and Delete are both present | | |
| 47 | interaction | selection-label.ts:11–22 | Multi-selection labels "Duplicate N items" / "Export N items" / "Delete N items" | | |
| 48 | state | folder-item.tsx:590–611, workflow-item.tsx:489–501 | Single-row-only items (Open in new tab, Rename, Create…, Lock) hidden for mixed or multi selection | | |
| 49 | state | use-can-delete.ts:99–121 | Delete disabled when it would remove every workflow in the workspace | | |
| 50 | token | styles.ts:11–21, dropdown-menu.tsx:240,245 | Menu: `--bg` surface, `--border`, radius 12 px, `p-1`, rows 28 px 13 px text, icons 14 px, `max-w-[220px]`, offset 4 | | |
| 51 | interaction | context-menu.tsx:227–236 | Choosing Rename moves focus into the input and selects its text; other items do not steal focus | | |
| 52 | interaction | empty-area-context-menu.tsx:55–83, workflow-list.tsx:541–553 | Right-click on empty tree area opens a `sm` popover with "Create workflow", "Create folder" | | |
| 53 | network | use-workflow-operations.ts:30–47 | New workflow: POST with client id + `deduplicate:true`, navigates immediately, scrolls the row into view | | |
| 54 | network | use-folder-operations.ts:24–42, naming.ts:46–52 | Root folder name "Folder N" from a fresh GET of root folders | | |
| 55 | network | folder-item.tsx:177–204 | In-folder create names "Subfolder N", expands the parent, scrolls; error toast | | |
| 56 | interaction | sidebar.tsx:468–497 | Scroll-to-item centres the row only if it is outside the viewport; up to 10 rAF retries | | |
| 57 | interaction | folder-item.tsx:512, workflow-item.tsx:417 | Locked, editing, or read-only rows are not draggable | | |
| 58 | interaction | folder-item.tsx:222–249, utils.ts:54–108 | Drag carries the selection when the row is selected; ghost pill shows name or "name +N more", icon only for single item | | |
| 59 | token | utils.ts:56–74 | Ghost: `--surface-active` fill, 8 px radius, 4×10 px padding, 13 px text, shadow `0 4px 12px rgba(0,0,0,.4)` | | |
| 60 | state | folder-item.tsx:507, workflow-item.tsx:415 | Dragged and co-selected rows at 50 % opacity; row actions do not reveal during a drag | | |
| 61 | interaction | use-drag-drop.ts:98–102,597–617 | Over a same-folder workflow: line above/below by midpoint; over another folder's workflow: "inside" that folder | | |
| 62 | interaction | use-drag-drop.ts:108–118,619–647 | Over a folder: top 25 % before, bottom 25 % after, middle inside | | |
| 63 | interaction | use-drag-drop.ts:386–424 | "after X" normalised to "before next sibling" | | |
| 64 | layout | workflow-list.tsx:43–64 | Drop line 2 px `--text-subtle` rounded, 2 px outside the row, indented by level | | |
| 65 | layout | workflow-list.tsx:447–452,577–582 | "Inside" target: full-row overlay `--text-subtle` at 10 % (folder) or over the whole root zone | | |
| 66 | layout | workflow-list.tsx:583–601 | 12 px edge zones at the top/bottom of the root list while dragging | | |
| 67 | layout | workflow-list.tsx:473–475 | Empty expanded folder shows a 24 px drop zone while dragging | | |
| 68 | interaction | use-drag-drop.ts:18,250–271 | Hovering a collapsed folder's middle band for 400 ms expands it | | |
| 69 | interaction | use-drag-drop.ts:721–746,562–577 | Spring-opened folders close on drag end except the destination path | | |
| 70 | interaction | use-drag-drop.ts:16–17,196–232 | Auto-scroll within 60 px of the container edges at ≤ 8 px/frame | | |
| 71 | interaction | use-drag-drop.ts:426–435,497–501 | Folder cannot be dropped into itself/descendants; such drops are no-ops | | |
| 72 | network | use-drag-drop.ts:273–328,489–521 | Drop re-indexes the whole destination level 0..n−1 and sends folder and workflow reorder PUTs concurrently | | |
| 73 | network | contracts/workflows.ts:321–330, contracts/folders.ts:109–122 | Reorder bodies: `{workspaceId, updates:[{id, sortOrder, folderId}]}` / `{workspaceId, resourceType:'workflow', updates:[{id, sortOrder, parentId}]}` | | |
| 74 | network | hooks/queries/workflows.ts:638–675, folders.ts:415–457 | Reorder applied optimistically; rolled back per-request on error; both invalidate on settle | | |
| 75 | state | use-drag-drop.ts:526–539 | Failed drop toasts "Failed to move items" / "Only some items moved" | | |
| 76 | interaction | use-drag-drop.ts:748–783 | Drop outside the list or Esc-cancel resets drag state and indicators | | |
| 77 | interaction | delete-modal.tsx:77–88,212–222 | Delete modal titles/text per item type, "You can restore it from Recently deleted in Settings.", Enter does not confirm | | |
| 78 | interaction | use-delete-workflow.ts:75–103 | Deleting the active workflow navigates to the next remaining workflow (server list order) or the workspace root first | | |
| 79 | network | hooks/queries/workflows.ts:531–567 | DELETE per workflow, optimistic removal, lists active+archived invalidated | | |
| 80 | network | hooks/queries/folders.ts:279–296 | Folder DELETE with `?resourceType=workflow`; folder + workflow lists invalidated | | |
| 81 | network | use-duplicate-workflow.ts:66–95 | Duplicate posts `name '(Copy)'`, keeps folder, uses `newId`, navigates when single | | |
| 82 | network | use-duplicate-folder.ts:30–41,77–83 | Folder duplicate name "X Copy", "X Copy 2"…; keeps parent | | |
| 83 | network | hooks/queries/workflows.ts:120–133, workflow-list-query.ts:9 | Workflow list key `['workflows','list',ws,'active']`, staleTime 60 s, keepPreviousData | | |
| 84 | network | hooks/queries/folders.ts:46–80, folder-keys.ts:6,41–51 | Folder list key `['folders','list','workflow',ws,'active']`, staleTime 60 s | | |
| 85 | network | use-workspace-invalidation-room.ts:34–74 | Socket joins `workspace-workflows` room; `workspace-workflows-changed` invalidates both lists | | |
| 86 | network | hooks/queries/workflows.ts:479–524, folders.ts:254–277 | Rename workflow optimistic + rollback; rename folder non-optimistic, invalidates folder resource | | |
| 87 | layout | sidebar.tsx:1768–1777, constants.ts:50 | Collapsed rail: 32 px chip with `Workflow` 16 px icon, no header actions | | |
| 88 | layout | collapsed-sidebar-menu.tsx:262–267 | Flyout 220 px wide, `side=right`, offset 8, no animation | | |
| 89 | interaction | use-hover-menu.ts:3,33–43,71–89 | Flyout opens on hover, closes 150 ms after leaving trigger and content | | |
| 90 | interaction | collapsed-sidebar-menu.tsx:271–278, sidebar.tsx:1779 | Flyout: "New workflow" row, separator, then items; "No workflows yet" when empty | | |
| 91 | interaction | collapsed-sidebar-menu.tsx:529–570 | Folder with children → submenu interleaved by order; empty folder → disabled row | | |
| 92 | interaction | collapsed-sidebar-menu.tsx:418–478 | Workflow flyout row: current route active; "…"/right-click opens submenu with Open in new tab, Rename | | |
| 93 | interaction | use-flyout-inline-rename.ts, sidebar.tsx:1021–1023 | Flyout rename keeps the flyout locked open; Enter/Escape/blur as in the tree | | |
| 94 | keyboard | global-commands-provider.tsx:103–106,158 | Editable-target rule: input/textarea/contentEditable block non-editable commands | | |
| 95 | keyboard | workflow-list.tsx:563–569 | Enter/Space on the tree container resets selection | | |
| 96 | state | sidebar.tsx:1830 | Nothing renders while the first workflow fetch is pending | | |

## Ambiguities and later-phase dependencies
- `hooks/use-resource-list-preferences.ts` is not used by the sidebar tree; it serves the resource tables. Nothing to port for this spec.
- There is no running/execution indicator and no item count on tree rows in this commit; the brief's "running indicator" exists only on chat rows (`sidebar.tsx:257, 309–314`).
- Keyboard navigation in the tree is limited to Tab order plus Enter/Space; there is no arrow-key roving focus.
- Deleting a **single folder** that contains the active workflow does not navigate away (`use-delete-folder.ts`); the editor is left on an archived workflow until the realtime `workflow-deleted` event (Phase 2) handles it. Mirror as-is.
- `buildFolderTree` sorts by `sortOrder || name`, while the renderer re-sorts by `compareByOrder` (`sortOrder, createdAt, id`); the renderer wins.
- Presence avatars depend on the editor's socket room (Phase 2). In Phase 1 render the (empty) stack.
- The "Export" items download JSON/ZIP via `use-export-*` hooks; the file-download path is Phase 1 shell plumbing but the workflow serialisation it needs is Phase 2 — mark `verified-by-review` until then.
- Import (`.json,.zip`) uses the same create mutations; the parser lives in `lib/workflows/operations/import-export` (Phase 2).
- *Recorded 2026-10-22 (review v1 finding 25):* until the Phase 2 import parser and export serialisation exist, "Import workflow" (header More menu) and "Export" (row menus) are shown **disabled** instead of being silent no-ops, the palette's "Import workflow" row is absent (no handler), and the "Importing..." label/spinner state is not modelled. `verified-by-review`, deferred to Phase 2 (`known-gaps.md`).
- *Recorded 2026-10-22 (review v1 finding 23):* the tree container takes no tab stop (like the `role=tree` div, which has no `tabIndex`); Enter/Space reset the selection only when the container itself holds focus. Escape during a drag cancels it (no drop, spring-opened folders collapse).
- Hover states use the `hover-hover:` media query (`@media (hover: hover)`); on touch pointers rows show no hover and row actions are always visible (`row-actions.tsx:38–42`). Desktop parity only.
- `--border-1` and `--border-muted` resolve to `--border` in both themes (`globals.css:730–731, 894–895`).
