# OAuth pages (consent, sign-in bridge, oauth-error, chat-complete, credential-connected)
Upstream: `apps/sim/app/(auth)/oauth/sign-in/route.ts`, `apps/sim/app/(auth)/oauth/consent/**`, `apps/sim/app/oauth-error/page.tsx`, `apps/sim/app/oauth/chat-complete/**`, `apps/sim/app/oauth/credential-connected/page.tsx`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

Five small surfaces. Two frames are used: the `AuthShell` (consent, inside `(auth)`) and the `LogoShell`/`DesktopHandoffShell` (oauth-error, chat-complete, credential-connected). All are forced light (`theme-provider.tsx:16-31`: segments `oauth`, `oauth-error`).

## Files
| File | Lines | Role |
|---|---|---|
| `app/(auth)/oauth/sign-in/route.ts` | 61 | Server GET: the OAuth provider plugin's `loginPage`; rebuilds the authorize URL and 302s to `/signup` or `/login` with `callbackUrl` |
| `app/(auth)/oauth/consent/page.tsx` | 63 | Server page: auth-disabled → `/`; signed-out → `/oauth/sign-in?<same query>`; tamper/unsigned/expiry checks; renders `OAuthConsentView` |
| `app/(auth)/oauth/consent/consent-view.tsx` | 198 | Client view: public-client lookup, scopes, Allow/Deny, switch account |
| `app/(auth)/oauth/consent/search-params.ts` | 13 | nuqs parsers `client_id`, `scope`, `redirect_uri` |
| `app/(auth)/oauth/consent/loading.tsx` | 17 | `OAuthConsentLoading` (header + spinner) |
| `hooks/queries/oauth-provider.ts` | 51-113 | `useOAuthPublicClient` (`client.oauth2.publicClientPrelogin`), `useOAuthConsent` (`client.oauth2.consent({accept})`), `useOAuthSwitchAccount` (`client.signOut()`) |
| `lib/auth/oauth-provider.ts` | 8, 93-117 | `SIM_CLI_CLIENT_ID = 'sim-cli'`, `OAUTH_SCOPE_DESCRIPTIONS`, `visibleOAuthScopes` |
| `app/oauth-error/page.tsx` | 69 | Server page: `?error=` → friendly message in `DesktopHandoffShell` |
| `app/oauth/chat-complete/page.tsx` | 28 | `ChatCompleteHandoff` + `DesktopHandoffShell` "Finishing the connection" |
| `app/oauth/chat-complete/chat-complete-handoff.tsx` | 67 | Client effect: publish attempt verdict, `window.close()`, fallback redirect after 400 ms |
| `app/oauth/credential-connected/page.tsx` | 39 | `LogoShell center` + `StatusPageContent` + "Open Sim" chip link |
| `app/desktop/components/desktop-handoff-shell/desktop-handoff-shell.tsx` | 32 | Title 40 px + description 18 px frame inside `LogoShell center` |
| `app/(landing)/components/logo-shell/logo-shell.tsx` | 45 | `LogoPage` with the landing logo link |
| `packages/emcn/src/components/status-page/status-page.tsx` | 78 | `StatusPageContent`, `LogoPage` (`PAGE_CONTENT_WIDTH` 1728 px, `PAGE_GUTTER` px-10) |
| `lib/credentials/oauth-chat-attempt.ts` | | `OAUTH_CHAT_ATTEMPT_PARAM`, `OAUTH_CHAT_RETURN_TO_PARAM`, `setOAuthChatAttemptStatus` (localStorage record read by the chat tab) |

## Layout
### A. `/oauth/sign-in` (route, no UI)
Server-only redirect (`sign-in/route.ts:40-61`): if `isAuthDisabled` → 302 `/`; strips `sig`, `exp`, `ba_iat`, `ba_param`, `ba_pl` from the query (`:12, 47`); removes `login` and `create` from `prompt` (keeping others) and remembers whether `login` was present (`:15-22, 48`); builds `authorizeUrl = /api/auth/oauth2/authorize?<remaining query>` (`:50`); 302 to `buildAuthCrossLink(isRegistrationDisabled || requiresLogin ? '/login' : '/signup', { callbackUrl: authorizeUrl, isInviteFlow: false })` (`:51-60`). Flutter: this route stays on the Next origin (it is reached only from the authorize endpoint, which is also Next). The Flutter login/signup pages must accept a `callbackUrl` of `/api/auth/oauth2/authorize?…` and, after sign-in, navigate the top-level browser there (which then shows `/oauth/consent`). The proxy never bounces a signed-in visitor off `/login` when that callback is present (`proxy.ts:388-395`).

### B. `/oauth/consent` — parity `oauth.consent`
`AuthShell` (header 62 px, 400 px column) wrapped in `div.[overflow-wrap:anywhere]` (`consent/page.tsx:52`). Content (`consent-view.tsx:135-197`), `space-y-6`:
1. `oauth.consent.header` `AuthHeader`: title `Authorize {appName}` (32 px / 1.2), description "Only continue if you started this yourself." (15 px `--text-muted`) — omitted for the CLI client (`:137-140`).
2. `div.space-y-4` (16 px) (`:141`):
   - `oauth.consent.scopes` `<ul class='space-y-2 px-2'>` (8 px gap, 8 px side padding), only when scopes remain after `visibleOAuthScopes` (`:142-154`): each `<li class='flex items-start gap-2 text-sm text-[var(--text-body)]'>` with `Check` icon 14×14 `mt-[3px] shrink-0 --text-icon` and the description text (`:145-151`). Scope copy (`oauth-provider.ts:93-99`): `offline_access` "Stay signed in without asking again"; `api:read` "Read your workspaces, workflows, files, tables, and logs"; `api:write` "Read, create, change, run, and delete resources in your workspaces"; `search:read` "Search and read documents you can access, and start private Sim Search conversations". `api:read` is hidden when `api:write` is present; `search:read` hidden when `api:read` is satisfied (`:109-117`). Declaration order.
   - `oauth.consent.allow` `AuthSubmitButton type='button'` "Allow" / spinner "Authorizing" (400×36 primary) (`:155-163`).
   - `oauth.consent.deny` `Chip variant='border' fullWidth` + `AUTH_BUTTON_CLASS`: 400×36, radius 8, transparent, box-shadow ring `0 0 0 1px rgba(28,40,64,.08), 0 1px 3px rgba(28,40,64,.1)`, hover `--surface-hover`, label "Deny" / "Declining…" (`:164-173`, `chip.tsx:77`).
   - `oauth.consent.destination` `<p class='break-words text-center text-caption --text-muted'>` "Returns to {hostname|this computer}." (loopback hosts `127.0.0.1`, `[::1]`, `::1` → "this computer"), omitted for the CLI (`:174-178`, `:51-61`).
   - `oauth.consent.error` `div[role=alert]` → `AuthFormMessage type='error' align='center'` with the mutation error message or "Something went wrong. Please try again." (`:179-188`).
   - `oauth.consent.account` `<p class='break-words text-center text-caption --text-muted'>` "Continuing as {email}. " + `oauth.consent.switch` `AuthTextLink` button "Use another account" / "Signing out…" (`:189-194`).
Refusal view (`:80-95`, `:101-109`) — parity `oauth.consent.refusal`: only an `AuthHeader` with title "Unable to connect" and description: `expired` "This authorization request has expired. Start sign-in again from the app."; `missing` "The authorization request is missing its client identifier."; `tampered` "This authorization request was altered on its way here."; `unsigned` "This authorization request did not come from Sim."; client lookup error → its message or "Sim could not identify the app. Start again from the app."; empty registered name → "Sim could not identify the app. Start again from the app asking for access."
Loading (`consent/loading.tsx:4-13`) — parity `oauth.consent.loading`: `div[role=status].space-y-6`: `AuthHeader` "Review app access" / "Loading the authorization request…" + centred `Loader` 20×20 spinning.

### C. `/oauth-error` — parity `oauth.error`
`DesktopHandoffShell` (`desktop-handoff-shell.tsx:20-31`) in `LogoShell center` (`logo-shell.tsx:26-44`) → `LogoPage` (`status-page.tsx:49-78`): root `relative flex min-h-screen flex-col bg --bg --text-primary` + `light`; header `nav` `flex items-center py-4 mx-auto w-full max-w-[1728px] px-10` (16 px vertical, 40 px horizontal at ≥1280; 36 px <1280, 32 px <1024, 28 px <768) with the same 30 px logo link + `LogoMark` + `SimWordmark` as `AuthShell`; `main.flex.flex-1.flex-col.items-center.justify-center.px-4.pb-16`. Content `oauth.error.card` `div.flex.w-full.max-w-[410px].flex-col.items-center.gap-3.text-center` (12 px gap): `oauth.error.title` `<h1>` 40 px / 110 % / −0.02 em `--text-primary` `text-balance` "Sign-in couldn’t be completed"; `oauth.error.description` `<p>` 18 px `--text-muted` = `{message} You can close this tab and return to Sim.` No action row.
Messages (`oauth-error/page.tsx:26-57`): `access_denied` "You declined the request at the provider, so nothing was connected."; `oAuth_code_missing` "The provider didn’t return a valid response. Please try again."; `signup_disabled` "Account creation is disabled on this instance. Ask your admin to create an account for you."; `account_not_linked` "An account already exists for this email address. Sign in using the method you originally signed up with."; `SSO_REQUIRED` "Your organization requires single sign-on. Sign in through your identity provider."; `email_not_found` "Your identity provider didn’t share an email address with us, so we couldn’t complete sign-in. Please contact your administrator."; anything else / missing → "The sign-in couldn’t be completed. Please try again."

### D. `/oauth/chat-complete` — parity `oauth.chatComplete`
Same `DesktopHandoffShell`: title "Finishing the connection", description "Returning you to Sim." (`chat-complete/page.tsx:21-28`). Behaviour (`chat-complete-handoff.tsx:47-64`, runs once): reads `?<OAUTH_CHAT_ATTEMPT_PARAM>` and `?<OAUTH_CHAT_RETURN_TO_PARAM>`; if an attempt id is present, `setOAuthChatAttemptStatus(id, 'failed' if ?error else 'connected')` (writes the attempt record the chat tab watches over the `storage` event); `window.close()`; after 400 ms (`:11`) if still open `window.location.replace(returnTo ?? '/home')` where `returnTo` must be same-origin (`:17-25`).

### E. `/oauth/credential-connected` — parity `oauth.credentialConnected`
`LogoShell center` + `StatusPageContent` (`status-page.tsx:16-36`): `div.flex.w-full.max-w-[410px].flex-col.items-center.gap-3.text-center`; `<h1>` 40 px / 110 % / −0.02 em `--text-primary`; `<p>` 18 px `--text-body` (not muted); action row `div.mt-3.flex.w-full.flex-wrap.items-center.justify-center.gap-2` (12 px extra top) with `oauth.credentialConnected.open` `ChipLink variant='primary' href='/home'` "Open Sim" (30 px primary chip, inline width). Copy (`credential-connected/page.tsx:24-38`): `?result=connected` and no `?error` → "Credential connected" / "The credential is ready to use. You can close this tab and return to the app that started the connection."; otherwise "Connection failed" / "The credential could not be connected. Return to the app that started the connection and try again."

## Tokens
| Element | Token(s) |
|---|---|
| Frames | `--bg`, `--text-primary`, `.light` (`status-page.tsx:60-63`, `auth-shell.tsx:35`) |
| Wordmark | `--text-body` |
| Consent scope rows | text `--text-body` 14 px, check `--text-icon` 14 px |
| Allow | primary chip tokens |
| Deny | `border` chip: shadow ring rgba(28,40,64,.08)+(.1), hover `--surface-hover`, label `--text-body` |
| Muted lines | `--text-muted` 12 px |
| Errors | `--text-error` 12 px centred |
| Switch link | `--text-secondary` → `--text-primary`; disabled opacity .5 |
| Status titles | `--text-primary` 40 px; descriptions `--text-muted` (handoff shell) or `--text-body` (status page) 18 px |
| Loader | `currentColor`, 20 px (consent loading) |

## States
| Surface | State | Behaviour |
|---|---|---|
| consent | auth disabled | server redirect `/` (`page.tsx:25`) |
| consent | signed out | server redirect `/oauth/sign-in?<every string param>` (`:29-35`) → login/signup with `callbackUrl=/api/auth/oauth2/authorize?…`; after sign-in the authorize endpoint re-issues a signed consent query |
| consent | tampered (any repeated key other than `ba_param`) / unsigned (no `sig`) / expired (`exp` seconds < now) | refusal header (`:41-49`) |
| consent | no `client_id` | refusal `missing` (`:80`) |
| consent | loading client | header "Review app access" + spinner (`:97`) |
| consent | client lookup error or empty name | refusal copy (`:81-95, 101-109`) |
| consent | ready | app name, optional scopes, Allow/Deny, destination, account line |
| consent | deciding | Allow shows "Authorizing" spinner (when accepting) or Deny shows "Declining…"; both disabled, switch disabled (`:112-113, 157-173`) |
| consent | decided | `window.location.assign(url)` to the client's `redirect_uri` (with `code` or `error=access_denied`) (`:118-120`) |
| consent | switching account | "Signing out…"; on success `window.location.assign('/oauth/sign-in?<current query>&prompt=login consent')` (`:124-133`) |
| consent | mutation error | centred red message (`:179-188`) |
| oauth-error | any | static copy by `?error` |
| chat-complete | any | closes itself; fallback redirect after 400 ms |
| credential-connected | connected / failed | copy by `?result` and `?error` |
| all | hosted-only | none |

## Interactions
- consent: Allow → `consent.mutate(true)`; Deny → `consent.mutate(false)`; "Use another account" → sign-out then restart at the login bridge; links in the header (logo → `/`). Keyboard: Tab order logo → Allow → Deny → Use another account; Enter/Space on the focused chip. No form.
- oauth-error / chat-complete / credential-connected: logo → `/`; "Open Sim" → `/home`.

## Network and realtime
Consent (`hooks/queries/oauth-provider.ts`):
1. `GET /api/auth/get-session` (page needs `session.user.email`; Flutter guards signed-out → `/oauth/sign-in?…` on the Next origin).
2. Public client: `client.oauth2.publicClientPrelogin({ client_id })` → Better Auth OAuth-provider plugin endpoint (GET, query `client_id`) → `{ client_id, client_name }`; query key `['oauth-provider','client', clientId, JSON.stringify(rawQuery)]`, `staleTime` 5 min, `enabled` only with both ids (`:64-85`). Ambiguity: the exact path of this plugin endpoint (`/api/auth/oauth2/public-client/prelogin` in `@better-auth/oauth-provider`) is not verifiable in this checkout (no `node_modules`); confirm in a contract test.
3. Allow/Deny: `client.oauth2.consent({ accept })` → `POST /api/auth/oauth2/consent` with `{ accept, oauth_query: <the signed query from the page URL> }` (the plugin client forwards it automatically, `lib/auth/client.ts:28-33`) → `{ url }`; then top-level navigation to `url` (`:93-103`). The server refuses `accept: true` with 403 when the user's `oauth_apps.use` (or `cli.use` for `sim-cli`) capability is withheld (`lib/auth/auth.ts:1053-1075`).
4. Switch account: `POST /api/auth/sign-out` (`:106-113`) then navigation.
oauth-error, chat-complete, credential-connected: no requests (chat-complete writes localStorage only).

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | consent-view.tsx:135-141 | `AuthShell` column; header + 16 px action stack; `[overflow-wrap:anywhere]` | | |
| 2 | layout | consent-view.tsx:142-154 | scope list `px-2`, rows 14 px with 14 px check at `mt-3px`, 8 px gaps | | |
| 3 | layout | consent-view.tsx:155-173; chip.tsx:77 | Allow 400×36 primary; Deny 400×36 `border` variant (shadow ring, no border) | | |
| 4 | layout | consent-view.tsx:174-194 | destination and account lines 12 px centred muted; switch link inline | | |
| 5 | layout | consent/loading.tsx:4-13 | "Review app access" header + 20 px spinner | | |
| 6 | layout | desktop-handoff-shell.tsx:22-30; status-page.tsx:60-72 | handoff frame: `LogoPage` header (py-4, px-10, max 1728), centred 410 px card, 12 px gap, 40 px title, 18 px description | | |
| 7 | layout | credential-connected/page.tsx:24-38; status-page.tsx:24-33 | status card with `--text-body` description and `mt-3` action row holding a 30 px primary chip link | | |
| 8 | token | consent-view.tsx:145-150 | scope text `--text-body`, icon `--text-icon` | | |
| 9 | token | chip.tsx:77 | Deny ring colours and hover `--surface-hover` | | |
| 10 | token | desktop-handoff-shell.tsx:27 vs status-page.tsx:31 | description `--text-muted` on handoff pages, `--text-body` on credential-connected | | |
| 11 | state | consent/page.tsx:25-49 | auth disabled → `/`; signed out → `/oauth/sign-in?…`; tampered/unsigned/expired refusals | | |
| 12 | state | consent-view.tsx:27-32, 80-109 | refusal copy table incl. missing client id and lookup failure | | |
| 13 | state | consent-view.tsx:99, 137-140, 174-178 | CLI client (`sim-cli`): no description line, no "Returns to" line | | |
| 14 | state | oauth-provider.ts:109-117 | `api:read` hidden under `api:write`; `search:read` hidden when `api:read` satisfied; declaration order | | |
| 15 | state | consent-view.tsx:112-113, 157-173 | in-flight labels "Authorizing" / "Declining…", all actions disabled | | |
| 16 | state | consent-view.tsx:179-188 | mutation error centred, fallback copy | | |
| 17 | state | consent-view.tsx:124-133 | switch account → sign-out → `/oauth/sign-in?…&prompt=login consent` | | |
| 18 | state | oauth-error/page.tsx:26-57 | error code → message table; suffix "You can close this tab and return to Sim." | | |
| 19 | state | chat-complete-handoff.tsx:47-64 | attempt verdict written; `window.close()`; 400 ms fallback to same-origin `returnTo` or `/home` | | |
| 20 | state | credential-connected/page.tsx:18-21, 24-38 | `result=connected` without `error` → connected copy; else failed copy | | |
| 21 | interaction | sign-in/route.ts:40-61 | login/signup accept `callbackUrl=/api/auth/oauth2/authorize?…` and navigate there after auth | | |
| 22 | network | oauth-provider.ts:64-85 | public client lookup via the plugin endpoint, 5 min stale, keyed on the whole signed query | | |
| 23 | network | oauth-provider.ts:93-103; client.ts:28-33 | `POST /api/auth/oauth2/consent` `{accept, oauth_query}` → navigate to `url` | | |
| 24 | network | oauth-provider.ts:106-113 | `POST /api/auth/sign-out` for "Use another account" | | |
| 25 | keyboard | DOM order | consent tab order logo → Allow → Deny → Use another account | | |

Colour anchors: consent: `auth.shell @ (8,8)` → #fefefe · `oauth.consent.allow @ (6,18)` → `--text-primary` #1a1a1a · `oauth.consent.deny @ (6,18)` → #fefefe (transparent) · `oauth.consent.deny @ (0,18)` → ring ≈ rgba(28,40,64,.08) over #fefefe ≈ #ededf0 (ΔE tolerance applies). oauth-error / credential-connected: `oauth.error.card @ (4,4)` → #fefefe · `oauth.credentialConnected.open @ (4,15)` → `--text-primary` #1a1a1a.
