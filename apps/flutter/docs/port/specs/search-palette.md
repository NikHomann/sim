# Search palette (command palette)
Upstream: `apps/sim/app/workspace/[workspaceId]/w/components/sidebar/components/search-modal/**`, `apps/sim/stores/modals/search/`, commit `27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c`
Phase: 1 (canvas groups and "add block" selections become live in Phase 2)

Paths are relative to `apps/sim/` unless prefixed `packages/`.

## Files
| File | Lines | Role |
|---|---|---|
| `.../search-modal/search-modal.tsx` | 1419 | `SearchModal` (mount gate 130–139) and `SearchModalContent` (141–1419): data wiring, actions, ranking, selection handlers, portal + geometry |
| `.../search-modal/components/command-chrome/command-chrome.tsx` | 121 | `CommandSearch` (floating input, 44–83) and `CommandFadedList` (92–119) |
| `.../search-modal/components/search-groups/search-groups.tsx` | 290 | `renderSearchEntry` (83–260), `SearchEntryGroup` (270–290), `BlocksGroup`/`ToolsGroup` (26–77, canvas connection selector only) |
| `.../search-modal/components/command-items/command-items.tsx` | 344 | Row components: `MemoizedCommandItem`, `MemoizedActionItem`, `MemoizedWorkflowItem`, `MemoizedFileItem`, `MemoizedTaskItem`, `MemoizedWorkspaceItem`, `MemoizedPageItem`, `MemoizedIconItem`; `ItemMeta`, `ItemFolderPath`, `ShortcutHint` |
| `.../search-modal/utils.ts` | 670 | Section constants, types, ranking (`fuzzyMatch`, tiers, `scoreSectionItems`, `scoreActions`, `getGlobalSearchResults`), row/heading class constants |
| `.../search-modal/integration-search-items.ts` | 94 | Integration catalogue rows and connected-account rows |
| `.../search-modal/utils.test.ts` | 345 | Ranking tests (reference behaviour) |
| `.../sidebar/sidebar.tsx` | 1958 | Feeds: `initializeData` (440–448), workflows (730–740), workspaces (742–752), chats (931–939), page context (1091–1108), credentials (1110–1116), logs (1118–1133), integrations (1135–1155), Search chip (1452–1467), `open-search` command (1342–1347), `<SearchModal>` props (1933–1948) |
| `.../sidebar/constants.ts` | 65 | `CMDK_SECTION_GAP_CLASS` (58), `CMDK_ITEM_GAP_CLASS` (61) |
| `stores/modals/search/store.ts` | 195 | `isOpen`, `setOpen/open/close`, `initializeData` (block/tool/trigger/tool-operation catalogue) |
| `stores/modals/search/types.ts` | 89 | `SearchBlockItem`, `SearchToolOperationItem`, `SearchData`, `SearchModalState` |
| `app/workspace/[workspaceId]/utils/commands.ts` | 152 | `open-search` = `Mod+K`, `allowInEditable: true` (66–70) |
| `app/workspace/[workspaceId]/providers/global-commands-provider.tsx` | ~230 | Shortcut dispatch (capture-phase `window` keydown, 152–176), `useInvokeGlobalCommand` (203) |
| `app/workspace/[workspaceId]/w/[workflowId]/components/command-list/command-list.tsx` | 227 | Empty-canvas command list; shares **only** `useSearchModalStore.open` (line 56, 84–87). No row/ranking code is shared |
| `lib/search/tokens.ts` | 13 | `toSearchToken` (kebab-cases phrases) |
| `lib/folders/tree.ts` | 103 | `getFolderPathNames` (96–103) for folder receipts |
| `components/identity-tile/identity-tile.tsx` | 71 | Workspace tile (16 px) |
| `blocks/block-tile.tsx` | 19 | `BlockTile` → `@sim/workflow-renderer` `BlockTileView` (block/tool/integration icon tile) |
| `hooks/queries/tables.ts` (`useTablesList`), `hooks/queries/workspace-files.ts` (`useWorkspaceFiles`), `hooks/queries/kb/knowledge.ts` (`useKnowledgeBasesQuery`), `hooks/queries/folders.ts` (`useFolderMap` for `table`/`knowledge_base`), `hooks/queries/credentials.ts` (`useWorkspaceCredentials`), `hooks/queries/logs.ts` (`useLogsList`), `hooks/queries/mothership-chats.ts` (`useMothershipChats`), `hooks/queries/workspace.ts` (`useOrderedWorkspacesQuery` via `useWorkspaceManagement`), `hooks/queries/workflows.ts` (`useWorkflowMap`) | — | Data sources per group (see Network) |
| emcn | — | `cn`, `useNativeSurfaceOcclusionReady`, `scrollFadeClass`/`scrollFadeAttributes`/`useScrollEdges` (`packages/emcn/src/components/scroll-fade/*`), `OverflowText`, icons |
| cmdk | — | `Command`, `Command.Input`, `Command.List`, `Command.Group`, `Command.Item`, `Command.Empty` (`shouldFilter={false}`, `loop`) |

## Layout

### Trigger surfaces
- Header "Search" chip (`sidebar.tsx:1458–1466`): `Chip leftIcon={Search} aria-label='Search'` (30 × 32 px icon chip, 16 px glyph) inside the 65 px trailing cluster; tooltip "Search" with shortcut `⌘K`/`Ctrl+K` `side='bottom'` (1452–1457). Hidden (`w-0 opacity-0`, `inert`) when the rail is collapsed (1444–1450).
- Global shortcut `Mod+K` (`open-search`, `allowInEditable: true`, `commands.ts:66–70`) toggles: `setOpen(!isOpen)` (`sidebar.tsx:1342–1347`). Dispatched from a capture-phase `window` keydown; a focused element declaring `data-owned-shortcuts` containing `Mod+K` keeps the key (`global-commands-provider.tsx:113–123, 161`).
- Empty-canvas command list "Search Blocks (K)" row → `openSearchModal()` (`command-list.tsx:56, 84–87`) — Phase 2 surface.
- Other callers use the store directly (`useSearchModalStore.open`).

### Overlay and dialog (`search-modal.tsx:1314–1418`)
Rendered through `createPortal(…, document.body)` only while `open && mounted`.
- Overlay (1316–1324): `div.fixed.inset-0.z-[var(--z-modal)]` (z 200) with **no background colour** (transparent click-catcher), `transition-opacity duration-100`, `aria-hidden` while not visually open, `data-native-surface-occlusion='modal'`. Click → close.
- Dialog (1326–1342): `div[role=dialog][aria-modal][aria-label=Search]` `fixed top-[15%] z-[var(--z-modal)] -translate-x-1/2 w-[min(500px,calc(100%-32px))] rounded-xl border border-[var(--border-muted)] bg-[var(--surface-4)] dark:bg-[var(--surface-5)] p-[3px]`. Width = min(500 px, viewport − 32 px). Top = 15 % of the viewport height.
  - `left` (1335–1341): `clamp(calc(16px + H), CENTER, calc(100% - 16px - H))` with `H = min(250px, 50% - 16px)` (`PALETTE_HALF_WIDTH`, 113) and `CENTER = calc(50% + (var(--sidebar-width) - var(--panel-width)) / 2)` on the workflow canvas (`pageContext==='workflow'`) or `calc(var(--sidebar-width) / 2 + 50%)` elsewhere — i.e. centred over the content pane right of the sidebar (and between sidebar and right panel on the canvas), never closer than 16 px to either viewport edge.
  - Visibility: `visible opacity-100` once `useNativeSurfaceOcclusionReady` resolves (immediately on web), else `invisible opacity-0` (1333; 163–165).
- Inner card (1343): `div.overflow-hidden.rounded-lg.border.border-[var(--border-1)].bg-[var(--bg)]` — the 3 px ring is the dialog's `--surface-4/5` fill; the card is `--bg` with an 8 px radius.
- `Command` (1344–1349): `label='Search' shouldFilter={false} loop value={askMode ? askSimLabel : undefined}`.
- Relative wrapper (1350) containing, in DOM order, the list then the floating input.

### List (`CommandFadedList`, `command-chrome.tsx:92–119`; usage 1357–1364)
`Command.List` `overflow-y-auto overflow-x-hidden px-1.5 pt-12 pb-1.5` (6 px side padding, 48 px top padding under the floating input, 6 px bottom), `[--scroll-fade-inset:3rem]` so the top fade band (12 px, `SCROLL_FADE_BAND_PX`) starts 48 px down and only while scrolled; bottom band only while content hides below. Extra classes: `scrollbar-none`, `max-h-[min(448px,calc(85dvh-26px))]`, `[clip-path:inset(3px_round_13px)]`, `[&_[cmdk-group-items]]:gap-[1px]` (1 px between rows, `CMDK_ITEM_GAP_CLASS`), `[&_[cmdk-group]+[cmdk-group]]:mt-4` (16 px between groups, `CMDK_SECTION_GAP_CLASS`), `[&_[cmdk-group-items]]:flex [&_[cmdk-group-items]]:flex-col`.
- Group heading (`GROUP_HEADING_CLASSNAME`, `utils.ts:273–274`): `flex h-[18px] items-center px-2 mb-2 scroll-mt-12 text-small text-[var(--text-muted)]` → 18 px tall, 8 px inset, 8 px gap to the first row, 13 px muted text.
- Row (`COMMAND_ITEM_CLASSNAME`, `utils.ts:276–277`): `group mx-0.5 flex h-[30px] w-full cursor-pointer items-center gap-2 rounded-lg border border-transparent px-2 text-left text-sm scroll-mt-12 scroll-mb-1.5 aria-selected:border-[var(--border-1)] aria-selected:bg-[var(--surface-active)] data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50` → 30 px tall, 2 px side margin (*corrected 2026-10-22, parity sweep: `w-full` plus `mx-0.5` makes the item box exactly as wide as its group and shifts it 2 px in, so it overhangs the group by 2 px on the end side — 478 px at x+2 in a 478 px group; it does not shrink to 474*), 8 px padding, 8 px gap, 8 px radius, 14 px text; the selected row gets a 1 px `--border-1` border and `--surface-active` fill. Hover does **not** paint (selection follows the pointer via cmdk `aria-selected`).
- Empty (1365–1367): `Command.Empty` `flex items-center justify-center px-4 py-6 text-[var(--text-subtle)] text-sm` → "No results found." (cmdk shows it only when no item is rendered).

### Input (`CommandSearch surface='palette'`, `command-chrome.tsx:44–83`; usage 1394–1411)
Wrapper `absolute inset-x-[3px] top-[3px] z-20 flex h-12 cursor-text items-center gap-2 rounded-t-[13px] px-2.5 pb-2` + palette fog `bg-[linear-gradient(to_bottom,var(--bg)_0%,color-mix(in_srgb,var(--bg)_88%,transparent)_68%,transparent_100%)]` → 48 px tall band floating over the list's top, 10 px side padding, 8 px bottom padding, 8 px gap. Children: `Search` icon `size-[14px] text-[var(--text-muted)]`; `Command.Input` `-ml-1 h-8 min-w-0 flex-1 bg-transparent indent-1 text-[var(--text-body)] text-sm placeholder:text-[var(--text-muted)]` (32 px tall, no outline); `endAdornment` (only when `chatEnabled`): `span.shrink-0.whitespace-nowrap.text-[var(--text-subtle)].text-xs` "⇥ Ask Sim" or "⇥ Search" in ask mode. Placeholder "Search anything..." / "Ask Sim anything..."; `aria-label` "Search anything" / "Ask Sim"; `autoFocus` unless the atomic browser-panel occlusion mode is active (then focused by effect, 701–704).

### Row anatomy (`command-items.tsx`)
| Row | Leading | Label | Trailing |
|---|---|---|---|
| `MemoizedActionItem` (actions, ask row) 116–145 | icon 16 px `--text-icon` | `OverflowText` `--text-body` | `ShortcutHint` (3-column grid 40 px wide, `text-small --text-subtle`, `⌘` in the middle column; *corrected 2026-10-22, parity sweep: `text-small` sets only the size, so the line keeps the item's inherited `text-sm` ratio 20/14 → 18.56 px tall, not 13 × 1.5*) or `ItemMeta` |
| `MemoizedCommandItem` (blocks, triggers, tools, tool operations, integrations, connected) 81–114 | `BlockTile` (`@sim/workflow-renderer` tile with `bgColor`; accent per `hasBlockAccent`) | `OverflowText` with optional muted `labelPrefix` (tool operations: service name) | `ItemMeta` |
| `MemoizedWorkflowItem` 147–185 | 16 px box holding `Workflow` 14 px `--text-icon` | name in `span.max-w-[75%]` + " (current)" when `isCurrent` | `ItemFolderPath` (muted, `ml-auto`, head segments shrink first, " / " separators) |
| `MemoizedFileItem` 187–221 | `File` 14 px in 16 px box | name `max-w-[75%]` | folder path |
| `MemoizedIconItem` (tables `Table`, knowledge bases `Database`, logs `Library`) 309–344 | icon 16 px | name `max-w-[75%]` | folder path or meta (logs: date) |
| `MemoizedTaskItem` (chats) 223–242 | — | name | meta (date) |
| `MemoizedWorkspaceItem` 244–276 | `IdentityTile` 16 px (`--surface-6` tile or logo) | name + " (current)" | meta |
| `MemoizedPageItem` 278–307 | icon 16 px | name | `ShortcutHint` |
`ItemMeta` (22–24): `ml-auto shrink-0 pl-2 text-[var(--text-subtle)] text-small`.

### Parity ids
| id | element | React selector |
|---|---|---|
| `search.overlay` | click-catcher | `[data-native-surface-occlusion=modal]` |
| `search.dialog` | outer ring | `[role=dialog][aria-label=Search]` |
| `search.card` | inner `--bg` card | `[role=dialog] > div` |
| `search.palette.input` | text input (*corrected 2026-10-22, parity sweep: the id is the `-ml-1 h-8 flex-1 indent-1` input box — 32 px tall, starting 4 px left of the text (gap-2 less the -ml-1 after the 14 px glyph), 4 px wider than the flex slot — not the text line*) | `[role=dialog] input[cmdk-input]` |
| `search.palette.input.icon` | 14 px search glyph | first `svg` in the input band |
| `search.palette.input.hint` | "⇥ Ask Sim" / "⇥ Search" (*corrected 2026-10-22, parity sweep: `⇥` is in no bundled face; Chrome on Windows draws it from Segoe UI Symbol at a 9.72 px advance (11 px, 0.02em tracking) and CanvasKit's fallback narrower, which shifted the input box width by 1.28 px; the port pins the glyph advance*) | `span` after the input |
| `search.palette.list` | scroll list | `[cmdk-list]` |
| `search.palette.group.<key>` | group (`actions`, `sim`, `blocks`, `triggers`, `tools`, `toolOperations`, `pages`, `workflows`, `workspaces`, `files`, `tables`, `knowledgeBases`, `logs`, `connectedAccounts`, `chats`, `integrations`, `results`) | `[cmdk-group]` by heading text |
| `search.palette.group.<key>.heading` | heading | `[cmdk-group-heading]` |
| `search.palette.row.<section>.<id>` | row | `[cmdk-item]` (value contains the section/id key) |
| `search.palette.row.selected` | selected row | `[cmdk-item][aria-selected=true]` |
| `search.palette.row.shortcut` | shortcut hint grid | `[aria-label^="Keyboard shortcut"]` |
| `search.palette.row.folder-path` | folder receipt | `.ml-auto.flex.min-w-0` inside a row |
| `search.palette.empty` | "No results found." | `[cmdk-empty]` |
| `search.palette.ask-row` | ask-mode row | the single `[cmdk-item]` in ask mode |
| `search.trigger.chip` | header Search chip | `button[aria-label=Search]` |

### Colour anchors
| anchor | point | expected (light / dark) |
|---|---|---|
| S1 | dialog ring: 1 px inside the dialog's outer border, top-left | `--surface-4` #f5f5f5 / `--surface-5` #363636 |
| S2 | dialog outer border pixel | `--border-muted` = `--border` #d8d8d8 / #444444 |
| S3 | card interior: 4 px inside the card's left edge, vertical centre of the list (between rows) | `--bg` #fefefe / #1b1b1b |
| S4 | selected row fill: 4 px from the row's left edge, row centre | `--surface-active` #ececec / #2c2c2c |
| S5 | selected row border pixel (left edge) | `--border-1` = `--border` |
| S6 | input band, 2 px below the band's top, 20 px from the left | `--bg` (gradient start) |
| S7 | overlay outside the dialog | unchanged page colour (overlay is transparent) |
| S8 | block tile centre on a Blocks row (Phase 2) | the block's `bgColor` (e.g. Agent `--brand-agent` #6f3dfa / #701ffc) |

## Tokens
| Element | Tokens |
|---|---|
| Dialog | `--surface-4` light / `--surface-5` dark, border `--border-muted`, `rounded-xl` 12 px, 3 px padding, `--z-modal` 200 |
| Card | `--bg`, border `--border-1`, `rounded-lg` 8 px |
| Input | text `--text-body` 14 px, placeholder `--text-muted`, icon `--text-muted` 14 px, hint `--text-subtle` 11 px (`text-xs`) |
| Group heading | `text-small` 13 px `--text-muted`, 18 px row |
| Row | 30 px, `text-sm` 14 px `--text-body`, transparent border; selected `--surface-active` + `--border-1` |
| Row icons | `--text-icon` 16 px (14 px glyph inside 16 px box for Workflow/File) |
| Trailing meta / shortcut / folder path | `--text-subtle`, `text-small` 13 px |
| Empty state | `--text-subtle`, `text-sm` |
| Scroll fade | 12 px band, top inset 48 px |
| Block tile | `BlockTileView` (shared renderer package) |
| Workspace tile | `IdentityTile sm`: 16 px, `rounded-sm`, `--surface-6`, letter `--text-icon` (dark: `--text-secondary`), `text-micro` |

## States
| State | Behaviour | Source |
|---|---|---|
| Closed | Nothing in the DOM (`!open` → `null`); store `isOpen=false` | 130–139 |
| Opening | Content mounts with `search=''`, `askMode=false`; input focused; workspace-wide queries (tables, files, knowledge bases, their folder maps, credentials, logs) start fetching **only now** | 189–205, 701–704; `sidebar.tsx:1110–1122` |
| Browse (empty query) | Section groups in canonical order with headings; no per-section cap (`MAX_BROWSE_RESULTS = ∞`); tool operations hidden | 1229–1275, 120, 1123–1128 |
| Searching (non-empty trimmed query) | One flat `results` group without heading, ranked, capped at 50 (`MAX_SEARCH_RESULTS`), per-section inputs capped at 50 (`MAX_RESULTS_PER_GROUP`) | 1203–1227, 121, `utils.ts:655` |
| Ranking lag | Ranking uses `useDeferredValue(search)`; the layout mode follows the deferred value, handlers read the live value; after each deferred change a synthetic `Home` keydown re-anchors cmdk's selection to the first row | 684–694, 753–755 |
| Ask mode (`chatEnabled` only) | Tab toggles; list shows a single row "New chat: <query>" or "Start a new chat" (`Home` icon); hint flips to "⇥ Search"; placeholder/aria-label change | 718–730, 1228, 1369–1375, 1399–1409 |
| Empty results | "No results found." centred | 1365–1367 |
| Loading | No loading rows; a group is simply absent until its query resolves (`SearchEntryGroup` returns `null` for empty lists) | `search-groups.tsx:276` |
| Permission-gated groups | `hideTablesTab`/`hideFilesTab`/`hideKnowledgeBaseTab` → those lists are `[]` even if cached; `hideIntegrationsTab` → integrations and connected accounts `[]`; `hideCopilot` → chats `[]`; `!chatEnabled` → chats `[]` and no ask mode / "New chat" (*corrected 2026-10-22, review v1 finding 28: `hideCopilot` does not gate New chat or ask mode, React reads only `chatEnabled` there*) | 213–257; `sidebar.tsx:931–939, 1135–1155` |
| Off-canvas | Blocks/Triggers/Tools/Tool operations empty (`onCanvas=false`) | 1019, 1031–1060 |
| On-canvas (`pageContext==='workflow'`) | Canvas groups populated; Integrations and Connected Integrations suppressed; credentials query disabled | 1168–1175; `sidebar.tsx:1112–1115` |
| Page context (tables, tableDetail, files, fileDetail, knowledge, knowledgeBase, logs, logsDashboard) | A page "Actions" group precedes "Sim"; the page's own entity section is hoisted right after the action groups | 1020–1030, 1212–1220, 1243–1263 |
| Read-only (`!canEdit`) | Create/Import/page mutating actions absent; `Deploy workflow` needs `canAdmin` | 357, 403–433, 443–669 |
| Hosted-only | None |
| Error | Query errors leave their group empty; clipboard failures logged | 385–389 |

## Interactions

### Open / close
- Open: Search chip click → `open()`; `Mod+K` → toggle; store `setOpen(true)`.
- Close: `Escape` (document-level keydown listener, `preventDefault`, 732–742); overlay click (1015–1017); any selection (every handler calls `onOpenChange(false)`); `Mod+K` again.
- Nothing is persisted between opens: query and ask mode reset because the content unmounts.
- No recent-items / history feature exists.

### Keyboard (inside the palette)
| Key | Effect | Source |
|---|---|---|
| typing | `setSearch(value)`; list scrolled to top on next frame | 706–711 |
| ArrowDown / ArrowUp | cmdk moves `aria-selected`; `loop` wraps at both ends; selected row scrolled into view with `scroll-mt-12`/`scroll-mb-1.5` margins | `Command loop` 1347; `utils.ts:266–277` |
| Home / End | cmdk first/last row | cmdk |
| Enter | selects the `aria-selected` row (`onSelect`) | cmdk |
| Escape | close | 732–742 |
| Tab | `chatEnabled`: toggle ask mode, keep the text, then re-anchor selection (`Home`); `!chatEnabled`: `cycleResultsOnTab` → Tab = ArrowDown, Shift+Tab = ArrowUp | 718–730, 1397; `command-chrome.tsx:49–61` |
| Mod+K | toggle (closes) | `sidebar.tsx:1342–1347` |
| Type-ahead | none beyond live filtering; cmdk's own filter is disabled (`shouldFilter={false}`), all matching is in `utils.ts` | 1346 |

### Pointer
- Hover moves cmdk's selection to the hovered row (cmdk `pointermove` → `aria-selected`); click selects. No separate hover fill.
- Overlay click closes. Clicks inside the dialog do not close.

### Groups, order, data source, selection
Canonical section order (`SEARCH_SECTIONS`, `utils.ts:11–27`): `actions, blocks, triggers, tools, toolOperations, pages, workflows, workspaces, files, tables, knowledgeBases, logs, connectedAccounts, chats, integrations`. Labels (`SECTION_LABELS` 204–220): Sim, Blocks, Triggers, Tools, Tool operations, Pages, Workflows, Workspaces, Files, Tables, Knowledge Bases, Logs, Connected Integrations, Chats, Integrations.

Browse-mode group order (1242–1263): `[Actions (page, only with pageContext)] → Sim → [hoisted page section] → Blocks → Triggers → Tools → Tool operations → remaining sections in canonical order (pages, workflows, workspaces, files, tables, knowledgeBases, logs, connectedAccounts, chats, integrations minus the hoisted one)`. Note: the brief's listing puts Chats last; in source **Integrations** is last and Chats precedes it (`SEARCH_SECTIONS` 25–26).

| Group | Items | Data source | On select |
|---|---|---|---|
| Actions (page) | page-context verbs (`context !== 'global'`): tables → New table, New folder, Import CSV (`canEdit`); tableDetail → Export CSV, New column, Import CSV; files → New file, New folder, Upload; fileDetail → Download, Rename, Share, Delete; knowledge → New base, New folder; knowledgeBase → New documents, New connector, Rename, Edit tags, Delete; logs/logsDashboard → Refresh, Export (`canEdit`), Switch to Dashboard / Switch to Logs (443–669) | static, gated by `pageContext` + `canEdit` | `invokeCommand(id)` on the page's registered global command (`useInvokeGlobalCommand`); the palette closes first, then `run()` (953–965) |
| Sim (`actions`, `context==='global'`; *corrected 2026-10-22, review v1 finding 28: the workflow-context verbs (Run, Deploy, Fit, Copy link) render in the page "Actions" group, `utils.ts:158-160`, not in Sim*) | Run workflow (`⌘↵`, workflow ctx) · Deploy workflow (`canAdmin`, workflow ctx, `exactQueries ['deploy']`) · Fit workflow to view (`⇧⌘F`, workflow ctx) · Copy workflow link (workflow ctx, writes `location.href` to clipboard) · New chat (`chatEnabled`; `Home` icon; `exactQueries ['chats']`) · Create workflow (`canEdit && onCreateWorkflow`; `exactQueries ['workflows']`) · Create folder (`canEdit`) · Import workflow (`canEdit`; *corrected 2026-10-22, parity sweep: the mounting sidebar always passes `handleImportWorkflow`, so React always lists it on home; until the Phase 2 import parser exists the port lists it disabled (cmdk `disabled`: half opacity, skipped by the arrows, inert) rather than omitting it*) · Invite teammates (→ settings `teammates`) (344–442) | static | as above; Create workflow/folder/Import call the sidebar handlers (`sidebar.tsx:1945–1947`) |
| Blocks | `store.data.blocks` minus custom blocks bound to the current workflow (`sourceWorkflowId`) | `useSearchModalStore.initializeData` (`store.ts:84–128`): `getAllBlocks()` filtered by permission groups, `hideFromToolbar` skipped, `category==='blocks'` except `starter`, plus Loop (`#2FB3FF`) and Parallel (`#FEE12B`); `searchValue` = kebab name + type + command-searchable dropdown options | `window.dispatchEvent(new CustomEvent('add-block-from-toolbar', { detail:{ type, enableTriggerMode:false } }))` (757–774) — **Phase 2** (canvas listener) |
| Triggers | `store.data.triggers` renamed "<Name> Trigger" unless already suffixed (`baseName` kept for ranking) | `getTriggersForSidebar()`, priority order Start, Schedule, Webhook Trigger, then alphabetical (`store.ts:130–157`) | same event with `enableTriggerMode = hasTriggerCapability(config)` — Phase 2 |
| Tools | `store.data.tools` minus current-workflow custom blocks | `category==='tools'` blocks | same event, `enableTriggerMode:false` — Phase 2 |
| Tool operations | search-only (hidden in browse; `onCanvas && query`) | `getToolOperationsIndex()` filtered to allowed blocks and `isOperationAllowed` (`store.ts:159–180`); row shows `serviceName` prefix | event `{ type: blockType, presetOperation: operationId }` (776–791) — Phase 2 |
| Pages | Integrations (`Integration`), Skills (`Hammer`), Tables (`Table`), Files (`File`), Knowledge bases (`Database`), Logs (`Library`, shortcut `⇧⌘L`), Secrets (`Key`, → `/settings/secrets`), Help (`HelpCircle`, dispatches `open-help-modal`), Settings (`Settings`, `navigateToSettings()`); hidden per `hide*Tab` unless access requests are enabled (263–337) | static | `page.onClick()` or `router.push(href)` (`window.open` for `http…`) (893–912) |
| Workflows | all active workflows of the workspace with `folderPath` names and `isCurrent` | `useWorkflowMap` via `useWorkflowOperations` (sorted newest first) + `useFolderMap` (`sidebar.tsx:730–740`) | `router.push('/workspace/{ws}/w/{id}')` unless current; dispatch `sidebar-scroll-to-item` (808–824) |
| Workspaces | all workspaces (pinned first, then recency) with `logoUrl`, `isCurrent`, href `/workspace/{id}/w` | `useOrderedWorkspacesQuery` (`sidebar.tsx:742–752`) | `router.push(href)` unless current (826–839) |
| Files | workspace files with display folder path | `useWorkspaceFiles(ws,'active',{enabled:!hideFilesTab})` (192–194, 226–239) | `router.push('/workspace/{ws}/files/{id}')` |
| Tables | tables with folder path from the `table` folder tree | `useTablesList(ws,'active')` + `useFolderMap(ws,'table')` (189–201, 213–224) | `router.push('/workspace/{ws}/tables/{id}')` |
| Knowledge Bases | KBs with folder path from the `knowledge_base` folder tree | `useKnowledgeBasesQuery(ws)` + `useFolderMap(ws,'knowledge_base')` (195–205, 241–257) | `router.push('/workspace/{ws}/knowledge/{id}')` |
| Logs | first page of recent runs, name = workflow name / job title / "Unknown workflow", date "Oct 21, 3:05 PM" style | `useLogsList(ws, SEARCH_MODAL_LOG_FILTERS, { enabled: isOpen && on logs page })` (`sidebar.tsx:169–179, 1118–1133`) — only on `/logs` | `router.push('/workspace/{ws}/logs?executionId=…')` (or `/logs`) |
| Connected Integrations | OAuth/service-account credentials with resolvable service icon | `useWorkspaceCredentials({ enabled: isOpen && !hideIntegrationsTab && !workflow })` → `buildConnectedAccountSearchItems` (`integration-search-items.ts:74–94`) | `router.push('/workspace/{ws}/integrations/connected/{credentialId}')` |
| Chats | mothership chats with formatted `updatedAt` | `useMothershipChats(ws)` (`sidebar.tsx:907–939`) | `router.push('/workspace/{ws}/chat/{id}')` |
| Integrations | full catalogue (`INTEGRATIONS` with an icon) filtered by `isBlockAllowed`; href `/workspace/{ws}/integrations/{slug}` + `?connect=oauth` / `?connect=service-account` per availability (`sidebar.tsx:1139–1145`) | static registry (`integration-search-items.ts:48–66`) | `router.push(href)` |
| Ask row | "New chat: <query>" / "Start a new chat" | — | with text: if already on `/home` → `sendMothershipMessage({content})`, else store a one-shot handoff (`MothershipHandoffStorage.store({message}, ws)`) and `router.push('/workspace/{ws}/home')`; without text → push `/home` (967–1013) — Phase 4 surface |

Every selection also fires PostHog `search_result_selected` (`result_type`, `query_length`, `workspace_id`) — hosted-only analytics, verified by review.

### Ranking (`utils.ts`)
- `fuzzyMatch(text, query, {scatter})` (366–428): case-insensitive. Substring hit → base 1 + 10 (at index 0) / 8 (after a separator ` -_/.:()`) / 6 (camelCase hump) + 6·(len−1); + 120 exact / + 50 prefix / + 25 other; − 0.5·index − 0.15·(len−1) − 0.1·textLength. No substring → scattered subsequence (each char: 1, +10/+8/+6 boundary bonus, +5 consecutive) accepted only when the first hit is at a hard boundary; else multi-word token fallback (every token somewhere, score `10 − 0.1·len`). Empty query matches everything with score 1.
- `scoreItem` (484–493): name match → score + `NAME_MATCH_TIER` (1 000 000); else best secondary-text match (whole string without scatter, or per word).
- `scoreItemsForSection` (522–558): rank items; if the query fuzzy-matches the **section label** and the section is under cap, append the unmatched rows in natural order with a score just below the lowest match; if the query **equals** the label, all rows are lifted to `SECTION_MATCH_TIER` (2 000 000) − index. `toolOperations` is exempt (566).
- `PAGE_MATCH_TIER` (3 000 000): a page whose name equals the query (1132), a block whose name equals the query (1095), a trigger whose base name equals the query and no block shares it (1109–1113), an action whose `exactQueries` contains the query (625).
- Actions (`scoreActions` 610–633): scored against the group label ("Sim"/"Actions") with keywords as secondary text; word-start name matches get `ACTION_MATCH_BIAS` (+500 000); mid-word name hits do not.
- Secondary text per section: blocks/tools/tool-ops `searchValue`; triggers `kebab(name) + id`; workflows/files/tables/KBs `folderPath` kebab tokens; others name only (1087–1180).
- Flat results (`getGlobalSearchResults` 254–263): concatenate sections in `orderedSections` order (hoisted section second), stable-sort by score descending — ties keep section order then in-section order; slice to 50.

## Network and realtime
Palette-triggered requests (only while open; all `GET`, cached by React Query):
1. `GET /api/table` (`listTablesContract`, `contracts/tables.ts:880–881`; `useTablesList(ws,'active')`, key `tableKeys.list(…)`) — skipped when `hideTablesTab`.
2. `GET /api/folders?workspaceId={ws}&resourceType=table&scope=active` (`useFolderMap(ws,'table')`, key `['folders','list','table',ws,'active']`, staleTime 60 s).
3. `GET /api/workspaces/{ws}/files` (`listWorkspaceFilesContract`, `contracts/workspace-files.ts:186–187`; `useWorkspaceFiles(ws,'active')`) — skipped when `hideFilesTab`.
4. `GET /api/knowledge` (`contracts/knowledge/base.ts:220`; `useKnowledgeBasesQuery(ws)`) — skipped when `hideKnowledgeBaseTab`.
5. `GET /api/folders?workspaceId={ws}&resourceType=knowledge_base&scope=active`.
6. `GET /api/credentials` (`contracts/credentials.ts:479–480`; `useWorkspaceCredentials({ workspaceId })`, `sidebar.tsx:1110–1116`) — only off-canvas and when integrations are visible.
7. `GET /api/logs` (`contracts/logs.ts:408`; `useLogsList` first page with `SEARCH_MODAL_LOG_FILTERS`: `limit=50`, `sortBy=date`, `sortOrder=desc`, `timeRange='All time'`, `level` omitted because `'all'` is not sent, `hooks/queries/logs.ts:97–145`) — only on the logs pages.
Already-loaded sources reused: workflows (`['workflows','list',ws,'active']`), workflow folders, workspaces (`['workspace','list','user','active']`, staleTime 30 s), chats (`useMothershipChats`). The exact query-string shapes and stale times of 1, 3, 4, 6, 7 are owned by their Phase 4 specs; the palette only consumes `id`, `name`, `folderId`/`folderPath`, `logoUrl`, `updatedAt`, `executionId`, `createdAt`, `displayName`, `type`.
No mutations are issued by the palette itself; "Create workflow"/"Create folder"/"Import" delegate to the sidebar handlers (see `sidebar-workflow-tree.md`). No socket events. Catalogue data (`initializeData`) is recomputed whenever the permission config, provider model list, or custom-block overlay version changes (`sidebar.tsx:440–448`).

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | keyboard | commands.ts:66–70, sidebar.tsx:1342–1347 | `Mod+K` toggles the palette, also from inside inputs/textareas | | |
| 2 | interaction | sidebar.tsx:1452–1466 | Search chip opens it; tooltip "Search ⌘K/Ctrl+K" below the chip. *Corrected 2026-10-22 (review v1): the chip carries both `search.trigger.chip` and the sidebar spec's `shell.sidebar.header.search`.* | | |
| 3 | layout | search-modal.tsx:1326–1332 | Dialog `top: 15%`, width `min(500px, 100% − 32px)`, 12 px radius, 3 px ring | | |
| 4 | layout | search-modal.tsx:113,1335–1341 | Horizontal centre over the content pane (sidebar offset; panel offset on canvas), clamped to 16 px gutters | | |
| 5 | token | search-modal.tsx:1332 | Ring `--surface-4` light / `--surface-5` dark, border `--border-muted` | | |
| 6 | token | search-modal.tsx:1343 | Card `--bg`, border `--border-1`, 8 px radius, `overflow-hidden` | | |
| 7 | layout | search-modal.tsx:1316–1324 | Overlay full-viewport, transparent, closes on click | | |
| 8 | layout | command-chrome.tsx:64–69 | Input band 48 px tall, inset 3 px, `px-2.5 pb-2`, gap 8 px, floats over the list | | |
| 9 | token | command-chrome.tsx:31–36 | Band background = `--bg` → 88 % at 68 % → transparent gradient | | |
| 10 | layout | command-chrome.tsx:70–76 | Search glyph 14 px `--text-muted`; input 32 px tall, 14 px `--text-body`, placeholder `--text-muted` | | |
| 11 | state | search-modal.tsx:1399–1409 | Placeholder "Search anything..." / "Ask Sim anything..."; hint "⇥ Ask Sim" / "⇥ Search" only when chat is enabled | | |
| 12 | layout | command-chrome.tsx:107–116, search-modal.tsx:1360 | List `px-1.5 pt-12 pb-1.5`, max height `min(448px, 85dvh − 26px)`, no scrollbar, clip-path inset 3 px radius 13 px | | |
| 13 | token | scroll-fade.ts:16, command-chrome.tsx:110 | 12 px scroll fade; top band inset 48 px; no fade at rest | | |
| 14 | layout | constants.ts:58,61 | 16 px between groups, 1 px between rows | | |
| 15 | layout | utils.ts:273–274 | Group heading 18 px, `px-2`, 8 px below, 13 px `--text-muted` | | |
| 16 | layout | utils.ts:276–277 | Row 30 px, `mx-0.5 px-2`, gap 8 px, radius 8 px, 14 px text | | |
| 17 | token | utils.ts:277 | Selected row `--surface-active` fill + 1 px `--border-1` border; no hover fill | | |
| 18 | interaction | cmdk, search-modal.tsx:1347 | Arrow keys move selection, wrap at ends; Enter activates; Home/End | | |
| 19 | keyboard | search-modal.tsx:732–742 | Escape closes | | |
| 20 | keyboard | search-modal.tsx:718–730 | Tab toggles ask mode (chat enabled), keeps the typed text, re-anchors selection | | |
| 21 | keyboard | command-chrome.tsx:49–61, search-modal.tsx:1397 | Chat disabled: Tab / Shift+Tab step the selection down / up | | |
| 22 | interaction | search-modal.tsx:706–711 | Typing scrolls the list to the top on the next frame | | |
| 23 | interaction | search-modal.tsx:684–694,753–755 | Ranking runs on the deferred query; first row re-selected after each ranking | | |
| 24 | state | search-modal.tsx:130–139 | Content unmounts on close; query/ask mode never persist | | |
| 25 | interaction | utils.ts:11–27, search-modal.tsx:1242–1263 | Browse order: [Actions], Sim, [hoisted], Blocks, Triggers, Tools, Tool operations, Pages, Workflows, Workspaces, Files, Tables, Knowledge Bases, Logs, Connected Integrations, Chats, Integrations | | |
| 26 | state | search-groups.tsx:276 | Empty groups render nothing (no heading) | | |
| 27 | state | search-modal.tsx:1365–1367 | "No results found." centred, `--text-subtle`, `px-4 py-6` | | |
| 28 | interaction | search-modal.tsx:1123–1128 | Tool operations only appear while searching on the canvas | | |
| 29 | interaction | search-modal.tsx:1203–1227, utils.ts:254–263 | Searching shows one flat heading-less group, ≤ 50 rows, score desc, ties by section order | | |
| 30 | interaction | utils.ts:366–428 | Fuzzy scoring: exact +120, prefix +50, substring +25, boundary bonuses 10/8/6, scattered only from a hard boundary, multi-token fallback | | |
| 31 | interaction | utils.ts:431,438,445 | Tiers: name 1 000 000; section-label equality 2 000 000; page/exact 3 000 000 | | |
| 32 | interaction | utils.ts:522–558 | Query matching a section label fills that section with its remaining rows | | |
| 33 | interaction | utils.ts:592,610–633 | Actions get +500 000 unless the name hit starts mid-word; `exactQueries` → page tier | | |
| 34 | interaction | search-modal.tsx:1095,1109–1113,1132 | Exact block / trigger / page name → page tier (trigger only when no block shares the name) | | |
| 35 | interaction | search-modal.tsx:1212–1220 | Page context hoists its entity section to second place in both browse and tie-break order | | |
| 36 | interaction | search-modal.tsx:344–442 | Sim verbs and their icons/shortcuts: Run `⌘↵`, Deploy (admin), Fit `⇧⌘F`, Copy link, New chat, Create workflow, Create folder, Import workflow, Invite teammates | | |
| 37 | interaction | search-modal.tsx:443–669 | Page action sets per context exactly as listed | | |
| 38 | interaction | search-modal.tsx:263–337 | Pages list, icons, Logs `⇧⌘L`, Secrets → settings, Help → help modal, Settings → settings | | |
| 39 | layout | command-items.tsx:60–79 | Shortcut hint: 40 px, 3 columns, `⌘` centred, `--text-subtle` 13 px | | |
| 40 | layout | command-items.tsx:147–185 | Workflow row: 14 px glyph in 16 px box, name ≤ 75 % width, " (current)" suffix, folder path receipt right-aligned | | |
| 41 | layout | command-items.tsx:31–46 | Folder path: head segments shrink first, " / " separators, `--text-subtle` 13 px | | |
| 42 | layout | command-items.tsx:244–276 | Workspace row: 16 px identity tile (logo or initial on `--surface-6`), " (current)" | | |
| 43 | layout | command-items.tsx:81–114 | Block/tool/integration rows: `BlockTile` + label; tool operations prefix the muted service name | | |
| 44 | layout | command-items.tsx:22–24,223–242,309–344 | Chats and logs show a right-aligned date "Mon D, H:MM AM" (`Intl.DateTimeFormat` month short, day, hour, 2-digit minute) | | |
| 45 | interaction | search-modal.tsx:808–824 | Workflow select navigates (unless current) and scrolls the sidebar row into view, then closes | | |
| 46 | interaction | search-modal.tsx:826–839 | Workspace select navigates to `/workspace/{id}/w` unless current | | |
| 47 | interaction | search-modal.tsx:893–912 | Page select: `onClick` or push; external `http` links open a new tab | | |
| 48 | interaction | search-modal.tsx:953–965 | Action select closes first, then runs | | |
| 49 | interaction | search-modal.tsx:757–791 | Block/Trigger/Tool/Tool-op select dispatches `add-block-from-toolbar` with `type`, `enableTriggerMode` / `presetOperation` | | |
| 50 | state | search-modal.tsx:213–257, sidebar.tsx:931–939,1135–1155 | Hidden-tab permission groups empty their groups even when data is cached | | |
| 51 | state | search-modal.tsx:1031–1060,1168–1175 | Canvas groups only on the canvas; Integrations/Connected only off the canvas | | |
| 52 | network | search-modal.tsx:182–205 | Tables/files/KBs and their folder maps are fetched only while the palette is open | | |
| 53 | network | sidebar.tsx:1110–1122 | Credentials fetched only when open, off-canvas, integrations visible; logs only on logs pages | | |
| 54 | state | store.ts:84–191 | Catalogue: blocks (no starter, no `hideFromToolbar`) + Loop/Parallel; triggers Start, Schedule, Webhook Trigger first then A–Z; tool ops filtered by allow-lists | | |
| 55 | interaction | search-modal.tsx:967–1013 | Ask mode Enter: sends to a mounted Home or stores a one-shot handoff and navigates; empty query just opens Home | | |

## Ambiguities and later-phase dependencies
- Block/Trigger/Tool/Tool-operation selections dispatch `add-block-from-toolbar`; the canvas listener is Phase 2, so in Phase 1 the rows exist (on a workflow route) but selecting them only closes the palette. The catalogue itself (`initializeData`) needs the generated block registry from `sim_workflow` (Phase 0 output) plus `getTriggersForSidebar`/`getToolOperationsIndex`/permission-group filtering; port the catalogue builder as data, verify counts against the extraction.
- Files, Tables, Knowledge Bases, Logs, Connected Integrations, Chats groups depend on Phase 4 query hooks; in Phase 1 they render empty (the group simply does not appear). Pages and Workspaces and Workflows are fully live in Phase 1.
- Ask mode / "New chat" depends on the chat engine (Phase 4) and `chatEnabled` from the deployment shape; the Tab toggle and row rendering are Phase 1.
- Page "Actions" groups rely on each page registering commands via `useRegisterGlobalCommands`; the `invokeCommand` plumbing is Phase 1, the registrations arrive with their pages.
- `useNativeSurfaceOcclusionReady` / `supportsAtomicBrowserPanelOcclusion` are desktop-shell concerns; on web the dialog is visible immediately and `autoFocus` applies.
- The overlay has no fill; the only visual change behind the palette is the dialog itself. Do not add a scrim.
- The brief listed Chats as the last group; source order ends `…, connectedAccounts, chats, integrations`.
- `--border-muted` and `--border-1` alias `--border` (`globals.css:730–731, 894–895`).

## Parity geometry notes (2026-10-22)

- React ids report element boxes (`getBoundingClientRect`, which ignores `overflow` and `clip-path`); Flutter semantics rects are clipped to their ancestors' paint clips. The port clips the card (`overflow-hidden`) and the list (`clip-path:inset(3px round 13px)`) for painting only, so a group or row the list scrolls partly out of view reports its whole box (Pages: 304 px, not the 235 px left inside the list); a group or row wholly outside the list is marked hidden and keeps its whole box even where the screen edge cuts it (Workflows at 1280×800: 118 px, not 111).
- The browse list renders Tables, Knowledge Bases, Logs, Chats and Integrations groups only with their Phase 2/4 data, so the list's group count is 4 in Phase 1 against React's 9 on the seeded workspace.
