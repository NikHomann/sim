# Workspace modals (create, rename/logo "settings", invite, delete, leave, pending invitations)
Upstream: `app/workspace/[workspaceId]/w/components/sidebar/components/workspace-header/components/**`, `app/workspace/[workspaceId]/components/invite-modal/**`, `hooks/use-workspace-invite-policy.ts`, `app/workspace/[workspaceId]/w/components/sidebar/components/workflow-list/components/delete-modal/delete-modal.tsx`, `packages/emcn/src/components/chip-modal/chip-modal.tsx`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

Paths relative to `apps/sim/` unless stated. All of these open from the workspace switcher in `workspace-sidebar.md`.

**Ambiguity recorded:** the brief asks for a "workspace settings modal (name/logo upload via upload session)". At this commit there is no such modal in the switcher: renaming is an inline row inside the switcher list and the logo is uploaded from the row's context menu through a hidden file input (`workspace-header.tsx:359–367, 404–407, 631–680`; `sidebar.tsx:1220–1227, 1366–1372`). Both flows are specified below under "Rename and logo"; the General settings page (`settings/general`) that also edits name/logo is Phase 5.

## Files

| File | Lines |
|---|---|
| `…/workspace-header/components/create-workspace-modal/create-workspace-modal.tsx` | 87 |
| `…/workspace-header/components/pending-invitations/view-invitations-modal.tsx` | 222 |
| `…/workspace-header/components/pending-invitations/view-invitations-menu-item.tsx` | 30 |
| `app/workspace/[workspaceId]/components/invite-modal/invite-modal.tsx` | 370 |
| `app/workspace/[workspaceId]/components/invite-modal/index.ts` | 1 |
| `hooks/use-workspace-invite-policy.ts` | 48 |
| `…/workflow-list/components/delete-modal/delete-modal.tsx` | 241 |
| `…/workspace-header/workspace-header.tsx` | 888 (rename row 631–680, leave modal 867–883, modal wiring 839–866) |
| `…/sidebar/components/sidebar-rename-row.tsx` | 39 |
| `…/sidebar/hooks/use-workspace-logo-upload.ts` | 142 |
| `lib/uploads/client/logo-file.ts` | 24 |
| `lib/uploads/client/session-upload.ts` / `upload-session.ts` | 256 / 380 |
| `hooks/queries/workspace.ts` | 530 (`useCreateWorkspace` 289–316, `useDeleteWorkspace` 326–341, `useUpdateWorkspace` 352–365, `useAdminWorkspaces` 518–530) |
| `hooks/queries/invitations.ts` | 468 (`useSendWorkspaceInvitations` 240–286, `useLeaveWorkspace` 400–425, `useMyPendingInvitations` 155–161, `useAcceptMyInvitation` 176–213, `useDeclineMyInvitation` 216–226) |
| `hooks/queries/organization-plan-seats.ts` | — (`GET /api/organizations/[id]/billing-plan`) |
| `lib/api/contracts/workspaces.ts` | create 197–207, update 396–407, delete 409–420 |
| `lib/api/contracts/invitations.ts` | batch 59–135, 246–254; list mine 296–305; accept 307–316; reject 318–326; remove member 365–375 |
| `lib/invitations/limits.ts` | `MAX_INVITE_WORKSPACES = 50`, `MAX_INVITE_EMAILS = 100` |
| `lib/messaging/email/validation.ts` | `quickValidateEmail` (66–) |
| `packages/emcn/src/components/chip-modal/chip-modal.tsx` | 1755 |
| `packages/emcn/src/components/modal/modal.tsx` | overlay 397–431, content animation 631, size map 453–457 |
| `packages/emcn/src/components/chip-emails-input/chip-emails-input.tsx` | ~200 |
| `packages/emcn/src/components/chip-dropdown/chip-dropdown.tsx` | multiple/searchable 120–160, 231–276 |

## Layout

### Shared ChipModal chrome (every modal here)
- Overlay: `fixed inset-0 z-[var(--z-modal)] bg-black/10 backdrop-blur-[2px]` (`modal.tsx:421`); content animates `zoom-in-95` / `zoom-out-95` over 200 ms (`:631`).
- Sizes (`modal.tsx:453–457`): `sm` `w-[90vw] max-w-[440px]`, `md` `max-w-[500px]`, `lg` 600, `xl` 800, `full` `w-[95vw] max-w-[1200px]`. `ChipModal` defaults to `md` (`chip-modal.tsx:276`); `ChipConfirmModal` defaults to `sm` (`:1669`).
- Surface (`chip-modal.tsx:234–245`): outer ring `flex min-h-0 w-full flex-col rounded-xl border border-[var(--border-muted)] bg-[var(--surface-4)] p-[3px] text-small dark:bg-[var(--surface-5)]`; inner `flex min-h-0 flex-1 flex-col overflow-hidden rounded-lg border border-[var(--border-1)] bg-[var(--bg)]`. `--border-1` and `--border-muted` are both aliases of `--border` in light and dark (`globals.css:730–731, 894–895`); they are not in `02-design-system.md` §1a and should be added to `SimTokens` as aliases.
- Header (`:336–357`): `flex min-w-0 items-center justify-between gap-2 px-4 pt-3`; title `chipContentLabelClass` (`text-sm --text-body`), optional 16px icon; close `Button variant='ghost'` 14×14 with a 14px hit extension (`before:inset-[-14px]`), `X` 14px `--text-icon`; then `ChipModalSeparator` (`h-px bg-[var(--border)]`) with `mt-3`.
- Body (`:440–452`): `flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto overflow-x-hidden px-2 pt-4 pb-4.5` (16px gap, 8px gutters, 16px top, 18px bottom).
- Field (`:724–770`): `flex flex-col gap-[9px] px-2`; title row `Label` `text-small` `--text-muted` (required marker `ml-0.5 --text-error`); control; field error `<p role='alert' class="text-[var(--text-error)] text-caption">`; hint `<p class="text-[var(--text-muted)] text-caption">`. `ChipModalError` (form-level): `mt-1 px-2 text-[var(--text-error)] text-caption`, renders nothing when empty (`:1729–1736`).
- Footer (`:1267–1292`): separator + `flex items-center gap-x-2 gap-y-1.5 bg-[var(--surface-3)] px-4 pt-2 pb-2`; actions cluster right-aligned `flex shrink-0 gap-2`; every action is a 30px `Chip` ("Cancel" default chip; primary `variant='primary'`; confirm `variant='destructive'` by default).
- Keyboard: `Escape`, overlay click and the X all route through `onOpenChange(false)` (`:1518`) and are refused while an action is pending (`dismissDisabled`, `:212–216`); `Enter` inside the modal activates the element tagged `data-chip-modal-default-action` (the primary action for `ChipModalFooter` `defaultAction='primary'`, the dismiss chip for `defaultAction='dismiss'`, the confirm chip for `'confirm'`, nothing for `'none'`) unless the focused control owns Enter (`:78–104`). `ChipConfirmModal` defaults to `defaultAction='dismiss'`, `dismissLabel='Cancel'` (`:1667–1668`).
- Confirm text (`ChipModalDescription`, `:257–262`): `whitespace-pre-wrap break-words px-2 text-[var(--text-primary)] text-sm`; `{bold:true}` segments → `<strong class="font-medium">`, `{error:true}` → `text-[var(--text-error)]` (`:1496, 1504`).

### Parity ids
`modal.create-workspace` · `modal.create-workspace.name` · `modal.create-workspace.submit` · `modal.invite` · `modal.invite.emails` · `modal.invite.workspaces` · `modal.invite.access` · `modal.invite.membership` · `modal.invite.error` · `modal.invite.submit` · `modal.delete-workspace` · `modal.delete-workspace.confirm-input` · `modal.delete-workspace.confirm` · `modal.leave-workspace` · `modal.leave-workspace.confirm` · `modal.invitations` · `modal.invitations.row` · `modal.invitations.accept` · `modal.invitations.decline` · `sidebar.workspace.rename-row` · `sidebar.workspace.logo-input`.

One implementation serves every entry point: `lib/features/workspace_shell/modals/` (`showCreateWorkspaceModal`, `showDeleteWorkspaceModal`, `showLeaveWorkspaceModal`, `showInviteModal`, `showPendingInvitationsModal`, `WorkspaceLogoUploader`). The switcher spec's `workspace.switcher.create-modal`, `workspace.switcher.delete-modal` and `workspace.switcher.leave-modal` are aliases of `modal.create-workspace`, `modal.delete-workspace` and `modal.leave-workspace`; captures use the `modal.*` ids (corrected 2026-10-22).

### Colour anchors (modal rects from the capture; dpr 1)
| # | Point | Light | Dark | Source |
|---|---|---|---|---|
| M1 | overlay at (40, 40) over a `--bg` pane | `--bg` darkened by 10 % black (`#e5e5e5` on #fefefe) | #181818 on #1b1b1b | `modal.tsx:421` |
| M2 | outer ring (modal.left+1, modal.top+1) | `--surface-4` #f5f5f5 | `--surface-5` #363636 | `chip-modal.tsx:234` |
| M3 | inner surface (modal.left+12, modal.top+12) — header gutter | `--bg` #fefefe | #1b1b1b | `:243` |
| M4 | header separator (modal.centerX, header.bottom) | `--border` #d8d8d8 | #444444 | `:63, 356` |
| M5 | footer band (modal.left+12, footer.centerY) | `--surface-3` #f7f7f7 | #242424 | `:1287` |
| M6 | primary action chip centre, right edge (chip.right−4, chip.centerY) | `--text-primary` #1a1a1a | white | `chrome.ts:16–17` |
| M7 | destructive confirm chip (chip.right−4, chip.centerY) | `--text-error` #ef4444 | #ef4444 | `chip.tsx:73–74` |
| M8 | emails field surface (field.left+4, field.centerY) | `--surface-5` #f3f3f3 | `--surface-4` #292929 | `chrome.ts:2–9` |

## Tokens

| Element | Tokens |
|---|---|
| Ring / inner / header / body / footer | see chrome above (`--surface-4`/`-5`, `--border-muted`, `--border-1`, `--bg`, `--border`, `--surface-3`) |
| Field title | `--text-muted` `text-small` |
| Field error / form error | `--text-error` `text-caption` |
| Hint | `--text-muted` `text-caption` |
| Inputs (`ChipInput`, textarea, emails, dropdown trigger) | `chipFieldSurfaceClass` = `rounded-lg border border-[var(--border-1)] bg-[var(--surface-5)] dark:bg-[var(--surface-4)]`; text `--text-body` `text-sm`; placeholder `--text-muted` |
| Dropdown trigger | `chipVariants({variant:'filled'})` + `TRIGGER_BORDER_CLASS` (`border --border-1`), chevron 16px |
| Primary / destructive chips | `chipPrimaryFillTokens` (`--text-primary` fill, `--text-inverse` text; dark white/`--bg`) / `--text-error` fill white text |
| Confirm copy | `--text-primary` `text-sm`; bold `font-medium`; error runs `--text-error` |
| Invitation rows (`ViewInvitationsModal`) | `IdentityTile` 16px, `ChipTag variant='gray'` (bg #e7e5e4 / text #57534e light; #3a3a3a / #a8a8a8 dark), separator `--border` |

## States

### Create workspace (`modal.create-workspace`, `create-workspace-modal.tsx:415–476`)
- `ChipModal` (md, 500px), `srTitle='Create workspace'`; header "Create workspace".
- Field "Name": `ChipModalField type='input'`, placeholder "Workspace name", `maxLength=100`, `autoComplete='off'`, `required`, disabled while creating. `ChipModalError` below.
- Footer: Cancel (disabled while creating) + primary "Create" / "Creating..." disabled when `name.trim()` is empty or creating. `Enter` submits (primary is the default action).
- Open resets name and error (424–431). Submit: `onConfirm(trimmed)` → `useCreateWorkspace` → on success close and switch to the new workspace; on error the message (`getErrorMessage(err, 'Failed to create workspace')`) shows in `ChipModalError` and the modal stays open (433–441).
- Entry: switcher "New workspace" (hidden/disabled by `creationPolicy.canCreate === false` with `reason` tooltip, `workspace-header.tsx:279–281, 744–760`).

### Rename and logo (no modal)
- Rename (`workspace-header.tsx:359–367, 631–680`): the switcher stays open; the row becomes `SidebarRenameRow` (`chipVariants({active:true, fullWidth:true})` wrapper, leading `IdentityTile`, `<input type='text' maxLength=100 autoComplete/autoCorrect/autoCapitalize off spellCheck=false>` `text-sm --text-body` transparent; `aria-label="Rename workspace {name}"`), focused with the text selected. `Enter` → `onRenameWorkspace(id, trimmed)` then exit; `Escape` → exit without saving; blur → save when trimmed non-empty and changed, then exit; the input is disabled while saving. If the switcher closes mid-edit the pending change is saved (301–309). Allowed only for `permissions === 'admin'` (context-menu item disabled otherwise).
- Logo (`sidebar.tsx:1220–1227, 1366–1372`; `use-workspace-logo-upload.ts`): context-menu "Upload logo" (admin only) sets the target workspace and clicks a hidden `<input type='file' accept='image/png,image/jpeg,image/jpg,image/gif,image/svg+xml,image/webp'>`. `validateLogoFile`: > 5 MB → `File "{name}" is too large. Maximum size is 5MB.`; wrong type → `File "{name}" is not a supported image format. Please use PNG, JPEG, GIF, SVG, or WebP.`; errors go to `onError` (logged, **no UI** in the sidebar). Valid file: object-URL preview → `uploadInternalFileSession({purpose:'workspace_logo', file, workspaceId})` → `PATCH /api/workspaces/[id] {logoUrl: result.path}`; failure reverts the preview to the previous logo. The input value is cleared after each pick.
- Upload session protocol (`session-upload.ts:106–160`, `upload-session.ts`): `POST /api/files/uploads` body `{purpose:'workspace_logo', workspaceId, name, contentType, size} (field is `name` per `internalUploadBody` in `session-upload.ts`; corrected 2026-10-22)` → `{session{id, purpose,…}, uploadToken, transfer}`; `transfer.method === 'put'` → one `PUT` to `transfer.url` with the file (XHR progress), else multipart: `POST /api/files/uploads/[uploadId]/parts {partNumbers}` → signed part URLs in batches, `PUT` each part with concurrency 3 (`PART_UPLOAD_CONCURRENCY`), part size `transfer.partSize`; then `POST /api/files/uploads/[uploadId]/complete` → `{data{purpose, result{path,…}}}`; on failure `DELETE /api/files/uploads/[uploadId]`; `MAX_RETRIES = 3` with `backoffWithJitter` honouring `retryAfterMs`; a 409 on retry of a create-only `PUT` counts as success.

### Invite teammates (`modal.invite`, `invite-modal.tsx:110–370`)
- `ChipModal` (md, 500px), `srTitle="Invite teammates to {workspaceName|'workspace'}"` (or "organization" when `organizationOnly`); header "Invite teammates".
- Props from the switcher: `workspaceId`, `workspaceName`, `organizationId` (= `activeWorkspace.organizationId`), `inviteDisabledReason` (= `workspace.inviteDisabledReason`), `canInvite` (= `userPermissions.canAdmin`) (`workspace-header.tsx:849–857`).
- On every open the form resets: `emails=[]`, `selectedWorkspaceIds=[workspaceId]`, `access='write'`, `membership='member'`, `errorMessage=null` (133–143).
- Fields, in order:
  1. "Emails" (`type='emails'`, `ChipEmailsInput` variant `block`): tokens added on Enter/comma/space/paste (paste splits on whitespace, commas, semicolons), lowercased, de-duplicated, Backspace removes the last chip; `validate(email)`: `quickValidateEmail` failure reason (e.g. "Invalid email format") or "You cannot invite yourself" when it equals the session email; placeholder "Enter emails" (after the first chip "Add email", per `derivePlaceholderWithTags`; corrected 2026-10-22), or when `!canInvite`: `inviteDisabledReason || 'Only administrators can invite new teammates'`; `hint = inviteDisabledReason ?? seatLimitReason`; disabled while submitting or `!canInvite`. Field errors render inside the emails control itself (`chip-modal.tsx:766`).
  2. "Workspaces" (custom field; hidden when `organizationOnly`): `ChipDropdown multiple fullWidth allLabel='Select workspaces' showAllOption={false} searchable={isOrganizationInvite} searchPlaceholder='Search workspaces...'`; options: personal workspace → `[{value: workspaceId, label: workspaceName ?? 'This workspace'}]`; organization → `useAdminWorkspaces(userId, organizationId)` (`GET /api/workspaces` filtered to `permissions==='admin'` and that organization, `inviteMembersEnabled` → `canInvite`) filtered to `canInvite || id === workspaceId`; disabled when submitting, `!canInvite`, or ≤ 1 option. Trigger label: the single selected option's label, or `allLabel` ("Select workspaces") when none/several (`chip-dropdown.tsx:268–276`).
  3. "Workspace access" (`type='dropdown'`, hidden when `organizationOnly`): Admin `admin` / Write `write` / Read `read`; default `write`; placeholder "Select access"; `align='start'`.
  4. "Organization membership" (`type='dropdown'`, only when `organizationId`; titled "Role" when `organizationOnly`): Member `member` / Admin `admin` (only when `canGrantOrganizationAdmin` = `isOrganizationAdmin ?? (hostContext.hostOrganizationId === organizationId && hostContext.viewer.isHostOrganizationAdmin)`) / External `external` (not when `organizationOnly`); default `member`; hint for `external`: "Access to the selected workspaces only — no seat. Only available for people already on a paid Sim plan."
  5. `ChipModalError` with `errorMessage`.
- Seats (advisory, Enterprise only): when `open && billingEnabled && canGrantOrganizationAdmin`, `GET /api/organizations/[id]/billing-plan` → `data{totalSeats, usedSeats, subscriptionPlan}`; if `subscriptionPlan === 'enterprise'` and `totalSeats > 0` and `membership !== 'external'` and `emails.length > available`: hint "Only {n} seat(s) available — invites beyond that may fail. External collaborators and existing members do not use seats." (196–220). Hosted-only → review.
- Footer: Cancel (disabled while submitting) + primary "Send invites" / "Sending..."; disabled when `!canInvite`, `inviteDisabledReason`, submitting, no emails, no workspace selected (unless `organizationOnly`), or `organizationOnly && !canGrantOrganizationAdmin` (286–292).
- Submit (241–284): `POST /api/workspaces/invitations/batch` `{workspaceIds, emails, permission: access, membership (org invites only), organizationId?}` (limits 50 workspaces / 100 emails, `invitations.ts:59–84`) → `{success, successful[], added[], failed[{email,error}], invitations[]}`. Success toast: `"{n} member(s) added"` and/or `"{n} invite(s) sent"` joined with " · " (only when non-empty). If `failed` is non-empty: the emails field is replaced with the failed addresses and `errorMessage = buildInviteFailureMessage(failed, attempted)`: one failure → its `error`; several → headline "None of the {n} invitations could be sent." or "{failed} of {attempted} invitations could not be sent." followed by up to 3 distinct reasons and "And {k} more." (64–82); the modal stays open. Otherwise clear and close. Network/4xx error → `errorMessage = error.message || 'An unexpected error occurred. Please try again.'`.
- Invalidations (`invitations.ts:267–284`): per selected workspace `['invitations','list',ws]`, `['workspace','detail',ws,'permissions']`, `['workspace','detail',ws,'members']`; with an organization also `organizationKeys.roster(org)`, `.billing(org)`, `.detail(org)`.
- Policy (`use-workspace-invite-policy.ts:404–418`): `isInvitationsDisabled = (NEXT_PUBLIC_DISABLE_INVITATIONS || permissionGroup.disableInvitations) || inviteDisabledReason !== null`; `inviteDisabledReason` is read off the workspace list row. The switcher derives the same two values inline from its `workspaces` prop (`workspace-header.tsx:282–296`) and, when disabled, routes "Invite teammates" to Billing settings (`billingEnabled`) or does nothing (765–772).

### Delete workspace (`modal.delete-workspace`, `delete-modal.tsx:45–241` with `itemType='workspace'`)
- `ChipConfirmModal` (sm, 440px), `srTitle`/title "Delete workspace", `defaultAction='none'` (Enter does nothing, 71–75).
- Text: "Are you sure you want to delete **{name}**? " + error-coloured "This will permanently remove all associated workflows, tables, files, logs, and knowledge bases." + " This action cannot be undone." (182–194, 209–215); without a name: "Are you sure you want to delete this workspace? …".
- Body extra: `ChipModalField type='input'` titled `Type <span class="text-[var(--text-primary)]">{name}</span> to confirm`, placeholder `{name}`, value `confirmationText` (reset on open) (224–238).
- Footer: Cancel + destructive "Delete" / "Deleting..." (`pending`), disabled until `confirmationText === name` (216–222).
- Confirm: `DELETE /api/workspaces/[id]` body `{}`; `onSettled` invalidates `['workspace','list']` and `['workspace','detail',id]`; if it was the current workspace, switch to the first other workspace in the cached list (`use-workspace-management.ts:172–196`); on success close (`workspace-header.tsx:436–445`). A failure is logged by `confirmDeleteWorkspace` (`use-workspace-management.ts:191–193`), which does not rethrow, so `handleDeleteWorkspace` closes the modal after a failure too (corrected 2026-10-22). Entry: workspace context menu "Delete" (disabled unless admin and `workspaceCount > 1`).

### Leave workspace (`modal.leave-workspace`, `workspace-header.tsx:867–883`)
- `ChipConfirmModal` (sm), title "Leave workspace", text "Are you sure you want to leave **{name|'this workspace'}**? You will lose access to all workflows and data in this workspace. This action cannot be undone."; confirm destructive "Leave workspace" / "Leaving..." (`pending: isLeavingWorkspace`); dismiss "Cancel" (default action).
- Confirm: `DELETE /api/workspaces/members/[userId]` body `{workspaceId}`; invalidates permissions(ws), lists, detail(ws); if current, switch to the next workspace; on error `toast.error("Couldn't leave workspace", {description: getErrorMessage(error, 'Please try again in a moment.')})` and the modal stays open (412–431). Entry: context-menu "Leave" (only when `sessionUserId !== ownerId && !isOrgAdmin`).

### Pending invitations (`modal.invitations`, `view-invitations-modal.tsx:66–222`)
- `ChipModal` (md), `srTitle='Pending invitations'`, header "Invitations". Data: `GET /api/invitations` (`['invitations','mine']`, 30 s), enabled while open.
- Body: error → `SettingsQueryErrorState` ("Could not load invitations", retry); pending → "Loading invitations…"; empty → "No pending invitations." (both `SettingsEmptyState variant='inline'`); rows separated by `ChipModalSeparator`: `SettingsResourceRow flush` with `IdentityTile` (single workspace grant), title (`organizationName` for organization invites; first workspace name `+N` otherwise), description "Invited by {inviterName}" / "Invited", `ChipTag gray` "{permission} access"; optional "Before you join" (`InvitationDisclosure`) and "Workspace access" (`InvitationWorkspaceAccess`) custom fields; actions `Chip` "Decline" + `Chip primary` "Accept" (disabled while busy or when an internal invite lacks its `joinPreview`, with a "Refresh invitation" chip).
- Accept: `POST /api/invitations/[id]/accept {disclosedWorkspaceIds?, disclosedOutcome?}` → toast "Joined {label}", close, `router.push(result.redirectPath)`; invalidates `['workspace','list']`, `organizationKeys.all`, `workspaceCredentialKeys.all`, `subscriptionKeys.all`, `['invitations','mine']`. Decline: `POST /api/invitations/[id]/reject {}` → invalidates `['invitations','mine']`; errors → `toast.error(getInvitationErrorMessage(...))`.
- Footer only when the list is empty: `ChipModalFooter defaultAction='dismiss' cancelLabel='Done'`.
- Entry: switcher "View invitations" (`ViewInvitationsMenuItem`, rendered only when the same query returns ≥ 1).

### State summary
| State | Create | Invite | Delete | Leave |
|---|---|---|---|---|
| Open | fields reset | fields reset to defaults | confirmation text reset | — |
| Pending | "Creating...", Cancel disabled, Escape/overlay refused | "Sending...", all fields disabled | "Deleting...", dismiss disabled | "Leaving...", dismiss disabled |
| Error | `ChipModalError` message, stays open | `ChipModalError` (+ failed emails kept), stays open | logged, modal closes (corrected 2026-10-22) | toast + stays open |
| Permission-gated | `creationPolicy.canCreate` | `canInvite` (admin) and `inviteDisabledReason` | admin and > 1 workspace | not owner, not org admin |
| Hosted-only | — | seat hint (Enterprise) | — | — |

## Interactions

| Interaction | Behaviour | Source |
|---|---|---|
| Escape / overlay click / X | close unless an action is pending | `chip-modal.tsx:212–216, 1518` |
| Enter | create: submit; invite: submit (primary default action) when the focused control does not own Enter (the emails input consumes Enter to add a chip); delete: nothing; leave: dismiss (Cancel) | `chip-modal.tsx:78–104`, `delete-modal.tsx:71–75`, `chip-modal.tsx:1667` |
| Emails input | Enter/comma/space/paste add; Backspace on empty removes the last chip; invalid entries show the validation reason inside the control | `chip-emails-input.tsx:66, 129, 145`, `tag-input.tsx:208–209, 335–361` |
| Workspaces dropdown | multi-select stays open while toggling; search filters when organization invite | `chip-dropdown.tsx:164–174, 248` |
| Delete confirm input | typing the exact name enables "Delete" | `delete-modal.tsx:70, 221` |
| Focus order | header close → fields in order → footer Cancel → primary (focus trapped by the modal) | DOM order |

## Network and realtime

| Modal | Request | React Query | Invalidations |
|---|---|---|---|
| Create | `POST /api/workspaces {name}` → `{workspace}` | mutation `useCreateWorkspace` | prepend to `['workspace','list','user','active']` cache; invalidate `['workspace','list']`, `['workspace','adminList']` |
| Rename | `PATCH /api/workspaces/[id] {name: trimmed}` | `useUpdateWorkspace` | `['workspace','list']`, `['workspace','detail',id]` |
| Logo | `POST /api/files/uploads` → `PUT`/multipart → `POST …/complete` (abort `DELETE …`), then `PATCH /api/workspaces/[id] {logoUrl}` | — | as rename |
| Invite | `GET /api/workspaces` (admin list, when org invite and open; key `['workspace','adminList',userId,orgId]`, 60 s, `keepPreviousData`); `GET /api/organizations/[id]/billing-plan` (seats, gated); `POST /api/workspaces/invitations/batch` | `useAdminWorkspaces`, `useOrganizationPlanSeats`, `useSendWorkspaceInvitations` | per workspace: invitations list, permissions, members; org: roster, billing, detail |
| Delete | `DELETE /api/workspaces/[id] {}` | `useDeleteWorkspace` | `onSettled`: lists, detail |
| Leave | `DELETE /api/workspaces/members/[userId] {workspaceId}` | `useLeaveWorkspace` | permissions(ws), lists, detail(ws) |
| Invitations | `GET /api/invitations`; `POST /api/invitations/[id]/accept`; `POST /api/invitations/[id]/reject {}` | `useMyPendingInvitations` (30 s), accept/decline mutations | see above |

## Parity checklist

| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | `modal.tsx:453–457`, `chip-modal.tsx:276,1669` | create/invite/invitations 500px max; delete/leave/dirty-guard 440px max; 90vw below | | |
| 2 | layout | `chip-modal.tsx:234–245` | 3px outer ring on `--surface-4`/`-5`, radius 12 outside / 8 inside, 1px inner border | | |
| 3 | layout | `chip-modal.tsx:336–357` | header `px-4 pt-3`, 14px close glyph with enlarged hit area, 1px separator 12px below | | |
| 4 | layout | `chip-modal.tsx:448` | body `px-2 pt-4 pb-4.5`, 16px between fields | | |
| 5 | layout | `chip-modal.tsx:745` | field label 9px above its control, 8px gutters | | |
| 6 | layout | `chip-modal.tsx:1287–1292` | footer `px-4 pt-2 pb-2` on `--surface-3`, chips 8px apart, right-aligned | | |
| 7 | token | `modal.tsx:421` | M1 overlay 10 % black + 2px blur | | |
| 8 | token | `chip-modal.tsx:234,243` | M2/M3 ring and surface | | |
| 9 | token | `chip-modal.tsx:1287` | M5 footer band | | |
| 10 | token | `chip/chrome.ts:16`, `chip.tsx:73` | M6 primary / M7 destructive chip fills | | |
| 11 | token | `chip-modal.tsx:75,1735,764` | errors `--text-error` caption; hints `--text-muted` caption | | |
| 12 | state | `create-workspace-modal.tsx:424–431` | create modal reopens empty | | |
| 13 | state | `create-workspace-modal.tsx:471` | "Create" disabled until a non-blank name; label "Creating..." while pending | | |
| 14 | state | `create-workspace-modal.tsx:436–441` | server error shown in the modal, modal stays open | | |
| 15 | interaction | `use-workspace-management.ts:155–170` | successful create switches to the new workspace | | |
| 16 | interaction | `workspace-header.tsx:631–680` | inline rename: Enter saves, Escape cancels, blur saves if changed, disabled while saving | | |
| 17 | interaction | `workspace-header.tsx:301–309` | closing the switcher saves a pending rename | | |
| 18 | state | `logo-file.ts:16–23` | logo > 5 MB or unsupported type rejected (no toast) | | |
| 19 | network | `session-upload.ts:106–160`, `upload-session.ts:18–19,101–122` | logo upload session: create → put/multipart (3 parts in flight, 3 retries) → complete → PATCH | | |
| 20 | state | `invite-modal.tsx:133–143` | invite modal reopens with defaults (current workspace, write, member) | | |
| 21 | state | `invite-modal.tsx:302–315` | emails placeholder/hint/disabled rules for non-admins and disabled invitations | | |
| 22 | state | `invite-modal.tsx:163–170,329` | workspaces dropdown: single option for personal workspaces (disabled); admin org workspaces otherwise | | |
| 23 | state | `invite-modal.tsx:189–193` | membership options: Admin only for org admins; External never for organization-only invites | | |
| 24 | state | `invite-modal.tsx:286–292` | "Send invites" disabled rules | | |
| 25 | interaction | `invite-modal.tsx:222–234` | email validation: format reason or "You cannot invite yourself" | | |
| 26 | interaction | `tag-input.tsx:208–209,335–361` | Enter/comma/space/paste tokenisation; Backspace removes last | | |
| 27 | network | `invite-modal.tsx:245–252`, `invitations.ts:246–254` | batch body shape; membership only for org invites | | |
| 28 | state | `invite-modal.tsx:254–277` | success toast text; partial failures keep failed emails and show the composed message | | |
| 29 | state | `invite-modal.tsx:64–82` | failure headline + ≤3 distinct reasons + "And N more." | | |
| 30 | network | `invitations.ts:267–284` | invalidations after sending | | |
| 31 | state | `invite-modal.tsx:196–220` | seat hint only for Enterprise orgs with seat data (review) | | |
| 32 | state | `use-workspace-invite-policy.ts:404–418` | invite gate = env/permission-group switch OR workspace reason | | |
| 33 | layout | `delete-modal.tsx:224–238` | delete workspace: type-to-confirm field with the name highlighted in `--text-primary` | | |
| 34 | state | `delete-modal.tsx:70,221,71–75` | "Delete" enabled only on exact match; Enter never confirms | | |
| 35 | state | `delete-modal.tsx:182–194,213–214` | copy: bold name, red warning sentence, "This action cannot be undone." | | |
| 36 | interaction | `use-workspace-management.ts:172–196` | deleting the current workspace switches to the next; a failed delete is logged and the modal closes (corrected 2026-10-22) | | |
| 37 | state | `workspace-context-menu.tsx:44` | delete disabled with a single workspace or for non-admins | | |
| 38 | state | `workspace-header.tsx:867–883` | leave modal copy, "Leaving..." pending label, Cancel default | | |
| 39 | interaction | `workspace-header.tsx:412–431` | leave error → toast with the server reason, modal stays open | | |
| 40 | state | `view-invitations-modal.tsx:112–123,213–219` | invitations modal: error / loading / empty states; "Done" footer only when empty | | |
| 41 | interaction | `view-invitations-modal.tsx:75–95` | accept → toast "Joined …", close, navigate to `redirectPath` | | |
| 42 | keyboard | `chip-modal.tsx:78–104,1667` | Enter = primary (create, invite) / dismiss (leave) / nothing (delete) | | |
