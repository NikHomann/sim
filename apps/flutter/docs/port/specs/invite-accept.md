# Invite accept
Upstream: `apps/sim/app/invite/[id]/**`, `apps/sim/app/invite/components/**`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

Route `/invite/[id]?token=…` (also `?new=true`, `?error=<code>`). Wears the `AuthShell` plus the support footer; forced light (`theme-provider.tsx:20`, segment `invite`).

## Files
| File | Lines | Role |
|---|---|---|
| `app/invite/[id]/page.tsx` | 20 | `Suspense` fallback `InviteLoading`; passes `registrationDisabled = isRegistrationDisabled`; `force-dynamic`; `robots: noindex` |
| `app/invite/[id]/invite.tsx` | 608 | The client page: token storage, session gating, invitation query, accept, every state |
| `app/invite/[id]/loading.tsx` | 13 | Route skeleton |
| `app/invite/components/layout.tsx` | 14 | `InviteLayout` = `AuthShell footer={<SupportFooter position='static' />}` |
| `app/invite/components/status-card.tsx` | 100 | `InviteStatusCard`: title/description, details slot, action buttons |
| `app/invite/components/invitation-disclosure.tsx` | 79 | Join-preview copy + workspace access list |
| `app/invite/components/invitation-workspace-access.tsx` | 32 | Granted-workspace rows |
| `app/(auth)/components/support-footer.tsx` | 39 | "Need help? Contact support" (mailto `brandConfig.supportEmail`, default `help@sim.ai`, `lib/branding/defaults.ts:12`) |
| `hooks/queries/invitations.ts` | 36-86 | `invitationKeys.detail(id, token, viewerId)`, `useInvitationDetails` (`staleTime` 30 s, `retry: false`) |
| `lib/api/contracts/invitations.ts` | 160-227, 267-316 | `getInvitationContract`, `acceptInvitationContract`, schemas |
| `app/api/invitations/[id]/route.ts` | 32-117 | GET: 401 / 404 `{error:'Invitation not found'}` / 403 `{error:'Forbidden'}` (non-invitee without token or admin view) / 500; `joinPreview` only for the pending, unexpired invitee |
| `app/api/invitations/[id]/accept/route.ts` | 11-74 | POST: 401; failure `{ error: <kind>, message? }` with status map (404 not-found/workspace-not-found, 409 disclosure-outdated/already-in-organization, 400 invalid-token/already-processed/expired/no-seats-available, 403 email-mismatch, 402 upgrade-required/external-requires-paid-plan, 500 server-error); success `{ success, redirectPath, invitation }` |
| `proxy.ts` | 260-286, 422-423 | Signed-out `/invite/*` without `callbackUrl` in the query → `/login?callbackUrl=%2Finvite%2F<id>[%3Ftoken%3D…]&invite_flow=true` |
| `lib/auth/stale-session-recovery.ts`, `stores/index.ts:23-…` | | `client.signOut()` + `clearUserData()` used by "Sign in with a different account" |
| App-local components | | `SettingsResourceRow` (`app/workspace/[workspaceId]/settings/components/settings-resource-row/settings-resource-row.tsx`), `IdentityTile` (`components/identity-tile/identity-tile.tsx`), `getWorkspaceInitial` (`lib/workspaces/initials.ts`), `formatQuotedNameList` (`packages/utils/src/string.ts:221-228`); emcn `ChipTag`, `Loader`, `Skeleton`, `Chip` |

Hooks: `useSession()` (`data`, `isPending`), `useSearchParams`, `useParams`, `useRouter`, `useQueryClient` (invalidations), `useInvitationDetails`. Cache keys touched on accept: `session`, `subscriptionKeys.all`, `organizationKeys.all`, `workspaceKeys.all`.

## Layout
`AuthShell` as login (header 62 px, 400 px column centred with `pb-16`) plus `SupportFooter position='static'` after the content (`layout.tsx:13`): `div.static.pb-8.text-center.text-caption.leading-relaxed --text-muted` → one 12 px / 19.5 px line "Need help? Contact support" with 32 px bottom padding, in normal flow below the centred area (`support-footer.tsx:23-37`). Because the column container is `flex-1`, the footer takes 51.5 px at the bottom and the column centres in the remaining height.

`InviteStatusCard` (`status-card.tsx:51-99`) — parity `invite.card` (the column itself):
- `invite.card.header` `div.space-y-1.text-center`: `invite.card.title` `<h1 class='text-[32px] tracking-tight --text-primary'>` — 32 px, line-height inherited 1.5 (48 px; no `leading-` class, unlike `AuthHeader`), letter-spacing −0.025 em; `invite.card.description` `<p class='text-[var(--text-muted)]'>` with no size class → inherits the document default 16 px / 24 px (`globals.css:1035-1044` sets no font-size; global letter-spacing 0.28 px). Note this is a different scale from `AuthHeader` (`auth-header.tsx:17-19`).
- `invite.card.actions` `div.mt-8.w-full.max-w-[410px].space-y-3` (32 px above, 12 px between rows; width capped by the 400 px column): optional `details` first, then (if `isExpiredError`) a primary "Request New Invitation" button, then the actions: index 0 as `AuthSubmitButton type='button'` (400×36 primary, spinner label `${label}...`), the rest as default `Chip fullWidth` + `AUTH_BUTTON_CLASS` + `border border-[var(--border)]` (400×36, 1 px `--border`, hover `--surface-hover`, `--text-body` label; loading shows a 16 px `Loader` + `${label}...`) (`:58-97`). Parity ids per row: `invite.card.action.0`, `invite.card.action.1`, … in render order (details and the expired button are not actions).
- Loading variant (`:37-49`): title "Loading" (32 px), description, then `div.mt-8.flex.w-full.items-center.justify-center.py-8` holding `Loader` 32×32 `--text-muted` spinning → 32 + 32 + 32 = 96 px tall block. Parity `invite.card.loader`.

`InvitationDisclosure` (`invitation-disclosure.tsx:21-78`) — parity `invite.details`: `div.space-y-3.text-left.text-small --text-body` (13 px): paragraphs per outcome (States); `<strong class='font-medium'>` (500) for the organisation name and role; `<ul class='mt-1 list-disc space-y-1 pl-5'>` of workspace names (20 px indent); then, when grants exist, `div.space-y-2` with `<p class='text-caption --text-muted'>` "Workspace access" and `invite.details.access` `<ul class='space-y-2' aria-label='Invited workspace access'>` of `SettingsResourceRow flush iconVariant='custom'` rows (`invitation-workspace-access.tsx:13-31`): `flex items-center justify-between gap-2.5` (no padding, no bleed because `flush`), cluster `gap-2.5` = `IdentityTile` 16×16 `rounded-sm bg --surface-6 --text-icon text-micro` (initial = first letter of the name with "workspace" stripped, upper-cased; or the `logoUrl` image) + title `--text-body` 14 px (name or "Unnamed workspace"); `badge` = `ChipTag variant='gray'` 20 px tall `rounded-md px-1 border --border-1 bg --surface-5 --text-secondary text-sm` "{permission} access" (`admin|write|read`) (`settings-resource-row.tsx:141-230`, `identity-tile.tsx:17-20, 58-70`, `chip-tag.tsx:72`). Row height 20 px (badge) ; gap between rows 8 px.

Skeleton (`loading.tsx:5-11`) — parity `invite.loading`: `flex flex-col items-center justify-center`: 48×48 r12; `mt-4` 200×24 r4; `mt-2` 280×14 r4; `mt-1` 240×14 r4; `mt-6` 200×44 r10 (all `--surface-active`).

## Tokens
| Element | Token(s) |
|---|---|
| Shell | `--bg`, `--text-primary`, light |
| Title / description | `--text-primary` 32 px; `--text-muted` 16 px |
| Primary action | primary chip (`--text-primary` fill, `--text-inverse`) |
| Secondary actions | transparent, `--border` border, `--text-body`, hover `--surface-hover`; disabled opacity .6 |
| Loader | `--text-muted` 32 px (loading card); `currentColor` 16 px inside buttons |
| Disclosure | `--text-body` 13 px; "Workspace access" `--text-muted` 12 px |
| Identity tile | `--surface-6` #e5e5e5 fill, `--text-icon` letter |
| ChipTag gray | `--surface-5` fill, `--border-1` border, `--text-secondary` text |
| Support footer | `--text-muted`; link hover `--text-body` + underline |
| Skeleton | `--surface-active` |

## States
Derived inputs (`invite.tsx:281-344`): `inviteId` (route), `tokenFromQuery` (`?token`, empty string treated as absent), `storedToken` from `sessionStorage['inviteToken:<id>']` (written when the query has one, read otherwise; `undefined` until read), `token = tokenFromQuery ?? storedToken ?? null`, `isTokenResolved`, `isNewUser = ?new === 'true'`, `urlError = getInviteError(?error)` when present. Query enabled only with a session user and a resolved token (`:316-319`). `isWrongAccount` = session email ≠ invitation email (normalised); `isDisclosureMissing` = `membershipIntent === 'internal'` and no `joinPreview`; `isLoading` = session user and (token unresolved or query pending). Error precedence: `actionError` > `fetchError` > wrong-account (`email-mismatch`) > `urlError` (only until the invitation loads) (`:340-344`).

| State | Card |
|---|---|
| Signed out (`!session.user && !isPending`) (`:415-434`) | title "You've been invited!"; description and actions by `signedOutPrompt` (`:64-105`): `registrationDisabled` → "Account creation is disabled on this instance", [Sign in]; `isNewUser` → "Create an account to join this workspace on Sim", [Create an account] (primary), [I already have an account]; else → "Sign in to your account to accept this invitation", [Sign in] (primary), [Create an account] (link carries `new=true`); always followed by [Return to Home]. Links: `/login?invite_flow=true&callbackUrl=<encoded /invite/<id>[?token=…]>` and `/signup?invite_flow=true&callbackUrl=…[&new=true]` (`:37-43`, `:409-413`; `callbackUrl` uses the token from state, sessionStorage or the query). Note the proxy normally sends a signed-out visitor to `/login` before this renders (`proxy.ts:268-280`), so this card appears only when the request carried `callbackUrl` or after a client-side sign-out. |
| Loading (`isLoading || isPending`) (`:436-442`) | loading card, description "Loading invitation..." |
| `email-mismatch` (`:447-479`) | "Wrong Account" / "This invitation was sent to a different email address. Please sign in with the correct account." / [Sign in with a different account] (signs out: `client.signOut()` + `clearUserData()` in parallel, then `router.push` to the login link if the in-memory reset succeeded, else `window.location.assign`), [Return to Home] |
| `already-in-organization` (409) (`:481-496`) | "Already Part of a Team" / "You are already a member of an organization. Leave your current organization before accepting a new invitation." / [Manage Team Settings] → `/home`, [Return to Home] |
| `requiresAuth` codes (`unauthorized` 401, `forbidden` 403, `user-not-found`) (`:498-524`) | "Authentication Required" / message / [Sign in to continue], [Create an account] (hidden when `registrationDisabled`), [Return to Home] |
| Other errors (`:526-544`) | "Invitation Error" / message / `isExpiredError` (`expired`) adds a primary "Request New Invitation" → `/` (`status-card.tsx:60-64`); `canRetry` codes (`disclosure-outdated`, `no-seats-available`, `upgrade-required`, `external-requires-paid-plan`, `server-error`, `network-error`, `unknown`) add [Try Again] → `window.location.reload()`; always [Return to Home] |
| Accepted (`:561-573`) | "Welcome!" / "You have successfully joined {displayName}. Redirecting..." / [Return to Home]; `router.push(redirectPath)` after 1200 ms (`:370`) |
| Invitation (`:575-607`) | title "Organization Invitation" or "Workspace Invitation"; description "You've been invited to join {displayName}."; details = `InvitationDisclosure`; actions [Accept Invitation] (primary; disabled while accepting or `isDisclosureMissing`; loading → "Accept Invitation..."), [Refresh invitation] only when `isDisclosureMissing` (disabled while refetching), [Return to Home] |

`displayName` (`:550-559`): workspace invitations → `formatQuotedNameList(grant names, 3)` → `"A", "B", "C" and N more` (or "a workspace" when no names); organisation invitations → `organizationName` or "an organization".

Error copy (`getInviteError`, `:147-254`): `missing-token` "The invitation link is invalid or missing a required parameter."; `invalid-token` "The invitation link is invalid or has already been used."; `expired` "This invitation has expired. Please ask for a new invitation."; `already-processed` "This invitation has already been accepted or declined."; `email-mismatch` (above, requiresAuth); `workspace-not-found` "The workspace associated with this invitation could not be found."; `disclosure-outdated` "Your workspaces changed since this page loaded. Review the updated notice and accept again." (retry); `user-not-found` "Your user account could not be found. Please try signing out and signing back in." (requiresAuth); `already-member` "You are already a member of this organization or workspace."; `already-in-organization` (above); `no-seats-available` "This organization has reached its seat limit. Ask an admin to contact support to add seats, then try again." (retry); `upgrade-required` "The workspace owner needs an active paid plan with billing set up before you can join. Ask them to update their plan, then try again." (retry); `external-requires-paid-plan` "External collaborators need their own paid Sim plan. Upgrade your plan, or ask the organization to re-invite you as a member — that uses one of their seats instead." (retry); `invalid-invitation` / `not-found` "This invitation is invalid or no longer exists."; `server-error` "An unexpected error occurred while processing your invitation. Please try again later." (retry; replaced by the server `message` when provided, `:392-404`); `unauthorized` "You need to sign in to accept this invitation." (requiresAuth); `forbidden` "You do not have permission to accept this invitation. Please check you are signed in with the correct account." (requiresAuth); `network-error` "Unable to connect to the server. Please check your internet connection and try again." (retry); unknown → "An unexpected error occurred while processing your invitation. Please try again or contact support." (retry). Code resolution (`:256-274`): `ApiClientError.code` if known, else `body.error` if known, else by status 401/403/404/409/≥500.

Disclosure copy (`invitation-disclosure.tsx:15-70`): outcome = `joinPreview.outcome` or `'external'` when `membershipIntent === 'external'`, else `null`. `will-join`: "You will join **{org}** as an organization **{role}**. This uses one organization seat." + either "Your owned personal workspaces, including archived workspaces, will move into the organization. Its administrators will be able to manage them:" with the bullet list (`workspacesToMove[i]` or "Unnamed workspace") or "You have no personal workspaces to move into the organization."; `already-member`: "You already belong to this organization. Your organization role will stay the same. No additional seat is used, and none of your personal workspaces will move."; `blocked`: "This invitation cannot currently be accepted. Try accepting to see what needs to be resolved, or contact the person who invited you."; `external`: no paragraph; `null`: "We could not load how this invitation affects your organization and personal workspaces. Refresh the invitation to review these details before accepting." Org name fallback "the workspace’s organization".

Hosted-only: none. Feature flags: none. Whitelabel: support email from `useBrandConfig()`.

## Interactions
- Buttons as listed; all are `type='button'` chips; `Enter`/`Space` on focus. No form, no shortcuts.
- Accept: `handleAcceptInvitation` guarded by session, invitation, not wrong account, disclosure present, not already accepting (`:346-349`).
- Return to Home: full navigation to `/` (`:29-31`).
- Token persistence: `sessionStorage['inviteToken:<id>']` written on arrival with `?token`, so the token survives the login round-trip even if the callback loses it (`:308-314`).
- Focus order: logo → action buttons in order → "Contact support".

## Network and realtime
1. `GET /api/auth/get-session` (session provider) — decides signed-out vs loading vs query.
2. `GET /api/invitations/[id]?token=<token>` (`token` omitted when null) (`invitations.ts:56-66`, contract `:267-280`) → `{ invitation: { id, kind, email, organizationId, organizationName, membershipIntent, role, status, expiresAt, createdAt, inviterName, inviterEmail, grants: [{ workspaceId, workspaceName, workspaceLogoUrl, permission }] }, joinPreview: { outcome, organizationName, workspacesToMove, workspaceIdsToMove } | null }`. Query key `['invitations','detail', id, token ?? '', viewerId ?? '']`, stale 30 s, no retry, enabled only signed-in with the token resolved. Errors: 401 `{error:'Unauthorized'}`, 403 `{error:'Forbidden'}`, 404 `{error:'Invitation not found'}` → `invalid-invitation`, 500.
3. Accept: `POST /api/invitations/[id]/accept` JSON `{ token?: <token>, disclosedWorkspaceIds?: joinPreview.workspaceIdsToMove, disclosedOutcome?: joinPreview.outcome }` (`:352-366`; the disclosure fields are sent whenever a preview rendered, even an empty list) → 200 `{ success: true, redirectPath, invitation: { id, kind, organizationId, acceptedWorkspaceIds } }`; failures `{ error: <kind>, message? }` with the status map in Files.
4. After success, best-effort in parallel (`:372-385`): `GET /api/auth/get-session?disableCookieCache=true` (`refreshSessionQuery`), invalidate `['subscription']`, `['organizations']`, `['workspaces']` (React Query refetches on next use). Flutter: same session refresh + cache invalidation in `Query<T>`.
5. Navigate to `redirectPath` after 1200 ms (client navigation; e.g. `/workspace/<id>/home`, see `entry-resolution.md` for the chat-disabled redirect of that path).
6. "Sign in with a different account": `POST /api/auth/sign-out`, then `clearUserData()` (localStorage wiped except `next-favicon`, `sim-theme`, `sim-landing-theme`), then `/login?…`.
7. Refresh invitation: refetch of 2.
No socket.

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | layout.tsx:13; support-footer.tsx:23-37 | `AuthShell` + static support footer (12 px line, 32 px bottom padding) below the centred column | | |
| 2 | layout | status-card.tsx:53-56 | title 32 px / 48 px line / −0.025 em; description 16 px `--text-muted`; 4 px gap; centred | | |
| 3 | layout | status-card.tsx:58 | actions block `mt-8`, `space-y-3`, full column width (max 410 → 400) | | |
| 4 | layout | status-card.tsx:66-77 | first action = 400×36 primary chip; spinner + "label..." while loading | | |
| 5 | layout | status-card.tsx:78-94 | other actions = 400×36 bordered transparent chips; loading shows 16 px loader + "label..." | | |
| 6 | layout | status-card.tsx:37-49 | loading card: "Loading" title, 32 px loader in a 96 px block | | |
| 7 | layout | invitation-disclosure.tsx:21-78 | details: 13 px `--text-body`, 12 px gaps, bullet list `pl-5`, "Workspace access" caption | | |
| 8 | layout | invitation-workspace-access.tsx:13-31; settings-resource-row.tsx:141-230; identity-tile.tsx:17-20 | access rows: 16 px tile + name, gray 20 px tag "{permission} access", 8 px row gap, no padding (`flush`) | | |
| 9 | layout | loading.tsx:5-11 | skeleton 48² r12, 200×24, 280×14, 240×14, 200×44 r10 with mt 16/8/4/24 | | |
| 10 | token | status-card.tsx:84; chip.tsx:86-90 | secondary chips border `--border`, hover `--surface-hover`, label `--text-body` | | |
| 11 | token | identity-tile.tsx:63; chip-tag.tsx:72 | tile `--surface-6`/`--text-icon`; tag `--surface-5`/`--border-1`/`--text-secondary` | | |
| 12 | token | support-footer.tsx:25, 33 | footer `--text-muted`, link hover `--text-body` + underline | | |
| 13 | state | invite.tsx:415-434, 64-105 | signed-out card: three prompt variants (registration disabled / new user / default) + Return to Home | | |
| 14 | state | invite.tsx:308-314, 409-413 | token stored under `inviteToken:<id>`; callback links carry it | | |
| 15 | state | invite.tsx:436-442 | loading card while session pending or query pending | | |
| 16 | state | invite.tsx:321-325, 447-479 | wrong account: "Wrong Account" card, sign-out-then-login action | | |
| 17 | state | invite.tsx:481-496 | 409 already-in-organization card with "Manage Team Settings" → `/home` | | |
| 18 | state | invite.tsx:498-524 | requiresAuth card; "Create an account" hidden when registration disabled | | |
| 19 | state | invite.tsx:526-544; status-card.tsx:60-64 | generic error card; expired adds "Request New Invitation"; retryable adds "Try Again" (reload) | | |
| 20 | state | invite.tsx:147-274 | error copy table and code resolution (code → body.error → status) | | |
| 21 | state | invite.tsx:340-344 | precedence actionError > fetchError > email-mismatch > urlError (urlError dropped once data loads) | | |
| 22 | state | invite.tsx:550-559; string.ts:221-228 | displayName: quoted names, max 3, "and N more"; org name; fallbacks | | |
| 23 | state | invite.tsx:575-607 | invitation card titles by kind; Accept disabled when disclosure missing; "Refresh invitation" shown then | | |
| 24 | state | invitation-disclosure.tsx:15-70 | outcome paragraphs (will-join with list/empty, already-member, blocked, null); external shows none | | |
| 25 | state | invite.tsx:561-573, 370 | "Welcome!" card then `redirectPath` after 1200 ms | | |
| 26 | interaction | invite.tsx:458-472 | sign-out path: signOut + clearUserData in parallel; in-app push vs full assign | | |
| 27 | network | invitations.ts:56-66, 73-86 | `GET /api/invitations/[id]?token=`, key incl. viewer id, stale 30 s, no retry, enabled only signed in | | |
| 28 | network | invite.tsx:352-366 | `POST /api/invitations/[id]/accept` `{token, disclosedWorkspaceIds, disclosedOutcome}` | | |
| 29 | network | invite.tsx:372-385 | after accept: session refresh (cookie cache bypassed) + invalidate subscription, organizations, workspaces | | |
| 30 | network | accept/route.ts:35-58 | failure envelope `{error: kind, message?}` and status map honoured by the client mapping | | |
| 31 | network | proxy.ts:268-280 | signed-out deep link bounces to `/login?callbackUrl=…&invite_flow=true` (Flutter guard does the same client-side) | | |

Colour anchors: `auth.shell @ (8,8)` → #fefefe · `invite.card.action.0 @ (6,18)` → `--text-primary` #1a1a1a (primary) · `invite.card.action.1 @ (6,18)` → #fefefe and `@ (0,18)` → `--border` #d8d8d8 · `invite.details.access` first tile `@ (2,8)` → `--surface-6` #e5e5e5 · `invite.loading` first block `@ (24,24)` → `--surface-active` #ececec.
