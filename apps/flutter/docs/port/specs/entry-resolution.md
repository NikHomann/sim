# Entry resolution (routing logic, not a screen)
Upstream: `apps/sim/proxy.ts`, `app/home/page.tsx`, `lib/navigation/resolve-app-entry.ts`, `lib/navigation/paths.ts`, `app/workspace/page.tsx`, `app/workspace/[workspaceId]/page.tsx`, `app/workspace/[workspaceId]/layout.tsx`, `app/workspace/[workspaceId]/home/layout.tsx`, `app/workspace/[workspaceId]/w/page.tsx`, `app/workspace/[workspaceId]/settings/[section]/layout.tsx`, `app/workspace/[workspaceId]/settings/navigation.ts`, `app/o/page.tsx`, `app/o/[organizationId]/page.tsx`, `app/o/[organizationId]/layout.tsx`, `app/_shell/providers/theme-provider.tsx`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

The React app decides most of these on the server (edge proxy or server components). The Flutter app has no server, so each decision becomes a go_router redirect or a page-level cubit that reads the data named in the table. Flutter routes are the same paths under the `/app/` base href (plan §3). "Cookie present" below is what the proxy sees (`getSessionCookie`, `proxy.ts:376-377`); Flutter has no access to the httpOnly cookie, so every "cookie present / absent" branch is replaced by the result of `GET /api/auth/get-session` (`{ user } | null`), with the stale-cookie subtleties noted in §4.

## Files
| File | Lines | Role |
|---|---|---|
| `proxy.ts` | 236-255, 260-286, 376-434, 468-488 | Edge: `/` redirect, `/login`+`/signup` bounce, app-surface auth gate, invite bounce; matcher |
| `lib/navigation/paths.ts` | 13-26, 35-54, 65-71 | `APP_ENTRY_PATH='/home'`, `LANDING_HREF='/?home'`, `WORKSPACES_PATH='/workspace'`, `WORKSPACE_SETTINGS_PATH='/workspace?redirect=settings'`, `organizationRoutes(id)`, `isAppSurfacePath` (`/home`, `/workspace`, `/o` and descendants) |
| `app/home/page.tsx` | 12-31 | `/home`: no session → `/workspace`; else `resolveAppEntryPath(session)` |
| `lib/navigation/resolve-app-entry.ts` | 11-32 | organization home when the viewer has an organization and its search surface is rolled out, else `/workspace` |
| `lib/organizations/surface.ts` | 166-181 | `resolveOrganizationLanding`: active organization if the viewer is a member of it, else the oldest membership, else null |
| `lib/knowledge/access/availability.ts` | 131-135 | `isKnowledgeMemberAccessAvailable({organizationId})` = member-scoped search rollout |
| `app/o/page.tsx` | 9-16 | `/o`: no session → `/login`; else same as `/home` |
| `app/o/[organizationId]/page.tsx` | 7-27 | `/o/[id]` → `home` if `mothershipAvailable`, else `search` if `searchAccess.memberScoped`, else `/workspace?redirect=settings`; no session → `/login?callbackUrl=/o/[id]`; no context → 404 |
| `app/o/[organizationId]/layout.tsx` | 48-67 | same auth redirect; no context → `OrganizationAccessDenied`; neither mothership nor member search → `/workspace?redirect=settings` |
| `app/workspace/page.tsx` | 35-37, 46-72, 74-218, 220-239, 241-281 | Workspace picker: stale-session recovery, blocked/error cards, default workspace creation, `redirect`, `redirect_workflow`, `reason` |
| `app/workspace/[workspaceId]/page.tsx` | 13-20 | `/workspace/[id]` → `home` or `w` by `isChatEnabled` |
| `app/workspace/[workspaceId]/layout.tsx` | 73-82 | no session → `/login`; no host context → `WorkspaceAccessDenied` |
| `app/workspace/[workspaceId]/home/layout.tsx` | 10-23 | chat disabled → `/workspace/[id]` |
| `app/workspace/[workspaceId]/w/page.tsx` | 24-45 | `/w` → first workflow of the workspace, else empty state |
| `app/workspace/[workspaceId]/settings/[section]/layout.tsx` | 11-18, 53-59 | legacy section redirects, aliases, 404 |
| `app/workspace/[workspaceId]/settings/navigation.ts` | 41-48, 60-63 | `SECTION_ALIASES` |
| `app/_shell/providers/theme-provider.tsx` | 16-31, 42, 70 | forced-light segments |
| `lib/core/config/env-flags.ts` | 82, 137, 235 | `isChatEnabled = !NEXT_PUBLIC_CHAT_DISABLED`, `isAuthDisabled = DISABLE_AUTH && !hosted`, `isRegistrationDisabled` |
| `lib/auth/stale-session-recovery.ts` | 19-29 | `recoverFromStaleSession`: sign-out → `clearUserData` → `window.location.assign('/login')` |
| `lib/billing/upgrade-reasons.ts` | 17, 78-89 | `UPGRADE_REASON_PARAM='reason'`, `buildUpgradeHref(id, reason?)` |
| `lib/api/contracts/workspaces.ts` | 64-78, 165-185, 197-207 | `GET /api/workspaces` response, `creationPolicy`, `POST /api/workspaces` |
| `hooks/queries/workspace.ts` | 91-98 | `useWorkspacesWithMetadata`: key `['workspaces','list','active']`, query `scope=active` |
| `app/_shell/application-loading.tsx` | 12-34 | Loading surface (wordmark 67×32 `--text-tertiary`, or brand wordmark/name) |

## Data each decision needs
| Source | Fields used |
|---|---|
| `GET /api/auth/get-session` | `user.id`, `user.email`, `session.activeOrganizationId` (`lib/auth/session-response.ts:34-38`), `user.role` (`'admin'` = platform admin, for `/account/settings/admin`, plan §5) |
| `GET /api/public-env` | `NEXT_PUBLIC_CHAT_DISABLED` (→ `chatEnabled`), `NEXT_PUBLIC_FORCE_HOSTED`/`NEXT_PUBLIC_APP_URL` (→ `hosted`), `NEXT_PUBLIC_SSO_ENABLED`, `NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED` |
| `GET /api/auth/providers` | `registrationDisabled` |
| `GET /api/workspaces?scope=active` | `workspaces[] { id, name, … }` (most recently visited first), `lastActiveWorkspaceId`, `pinnedWorkspaceIds`, `creationPolicy { canCreate, workspaceMode: personal\|organization\|grandfathered_shared, organizationId, maxWorkspaces, currentWorkspaceCount, reason, blockedReasonCode?: organization-subscription-inactive \| permission-group-denied }` |
| `GET /api/workspaces/[id]/host-context` | existence (200 vs 403/404) = workspace access; `deployment.chatEnabled` etc. |
| `GET /api/organizations/[id]/surface-context` (server addition, plan §5) | `context.mothershipAvailable`, `context.searchAccess.memberScoped`, 403 = not a member |
| `GET /api/workflows/[id]` (`getWorkflowStateContract`, `lib/api/contracts/workflows.ts:737-740`; corrected 2026-10-22, was `…/[id]/state`) | `data.workspaceId` (for `?redirect_workflow`) |
| `GET /api/workflows?workspaceId=` | first workflow for `/w` |
| Server-only, no transport | `DISABLE_AUTH` (anonymous session; `get-session` returns a user when it is on, which is enough), `isDev`, the organization rollout gate behind `resolveAppEntryPath` (`isKnowledgeMemberAccessAvailable`) — needs `surface-context` or a dedicated entry endpoint, see §8 |

## Decision tables

### 1. Root `/` (`proxy.ts:236-255`)
| Input | Destination |
|---|---|
| `?home` present | landing page (out of scope; Flutter does not own `/`) |
| cookie present | `/home` |
| no cookie, self-hosted and not dev (`!isHosted && !isDev`) | `/login` |
| no cookie, hosted or dev | landing page |
Flutter: `/app/` (the bundle root) behaves as "cookie present" when `get-session` has a user → entry resolution; otherwise `/login`. Flutter never serves the marketing landing.

### 2. `/login` and `/signup` (`proxy.ts:382-401`)
| Input | Destination |
|---|---|
| cookie present and `callbackUrl`/`redirect` is not the same-origin `/api/auth/oauth2/authorize` (or auth disabled) | `/home` |
| cookie present and that OAuth callback | render the page (re-authentication for an OAuth client) |
| no cookie | render |
Flutter: same with `get-session.user`. `resolveAuthRedirect` reads `redirect` first, then `callbackUrl` (`auth-redirect.ts:75`).

### 3. App surfaces `/home`, `/workspace/**`, `/o/**` (`proxy.ts:408-417`; `isAppSurfacePath`)
| Input | Destination |
|---|---|
| no cookie | `/login` (no `callbackUrl` is attached by the proxy; the organization pages add one themselves, see §7) |
| cookie present | render (the page may still find the session invalid, §4) |

### 4. `/home` (`home/page.tsx:12-31`, `resolve-app-entry.ts:11-32`)
| Input | Destination |
|---|---|
| cookie present but session invalid (`getSession()` null) | `/workspace` (the picker clears stale cookies, never `/login`, which would loop, `:15-27`) |
| session, viewer belongs to no organization | `/workspace` |
| session, organization = `session.activeOrganizationId` if the viewer is a member of it, else the viewer's oldest membership (`surface.ts:166-181`); organization search rollout available (`isKnowledgeMemberAccessAvailable`) | `/o/<organizationId>/home` |
| session, organization found but rollout not available | `/workspace` |
Default post-auth destination everywhere is `/home` (`paths.ts:13`; `auth-redirect.ts:17`), so this table runs after every sign-in, after `/`, after "Open Sim" links and after `Manage Team Settings` on the invite page. Flutter: needs the organization decision; see §8.

### 5. `/o` (`o/page.tsx:9-16`)
| Input | Destination |
|---|---|
| no session | `/login` |
| session | as §4 |

### 6. `/workspace` picker (`workspace/page.tsx:74-218`)
Runs client-side in React too, so this is a direct port. Inputs: `useSession()` (`data`, `isPending`, `error`), `useWorkspacesWithMetadata(isAuthenticated)`, query params `redirect`, `redirect_workflow`, `reason`, sessionStorage `workspaceRaceRetry`. Shows `ApplicationLoading` (wordmark, `application-loading.tsx`) until it navigates or renders a card.
| Order | Condition | Action |
|---|---|---|
| a | session pending | wait (loading) |
| b | session null and session query errored | error card "Could not load your workspaces" (`:201-215`) |
| c | session null (clean) | `recoverFromStaleSession()` (sign-out, wipe, `/login`); if sign-out fails → error card (`:103-119`) |
| d | authenticated and `GET /api/workspaces` → 401 | `recoverFromStaleSession()` once; failure → error card (`:89-98`, `:35-37`) |
| e | workspaces loading / other error / no data | wait; a non-401 error → error card (`:121`, `:204`) |
| f | `workspaces.length === 0` and `creationPolicy.canCreate === false` | blocked card "No workspace access yet" with copy by `blockedReasonCode` (`organization-subscription-inactive`, `permission-group-denied`) else by `workspaceMode === 'organization'`, else the plan-limit copy; primary "Check again" = reload, "Sign out" = recovery (`:138-154`, `:173-199`); not latched: a later refetch with access resumes |
| g | `workspaces.length === 0` and creation allowed | `POST /api/workspaces {name:'My Workspace'}` → `destinationFor(newId)`; 409 → set `workspaceRaceRetry` and reload once, a second 409 → error card; other failure → `/login` (`:155-157`, `:241-281`) |
| h | `?redirect_workflow=<id>` | `GET /api/workflows/<id>/state` → `/workspace/<data.workspaceId>/w/<id>`; failure or no workspace → `/workspace/<target>` (`:164-167`, `:220-239`) |
| i | otherwise | `router.replace(destinationFor(target))` where `target = workspaces.find(id === lastActiveWorkspaceId) ?? workspaces[0]` (`:160-170`) |
`destinationFor(id)` (`:129-134`): `?redirect=upgrade` → `/workspace/<id>/upgrade[?reason=<reason>]` (only when `reason` is a known `UpgradeReason`); `?redirect=settings` → `/workspace/<id>/settings/general`; else `/workspace/<id>`.
Cards (`:46-72`) — parity `entry.workspace.card`: `main.desktop-title-bar-page.flex.w-full.items-center.justify-center.bg --surface-1.p-6`; inner `flex max-w-md (448 px) flex-col items-center gap-3 text-center`: 40 px round `--surface-3` disc with `CircleAlert` 18 px `--text-icon`; `space-y-1`: `<h1 class='text-lg --text-primary'>` (18 px), `<p class='text-sm --text-muted'>`; `flex gap-2` with `Chip variant='primary'` (primary label) and default `Chip` "Sign out". Follows the viewer's theme (not forced light).

### 7. `/workspace/[id]` and children
| Route | Input | Destination |
|---|---|---|
| `/workspace/[id]` (`[workspaceId]/page.tsx:19`) | `chatEnabled` | `/workspace/[id]/home` if chat enabled else `/workspace/[id]/w` (always a redirect; no data fetched) |
| `/workspace/[id]/**` (`layout.tsx:73-82`) | no session → `/login`; host-context unavailable (403/404) → `WorkspaceAccessDenied` page (no redirect) |
| `/workspace/[id]/home/**` (`home/layout.tsx:17-20`) | chat disabled → `/workspace/[id]` (which then goes to `/w`); this path is baked into invitation emails and `acceptInvitation.redirectPath` |
| `/workspace/[id]/w` (`w/page.tsx:34-45`) | `GET /api/workflows?workspaceId` → `/workspace/[id]/w/<first workflow in this workspace>`; none → empty state with "create workflow" (Phase 2 screen) |
| `/workspace/[id]/settings/[section]` (`settings/[section]/layout.tsx:11-18, 55-59`) | `integrations` → `/workspace/[id]/integrations`; `skills` → `/workspace/[id]/skills`; `privacy` → `/workspace/[id]/settings/general?view=privacy`; `authorized-apps` → `/workspace/[id]/settings/general?view=authorized-apps`; aliases (`navigation.ts:41-48`) `subscription`→`billing`, `team`→`organization`, `api-keys`→`apikeys`, `domains`→`sso`, `sessions`→`security` resolve in place (no redirect; the alias URL stays); unknown section → 404 |
| `/o/[id]` (`o/[organizationId]/page.tsx:7-27`) | no session → `/login?callbackUrl=/o/[id]`; no surface context (not a member) → 404; `mothershipAvailable` → `/o/[id]/home`; else `searchAccess.memberScoped` → `/o/[id]/search`; else `/workspace?redirect=settings` |
| `/o/[id]/**` (`o/[organizationId]/layout.tsx:48-67`) | no session → `/login?callbackUrl=/o/[id]`; no context → `OrganizationAccessDenied` page; neither mothership nor member search → `/workspace?redirect=settings` |
| `/o/[id]/benchmark`, `/benchmark` | out of scope (plan §2) |

### 8. What Flutter must do for the server-side decisions
- Cookie checks (§1–§3): `GET /api/auth/get-session` once at app start (session cubit, stale 5 min, refetch on focus, `hooks/queries/session.ts:71-85`). `user` ⇒ authenticated. A stale cookie with a dead session is reported as `null` by `get-session`, which is what the picker's branch c handles (sign out to clear the cookie, then `/login`), so Flutter does not need cookie visibility.
- `/home`, `/o` (§4–§5): the organization landing needs (1) memberships and the active organization and (2) the rollout gate. `get-session` gives `session.activeOrganizationId`; memberships come from Better Auth's organization plugin (`client.organization.list()` → `GET /api/auth/organization/list`, used in `session-provider.tsx:81`), oldest first by `createdAt`; the rollout gate is `GET /api/organizations/[id]/surface-context` → `context.searchAccess.memberScoped` (plan §5 defines this endpoint as the client-visible form of `isKnowledgeMemberAccessAvailable`). Decision: if a candidate organization exists and `memberScoped` is true → `/o/<id>/home`; otherwise `/workspace`. Until the endpoint exists, Flutter resolves to `/workspace` and records the difference in `known-gaps.md`. (corrected 2026-10-22: the organization landing is not ported at all yet — `resolveEntry` always sends a signed-in `/`, `/home` or `/o` to the picker, there are no `/o/:id/**` routes and no hook to register an organization resolver; known-gaps.md row 9.)
- Flutter resolves every navigating entry decision in go_router redirects (`features/entry/entry_routes.dart`): `/`, `/home`, `/o` and the picker with a session and a loaded list never render a page, so the history keeps only the destination (`router.replace`). The pages render only the loading and card states; their own navigations (default workspace, recovery, retries) replace the current entry (`Router.neglect`). (corrected 2026-10-22)
- `/o/[id]` (§7): `surface-context` 403 → access-denied page; `mothershipAvailable` / `searchAccess.memberScoped` as in the table.
- `/workspace/[id]` (§7): `chatEnabled` from `GET /api/public-env` (`NEXT_PUBLIC_CHAT_DISABLED`), confirmed by `host-context.deployment.chatEnabled` once loaded.
- `/workspace/[id]/**` guard: `GET /api/workspaces/[id]/host-context` (already the runtime loader, plan §4.3); 403/404 → `WorkspaceAccessDenied`.
- Settings legacy redirects: a static map in the router (table §7).
- `callbackUrl` after login: the Flutter login page navigates to the validated callback or `/home`; a callback under the Flutter prefix is a client route, anything else (e.g. `/api/auth/oauth2/authorize?…`, `/cli/auth?…`) is a top-level browser navigation.

### 9. Forced-light routes (`theme-provider.tsx:16-31, 70`)
First path segment ∈ {`login`, `signup`, `reset-password`, `sso`, `invite`, `verify`, `chat`, `resume`, `oauth`, `oauth-error`, `f`, `unsubscribe`, `cli`, `credential-groups`} ⇒ `forcedTheme='light'` on `<html>` (overrides `sim-theme`); plus the landing surface (`/` and `lib/landing/routes.ts:28-51` segments) uses its own `sim-landing-theme` store defaulting to light. Everything else: `sim-theme` (`system` default). Flutter: the theme cubit applies the same segment set on the route path (without the `/app` prefix); `cli` and `credential-groups` are out of scope but keep the rule for completeness.

## Tokens
Only the picker cards paint: `--surface-1` background, `--surface-3` disc, `--text-icon` glyph, `--text-primary` title 18 px, `--text-muted` body 14 px, primary and default chips. `ApplicationLoading`: `--bg` background, wordmark `--text-tertiary` 67×32 (`sim-wordmark.tsx:13`), or brand wordmark `h-8 max-w-[240px]`, or brand name 18 px `--text-tertiary`.

## States
Loading (`ApplicationLoading`, `home/loading.tsx`), blocked card (4 copy variants), error card, redirecting. The picker's blocked state self-heals on refetch (`:139-143`); the error card offers reload or sign-out.

Blocked copy (`workspace/page.tsx:187-193`): `organization-subscription-inactive` → "Your organization's subscription is inactive, so new workspaces can't be created. Ask an organization owner to reactivate it."; `permission-group-denied` → "Your permission group doesn't allow creating workspaces, and you don't have access to an existing one. Ask an organization admin for workspace access."; `workspaceMode === 'organization'` → "Your account is linked to an organization, but you don't have access to any of its workspaces. Ask an organization admin for workspace access, then check again — or sign out and back in if you recently left the organization."; else → "Your plan has reached its workspace limit and none of your workspaces are active. Upgrade your plan to create another workspace, or contact support to restore an archived one." Error card: "Could not load your workspaces" / "Something went wrong while loading your account. Try again, or sign out and log back in." / "Try again".

## Interactions
"Check again" / "Try again" → `window.location.reload()`; "Sign out" → `recoverFromStaleSession()`. No keyboard shortcuts.

## Network and realtime
Picker order: `GET /api/auth/get-session` → `GET /api/workspaces?scope=active` → (optional) `POST /api/workspaces {name}` or `GET /api/workflows/[id]` (corrected 2026-10-22) → navigation. Sign-out path: `POST /api/auth/sign-out` then `/login`. `/o/[id]`: `GET /api/organizations/[id]/surface-context`. `/workspace/[id]/**`: `GET /api/workspaces/[id]/host-context` (the layout prefetches it). No socket. After `POST /api/workspaces` the React page navigates without invalidating; Flutter should invalidate `['workspaces']` so the sidebar list is fresh.

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | interaction | proxy.ts:236-255 | `/app/` root: signed in → entry; signed out → `/login` (self-hosted rule) | | |
| 2 | interaction | proxy.ts:382-395; auth-redirect.ts:83-91 | signed-in `/login`,`/signup` → `/home` unless OAuth authorize callback | | |
| 3 | interaction | proxy.ts:408-417; paths.ts:65-71 | signed-out `/home`, `/workspace/**`, `/o/**` → `/login` | | |
| 4 | interaction | proxy.ts:268-280 | signed-out `/invite/<id>` → `/login?callbackUrl=…&invite_flow=true` | | |
| 5 | interaction | home/page.tsx:26-30; resolve-app-entry.ts:30-32 | `/home` → `/o/<org>/home` or `/workspace`; invalid session → `/workspace` | | |
| 6 | interaction | surface.ts:166-181 | organization choice: active if member, else oldest membership | | |
| 7 | interaction | o/page.tsx:9-16 | `/o` signed out → `/login`; else as `/home` | | |
| 8 | interaction | o/[organizationId]/page.tsx:15-26 | `/o/<id>` → home / search / `/workspace?redirect=settings`; signed out → `/login?callbackUrl=/o/<id>` | | |
| 9 | interaction | o/[organizationId]/layout.tsx:48-67 | non-member → access denied page; no surface → `/workspace?redirect=settings` | | |
| 10 | interaction | workspace/page.tsx:100-119 | clean null session → sign-out + `/login`; errored session → error card (Flutter: the app-surface gate lets the bare `/workspace` through on a null session so the picker can sign stale cookies out; `/home` and deeper app paths still go straight to `/login` because Flutter cannot see cookie presence; corrected 2026-10-22) | | |
| 11 | interaction | workspace/page.tsx:89-98 | 401 on workspaces → sign-out + `/login` once | | |
| 12 | interaction | workspace/page.tsx:138-158, 241-281 | zero workspaces: blocked card or default workspace creation; 409 single reload; failure → `/login` | | |
| 13 | interaction | workspace/page.tsx:129-134, 160-170 | target = lastActive or first; `redirect=upgrade|settings` honoured incl. `reason` | | |
| 14 | interaction | workspace/page.tsx:164-167, 220-239 | `redirect_workflow` → workflow's workspace, fallback to target | | |
| 15 | layout | workspace/page.tsx:46-72 | status card geometry: 448 px max, 40 px disc, 18/14 px copy, two chips | | |
| 16 | state | workspace/page.tsx:173-199 | blocked copy by `blockedReasonCode` / `workspaceMode`, self-healing | | |
| 17 | state | workspace/page.tsx:201-215 | error card conditions and copy | | |
| 18 | layout | application-loading.tsx:16-33 | loading surface: wordmark 67×32 `--text-tertiary` or brand mark | | |
| 19 | interaction | [workspaceId]/page.tsx:19; env-flags.ts:82 | `/workspace/<id>` → `home` or `w` by `NEXT_PUBLIC_CHAT_DISABLED` | | |
| 20 | interaction | home/layout.tsx:17-20 | chat disabled: `/workspace/<id>/home` → `/workspace/<id>` → `/w` | | |
| 21 | interaction | [workspaceId]/layout.tsx:73-82 | signed out → `/login`; no host context → `WorkspaceAccessDenied` | | |
| 22 | interaction | w/page.tsx:34-45 | `/w` → first workflow of the workspace; none → empty state | | |
| 23 | interaction | settings/[section]/layout.tsx:11-18, 55-59 | legacy redirects (integrations, skills, privacy, authorized-apps) and 404 | | |
| 24 | interaction | navigation.ts:41-48 | aliases subscription/team/api-keys/domains/sessions resolve without redirect | | |
| 25 | state | theme-provider.tsx:16-31, 70 | forced-light segment set; everything else follows `sim-theme` | | |
| 26 | network | workspace.ts:91-98; workspaces.ts:165-185 | `GET /api/workspaces?scope=active` fields consumed | | |
| 27 | network | workspace/page.tsx:248-250 | `POST /api/workspaces {name:'My Workspace'}` | | |
| 28 | network | stale-session-recovery.ts:19-29 | `POST /api/auth/sign-out` then `clearUserData` then `/login` | | |
| 29 | network | plan §5; o/[organizationId]/page.tsx:18 | `/o/<id>` decisions from `surface-context` (server addition) — verified-by-review until shipped | | |
| 30 | network | resolve-app-entry.ts:11-20 | `/home` organization gate needs `surface-context.searchAccess.memberScoped` — gap until the endpoint exists | | |

Colour anchors (picker cards, light theme): `entry.workspace.card @ (8,8)` → `--surface-1` #fbfbfb · disc centre `@ (20,20)` of `entry.workspace.card.icon` → `--surface-3` #f7f7f7 · `entry.workspace.card.primary @ (6,15)` → `--text-primary` #1a1a1a. Dark: #1e1e1e, #242424, #e6e6e6.
