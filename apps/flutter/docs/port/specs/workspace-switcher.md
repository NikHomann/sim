# Workspace switcher (sidebar workspace header)
Upstream: `apps/sim/app/workspace/[workspaceId]/w/components/sidebar/components/workspace-header/**`, `apps/sim/hooks/queries/workspace.ts`, commit `27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c`
Phase: 1

Scope: the workspace trigger chip in the sidebar header, its dropdown (list, search, pinned ordering, per-workspace context menu, footer actions), inline rename, create/delete/leave flows as far as the switcher drives them, last-active recording. The invite modal, view-invitations modal and logo upload are separate modals (workspace create/settings/invite modals spec); only their entry points are covered here. Paths are relative to `apps/sim/` unless prefixed `packages/`.

## Files
| File | Lines | Role |
|---|---|---|
| `.../workspace-header/workspace-header.tsx` | 888 | `WorkspaceHeader` (memo): trigger, menu, list, search, rename row, context menu wiring, modals |
| `.../workspace-header/components/create-workspace-modal/create-workspace-modal.tsx` | 87 | "Create workspace" ChipModal |
| `.../workspace-header/components/pending-invitations/view-invitations-menu-item.tsx` | 30 | "View invitations" row (only when the account has pending invitations) |
| `.../workspace-header/components/pending-invitations/view-invitations-modal.tsx` | 222 | Modal (entry point only) |
| `.../sidebar/sidebar.tsx` | 1958 | Header slot (1396–1426), `useWorkspaceManagement` (503–521), switch/rename/logo/delete/leave handlers (1192–1247), logo file input (1366–1372, 526–539) |
| `.../sidebar/hooks/use-workspace-management.ts` | 247 | List, policy, pins, visit recording, switch, create, delete, leave |
| `.../sidebar/hooks/use-workspace-logo-upload.ts` | 142 | Logo upload (entry point) |
| `.../sidebar/components/sidebar-rename-row.tsx` | 39 | Inline rename row |
| `.../sidebar/components/workflow-list/components/context-menu/context-menu.tsx` | 456 | Shared menu (rows 238–452) |
| `.../sidebar/components/workflow-list/components/delete-modal/delete-modal.tsx` | 241 | "Delete workspace" confirm with typed name |
| `.../sidebar/constants.ts` | 65 | `SIDEBAR_RAIL_CHIP_CLASS` (50) |
| `components/workspaces/workspace-context-menu.tsx` | 47 | Role policy for the menu |
| `components/identity-tile/identity-tile.tsx` | 71 | 16 px logo/initial tile |
| `components/settings/settings-guarded-link.tsx` | — | "Back to organization" link honouring the settings dirty guard |
| `hooks/queries/workspace.ts` | ~420 | `workspaceKeys` (40–52), `useOrderedWorkspacesQuery` (138–146), `usePinnedWorkspaceIds` (127–135), `useWorkspaceCreationPolicy` (100–108), `useRecordWorkspaceVisit` (156–186), `useToggleWorkspacePin` (213–280), `useCreateWorkspace` (289–316), `useDeleteWorkspace` (326–341), `useUpdateWorkspace` (352–365) |
| `hooks/queries/utils/workspace-list-query.ts` | 27 | `WORKSPACE_LIST_STALE_TIME = 30 000` (3), `normalizeWorkspacesResponse` |
| `hooks/queries/pinned-items.ts` | 154 | Generic pin hooks (`usePinnedItems`, `usePinnedIds`, `usePinItem`, `useUnpinItem`) — **not** used for workspace pins (see Network) |
| `hooks/queries/utils/pinned-item-keys.ts` | 20 | `pinnedItemKeys`, `PINNED_ITEMS_STALE_TIME = 60 000` |
| `hooks/queries/invitations.ts` | ~470 | `useMyPendingInvitations` (155–162), `useLeaveWorkspace` (400–421), `invitationKeys.mine()` |
| `lib/api/contracts/workspaces.ts` | 463 | `workspaceSchema` (24–62), `workspaceCreationPolicySchema` (64–80), list (165–185), visit (187–195), create (197–207), update (396–407), delete (409–420) |
| `lib/api/contracts/pinned-items.ts` | 97 | `pinnedResourceTypeSchema` (22–29), create (75–85), delete (87–97), list (63–73) |
| `lib/api/contracts/invitations.ts` | — | `removeWorkspaceMemberContract` `DELETE /api/workspaces/members/[id]` (367) |
| `lib/workspaces/constants.ts` | 2 | `WORKSPACE_SEARCH_THRESHOLD = 6` |
| `lib/workspaces/initials.ts` | 8 | `getWorkspaceInitial` |
| `lib/workspaces/create-input.ts` | 8 | `createWorkspaceInputSchema` (`name` trimmed non-empty, `skipDefaultWorkflow?`) |
| `stores/sidebar/store.ts` | 141 | `workspaceDropdownOpen` flag (81, 86) — present but the header uses local state from `sidebar.tsx:457` |
| emcn | — | `Chip`, `ChipChevronDown` (`chip/chevron.tsx`), `chipGeometryClass`, `chipContentLabelClass`, `ChipInput` (`chip-input.tsx`, 30 px chip field), `DropdownMenu*` (`dropdown-menu.tsx`, `styles.ts`), `DropdownMenuItemLabel`, `DropdownMenuItemAction`, `OverflowText`, `Skeleton`, `Tooltip`, `ChipConfirmModal`, `ChipModal*`, `scrollFade*`, `toast`; icons `ArrowLeft`, `MoreHorizontal`, `PanelLeft`, `Pin`, `Plus`, `Search`, `Send`, `Mail` |

## Layout

### Header slot (`sidebar.tsx:1396–1426, 1443–1485`)
`div.relative.flex.shrink-0.items-center.px-2.pt-2` (8 px sides, 8 px top) → `WorkspaceHeader` in `div.min-w-0.flex-1` (`workspace-header.tsx:448`) → trailing cluster `div.flex.h-[30px].items-center.gap-[1px]` of width 65 px (two 32 px icon chips + 1 px) holding the Search and Collapse chips. The workspace chip therefore spans `sidebarWidth − 16 − 65` px (143 px at the 224 px default) and shrinks first.

### Trigger (expanded rail, workspace ready) (`workspace-header.tsx:500–520`)
`Chip aria-label='Switch workspace' className='min-w-0 max-w-full'` → `inline-flex h-[30px] items-center gap-1.5 px-2 rounded-lg text-sm` (chip geometry), hover `--surface-hover`, `data-state=open` is not styled (no active fill while the menu is open). Contents: `leftAdornment` = `IdentityTile` 16 × 16 px (`rounded-sm`, logo `object-cover` or initial on `--surface-6`), label = workspace name (`OverflowText`, `--text-body`, flex-1, fades at 16 px when clipped), `rightAdornment` = `ChipChevronDown` (16 px slot, 14 px `ChevronDown` `--text-icon`) only when a name exists. Right-click on the trigger opens the context menu for the active workspace (504–508).
- `workspaceInitial = getWorkspaceInitial(name)`: first character of the name with the word "workspace" removed (case-insensitive), upper-cased, fallback first char, fallback "W" (`initials.ts:5–8`).

### Trigger (loading / not ready) (791–819)
A disabled `<button aria-label='Switch workspace'>` with `chipGeometryClass` (same 30 px pill, no hover): `IdentityTile` (or `Skeleton size-[16px] rounded-sm` when there is no workspace yet), then name `OverflowText` + `ChipChevronDown` when expanded. `isWorkspaceReady = !isWorkspacesLoading && activeWorkspaceFull !== null` (278); until then `activeWorkspace` falls back to the route's host-context workspace (`sidebar.tsx:1405`), so the name shows immediately.

### Trigger (collapsed rail) (449–475)
`Chip aria-label='Expand sidebar' fullWidth className=SIDEBAR_RAIL_CHIP_CLASS` (32 px wide in the 48 px rail) with a 16 px slot: `IdentityTile` that turns `invisible` on hover while a `PanelLeft` icon rotated 180° (16 px, `--text-icon`) becomes visible — hovering the tile shows the "expand" affordance; click = `onExpandSidebar` (toggle collapse). No dropdown in the collapsed rail; `Skeleton` while no workspace.

### Dropdown (`DropdownMenuContent`, 521–530)
- `align='start' side='bottom' sideOffset={8}` (`side='right' sideOffset={16}` only in the collapsed branch, which never renders the dropdown — dead code).
- Classes: `flex max-h-[var(--radix-dropdown-menu-content-available-height,400px)] w-64 max-w-[calc(100vw-24px)] flex-col overflow-y-auto` → **256 px wide**, bounded by the available viewport height (Radix measured; 400 px fallback), plus the menu surface (`MENU_STYLES.surface`: `rounded-xl` 12 px, `border --border`, `bg --bg`, `shadow-medium` = `0 4px 12px rgba(0,0,0,.1)`, padding `p-1` 4 px; `CONTENT_BASE_CLASSES` `dropdown-menu.tsx:128`, `styles.ts:11–13`). The content-level `max-w-[220px]` from `DropdownMenuContent` is overridden by `w-64`.
- `modal` is Radix default (`true`) — the header passes no `modal` prop, so scroll outside is locked while open and pointer-down outside closes.
- `onOpenChange` (479–498): ignores close requests while the context menu is open/opening or a rename is active; on open refetches stale `workspaceKeys.lists()` and `invitationKeys.mine()`; when search is shown, focuses the search input on the next frame.

Content order (top to bottom):
1. **"Back to organization"** (531–543, only when `organizationHref`): `DropdownMenuItem size='lg' asChild` → `SettingsGuardedLink href=organizationHref` with `ArrowLeft` 14 px; followed by a `DropdownMenuSeparator` (`mx-2 my-1 border-t --border`) only when search is **not** shown or the list is loading.
2. **Search field** (546–586, only when `workspaces.length >= 6`): `ChipInput icon={Search} placeholder='Search workspaces...'` (30 px chip field: `chipGeometryClass` + `chipFieldSurfaceClass` = `rounded-lg border --border-1 bg --surface-5 light / --surface-4 dark`), `shrink-0`, `mt-2` (8 px) when the organization row precedes it.
3. **List** (588–739): `div.-mx-1.5.flex.max-h-[200px].flex-col.gap-0.5.overflow-y-auto.px-1.5.pb-1` (+ `pt-1.5` when search is shown) with `scrollFadeClass` (12 px bands) → max 200 px tall scroll area, rows 2 px apart, 4 px bottom padding; the negative margin lets the fade run edge to edge of the menu's 4 px padding (*corrected 2026-10-22, parity sweep: the content box is 246 px (256 − 2 × 4 padding − 2 × 1 border), so the `-mx-1.5` list box is 258 px and overhangs the 256 px menu by 1 px on each side, over the border — x 7 for a menu at x 8; the port's menu scroll view spans that overhang so the list reports the whole box*).
   - "No results" (600–604): `div.px-2.py-[5px].text-[var(--text-muted)].text-caption` → `No results for "<query>"` (only when the query is non-empty).
   - Row (682–734): `DropdownMenuItem size='lg'` → `chipGeometryClass` (30 px, `px-2`, gap 6 px, 8 px radius, 14 px text, `--text-body`) + menu row chrome (`dropdownMenuRowClass`: hover/focus `--surface-hover`, `active` → `--surface-active` held through hover; icons 14 px `--text-icon`). With `action` the row is wrapped in `div.group/dropdownitem.relative` and gets `pr-[28px]` when an indicator or open action exists, otherwise only while hovered/focused (`dropdown-menu.tsx:352–379`). Children: `IdentityTile` 16 px + `DropdownMenuItemLabel label=name` (flex-1 `OverflowText`).
   - `actionIndicator`: `Pin` 12 px `--text-icon` (`role=img aria-label='Pinned'`) for pinned rows; fades out while the row is hovered so the `MoreHorizontal` action (18 px `DropdownMenuItemAction`, 16 px glyph, `aria-label='Workspace options'`) shows in the same slot (`RowActions` absolute at `right-1`, vertically centred).
   - `active` = current workspace **or** the row whose context menu is open **or** keyboard-highlighted (search mode + keyboard navigation).
   - Rename row (631–680): `SidebarRenameRow` = `div` with `chipVariants({active:true, fullWidth:true})` (30 px, `--surface-active`) → `leadingAdornment` `IdentityTile` + `<input type=text maxLength=100 class='w-full min-w-0 border-0 bg-transparent p-0 text-[var(--text-body)] text-sm outline-hidden'>` (autocomplete/correct/capitalize/spellcheck off), `aria-label='Rename workspace <name>'`.
4. **Separator** (741): `DropdownMenuSeparator className='mx-0 mt-0 shrink-0'` → full-width 1 px `--border`, 4 px below.
5. **Footer** (743–785): `div.flex.shrink-0.flex-col.gap-0.5`:
   - "New workspace" (`Plus` 14 px), `size='lg'`, `disabled={isCreatingWorkspace || !canCreateWorkspace}`; wrapped in a tooltip showing `creationPolicy.reason` when `canCreate === false`.
   - "Invite teammates" (`Send` 14 px), only when `userPermissions.canAdmin`; tooltip with `inviteDisabledReason` when set.
   - "View invitations" (`Mail` 14 px), only when `useMyPendingInvitations()` returns ≥ 1.
   - While `isWorkspacesLoading` the search, list, separator and footer are all omitted (544).

### Context menu (`WorkspaceContextMenu` → `ContextMenu`, 822–837; `workspace-context-menu.tsx`)
Same chrome as the tree menus (`sideOffset 4`, `max-w-[220px]`, rows 28 px 13 px). Items in render order:
1. Pin / Unpin (`Pin`/`PinOff` 14 px) — always shown.
2. Rename (`Pencil`) — always shown; disabled unless `workspace.permissions === 'admin'`.
3. Upload logo (`ImageUp`) — shown (handler always passed); disabled unless admin.
4. — separator — (present because Delete is always rendered).
5. Leave (`LogOut`) — shown when `sessionUserId && sessionUserId !== ownerId && !isOrgAdmin`.
6. Delete (`Trash`) — always shown; disabled unless admin **and** `workspaceCount > 1`.
Opened by right-click on a row or on the trigger (cursor position), or by the row's "…" (anchored at the button's top-right, 705–708). Closing the context menu also closes the switcher unless the action was Rename or Pin (`keepWorkspaceMenuOpenRef`, 340–354) or another context menu is opening.

### Modals (entry points)
- `CreateWorkspaceModal` (839–847): `ChipModal` "Create workspace" with one `ChipModalField type='input' title='Name' placeholder='Workspace name' maxLength=100 required`, `ChipModalError`, footer Cancel / "Create" ("Creating..." while pending, disabled when the trimmed name is empty). Enter submits (chip-modal default). Error text from the failed request stays in the modal.
- `DeleteModal itemType='workspace'` (859–866): title "Delete workspace", text "Are you sure you want to delete **name**? This will permanently remove all associated workflows, tables, files, logs, and knowledge bases. This action cannot be undone.", plus a `ChipModalField` "Type **name** to confirm" (placeholder = name); confirm "Delete" disabled until the typed text equals the name; `defaultAction='none'`.
- Leave confirm (867–883): `ChipConfirmModal` "Leave workspace" — "Are you sure you want to leave **name**? You will lose access to all workflows and data in this workspace. This action cannot be undone." confirm "Leave workspace" / "Leaving...". Failure → `toast.error("Couldn't leave workspace", { description })` (412–431).
- `InviteModal` and `ViewInvitationsModal`: separate spec.

### Parity ids
| id | element | React selector |
|---|---|---|
| `workspace.switcher.trigger` | trigger chip | `button[aria-label="Switch workspace"]` |
| `workspace.switcher.trigger.tile` | identity tile | `[data-slot], img` first child of the trigger |
| `workspace.switcher.trigger.label` | name | `[data-overflow-text]` in the trigger |
| `workspace.switcher.trigger.chevron` | chevron slot | last `span[aria-hidden]` in the trigger |
| `workspace.switcher.trigger.collapsed` | rail chip | `button[aria-label="Expand sidebar"]` |
| `workspace.switcher.menu` | dropdown content | `[role=menu]` opened by the trigger |
| `workspace.switcher.menu.org-link` | Back to organization | `[role=menuitem] a[href]` first row |
| `workspace.switcher.menu.search` | search field | `input[placeholder="Search workspaces..."]` |
| `workspace.switcher.menu.list` | list scroll area | `.max-h-\[200px\]` |
| `workspace.switcher.menu.row.<id>` | workspace row | `[data-workspace-row-idx]` / row by name |
| `workspace.switcher.menu.row.active` | current workspace row | row with `--surface-active` |
| `workspace.switcher.menu.row.pin` | pin indicator | `[role=img][aria-label=Pinned]` |
| `workspace.switcher.menu.row.more` | row action | `button[aria-label="Workspace options"]` |
| `workspace.switcher.menu.row.rename` | rename row | `input[aria-label^="Rename workspace"]` |
| `workspace.switcher.menu.empty` | no-results text | `.text-caption` inside the list |
| `workspace.switcher.menu.separator` | footer separator | `[role=separator]` |
| `workspace.switcher.menu.new` | New workspace | `[role=menuitem]` "New workspace" |
| `workspace.switcher.menu.invite` | Invite teammates | `[role=menuitem]` "Invite teammates" |
| `workspace.switcher.menu.invitations` | View invitations | `[role=menuitem]` "View invitations" |
| `workspace.switcher.context-menu` | row context menu | second `[role=menu]` |
| `workspace.switcher.context-menu.item.<pin|rename|upload-logo|leave|delete>` | items | `[role=menuitem]` by label |
| `workspace.switcher.create-modal` | Create workspace modal | `[role=dialog]` titled "Create workspace" |
| `workspace.switcher.delete-modal` | Delete workspace modal | `[role=dialog]` titled "Delete workspace" |
| `workspace.switcher.leave-modal` | Leave modal | `[role=dialog]` titled "Leave workspace" |

### Colour anchors
| anchor | point | expected (light / dark) |
|---|---|---|
| W1 | identity tile without logo: tile centre minus the letter (sample 2 px from the tile's corner) | `--surface-6` #e5e5e5 / #454545 |
| W2 | trigger chip at rest, 4 px inside its left edge, vertical centre | `--surface-1` (transparent chip over the sidebar) #fbfbfb / #1e1e1e |
| W3 | trigger chip hovered, same point | `--surface-hover` #f2f2f2 / #262626 |
| W4 | menu surface, 2 px inside its top-left corner | `--bg` #fefefe / #1b1b1b |
| W5 | menu border pixel | `--border` #d8d8d8 / #444444 |
| W6 | current-workspace row fill, 4 px from its left edge | `--surface-active` #ececec / #2c2c2c |
| W7 | search field fill (when ≥ 6 workspaces), 4 px inside its left edge | `--surface-5` #f3f3f3 / `--surface-4` #292929 |
| W8 | footer separator line | `--border` |

## Tokens
| Element | Tokens |
|---|---|
| Trigger chip | chip geometry 30 px / `px-2` / gap 6 px / radius 8 px; text `--text-body` 14 px; hover `--surface-hover`; disabled skeleton `opacity-60` not applied (plain disabled button) |
| Identity tile | 16 px, `rounded-sm` 4 px, `--surface-6` fill, letter `--text-icon` (dark `--text-secondary`) `text-micro` 10 px `leading-none`; logo `object-cover` |
| Chevron | 14 px `--text-icon` in a 16 px slot |
| Menu | `--bg`, `--border`, 12 px radius, `shadow-medium`, 4 px padding, 256 px wide |
| Rows (`lg`) | 30 px, 14 px `--text-body`, hover `--surface-hover`, active `--surface-active`, icons 14 px `--text-icon`, `transition-colors duration-0` |
| Pin indicator | 12 px `--text-icon` |
| Row action | 18 px button, 16 px `MoreHorizontal` `--text-icon`, `rounded-sm` |
| Search field | `ChipInput`: 30 px, `--surface-5`/`--surface-4`, border `--border-1`, text `--text-body` 14 px, placeholder `--text-muted`, icon 16 px `--text-icon` |
| No-results text | `text-caption` 12 px `--text-muted` |
| Separator | 1 px `--border`, `my-1` |
| Tooltips | emcn `Tooltip` (reason text) |
| Rename row | `--surface-active` fill, input `--text-body` 14 px |
| Modals | ChipModal rhythm (design system §1e) |

## States
| State | Behaviour | Source |
|---|---|---|
| Workspaces loading | Trigger is the disabled button variant (name from host context, or skeleton tile); if the menu were open, its body is omitted | 278, 544, 790–819 |
| Ready | Dropdown trigger active | 476 |
| Collapsed rail | Rail chip with tile ↔ `PanelLeft` swap on hover; click expands the sidebar; no menu | 449–475 |
| Menu open | Refetch of stale workspace list + my invitations; search focused (≥ 6) | 486–497 |
| Search shown (`workspaces.length >= 6`) | Filtering by case-insensitive `includes` on the trimmed query; highlight only drawn in keyboard mode; list `pt-1.5` | 213–218, 609, 596 |
| No results | "No results for "q"" row | 600–604 |
| Pinned | Row carries the `Pin` indicator; pinned rows sort first | 689–698; `workspace.ts:116–119` |
| Current | Row `active`; selecting it just closes | 607, 685; `sidebar.tsx:1194–1197` |
| Context menu open on a row | Row `active` and its action stays visible (`actionOpen`) | 608, 684–685 |
| Renaming | Row replaced by the rename row; menu cannot close via outside interaction (`onOpenChange` guard) until Enter/Escape/blur; if the menu is forced closed while editing with a changed name, the rename is saved | 301–309, 479–485, 631–680 |
| Create disabled | `creationPolicy.canCreate === false` → row disabled with tooltip `reason` (e.g. workspace cap, inactive organization subscription, permission group) | 279–281, 744–760 |
| Invite disabled | `isInvitationsDisabled` (permission config or `inviteDisabledReason`) → selecting navigates to Billing settings when `billingEnabled`, else no-op; tooltip with the reason | 282–296, 761–778 |
| Non-admin (`permissions !== 'admin'`) | Rename / Upload logo / Delete disabled in the context menu; "Invite teammates" hidden (`canAdmin` from workspace permissions context) | `workspace-context-menu.tsx:30,42–44`; 761 |
| Only one workspace | Delete disabled | `workspace-context-menu.tsx:44` |
| Owner or org-admin | Leave hidden | `workspace-context-menu.tsx:31–33` |
| Settings page dirty | Switching routes through `requestLeave` (discard dialog) after the menu closes | `sidebar.tsx:1192–1205` |
| Creating / deleting / leaving | "New workspace" disabled while creating; delete/leave modals show pending labels | 755, 859–883 |
| Error | Create → `ChipModalError` with the server message; leave → toast; delete/rename/update → logged only | `create-workspace-modal.tsx:47–51`, 412–431, `use-workspace-management.ts:115–196` |
| Hosted-only | Billing redirect on disabled invites (`billingEnabled`) — verified by review | 768 |

## Interactions

### Pointer
| Target | Action | Result | Source |
|---|---|---|---|
| Trigger chip | click | toggle menu | 477–499 |
| Trigger chip | right-click | context menu for the active workspace at the cursor | 504–508 |
| Rail chip (collapsed) | click | expand sidebar | 452 |
| Row | click | `onWorkspaceSwitch(workspace)` (see Switch); `preventDefault` on Radix `onSelect` so the menu close is driven by the handler | 686, 713–719 |
| Row | Cmd/Ctrl+click | `window.open('/workspace/{id}', '_blank')` | 714–717 |
| Row | middle-click (`auxclick` button 1) | same new tab | 720–725 |
| Row | right-click | context menu at cursor | 726 |
| Row | hover (`mousemove`) | in search mode: `highlightedId = id`, keyboard mode off (highlight not drawn); `mouseenter` is deliberately not used | 611–629 |
| Row "…" | click | context menu anchored at the button's `rect.right, rect.top`; `pointerdown` marks `isContextMenuOpeningRef` so the switcher stays open | 699–712 |
| Pointer move / leave over rows | — | `preventDefault` while the search input has focus, so hovering rows does not steal focus from the search field | 185–187, 687–688 |
| "Back to organization" | click | navigate to `organizationHref` via the settings-guarded link | 533–538 |
| "New workspace" | select | close menu, open Create modal (no-op when `!canCreateWorkspace`) | 745–759 |
| "Invite teammates" | select | close menu; open `InviteModal`, or go to Billing settings when invitations are disabled | 763–777 |
| "View invitations" | select | close menu; open `ViewInvitationsModal` | 779–784 |
| Outside pointer-down / Escape | — | closes (Radix), unless a context menu or rename is active | 479–485 |

### Keyboard
| Key | Context | Effect | Source |
|---|---|---|---|
| Enter / Space / ArrowDown | trigger focused | Radix opens the menu (focus moves to content; search focused by rAF when shown) | Radix, 495–497 |
| ArrowDown / ArrowUp | search input (≥ 6 workspaces) | move `highlightedId` cyclically through `filteredWorkspaces` (wraps); `isKeyboardNav=true` so the highlight is drawn; highlighted row `scrollIntoView({block:'nearest'})`; `stopPropagation` keeps Radix from also moving focus | 559–573, 236–242 |
| Enter | search input | switch to the highlighted workspace — only after a cursor is armed (`isKeyboardNav`); otherwise ignored | 574–583 |
| typing | search input | filters; keyboard mode on; highlight re-seeded to the first result when the current one is filtered out | 553–558, 252–256 |
| ArrowDown / ArrowUp / Home / End / Enter / Escape | menu (no search) | Radix roving focus over rows and footer items; Enter activates the row's `onClick` via Radix `onSelect`… note `onSelect` is `preventDefault`ed, and the switch is wired to `onClick` — Enter on a row therefore triggers Radix's click emulation and switches | 682–719 |
| ArrowRight / ArrowLeft | row ↔ "…" action | move focus into/out of the action button | `dropdown-menu.tsx:324–350` |
| Enter / Escape / blur | rename input | Enter saves (trimmed) then exits; Escape exits without saving; blur saves if changed | 651–678 |
| IME composition | search input | ignored while `isComposing` | 561 |
No global shortcut opens the switcher.

### Switch (`use-workspace-management.ts:132–153`, `sidebar.tsx:1192–1205`)
1. Same workspace → just close the menu.
2. Otherwise close the menu first, then `requestLeave(cb)` (settings dirty guard; immediate when clean).
3. `switchToWorkspace(id)` on the workflow registry: resets workflow/subblock stores, clears the operation-queue error, invalidates workflow lists for the new workspace, sets `hydration.workspaceId` (`registry/store.ts:57–77`).
4. `router.push(href)` where `href = /workspace/{id}` or, when currently on `/workspace/{current}/settings/{section}/…`, `/workspace/{id}/settings/{section}` (`resolveWorkspaceSwitchHref`, 36–51).
5. The destination route's sidebar then records the visit (below), which moves the workspace to the front of the list.

### Last-active / visit recording (`use-workspace-management.ts:108–110`, `workspace.ts:156–186`)
On every mount or change of `workspaceId` while signed in: `POST /api/workspaces/{id}/visit` → `{ success: true }`. Optimistic: the cached `/api/workspaces` response gets `lastActiveWorkspaceId = id` and the visited workspace moved to index 0. Mutations are serialised (`scope: { id: 'workspace-visit' }`); `workspaceKeys.lists()` is invalidated only when no later visit is still queued. The server orders `workspaces` "most recently visited first, then newest first" (`contracts/workspaces.ts:172`); `lastActiveWorkspaceId` is consumed by the `/workspace` entry redirect (entry-resolution spec), not by the switcher.

### Ordering
`selectOrderedWorkspaces` (`workspace.ts:116–119`): stable sort of the server list with pinned workspaces first (`pinnedWorkspaceIds` from the same payload); within each partition the server's recency order is kept. Search filtering preserves that order.

### Pin / unpin (`workspace.ts:213–280`)
Context menu "Pin"/"Unpin" → `toggleWorkspacePin(id)` → `pinned = !pinnedWorkspaceIds.has(id)`:
- pin: `POST /api/pinned-items` body `{ workspaceId: id, resourceType: 'workspace', resourceId: id }` → `{ pinnedItem }`; a `409` is treated as success.
- unpin: `DELETE /api/pinned-items/workspace/{id}` → `{ success: true }`; a `404` is treated as success.
- Optimistic: `pinnedWorkspaceIds` in the cached list response is updated (`applyPinToggle`); on error the toggle is reverted (not snapshot-restored); mutations serialised with `scope 'workspace-pin'`; `workspaceKeys.lists()` invalidated when the queue drains. The switcher stays open (`keepWorkspaceMenuOpenRef`), so the row visibly moves into/out of the pinned group.
- Pins are read from `GET /api/workspaces` (`pinnedWorkspaceIds`), **not** from `GET /api/pinned-items` (`contracts/pinned-items.ts:15–20`). `hooks/queries/pinned-items.ts` serves the other resource types.

### Rename (359–367, 631–680)
Context menu "Rename" → `editingWorkspaceId = id`, `editingName = name`, menu kept open; the rename row mounts, focuses and selects the text once (`hasInputFocusedRef`). Save → `onRenameWorkspace(id, trimmed)` → `PATCH /api/workspaces/{id}` body `{ name }` (server trims; `name` min 1) → `{ workspace }`; no optimistic update; `onSettled` invalidates `workspaceKeys.lists()` and `workspaceKeys.detail(id)`. Empty trimmed value: Enter still calls the handler with `''` (server rejects with 400; the row exits edit mode) — blur path skips empty values. Escape discards.

### Upload logo (404–407; `sidebar.tsx:1220–1227, 526–539`)
Context menu "Upload logo" → hidden `<input type=file accept=LOGO_ACCEPT_ATTRIBUTE>` click; on completion `updateWorkspace(targetId, { logoUrl })` → `PATCH /api/workspaces/{id}` `{ logoUrl }` (must start with `/` or `https://`, nullable). Upload transport is in `use-workspace-logo-upload.ts` (separate spec).

### Create (155–170; modal above)
`POST /api/workspaces` body `{ name }` → `{ workspace }`; on success the row is prepended to the cached list (`workspace.ts:298–312`), lists + admin lists invalidated, then `switchWorkspace(newWorkspace)` navigates to `/workspace/{id}`. Modal closes after `onConfirm` resolves; errors stay in the modal.

### Delete (172–196; 372–381, 436–445)
Context menu "Delete" → menu closes, `DeleteModal` with typed-name confirmation → `DELETE /api/workspaces/{id}` body `{}` → `{ success: true }`; `onSettled` invalidates lists + detail; if the deleted workspace is the current one, switch to the first other workspace in the cached list.

### Leave (198–229; 386–395, 412–431)
Context menu "Leave" → menu closes, confirm modal → `DELETE /api/workspaces/members/{userId}` body `{ workspaceId }` (`removeWorkspaceMemberContract`); `onSettled` invalidates permissions, lists, detail; if leaving the current workspace, switch to the first other one; failure toasts the server reason.

## Network and realtime
Query keys (`workspace.ts:40–52`): `['workspace','list','user','active']` is shared by `useOrderedWorkspacesQuery`, `usePinnedWorkspaceIds`, `useWorkspaceCreationPolicy` and `useWorkspacesWithMetadata` (different `select`s); `staleTime` `WORKSPACE_LIST_STALE_TIME = 30 000` ms; `placeholderData: keepPreviousData` on `useWorkspacesQuery` only. `['invitations','mine']`-style key via `invitationKeys.mine()` with `MY_INVITATIONS_STALE_TIME`.

Order of requests on a workspace route:
1. `GET /api/workspaces?scope=active` → `{ workspaces: Workspace[], lastActiveWorkspaceId: string|null, pinnedWorkspaceIds: string[], creationPolicy: { canCreate, workspaceMode, organizationId, maxWorkspaces, currentWorkspaceCount, reason, blockedReasonCode? } | null }`. Fields used from `Workspace`: `id, name, logoUrl, ownerId, organizationId, permissions ('admin'|'write'|'read'|null), isOrgAdmin, inviteDisabledReason, inviteMembersEnabled, inviteUpgradeRequired` (normalised defaults `false`/`null`/`false`). Hydrated by the workspace layout's server prefetch when available.
2. `POST /api/workspaces/{ws}/visit` (effect, once per `workspaceId`).
3. On menu open: refetch (1) if stale and `GET /api/invitations` (`listMyInvitationsContract`, `contracts/invitations.ts:296–298`; `useMyPendingInvitations`) if stale; the "View invitations" item mounts `useMyPendingInvitations` so the fetch happens on first open.
Mutations: visit, pin/unpin, create, update (rename/logo), delete, leave — as detailed above. No socket events for the switcher.

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | sidebar.tsx:1396–1402,1443–1450 | Header row `px-2 pt-2`; workspace chip fills the width minus the 65 px trailing cluster | | |
| 2 | layout | workspace-header.tsx:500–519, chrome.ts:58 | Trigger chip 30 px, `px-2`, gap 6 px, radius 8 px; tile 16 px, name, 14 px chevron | | |
| 3 | token | identity-tile.tsx:17–20,63 | Tile `rounded-sm`, `--surface-6`, letter `--text-icon` 10 px (dark `--text-secondary`); logo `object-cover` | | |
| 4 | interaction | initials.ts:5–8 | Initial ignores the word "workspace" ("Acme Workspace" → "A") | | |
| 5 | state | workspace-header.tsx:278,790–819 | Disabled chip with the host-context name (or skeleton tile) until the list resolves; no layout shift when it does | | |
| 6 | layout | workspace-header.tsx:449–475, constants.ts:50 | Collapsed rail: 32 px chip; tile swaps to a rotated `PanelLeft` on hover; click expands | | |
| 7 | layout | workspace-header.tsx:521–530 | Menu 256 px wide, `sideOffset 8`, `align start`, max height = available height (400 px fallback) | | |
| 8 | token | styles.ts:11–13 | Menu `--bg`, `--border`, 12 px radius, `shadow-medium`, 4 px padding | | |
| 9 | layout | workspace-header.tsx:531–543 | "Back to organization" first row (ArrowLeft 14 px) when an organization href exists; separator only without search | | |
| 10 | state | constants.ts:2, workspace-header.tsx:213,546 | Search field appears at ≥ 6 workspaces; `mt-2` under the org row | | |
| 11 | token | chip-input.tsx:72–73, chrome.ts:9,2 | Search field 30 px chip field: `--surface-5`/`--surface-4`, border `--border-1`, `Search` icon, placeholder "Search workspaces..." | | |
| 12 | interaction | workspace-header.tsx:495–497 | Search input focused when the menu opens | | |
| 13 | layout | workspace-header.tsx:588–599 | List max 200 px tall, rows 2 px apart, `-mx-1.5 px-1.5 pb-1`, `pt-1.5` with search, scroll fade | | |
| 14 | layout | dropdown-menu.tsx:269, workspace-header.tsx:682–734 | Rows `size='lg'` = 30 px chip geometry; tile 16 px + label | | |
| 15 | token | dropdown-menu.tsx:55–59 | Row hover `--surface-hover`; current/menu-open/keyboard-highlighted row `--surface-active` | | |
| 16 | layout | workspace-header.tsx:689–698, dropdown-menu.tsx:357–362 | Pinned rows: `Pin` 12 px indicator, `pr-[28px]`; indicator fades to the "…" action on hover | | |
| 17 | layout | dropdown-menu.tsx:418 | Row action 18 px, `MoreHorizontal` 16 px, anchored `right-1` | | |
| 18 | interaction | workspace.ts:116–119 | Pinned workspaces first, then server recency order | | |
| 19 | interaction | workspace-header.tsx:215–218 | Search filters by case-insensitive substring of the trimmed query | | |
| 20 | state | workspace-header.tsx:600–604 | `No results for "q"` in 12 px `--text-muted` | | |
| 21 | keyboard | workspace-header.tsx:559–583 | Arrow keys cycle the highlight (wrapping), Enter switches only after keyboard navigation began | | |
| 22 | interaction | workspace-header.tsx:609,611–629 | Highlight drawn only in keyboard mode; pointer hover (mousemove) updates the target without drawing | | |
| 23 | interaction | workspace-header.tsx:236–242 | Highlighted row scrolled into view (`nearest`) | | |
| 24 | state | workspace-header.tsx:267–272 | Query, highlight and keyboard mode reset on close | | |
| 25 | interaction | workspace-header.tsx:713–725 | Click switches; Cmd/Ctrl-click and middle-click open `/workspace/{id}` in a new tab | | |
| 26 | interaction | sidebar.tsx:1192–1205, use-workspace-management.ts:132–153 | Switching closes the menu, runs the settings dirty guard, resets workflow stores, pushes `/workspace/{id}` (settings section preserved) | | |
| 27 | network | workspace.ts:156–186, contracts/workspaces.ts:187–195 | `POST /api/workspaces/{id}/visit` on every workspace entry; optimistic move to the front; serialised | | |
| 28 | network | workspace.ts:61–67,138–146, workspace-list-query.ts:3 | List key `['workspace','list','user','active']`, staleTime 30 s; fields `workspaces`, `pinnedWorkspaceIds`, `creationPolicy`, `lastActiveWorkspaceId` | | |
| 29 | network | workspace-header.tsx:486–492 | Opening the menu refetches stale workspace list and my invitations | | |
| 30 | interaction | workspace-context-menu.tsx:36–46, context-menu.tsx | Context menu: Pin/Unpin, Rename, Upload logo, ─, [Leave], Delete; admin gating; Delete disabled with one workspace; Leave hidden for owner/org-admin | | |
| 31 | interaction | workspace-header.tsx:699–712,316–324 | "…" opens the context menu at the button's top-right; right-click at the cursor; row marked active while open | | |
| 32 | interaction | workspace-header.tsx:340–354 | Closing the context menu closes the switcher except after Rename or Pin | | |
| 33 | network | workspace.ts:213–280, contracts/pinned-items.ts:75–97 | Pin → `POST /api/pinned-items {workspaceId, resourceType:'workspace', resourceId}`; unpin → `DELETE /api/pinned-items/workspace/{id}`; 409/404 tolerated; optimistic toggle with revert | | |
| 34 | interaction | workspace-header.tsx:359–367,631–680, sidebar-rename-row.tsx | Rename row replaces the row with an active-fill input (maxLength 100), focused and selected; Enter/blur save, Escape cancels | | |
| 35 | state | workspace-header.tsx:301–309,479–485 | Menu cannot be dismissed while renaming; a forced close saves a changed name | | |
| 36 | network | workspace.ts:352–365, contracts/workspaces.ts:396–407 | Rename/logo → `PATCH /api/workspaces/{id}` `{ name }` / `{ logoUrl }`; invalidates lists + detail; not optimistic | | |
| 37 | interaction | workspace-header.tsx:744–760,279–281 | "New workspace" disabled with tooltip `reason` when `creationPolicy.canCreate` is false; otherwise opens the Create modal | | |
| 38 | interaction | create-workspace-modal.tsx:59–85 | Create modal: Name field (max 100), Create disabled when empty, "Creating..." pending, error text inline | | |
| 39 | network | workspace.ts:289–316, use-workspace-management.ts:155–170 | `POST /api/workspaces {name}`; new row prepended; then switch to it | | |
| 40 | interaction | workspace-header.tsx:761–778 | "Invite teammates" only for admins; disabled-reason tooltip; disabled → Billing settings when billing is enabled | | |
| 41 | state | view-invitations-menu-item.tsx:17–29 | "View invitations" only with ≥ 1 pending invitation | | |
| 42 | interaction | delete-modal.tsx:68–75,182–194,224–238 | Delete workspace requires typing the exact name; Enter does not confirm | | |
| 43 | network | workspace.ts:326–341, use-workspace-management.ts:172–196 | `DELETE /api/workspaces/{id}` `{}`; switch to another workspace when deleting the current one | | |
| 44 | network | invitations.ts:400–421, use-workspace-management.ts:198–229 | Leave → `DELETE /api/workspaces/members/{userId}` `{ workspaceId }`; switch away when leaving the current one; toast on failure | | |
| 45 | layout | workspace-header.tsx:741 | Footer separator full width (`mx-0 mt-0`) | | |
| 46 | keyboard | dropdown-menu.tsx:324–350 | ArrowRight/ArrowLeft move between a row and its "…" action | | |

## Ambiguities and later-phase dependencies
- `side='right' sideOffset={16}` for the collapsed case (523–524) is unreachable: the collapsed branch renders the rail chip without a menu.
- `stores/sidebar/store.ts` has a `workspaceDropdownOpen` flag, but the header's open state is `useState` in `sidebar.tsx:457`; port the local state.
- Enter on a row without search: the row's `onSelect` is `preventDefault`ed and switching is bound to `onClick`; Radix's keyboard activation dispatches a click, so Enter switches. Verify in the browser during parity capture.
- Hover-peek (macOS desktop shell only) renders the expanded header inside the peek card; on web/Windows the collapsed rail shows the rail chip.
- `GET /api/invitations` (`listMyInvitationsContract`) has no query parameters in the contract; the response shape (`myInvitationSchema[]`) is consumed by the invite modal spec.
- `workspace-sidebar.md` also maps the switcher chip and menu at shell level with ids `shell.sidebar.header.workspace*`; this spec's `workspace.switcher.*` ids are the detailed set. The verifier should treat `shell.sidebar.header.workspace` ≡ `workspace.switcher.trigger` and `shell.sidebar.header.workspace.menu` ≡ `workspace.switcher.menu`.
- `creationPolicy.reason` strings are server-authored; render verbatim.
- Logo upload transport (`use-workspace-logo-upload.ts`) and the Invite / View-invitations modals are specified with the workspace modals.
- Hosted-only: the Billing redirect for disabled invitations (`billingEnabled`) is verified by review on the self-hosted stack.
