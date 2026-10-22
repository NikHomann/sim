# Phase 1 data layer (contract spec)

Upstream: `apps/sim` at commit `27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c` (v0.9.30) plus the three server additions (`app/api/public-env`, `app/api/workspaces/[id]/feature-flags`, `app/api/organizations/[id]/surface-context`).
Phase: 1 (auth pages, entry resolution, workspace chrome and loaders, sidebar with workflow tree, search palette, workspace switcher, workspace/invite modals, invite accept page, session-expired, store reset).
Audience: the `sim_api` implementer (contracts, repositories, `Query<T>` wiring) and the app-cubit implementer. Facts only; everything the contracts leave untyped or the UI leaves ambiguous is in §11.
Paths below are relative to `apps/sim` unless prefixed; `flutter/` means `apps/flutter`.

## 1. Files

### 1.1 React sources this spec maps (line counts at the baseline commit)

| Area | File | Lines | Role |
|---|---|---|---|
| Client core | `lib/api/client/request.ts` | 292 | `requestJson`/`requestRaw`/`contractUrl`, path/query serialisation, headers |
| | `lib/api/client/errors.ts` | 107 | `ApiClientError`, `extractValidationIssues`, `findValidationIssue` |
| | `lib/api/client-id.ts` | 77 | `x-sim-client-id` |
| | `app/_shell/providers/get-query-client.ts` | 51 | React Query defaults |
| | `.claude/rules/sim-queries.md` | — | key factory / staleTime / signal / invalidation rules |
| Session | `hooks/queries/session.ts` | 85 | `useSessionQuery`, `refreshSessionQuery` |
| | `app/_shell/providers/session-provider.tsx` | 154 | `useSession` context, post-upgrade refresh |
| | `lib/auth/session-response.ts` | 83 | `AppSession`, `getActiveOrganizationId` |
| | `lib/auth/client.ts` | 70 | Better Auth client plugins |
| | `lib/auth/stale-session-recovery.ts`, `lib/auth/sign-out.ts` | 29, 21 | sign-out paths |
| | `stores/index.ts`, `stores/reset-all-stores.ts`, `stores/user-data-reset-registry.ts` | 64, 59, 21 | store reset |
| Auth pages | `app/(auth)/login/login-form.tsx` | 507 | sign-in, forgot password |
| | `app/(auth)/signup/signup-form.tsx`, `signup/page.tsx` | —, 50 | sign-up, captcha header |
| | `app/(auth)/verify/use-verification.ts`, `verify/page.tsx` | 247, 23 | OTP |
| | `app/(auth)/reset-password/reset-password-form.tsx` | — | reset |
| | `app/(auth)/components/sso-login-button.tsx`, `app/(auth)/sso/launch/[providerId]/route.ts` | 43, 80+ | SSO |
| | `app/(auth)/auth-redirect.ts`, `lib/navigation/paths.ts` | 118, 98 | post-auth routes |
| | `app/api/auth/providers/route.ts` | 22 | providers |
| Entry | `app/home/page.tsx`, `app/o/page.tsx`, `lib/navigation/resolve-app-entry.ts` | 31, 16, 32 | server-side entry resolution |
| | `app/workspace/page.tsx` | 281 | picker, stale-session recovery, default workspace |
| | `app/workspace/[workspaceId]/page.tsx` | 20 | `home` vs `w` |
| Workspace shell | `app/workspace/[workspaceId]/layout.tsx` | 224 | provider tree, server flags, prefetch |
| | `app/workspace/[workspaceId]/prefetch.ts`, `prefetch-access.ts` | 146, 73 | server prefetch |
| | `app/workspace/[workspaceId]/providers/*.tsx` | — | host, flags, permissions, scope sync, settings, provider models, custom blocks, block visibility |
| | `lib/core/config/deployment-shape.ts`, `lib/core/config/feature-flags.ts`, `lib/core/config/env-flags.ts` | 146, 231, 665+ | deployment shape, flag registry |
| | `app/_shell/public-env-script.tsx`, `lib/core/config/env.ts` | 110, — | `NEXT_PUBLIC_*` transport |
| Queries | `hooks/queries/workspace.ts` | 530 | workspaces |
| | `hooks/queries/workspace-host.ts` | 37 | host context |
| | `hooks/queries/workspace-usage.ts`, `utils/workspace-usage-keys.ts` | 50, 12 | credit availability, usage gate |
| | `hooks/queries/workflows.ts`, `utils/workflow-keys.ts`, `utils/workflow-list-query.ts`, `utils/workflow-cache.ts`, `utils/invalidate-workflow-lists.ts` | 708, 22, 49, 48, 25 | workflows |
| | `hooks/queries/folders.ts`, `utils/folder-keys.ts`, `utils/folder-cache.ts`, `utils/optimistic-mutation.ts`, `utils/top-insertion-sort-order.ts` | 459, 51, 26, 84, 44 | folders |
| | `hooks/queries/pinned-items.ts`, `utils/pinned-item-keys.ts` | 154, 21 | pins |
| | `hooks/queries/invitations.ts` | 468 | invitations, members, permissions |
| | `hooks/queries/user-profile.ts`, `general-settings.ts`, `current-user-data.ts` | 104, 195, 65 | profile, settings |
| | `hooks/queries/custom-blocks.ts`, `block-visibility.ts`, `providers.ts` | 107, 31, 145 | loaders |
| | `hooks/queries/organization.ts`, `utils/organization-keys.ts`, `organization-plan-seats.ts` | 499, 17, 30 | organizations |
| | `hooks/queries/subscription.ts`, `subscription-data.ts`, `utils/subscription-keys.ts` | 220, 31, 13 | billing |
| | `hooks/queries/allowed-providers.ts`, `integration-availability.ts`, `utils/integration-availability-keys.ts` | 26, 15, 8 | settings/allowed-* |
| | `hooks/queries/recently-deleted.ts`, `utils/recently-deleted-keys.ts`, `utils/settings-read-retry.ts` | 52, 31, 9 | recently deleted |
| | `hooks/queries/contact.ts` | 25 | public contact form (not the help modal) |
| | `hooks/queries/status-page.ts`, `lib/status-page.ts` | 28, 35 | hosted status notice |
| | `hooks/queries/mothership-chats.ts` (list part) | 895 | sidebar chats section |
| | `hooks/queries/access-requests.ts`, `utils/access-request-keys.ts`, `ee/access-requests/components/permission-access-boundary.tsx` | 236, 41, — | access-request discovery |
| | `ee/access-control/hooks/permission-groups.ts`, `hooks/use-permission-config.ts`, `utils/permission-group-keys.ts` | —, 281, 18 | permission config |
| | `ee/whitelabeling/hooks/whitelabel.ts`, `ee/whitelabeling/components/branding-provider.tsx` | 70+, 80 | branding |
| Sidebar | `app/workspace/[workspaceId]/w/components/sidebar/sidebar.tsx` | 1950+ | chrome |
| | `.../sidebar/hooks/use-workspace-management.ts`, `use-workflow-operations.ts`, `use-folder-operations.ts`, `use-workspace-workflows-room.ts`, `use-workspace-logo-upload.ts` | 247, 57, 51, 29, 142 | operations |
| | `.../sidebar/components/workspace-header/workspace-header.tsx` | 880+ | switcher |
| | `.../workspace-header/components/create-workspace-modal/create-workspace-modal.tsx`, `pending-invitations/view-invitations-menu-item.tsx`, `view-invitations-modal.tsx` | 87, 30, 222 | modals |
| | `.../sidebar/components/sidebar-footer/sidebar-footer.tsx`, `help-modal/help-modal.tsx`, `status-notice/status-notice.tsx` | 339, 365, 57 | account menu, help, status |
| | `.../sidebar/components/search-modal/search-modal.tsx`, `stores/modals/search/store.ts` | 1420+, — | palette |
| | `app/workspace/[workspaceId]/components/invite-modal/invite-modal.tsx` | 300+ | invite |
| | `app/workspace/[workspaceId]/components/session-expired/session-expired.tsx`, `impersonation-banner/impersonation-banner.tsx`, `workspace-access-denied.tsx`, `workspace-chrome/workspace-chrome.tsx` | 86, 49, 27, 451 | shell states |
| | `app/workspace/[workspaceId]/hooks/use-workspace-invalidation-room.ts` | 137 | socket invalidation rooms |
| | `stores/sidebar/store.ts`, `lib/core/utils/theme.ts` | 141, 28 | sidebar persistence, theme sync |
| Invite | `app/invite/[id]/invite.tsx`, `lib/invitations/error-messages.ts` | 608, 37 | accept page |
| | `app/api/invitations/[id]/accept/route.ts`, `reject/route.ts` | 74, 60+ | status map |
| Contracts | `lib/api/contracts/{workspaces,workflows,folders,pinned-items,invitations,user,common,auth,custom-blocks,block-visibility,providers,organization,organizations,contact,recently-deleted,subscription,permission-groups,access-requests,mothership-chats,public-env}.ts` | — | wire shapes |
| Routes | `app/api/workspaces/route.ts`, `app/api/workspaces/[id]/host-context/route.ts`, `app/api/help/route.ts`, `lib/api/server/routes/internal-json-route.ts`, `lib/core/rate-limiter/route-helpers.ts` | 150+, 29, 120+, 200+, 90+ | behaviour cited in §2 |

### 1.2 Flutter files that already exist (reference, do not duplicate)

`flutter/packages/sim_api/lib/src/`:
- `client/sim_http_client.dart`: `SimHttpClient.send/requestJson/stream`, `resolvePath`, `x-sim-client-id` header (`clientIdHeader`, `generateShortId`), desktop `origin` header, `decodeBody` (JSON else raw text else `null`), `ApiResponse{status,data,headers,rateLimit,requestId}`.
- `client/api_client_error.dart`: `ApiClientError{status,message,code,body,rawBody,details,retryAfter}` (message from `body.message ?? body.error`, same as `messageFromErrorBody`), `ApiNetworkError`, `ApiCancelledError`, `RateLimitInfo.fromHeaders` (`x-ratelimit-limit/remaining/reset`, `retry-after`), `ValidationIssue.matches` (port of `findValidationIssue`).
- `client/query_serialization.dart`: `replacePathParams`, `appendQuery` (port of `request.ts:36-100`).
- `client/retry.dart`: `backoffWithJitter`, `parseRetryAfter`.
- `query/query_client.dart`: `QueryClient` (keys hashed like React Query, `staleTime`, in-flight dedupe, `invalidateQueries(prefix)`, `cancelQueries`, `removeQueries`, `onFocus()`, `optimisticUpdate`, `clear()`), `Query<T>` observer.
- `auth/auth_repository.dart` + `auth/auth_models.dart`: every Better Auth call of §4.1 (`signInEmail`, `signUpEmail` with `x-captcha-response`, `signInSocial`, `verifyEmailOtp`, `sendVerificationOtp`, `getSession(disableCookieCache)`, `signOut`, `forgetPassword`, `resetPassword`, `providers`, `resolveSsoProvider`, `socketToken`, `redeemOneTimeToken`); `AuthSession{user: AuthUser{id,email,emailVerified,name,image,role,createdAt,updatedAt}, session: SessionInfo{id,userId,activeOrganizationId,impersonatedBy,expiresAt}}`, `AuthProviders`, `SocialSignInStart`.
- `uploads/upload_session.dart`: signed upload sessions (used by the workspace-logo upload, `purpose: 'workspace_logo'`).
- `realtime/socket_transport.dart`: the Socket.IO transport (used by the workflow-list invalidation room, §4.9).
- `storage/shared_web_state.dart`: `sim-theme`, `sidebar-state`, `sidebar_collapsed` cookie access shared with React.

`flutter/generated/contracts/*.schema.json`: one file per contract module (`{source, contracts: {<name>: {method, path, params?, query?, body?, headers?, response: {mode, schema}}}}`, JSON Schema draft 2020-12 exported from the zod schemas). Field names and types in this spec are taken from the zod sources; the JSON files are the machine-readable twin. Modules needed in Phase 1: `auth`, `public-env`, `workspaces`, `workflows`, `folders`, `pinned-items`, `invitations`, `user`, `common`, `custom-blocks`, `block-visibility`, `providers`, `organization`, `organizations`, `recently-deleted`, `subscription`, `permission-groups`, `access-requests`, `mothership-chats`, `contact`.

## 2. Request and query conventions (verified against the sources)

### 2.1 Transport
- Every same-origin call goes through `requestJson(contract, {params, query, body, headers, signal, keepalive})` (`request.ts:198-243`). Path params fill `[id]`, `[...x]`, `[[...x]]` (`:36-61`); query: `undefined/null/''` skipped, scalar arrays repeat the key, arrays containing objects and plain objects are sent as one JSON-string param (`:63-100`); body is `JSON.stringify` with `Content-Type: application/json` only when the contract has a body and the method is not GET (`:214-221`).
- Headers added to **every** request (`:102-123`): `x-sim-client-id` (`CLIENT_ID_HEADER`, `client-id.ts:9`; per-tab `generateShortId()`, cached for the page lifetime `:30-34`; server ignores values longer than 64 chars `:17`) and `x-sim-client-info` when `getClientInfoHeader()` returns a value (`lib/api/client-info.ts`, desktop/CLI only; **the web client sends none**; Flutter sends only `x-sim-client-id`, already done by `SimHttpClient`).
- Success body is parsed with the contract's zod schema; a schema failure throws `ApiClientError{status: 200, message: 'Response failed contract validation — <field: reason>'}` (`:229-242`). Flutter: decode failures must surface as `ApiClientError` with the 2xx status, never as a generic exception.
- Non-2xx → `ApiClientError{status, message: body.message ?? body.error ?? 'Request failed with <status>', body, rawBody, code: body.code}` (`:223-231`, `errors.ts:9-24`). Internal routes answer `{error, requestId?}` (`internal-json-route.ts:160-180`), validation failures `{error, details:[{path, message}]}`, Better Auth `{code, message}`.
- `requestRaw` (`:261-292`) is the same with no body parsing; used for downloads and multipart. The help modal uses a raw `fetch('/api/help', {method:'POST', body: FormData})` (`help-modal.tsx:107-110`).

### 2.2 React Query defaults (`get-query-client.ts:4-35`)
`staleTime: 30_000` (every hook overrides with a named constant anyway), `refetchOnWindowFocus: isDesktopApp()` (**false on web**; only `useSessionQuery` and `useStatusPage` opt in), `retry: 1` in the browser (`0` on the server), `retryOnMount: false`, mutations `retry: false`. `QueryClient.onFocus()` in `sim_api` must therefore be wired only for the queries that set `refetchOnWindowFocus: true` (session, status page); the Flutter web app must **not** refetch everything on focus.

### 2.3 Key factory and staleTime rules (`.claude/rules/sim-queries.md`)
Hierarchical keys with an `all` root; every fetch-scoping argument appears in the key; `staleTime` is a named exported constant; `queryFn` forwards `signal`; plain mutations invalidate in `onSuccess`, optimistic ones in `onSettled`; targeted prefixes (`lists()`) over `all`. Dart keys are the same string arrays (hashed by `queryHash`), so invalidation prefixes match the React ones in §6.

### 2.4 Pagination shapes used in Phase 1
- Workspaces: `{workspaces, lastActiveWorkspaceId, pinnedWorkspaceIds, creationPolicy}` (no paging).
- Workflows: `{data: WorkflowListItem[]}`; folders `{folders}`; pinned items `{pinnedItems}`; invitations `{invitations}`; chats `{success:true, data}`.
- Recently deleted: cursor paging `?cursor&limit(≤100, default 50)` → `{items (≤100), nextCursor: string|null}` (`recently-deleted.ts:48-91`).
- Access-request discovery: offset paging `{limit, offset}` → `{entries, total, hasMore}`.

### 2.5 Rate limiting
- Internal JSON routes built with `defineInternalJsonRoute` use `internalRateLimits.user({bucketName})` (`internal-json-route.ts:124-154`), default bucket 60 burst / 30 per minute per user (`route-helpers.ts:12-17`). On refusal: HTTP 429, body `{error: 'Rate limit exceeded', retryAfter: <epoch ms>}`, headers `Retry-After: <seconds, ≥1>` and `X-RateLimit-Reset: <ISO date>` (`:27-42`). Buckets touched in Phase 1: `workspace-feature-flags`, `organization-surface-context` (the two new routes); the legacy `withRouteHandler` routes (workspaces, folders, workflows, pinned items, invitations, users/me, host-context, auth) enforce no per-user bucket. `POST /api/auth/socket-token` is 30/min/user (`03-api-and-auth.md` §7); `/sso/launch/[providerId]` 30/min/IP.
- `RateLimitInfo` in `sim_api` already parses these headers; `shouldRetrySettingsRead` (`settings-read-retry.ts:4-9`) retries once on 408/429/5xx except 503 and is the retry policy for `useRecentlyDeletedItems` and `useOrganizationPlanSeats`; `useUserPermissionConfig` retries up to 3 times on 5xx only (`permission-groups.ts:116-119`); session and invitation-details queries never retry.

### 2.6 Cancellation
Every `queryFn` forwards `signal`; `QueryClient.cancelQueries(key)` cancels the Dio token. Mutations with optimistic updates call `cancelQueries(listKey)` first (`workflows.ts:210-213`, `folders.ts:421`, `pinned-items.ts:106`, `workspace.ts:166, 238`).

## 3. Runtime configuration objects

### 3.1 `DeploymentShape` (`lib/api/contracts/workspaces.ts:267-298`, resolver `deployment-shape.ts:75-96`)
```
DeploymentShape {
  hosted: bool                 // NEXT_PUBLIC_APP_URL host is sim.ai or *.sim.ai, or NEXT_PUBLIC_FORCE_HOSTED (non-prod only)   env-flags.ts:49-65
  billingEnabled: bool         // server BILLING_ENABLED / client NEXT_PUBLIC_BILLING_ENABLED                                   :123-126
  chatEnabled: bool            // !NEXT_PUBLIC_CHAT_DISABLED (default true)                                                       :82
  azureConfigured: bool        // NEXT_PUBLIC_AZURE_CONFIGURED                                                                    :608
  cohereConfigured: bool       // NEXT_PUBLIC_COHERE_CONFIGURED                                                                   :616
  features: DeploymentFeatures {
    accessControl, auditLogs, customBlocks, dataDrains, dataRetention, inbox, sandboxes, scim,
    sessionPolicies, sso, usageMonitoring, whitelabeling: bool   // enterpriseFeatureEnabled(...) per NEXT_PUBLIC_*_ENABLED   :322-485
  }
}
```
Defaults when nothing is configured: every boolean `false` except `chatEnabled: true`. Source of truth for the browser: `hostContext.deployment` (optional on the wire for rolling compatibility; absent → fall back to the `NEXT_PUBLIC_*` values from `GET /api/public-env`, mirroring `browserFallbackShape()` `deployment-shape.ts:62-66`). `seedDeploymentShape` no-ops when the shape is structurally equal (`:97-120`), so a host-context refetch must not notify listeners for an unchanged shape.

### 3.2 Workspace feature flags (`workspaces.ts:350-376`, `feature-flags-provider.tsx:63-72`)
```
WorkspaceFeatureFlags {
  dashboards, "workflow-tests", changelog, "mothership-model-selector",
  "mothership-computer-use", "mothership-plan-mode", projects: bool      // all required on the wire
  "mothership-memory-spaces"?: bool                                        // only in the organization surface response
}
desktopExecutor { available: bool, registered: bool }
```
`useFeatureFlag(name)` returns `flags[name] ?? false` (`:87-91`). The server registry (`feature-flags.ts:55-144`) defines 13 flags (`dashboards`, `mothership-computer-use`, `mothership-search-integration-tools`, `workflow-tests`, `changelog`, `mothership-model-selector`, `agent-memory-history`, `zoom-search`, `slack-search-shared-app`, `trigger-eu-region`, `projects`, `knowledge-member-access`, `mothership-abandoned-run-takeover-disabled`); self-hosted fallback is the env variable named in `fallback` (`DASHBOARDS`, `WORKFLOW_TESTS`, `CHANGELOG`, `MSHIP_MODEL_SELECTOR`, `MSHIP_COMPUTER_USE`, `PROJECTS`), so on the docker stack every workspace flag is `false` unless those are set. `mothership-plan-mode` is per-user (`isPlanModeEnabled(userId).catch(() => false)`), the rest per host organization.

### 3.3 `NEXT_PUBLIC_*` keys Phase 1 reads (`GET /api/public-env`; the React client reads them through `getEnv`, `env.ts:88`)
`NEXT_PUBLIC_APP_URL`, `NEXT_PUBLIC_SOCKET_URL`, `NEXT_PUBLIC_BILLING_ENABLED`, `NEXT_PUBLIC_CHAT_DISABLED`, `NEXT_PUBLIC_SSO_ENABLED`, `NEXT_PUBLIC_ORGANIZATIONS_ENABLED`, `NEXT_PUBLIC_ENTERPRISE_ENABLED`, `NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED` (login/signup show the email form unless `isFalsy`), `NEXT_PUBLIC_TURNSTILE_SITE_KEY` (signup captcha), `NEXT_PUBLIC_DISABLE_INVITATIONS`, `NEXT_PUBLIC_DISABLE_PUBLIC_API` (`use-permission-config.ts:218-226`), `NEXT_PUBLIC_STATUS_NOTICE_PREVIEW` (`env-flags.ts:89`), `NEXT_PUBLIC_FORCE_HOSTED`, `NEXT_PUBLIC_AZURE_CONFIGURED`, `NEXT_PUBLIC_COHERE_CONFIGURED`, `NEXT_PUBLIC_{ACCESS_CONTROL,AUDIT_LOGS,CUSTOM_BLOCKS,DATA_DRAINS,DATA_RETENTION,INBOX,SANDBOXES,SCIM,SESSION_POLICIES,USAGE_MONITORING,WHITELABELING,FORKING}_ENABLED`, `NEXT_PUBLIC_POSTHOG_KEY`/`_ENABLED` (hosted analytics only). Values are strings; truthiness is `isTruthy` (`'true'|'1'`, case-insensitive) / `isFalsy`. The route returns **every** `NEXT_PUBLIC_*` currently in `process.env` (`public-env-script.tsx:10-14`) with `Cache-Control: no-store`; the contract rejects any key without the prefix (`public-env.ts:17-19`). Server-only flags the auth pages receive as props (`isRegistrationDisabled`, `isEmailSignupDisabled`, `isEmailVerificationEffectivelyEnabled`, `hasEmailService`, `isProd`) are **not** in the transport: see §11.

### 3.4 Organization surface context (`organization.ts:863-911`, `lib/organizations/surface.ts:51-61`)
```
GET /api/organizations/[id]/surface-context → {
  context: {
    organization: { id, name, slug, logo: string|null, memberCount: int ≥ 0 },
    viewer: { role: 'owner'|'admin'|'member', isAdmin, canInviteMembers, canConnectSearchIntegrations, canUsePersonalApiKeys, canUseSearchMcp: bool },
    connectedAccountsAvailable, mothershipAvailable, canBuild: bool,
    searchAccess: { sourceMirrored, memberScoped: bool },
    settingsFeatures: { billingEnabled, hasEnterprisePlan, governanceActive, hosted: bool,
                        selfHosted: Record<string, bool> },   // keys: connected-accounts, access-control, audit-logs, sso, security, data-retention, data-drains, usage, whitelabeling (navigation.ts:1073-1083)
    deployment: DeploymentShape
  },
  flags: WorkspaceFeatureFlags & { "mothership-memory-spaces": bool },
  benchmarkEnabled: bool
}
```
403 `{error}` for a non-member or unknown organization (`internalOrganizationErrorPolicy`), 401 signed out.

## 4. Endpoints and hooks

Format per entry: hook (file:line) · key · staleTime · contract (method path; params/query/body; response) · fields the UI reads · errors · prefetch note. "Prefetched" means the React layout hydrates the key server-side so the client gets it without a request on a cold load; Flutter must fetch it itself in the loader order of §7.

### 4.1 Auth (Better Auth SDK; already in `AuthRepository`)

| Call | Contract | UI behaviour | Source |
|---|---|---|---|
| Session | `GET /api/auth/get-session[?disableCookieCache=true]` → `{session, user}` or `null`. Hook `useSessionQuery` (`session.ts:71-85`): key `['session','detail']`, `SESSION_STALE_TIME = 5 min`, `retry: false`, `refetchOnWindowFocus: true`, `refetchInterval` 60 s **only while** `session.impersonatedBy` is set (then also `disableCookieCache=true`, `:75-77`). `AppSession.user{id,email,emailVerified?,name?,image?,role?,createdAt?,updatedAt?}`, `session{id?,userId?,activeOrganizationId?,impersonatedBy?}` (`session-response.ts:9-26`). | Superuser flag: `user.role === 'admin'` (plan §5). `refreshSessionQuery` (`:33-42`) cancels, fetches with `disableCookieCache=true`, `setQueryData`; called after invitation accept, signup/verify, `?upgraded=true` (`session-provider.tsx:47-56`). A `{data:null,error:{status,statusText,message?}}` envelope throws `Error(message ?? statusText)` (`session-response.ts:61-66`), never a null session. | |
| Providers | `GET /api/auth/providers` → `{githubAvailable, googleAvailable, microsoftAvailable, registrationDisabled}` (`auth.ts:11-16`, route `providers/route.ts:11-22`). Unauthenticated. | Login/signup button set; `registrationDisabled` hides the signup cross-link and makes `/signup` render `RegistrationDisabled`. | |
| Sign in | `POST /api/auth/sign-in/email` `{email, password, callbackURL}` | `code` contains `EMAIL_NOT_VERIFIED` → store `verificationEmail` in sessionStorage, go `/verify` (`login-form.tsx:199-203`); `status 403 && message` → form-level policy error (`:210-217`); else password-field error list: `BAD_REQUEST`/"not enabled" → "Email sign in is currently disabled."; `INVALID_CREDENTIALS`/"invalid password"; `USER_NOT_FOUND`/"not found"; `MISSING_CREDENTIALS`; `EMAIL_PASSWORD_DISABLED`; `FAILED_TO_CREATE_SESSION`; "too many attempts"; "account locked"; "network"; message contains "rate limit" (`:219-255`). Success → document navigation to `callbackUrl` (validated by `validateCallbackUrl`, default `DEFAULT_POST_AUTH_ROUTE = '/home'`, `auth-redirect.ts:17`). | |
| Sign up | `POST /api/auth/sign-up/email` `{email, password, name}`, header `x-captcha-response` when a Turnstile token exists (`signup-form.tsx:286-295`) | Codes: `USER_ALREADY_EXISTS` (email field), `BAD_REQUEST`/"not enabled", `INVALID_EMAIL`, `PASSWORD_TOO_SHORT`, `PASSWORD_TOO_LONG`, "network", "rate limit" (`:300-337`). Success → `refetchSession()`, then `resolvePostSignupDestination`: verification enabled → `/verify?fromSignup=true` with `verificationEmail` + `postAuthRedirectUrl` in sessionStorage; else document navigation to the validated callback or `/home` (`:349-380`, `auth-redirect.ts:43-49`). | |
| Verify | `POST /api/auth/email-otp/verify-email` `{email, otp}`; resend `POST /api/auth/email-otp/send-verification-otp` `{email, type:'email-verification'}` | OTP auto-submits 300 ms after 6 chars (`use-verification.ts:193-207`); error `code === SSO_REQUIRED_ERROR_CODE` keeps the server message, otherwise "Invalid verification code…"; thrown message containing `expired` / `invalid` / `attempts` maps to the three messages (`:139-156`); success → `refetchSession()`, 1 s delay, document navigation to `redirectAfter` or stored `postAuthRedirectUrl` or `/home` (`:107-123`). When verification is disabled the page immediately refetches the session and navigates (`:209-231`). | |
| Forgot | `POST /api/auth/forget-password` `{email, redirectTo: '<base>/reset-password'}` → `{success:true}` (`user.ts:200-227`) | Error messages rewritten when they contain `Invalid body parameters`/`invalid email`, `Email is required`, `user not found` (`login-form.tsx:322-340`). | |
| Reset | `POST /api/auth/reset-password` `{token, newPassword}` (8–100, upper, lower, digit, special; `user.ts:229-253`) → `{success:true}` | success → `/login?resetSuccess=true` banner. Client validates the same policy before sending. | |
| SSO | `POST /api/auth/sso/resolve` `{email (trim, lowercase, ≤320), providerId?}` → `{providerId}` (`auth.ts:106-118`); then navigate to `/sso/launch/[providerId]` (page route: redirects signed-in users to `/home`, rate-limits 30/min/IP, redirects to `/sso?error=sso_failed&provider=…` on failure). `SSOLoginButton` only navigates to `/sso?callbackUrl=…` (`sso-login-button.tsx:24-27`); the form lives in `ee/sso/components/sso-form` (not mapped here). | |
| Sign out | `POST /api/auth/sign-out` | `signOutAndRedirect` (`sign-out.ts:8-21`): `Promise.all([signOut(), clearUserData()])`; navigate in-app to `/login?fromLogout=true` when the in-memory reset succeeded, else `window.location.assign`. `recoverFromStaleSession` (`stale-session-recovery.ts:19-29`): sign out, `clearUserData()`, `window.location.assign('/login')`; returns `false` without navigating when sign-out fails. | |
| Social | `POST /api/auth/sign-in/social` `{provider, callbackURL}` → `{url, redirect}` (`social-sign-in.ts:21-29`) | browser navigates to `url`. | |
| Stop impersonating | Better Auth admin plugin `client.admin.stopImpersonating()` = `POST /api/auth/admin/stop-impersonating` (`admin-users.ts:275-285`) | then `clearUserData({preserveRecentImpersonations:true})` and `window.location.assign('/home')` (`impersonation-banner.tsx:40-44`). | |
| Socket token | `POST /api/auth/socket-token` header `cache-control: no-store` → `{token}`; 401 → "Authentication required"; other → `SocketTokenUnavailableError(parseRetryAfter(retry-after))` (`socket-provider.tsx:367-388`) | already `AuthRepository.socketToken`. | |

### 4.2 Runtime config

| Hook / key | staleTime | Contract | UI reads | Errors |
|---|---|---|---|---|
| (new) `GET /api/public-env` → `Record<'NEXT_PUBLIC_*', string>` (`public-env.ts:10-22`); unauthenticated; `Cache-Control: no-store` | fetch once at app start, refetch never (React reads it from `<html data-public-env>` / `window.__ENV`) | §3.3 keys | 5xx → the app cannot start; show the loading page error state |
| `useWorkspaceHostContextQuery(workspaceId)` (`workspace-host.ts:30-37`); key `['workspace-host','detail',id]`; `WORKSPACE_HOST_CONTEXT_STALE_TIME = 30 s` | `GET /api/workspaces/[id]/host-context` → `WorkspaceHostContext` (`workspaces.ts:302-335`): `workspace{id,name,workspaceMode: 'personal'|'organization'|'grandfathered_shared', billedAccountUserId, allowPersonalApiKeys?}`, `hostOrganizationId: string|null`, `ownerBilling{plan, status: string|null, isPaid, isPro, isTeam, isEnterprise, isOrgScoped, organizationId: string|null, billingInterval: 'month'|'year', billingBlocked, billingBlockedReason: 'payment_failed'|'dispute'|null}`, `viewer{permission: 'admin'|'write'|'read', isHostOrganizationMember, isHostOrganizationAdmin, organizationRole?: 'owner'|'admin'|'member'|null}`, `features?{credentialGroups, organizationSearch?, knowledgeMemberAccess?, knowledgeSourceMirroredAccess?}`, `deployment?: DeploymentShape` | `deployment` seeds the shape; `viewer.permission`; `hostOrganizationId` + `viewer.isHostOrganizationMember` drive branding; `canViewWorkspaceBillingSettings(hostContext, profile.id)` = `deployment.billingEnabled && (hostOrganizationId ? viewer.isHostOrganizationAdmin : workspace.billedAccountUserId === viewerId)` (`lib/billing/workspace-permissions.ts:11-41`) gates the Billing entry in the account menu; `features.credentialGroups` gates the `credential_group` block | 401 `{error:'Unauthorized'}`; **403** `{error:'Workspace access denied'}` for a workspace the viewer cannot read or that does not exist (`host-context/route.ts:9-29`) → `WorkspaceAccessDenied` page (`workspace-host-provider.tsx:35-37`). Prefetched by the layout (`prefetch.ts:32-42`); a `null` server result renders `WorkspaceAccessDenied` before anything else (`layout.tsx:72-76`). |
| (new) feature flags; no React hook (server props) | fetch on workspace entry, refetch on workspace switch; no staleTime upstream (choose 30 s like host context) | `GET /api/workspaces/[id]/feature-flags` → `{flags: WorkspaceFeatureFlags, desktopExecutor{available, registered}}` (`workspaces.ts:360-376`); `internalSessionAuth`, `internalRateLimits.user('workspace-feature-flags')`, `internalOrchestrationErrorPolicy` | sidebar: `dashboards`, `workflow-tests`, `changelog` (`sidebar.tsx:754-756`); desktop executor entry (`:380, 912`) | 401; 403 `{error}` when the viewer cannot read the workspace; 404 unknown workspace; 429 per §2.5 |
| (new) organization surface context | per organization, on `/o/*` entry | §3.4 | organization entry link in the account menu needs only "does the viewer have an organization home" (§8) | 401; 403 `{error}` non-member |
| `useGeneralSettings` (`general-settings.ts:47-55`); key `['generalSettings','settings']`; `GENERAL_SETTINGS_STALE_TIME = 60 min` (`current-user-data.ts:30`) | `GET /api/users/me/settings` → `{data: UserSettingsApi}` (`user.ts:136-186`): `theme: 'system'|'light'|'dark' (default 'system')`, `autoConnect (true)`, `telemetryEnabled (true)`, `emailPreferences{unsubscribeAll?, unsubscribeMarketing?, unsubscribeUpdates?, unsubscribeNotifications?}`, `billingUsageNotificationsEnabled (true)`, `superUserModeEnabled (false)`, `mothershipEnvironment: 'default'|'dev'|'staging'|'prod'`, `errorNotificationsEnabled (true)`, `snapToGridSize: 0..50 (0)`, `showActionBar (true)`, `autoFocusOnClick (true)`, `copilotAutoAllowedTools: string[]`, `timezone: string|null`, `lastActiveWorkspaceId?: string|null` | mapped to `GeneralSettings` (`current-user-data.ts:50-65`; `lastActiveWorkspaceId` and `emailPreferences` dropped); `theme` is written to `localStorage['sim-theme']` + a synthetic `storage` event (`theme.ts:11-28`) on every change; `useTimezoneState` falls back to the browser zone | 500 `{error:'Failed to load settings'}`; the theme defaults to the stored `sim-theme` until loaded |

### 4.3 Workspaces (`hooks/queries/workspace.ts`)

Keys (`:40-52`): `workspaceKeys.all = ['workspace']`, `lists() = [...all,'list']`, `list(scope='active') = [...lists(),'user',scope]`, `details()`, `detail(id)`, `settings(id) = [...detail(id),'settings']`, `permissions(id) = [...detail(id),'permissions']`, `members(id)`, `adminLists()`, `adminList(userId)`. Constants: `WORKSPACE_LIST_STALE_TIME = 30 s` (`workspace-list-query.ts:3`), `WORKSPACE_PERMISSIONS_STALE_TIME = 30 s`, `WORKSPACE_SETTINGS_STALE_TIME = 30 s`, `WORKSPACE_MEMBERS_STALE_TIME = 5 min`, `WORKSPACE_ADMIN_LIST_STALE_TIME = 60 s` (`:56-59`).

Wire `Workspace` (`workspaces.ts:24-62`): `id, name, color?, logoUrl?: string|null, ownerId, organizationId: string|null, workspaceMode, role?, membershipId?, permissions?: 'admin'|'write'|'read'|null, isOrgAdmin?, billedAccountUserId?: string|null, allowPersonalApiKeys?, storageUsedBytes?, inboxEnabled?, inboxAddress?, inboxProviderId?, inboxSecretScope?, inboxMountedSecrets?, archivedAt?: datetime|null, organizationAssignedAt?, forkSyncNewWorkflowsExcluded?, createdAt?, updatedAt?, inviteMembersEnabled?, inviteDisabledReason?: string|null, inviteUpgradeRequired?, forkedFromWorkspaceId?: string|null`. `normalizeWorkspace` defaults `inviteMembersEnabled=false`, `inviteDisabledReason=null`, `inviteUpgradeRequired=false` (`workspace-list-query.ts:10-17`).
`WorkspaceCreationPolicy` (`:66-80`): `canCreate, workspaceMode, organizationId: string|null, maxWorkspaces: number|null, currentWorkspaceCount, reason: string|null, blockedReasonCode?: 'organization-subscription-inactive'|'permission-group-denied'`.

| Hook | Contract | UI reads | Errors / notes |
|---|---|---|---|
| `useWorkspacesQuery(enabled, scope)` (`:76-85`, `select: data.workspaces`, `keepPreviousData`), `useWorkspacesWithMetadata` (`:91-98`), `useWorkspaceCreationPolicy` (`:100-108`), `usePinnedWorkspaceIds` (`:127-135`, `Set`), `useOrderedWorkspacesQuery` (`:138-146`: pinned first, server order otherwise) — all share key `list('active')` | `GET /api/workspaces?scope=active|archived|all` (default `active`) → `{workspaces: Workspace[] (most recently visited first, then newest), lastActiveWorkspaceId: string|null, pinnedWorkspaceIds: string[] (default []), creationPolicy: WorkspaceCreationPolicy|null}` (`:183-204`) | switcher list, active workspace (`name, logoUrl, color, organizationId, inviteDisabledReason, inviteMembersEnabled, isOrgAdmin, permissions, ownerId`), create-button gate (`creationPolicy.canCreate`, `reason`), picker redirect (`lastActiveWorkspaceId`) | Route behaviour (`api/workspaces/route.ts:28-118`): 401 `{error:'Unauthorized'}` also when the cached cookie outlives the account (`WorkspaceOwnerMissingError`); with `scope=active` and no workspaces it **creates "My Workspace"** server-side and returns it unless `creationPolicy.canCreate` is false (then `{workspaces:[],…,creationPolicy}`); a membership race re-lists. The picker treats a 401 here as a stale session → `recoverFromStaleSession` (`workspace/page.tsx:35-37, 89-98`). Seeded by the layout only when non-empty (`seed-workspace-list.ts:15-38`). |
| `useRecordWorkspaceVisit` (`:156-186`) | `POST /api/workspaces/[id]/visit` → `{success:true}` (`:206-214`) | fired by `useWorkspaceManagement` on every `workspaceId` change while signed in (`use-workspace-management.ts:108-110`) | Optimistic: cancel `list('active')`, set `lastActiveWorkspaceId = id` and move the workspace to the front; mutations are serialised (`scope: 'workspace-visit'`); `onSettled` invalidates `lists()` only when no later visit is still pending (`:181-185`). No rollback on error. |
| `useToggleWorkspacePin` (`:213-280`) | pin: `POST /api/pinned-items` `{workspaceId: id, resourceType: 'workspace', resourceId: id}`; unpin: `DELETE /api/pinned-items/workspace/[id]` | switcher pin icon | Optimistic toggle of `pinnedWorkspaceIds` on `list('active')`; a `409` on pin or `404` on unpin is **success** (`:231-235`); `onError` applies the inverse toggle (not a snapshot, `:252-261`); serialised; `onSettled` invalidates `lists()` only when it is the last queued toggle (`:271-278`). |
| `useCreateWorkspace` (`:289-316`) | `POST /api/workspaces` `{name (trim, min 1), skipDefaultWorkflow?: bool=false}` → `{workspace}` (`:216-226`, body `lib/workspaces/create-input.ts`) | create modal (name ≤ 100 chars, `create-workspace-modal.tsx:63-73`), then `switchWorkspace(newWorkspace)` → `router.push('/workspace/<id>')` (settings section preserved by `resolveWorkspaceSwitchHref`, `use-workspace-management.ts:36-51`) | `onSuccess` prepends the row to `list('active')` (creating a `{workspaces:[w], lastActiveWorkspaceId:null, pinnedWorkspaceIds:[], creationPolicy:null}` entry when empty) then invalidates `lists()` and `adminLists()`. Errors: 401; `canCreate=false` → 403 capability refusal (`{error, details:{code:'PERMISSION_GROUP_CAPABILITY_BLOCKED'}}` when `permission-group-denied`) else `{error: reason}`; 409 on an organization-membership race (the picker reloads once, keyed `sessionStorage.workspaceRaceRetry`, `workspace/page.tsx:266-277`). Modal shows `getErrorMessage(err, 'Failed to create workspace')`. |
| `useUpdateWorkspace` (`:352-365`) | `PATCH /api/workspaces/[id]` `{name? (trim, min 1), logoUrl?: string|null (must start with '/' or 'https://'), billedAccountUserId?, allowPersonalApiKeys?}` → `{workspace}` (`:407-417`) | rename (inline, `handleRenameWorkspace`), logo (`handleUploadLogo` → upload session `purpose:'workspace_logo'` → `updateWorkspace(id, {logoUrl: path})`, `use-workspace-logo-upload.ts:53-66`) | not optimistic; `onSettled` invalidates `lists()` + `detail(id)`. Route: 401; 403 `Insufficient permissions` (non-admin); 404; 400 `No updates provided` / invalid logo. `updateWorkspace` swallows errors and returns `false` (`use-workspace-management.ts:115-130`). |
| `useDeleteWorkspace` (`:326-341`) | `DELETE /api/workspaces/[id]` body `{}` → `{success:true}` (`:419-429`) | delete modal; when deleting the current workspace switch to the first other one (`:172-196`) | `onSettled` invalidates `lists()` + `detail(id)`. Route: 401; 403; 400 `Cannot delete the only workspace`; 404. Errors are logged only. |
| `useWorkspacePermissionsQuery(id)` (`:391-398`) | `GET /api/workspaces/[id]/permissions` → `{users: WorkspaceUser[], total: int, viewer?: {userId, isAdmin, permissionType}}`; `WorkspaceUser{userId, email, name: string|null, image: string|null, permissionType, isExternal, joinedAt, roleSource: 'owner'|'explicit'|'org-admin', isOrgAdmin, isBilledAccount}` (`:117-146`) | `useUserPermissions`: `viewer.permissionType` → `canRead=true, canEdit = write|admin, canAdmin = admin`; fallback scans `users` by session email (`use-user-permissions.ts:57-101`) | `fetchWorkspacePermissions` rethrows 404 as `Error('Workspace not found or access denied')` and 401 as `Error('Authentication required')` (`:367-385`); route 401 `Authentication required`, 403. Prefetched (`prefetch.ts:97-105`). |
| `useWorkspaceMembersQuery(id)` (`:415-422`) | `GET /api/workspaces/[id]/members` → `{members: {userId, name, image: string|null}[]}` (`:457-466`) | presence avatars / owner cells (Phase 2+, listed for invalidation completeness) | |
| `useWorkspaceSettings(id)` (`:447-469`) | `GET /api/workspaces/[id]` → `{workspace}` (`:228-238`) **and** permissions in parallel | settings pages (Phase 5); `prefetchWorkspaceSettings` on hover | 404 `Workspace not found or access denied` |
| `useAdminWorkspaces(userId, organizationId?)` (`:518-530`) | `GET /api/workspaces` (default scope) filtered client-side to `permissions === 'admin'` (and `organizationId` + `workspaceMode === 'organization'` when scoped) → `AdminWorkspace{id, name, isOwner, ownerId, canInvite: inviteMembersEnabled ?? false, organizationId, workspaceMode}` | invite modal workspace multi-select (organization invites only, `invite-modal.tsx:157-170`) | key `[...adminList(userId), organizationId ?? '']` |
| `useWorkspaceCreditAvailability(id)` / `useWorkspaceUsageGate(id)` (`workspace-usage.ts:34-50`); keys `['workspace-usage','credit-availability',id]`, `['workspace-usage','gate',id]`; both 30 s | `GET /api/workspaces/[id]/credit-availability` → `{remainingDollars: number|null (≥0), scope: 'payer'|'member'|'effective'}`; `GET /api/workspaces/[id]/usage-gate` → `{isExceeded, message: string|null, scope: 'actor'|'payer'|'member'|null}` (`workspaces.ts:378-405`) | not read by Phase 1 chrome (the usage gate is consumed by the editor run button and the access-request discovery refetch, `access-requests.ts:54-60`); listed because `invalidateWorkspaceUsage` (`invalidate-usage.ts:16-21`) is part of the shared invalidation map | |

### 4.4 Invitations and members (`hooks/queries/invitations.ts`)

Keys (`:36-51`): `invitationKeys.all = ['invitations']`, `lists()`, `list(workspaceId)`, `details()`, `detail(invitationId, token ?? '', viewerId ?? '')` (viewer-scoped on purpose), `mine() = [...all,'mine']`. Constants: `WORKSPACE_INVITATION_LIST_STALE_TIME = 30 s`, `INVITATION_DETAILS_STALE_TIME = 30 s`, `MY_INVITATIONS_STALE_TIME = 30 s`.

| Hook | Contract | UI reads | Errors / invalidation |
|---|---|---|---|
| `useInvitationDetails(id, token, viewerId, {enabled})` (`:73-86`, `retry: false`) | `GET /api/invitations/[id]?token=` → `{invitation: InvitationDetails, joinPreview: InvitationJoinPreview|null}`; `InvitationDetails{id, kind: 'organization'|'workspace', email, organizationId: string|null, organizationName: string|null, membershipIntent: 'internal'|'external', role, status, expiresAt, createdAt, inviterName: string|null, inviterEmail: string|null, grants: {workspaceId, workspaceName: string|null, workspaceLogoUrl?: string|null, permission}[]}`; `joinPreview{outcome: 'will-join'|'already-member'|'external'|'blocked', organizationName: string|null, workspacesToMove: string[] (≤500), workspaceIdsToMove: string[] (≤500)}` (`invitations.ts:180-216, 267-280`) | invite page: title from `kind`/`grants[].workspaceName`/`organizationName`; wrong-account check `normalizeEmail(session.email) !== normalizeEmail(invitation.email)`; `membershipIntent==='internal' && !joinPreview` disables Accept ("Refresh invitation") | Enabled only when signed in and the token is resolved (`?token=` else `sessionStorage['inviteToken:<id>']`, `invite.tsx:299-318`). Error → `codeFromApiClientError`: `error.code`, else `body.error` when it is a known code, else by status 401 `unauthorized`, 403 `forbidden`, 404 `invalid-invitation`, 409 `already-in-organization`, ≥500 `server-error` (`:256-274`). |
| accept (page, direct `requestJson`, `invite.tsx:352-366`) and `useAcceptMyInvitation` (`:177-213`) | `POST /api/invitations/[id]/accept` `{token?, disclosedWorkspaceIds?: string[] (≤500), disclosedOutcome?}` → `{success:true, redirectPath, invitation{id, kind, organizationId: string|null, acceptedWorkspaceIds: string[]}}` (`:160-178, 218-227, 307-316`) | page: success card, `router.push(redirectPath)` after 1.2 s; modal: toast `Joined <label>`, close, `router.push(redirectPath)` | Route status map (`accept/route.ts:36-58`): `not-found` 404, `workspace-not-found` 404, `disclosure-outdated` 409, `invalid-token` 400, `already-processed` 400, `expired` 400, `email-mismatch` 403, `already-in-organization` 409, `no-seats-available` 400, `upgrade-required` 402, `external-requires-paid-plan` 402, `server-error` 500 (+ `message`); body `{error: <kind>, message?}`. Page copy per code in `invite.tsx:147-254` (`requiresAuth`: `email-mismatch`, `user-not-found`, `unauthorized`, `forbidden`; `canRetry`: `disclosure-outdated`, `no-seats-available`, `upgrade-required`, `external-requires-paid-plan`, `server-error`, `network-error`); modal copy in `error-messages.ts:10-28`. Invalidation after accept (page, best effort): `refreshSessionQuery`, `['subscription']`, `['organizations']`, `['workspace']` (`invite.tsx:372-385`); hook `onSuccess`: `workspaceKeys.lists()`, `organizationKeys.all`, `workspaceCredentialKeys.all`, `subscriptionKeys.all`, `refreshSessionQuery`; `onSettled`: `invitationKeys.mine()` (`:199-212`). |
| `useDeclineMyInvitation` (`:217-226`) | `POST /api/invitations/[id]/reject` body `{}` (token optional) → `{success, …}` | modal Decline | reject status map (`reject/route.ts:33-43`): `not-found` 404, `invalid-token`/`already-processed`/`expired` 400, `email-mismatch` 403. `onSettled`: `mine()`. |
| `useMyPendingInvitations(enabled)` (`:156-162`) | `GET /api/invitations` → `{invitations: MyInvitation[]}` (= `InvitationDetails & {joinPreview}`; `:290-305`) | switcher menu item renders only when `length > 0` (mounted when the dropdown opens, `view-invitations-menu-item.tsx:17-29`); modal passes `enabled: open` | |
| `usePendingInvitations(workspaceId)` (`:134-140`, `retryOnMount: true`) | `GET /api/workspaces/invitations` → `{invitations: PendingInvitationRow[]}` (`{id, workspaceId, email, token? (admins only), permission, membershipIntent?, status, createdAt, …passthrough}`, `:38-50, 235-244`) filtered client-side to `status==='pending' && workspaceId` → `WorkspaceInvitation{email, permissionType, isPendingInvitation:true, isExternal, invitationId, token?}` | teammates settings (Phase 5); invalidated by batch send / cancel / resend | |
| `useSendWorkspaceInvitations` (`:241-286`) | `POST /api/workspaces/invitations/batch` `{workspaceIds: string[] (≤ MAX_INVITE_WORKSPACES), emails: string[] (1..MAX_INVITE_EMAILS, trimmed), permission?, membership?: 'member'|'admin'|'external', organizationId?}`; refinement: empty `workspaceIds` only with `organizationId` and `membership !== 'external'` (`:60-85`) → `BatchInvitationResult{success, successful: string[], added: string[], failed: {email, error}[], invitations: {id, email, workspaceIds, permission, membershipIntent, instantAdd?, outcome?: 'added'|'updated'|'unchanged'}[]}` (`:87-136`) | invite modal: toast from `added`/`successful` counts; `failed` → `buildInviteFailureMessage` (≤3 distinct reasons listed, `invite-modal.tsx:64-82`); HTTP 2xx with `failed` entries is a partial failure | `onSettled` per workspace: `invitationKeys.list(ws)`, `workspaceKeys.permissions(ws)`, `workspaceKeys.members(ws)`; with `organizationId`: `organizationKeys.roster/billing/detail(org)` (`:267-285`). |
| `useCancelWorkspaceInvitation` (`:303-326`) | `DELETE /api/invitations/[id]?workspaceId=` → `{success, invitationCancelled: bool}` | teammates | `onSettled`: `invitationKeys.list(ws)`, org `roster`/`billing` |
| `useResendWorkspaceInvitation` (`:338-352`) | `POST /api/invitations/[id]/resend` → `{success}` | | `onSettled`: `invitationKeys.list(ws)` |
| `useRemoveWorkspaceMember` (`:364-390`) | `DELETE /api/workspaces/members/[userId]` body `{workspaceId (uuid)}` → `{success}` | | `onSettled`: `permissions(ws)`, `members(ws)`, `workspaceCredentialKeys.all`, org `roster` |
| `useLeaveWorkspace` (`:401-422`) | same endpoint with the viewer's own `userId` | switcher "Leave" confirm; on the current workspace switch to the next one (`use-workspace-management.ts:198-229`); failure → toast "Couldn't leave workspace" with the server message (`workspace-header.tsx:412-432`) | `onSettled`: `permissions(ws)`, `workspaceKeys.lists()`, `detail(ws)` |
| `useUpdateWorkspacePermissions` (`:430-468`) | `PATCH /api/workspaces/[id]/permissions` `{updates: {userId (≤128), permissions: 'admin'|'write'|'read'}[] (1..100, unique userId)}` → `{message}` (`workspaces.ts:441-455`, body `lib/workspaces/permissions/input.ts`) | teammates role select | `onError` toast "Couldn't update role" with the first validation issue (`extractValidationIssues`) or the error message; `onSettled`: `permissions(ws)`, org `roster` |

### 4.5 Folders (`hooks/queries/folders.ts`, keys `utils/folder-keys.ts:41-51`)

Keys: `folderKeys.all = ['folders']`, `lists()`, `resource(type='workflow') = [...lists(), type]`, `list(workspaceId, scope='active', type='workflow') = [...resource(type), workspaceId ?? '', scope]`. `FOLDER_LIST_STALE_TIME = 60 s`. Wire `FolderApi` (`folders.ts:36-52`): `id, resourceType: 'workflow'|'file'|'knowledge_base'|'table', name, userId, workspaceId, parentId: string|null, locked, sortOrder: number, createdAt, updatedAt, deletedAt: string|null`; `mapFolder` turns the three dates into `Date` (`folder-keys.ts:17-31`). `servedFolderResourceType` ∈ `workflow|knowledge_base|table` (default `workflow`; `file` is rejected with 400).

| Hook | Contract | Optimistic / invalidation | Route errors |
|---|---|---|---|
| `useFolders(ws, {scope, resourceType})` (`:46-63`, `keepPreviousData`), `useFolderMap` (`:68-80`, `Record<id, folder>`) | `GET /api/folders?workspaceId&scope=active|archived&resourceType` → `{folders}` (`:135-145`) | prefetched by the layout for `workflow` (`prefetch-resource-folders.ts:19-37`) | 401; 403 `Access denied to this workspace` |
| `useCreateFolder` (`:193-252`) | `POST /api/folders` `{id?: uuid, resourceType, name (trim 1..255), workspaceId, parentId?: string|null, sortOrder?: int}` → `{folder}` (`:71-78, 147-157`) | `createOptimisticMutationHandlers` (`optimistic-mutation.ts:24-74`): cancel `list(ws,'active',type)`, snapshot the folder map, append `{id: variables.id ?? generateId(), name, userId:'', workspaceId, parentId ?? null, resourceType, locked:false, sortOrder: variables.sortOrder ?? getTopInsertionSortOrder(workflows, folders, ws, parentId) (= min(sibling orders) − 1, or 0), createdAt/updatedAt: now, deletedAt:null}`; `onSuccess` replaces the temp row; `onError` restores the snapshot; `onSettled` invalidates the list. Name from `generateFolderName(ws)` = `GET /api/folders?workspaceId` then "Folder N" over root folders (`naming.ts:36-52`) | 401; 403; 400 validation `{error, details}`; `error.status` passthrough from the service |
| `useUpdateFolder` (`:254-277`) | `PUT /api/folders/[id]?resourceType=` `{name? (trim 1..255), locked?, parentId?: string|null, sortOrder?: int ≥ 0}` → `{folder}` (`:85-95, 159-171`) | not optimistic; `onSettled` invalidates `folderKeys.resource(type)` (every workspace's list of that type) | |
| `useDeleteFolderMutation` (`:279-296`) | `DELETE /api/folders/[id]?resourceType=` → `{success:true, deletedItems?: {folders, workflows?, files?, knowledgeBases?, tables?}}` (`:173-185`) | `onSettled`: `resource(type)` + cascaded lists: `workflow` → `invalidateWorkflowLists(ws, ['active','archived'])`; `table` → `tableKeys.lists()`; `knowledge_base` → `knowledgeKeys.lists()` (`:120-140`) | |
| `useRestoreFolder` (`:304-325`) | `POST /api/folders/[id]/restore` `{workspaceId, resourceType}` → `{success:true, restoredItems?}` | `onSettled`: `recentlyDeletedKeys.lists()`, `resource(type)`, cascaded lists | |
| `useDuplicateFolderMutation` (`:333-393`, workflow folders only) | `POST /api/folders/[id]/duplicate` `{name, workspaceId?, parentId?: string|null, newId?: uuid}` → `{folder}` | optimistic insert like create (parent = `variables.parentId ?? source.parentId`); `onSettled`: `folderKeys.list(ws)` prefix + `invalidateWorkflowLists(ws)` | |
| `useReorderFolders` (`:405-459`) | `PUT /api/folders/reorder` `{workspaceId, resourceType, updates: {id, sortOrder ≥ 0, parentId?: string|null}[] (1..1000)}` → `{success:true, updated: int}` | optimistic: apply `sortOrder`/`parentId` to matching rows, snapshot rollback; `onSettled`: `list(ws,'active',type)` | |

### 4.6 Workflows (`hooks/queries/workflows.ts`, keys `utils/workflow-keys.ts`)

Keys: `workflowKeys.all = ['workflows']`, `lists()`, `list(workspaceId, scope='active') = [...lists(), workspaceId ?? '', scope]`, `states()`, `state(workflowId)`, `deploymentVersions()`, `deploymentVersion(...)`. `WORKFLOW_LIST_STALE_TIME = 60 s` (`workflow-list-query.ts:9`), `WORKFLOW_STATE_STALE_TIME = 30 s`. Wire `WorkflowListItem` (`workflows.ts:245-258`): `id, name, description: string|null, workspaceId: string|null, folderId: string|null, sortOrder: number, createdAt, updatedAt, archivedAt: string|null, locked, forkSyncExcluded (default false), isDeployed?`; `mapWorkflow` → `WorkflowMetadata{id, name, description?, workspaceId?, folderId, sortOrder, createdAt: Date, lastModified: Date, archivedAt: Date|null, locked, forkSyncExcluded, isDeployed}` (`workflow-list-query.ts:11-26`).
`invalidateWorkflowLists(ws, scopes=['active'])` = invalidate each `list(ws, scope)` + `selectorKeys.all` (`invalidate-workflow-lists.ts:12-25`).

| Hook | Contract | Optimistic / invalidation | Notes |
|---|---|---|---|
| `useWorkflows(ws, {scope})` (`:121-133`, `keepPreviousData`), `useWorkflowMap` (`:144-153`) | `GET /api/workflows?workspaceId&scope=active|archived|all` → `{data: WorkflowListItem[]}` (`:692-702`) | prefetched by the layout for `active` (`prefetch.ts:81-88`) | route 401; 404/403 for a workspace the viewer cannot read; the sidebar sorts by `createdAt` desc and filters `workspaceId === ws` (`use-workflow-operations.ts:18-24`) |
| `useCreateWorkflow` (`:176-316`) | `POST /api/workflows` `{id?: uuid, name (required), description? (default ''), workspaceId?, folderId?: string|null, sortOrder?: int, deduplicate?}` → `{id, name, description, workspaceId, folderId?: string|null, sortOrder, createdAt, updatedAt, startBlockId, subBlockValues: Record<blockId, Record<subBlockId, unknown>>}` (`:261-282, 782-790`) | `onMutate`: cancel `list(ws,'active')`, snapshot, append `{id: variables.id ?? generateId(), name: variables.name ?? generateCreativeWorkflowName(), lastModified/createdAt: now, description ?? '', workspaceId, folderId ?? null, sortOrder: variables.sortOrder ?? top-insertion, locked:false}`; `onSuccess` replaces the temp row (and moves the folder-store selection from temp to real id, seeds `subBlockValues` into the subblock store, `markWorkflowCreated(id)`); `onError` restores the snapshot and `markWorkflowCreated(null)`; `onSettled` `invalidateWorkflowLists(ws, ['active','archived'])` | The sidebar generates the id client-side, `deduplicate: true`, calls `markWorkflowCreating(id)` and navigates to `/workspace/<ws>/w/<id>` **before** the response (`use-workflow-operations.ts:30-47`). Route: 401, 403 (read-only), 400 validation. |
| `useDuplicateWorkflowMutation` (`:341-471`) | `POST /api/workflows/[id]/duplicate` `{name, description?, workspaceId?, folderId?: string|null, newId?: uuid}` → `{id, name, description: string|null, workspaceId, folderId: string|null, sortOrder, locked, blocksCount, edgesCount, subflowsCount}` (`:287-306, 792-801`) | optimistic insert at the top of the target folder with `id = newId ?? generateId()`; replace on success; rollback on error; `onSettled` `invalidateWorkflowLists(ws)` | |
| `useUpdateWorkflow` (`:480-524`) | `PUT /api/workflows/[id]` `{name?, description?, folderId?: string|null, sortOrder?: int ≥ 0, locked?, forkSyncExcluded?}` → `{workflow: WorkflowListItem}` (`:311-318, 803-813`) | optimistic merge of `metadata` + `lastModified: now` into the row; rollback; `onSettled` `invalidateWorkflowLists(ws)` | rename, move to folder, lock |
| `useDeleteWorkflowMutation` (`:532-567`) | `DELETE /api/workflows/[id]` → `{success:true}` | optimistic removal (`removeWorkflowFromActiveCache`, `workflow-cache.ts:37-48`); rollback; `onSettled` `invalidateWorkflowLists(ws, ['active','archived'])` | soft delete (appears in recently deleted) |
| `useReorderWorkflows` (`:632-676`) | `PUT /api/workflows/reorder` `{workspaceId, updates: {id, sortOrder ≥ 0, folderId?: string|null}[]}` → `{success:true, updated}` (`:322-331, 826-836`) | optimistic `sortOrder`/`folderId` per row; rollback; `onSettled` `invalidateWorkflowLists(ws)` | DnD in the tree |
| `useRestoreWorkflow` (`:697-708`) | `POST /api/workflows/[id]/restore` → `{success:true}` | `onSettled`: `recentlyDeletedKeys.lists()` + `invalidateWorkflowLists(ws, ['active','archived'])` | |
| picker redirect (`workspace/page.tsx:220-239`) | `GET /api/workflows/[id]` → `{data: GetWorkflowResponseData}`; the picker reads only `data.workspaceId` for `?redirect_workflow=` | | failure → fall back to `/workspace/<lastActive>` |

Realtime: the sidebar joins the `workspace-workflows` invalidation room over the shared socket (`use-workspace-workflows-room.ts:22-29`): emit `join-workspace-workflows {workspaceId}` on connect (and on every reconnect), listen `join-workspace-workflows-success {workspaceId}`, `join-workspace-workflows-error {workspaceId, error, code, retryable?}` (retry ≤3 with 1 s·n backoff when `retryable`), `workspace-workflows-changed {workspaceId}` → `invalidateWorkflowLists(ws, ['active','archived'])` + `folderKeys.list(ws,'active')` + `folderKeys.list(ws,'archived')`; emit `leave-workspace-workflows {workspaceId}` on dispose (`use-workspace-invalidation-room.ts:29-86`). Room type tokens: `packages/realtime-protocol/src/rooms.ts:20-58`.

### 4.7 Pinned items (`hooks/queries/pinned-items.ts`, keys `utils/pinned-item-keys.ts:14-21`)

Keys: `pinnedItemKeys.all = ['pinnedItems']`, `lists()`, `workspaceLists(ws) = [...lists(), ws ?? '']`, `list(ws, type) = [...workspaceLists(ws), type ?? '']`. `PINNED_ITEMS_STALE_TIME = 60 s`. Wire `PinnedItemApi{id, userId, workspaceId, resourceType: 'workflow'|'file'|'knowledge_base'|'table'|'folder'|'workspace', resourceId, pinnedAt: string}` (`pinned-items.ts:22-41`).

| Hook | Contract | Behaviour |
|---|---|---|
| `usePinnedItems(ws, type?)` (`:32-40`, `keepPreviousData`), `usePinnedIds` (`:48-57`, `Set<resourceId>`) | `GET /api/pinned-items?workspaceId&resourceType?` → `{pinnedItems}` | sidebar reads `usePinnedIds(ws, 'workflow')` and `'folder'`; `workspace` pins are **not** read here (they ride on `/api/workspaces`, `:15-20`) |
| `usePinItem` (`:124-146`) | `POST /api/pinned-items` `{workspaceId, resourceType, resourceId (1..255)}` → `{pinnedItem}` | optimistic append `{id: generateId(), userId:'', …, pinnedAt: now ISO}` to the type-scoped **and** the unscoped list of the workspace (`isAffectedListKey`, `:76-86`); snapshot of every affected list for rollback; `onSettled` invalidates `workspaceLists(ws)`. Route: 401, 403, 404 `Resource not found in this workspace`, 409 `This item is already pinned`. |
| `useUnpinItem` (`:148-154`) | `DELETE /api/pinned-items/[resourceType]/[resourceId]` → `{success:true}` | optimistic filter; same rollback/invalidation; 404 when not pinned |

### 4.8 User profile (`hooks/queries/user-profile.ts`, `current-user-data.ts`)

| Hook | Contract | Behaviour |
|---|---|---|
| `useUserProfile` (`:32-38`); key `['userProfile','profile']`; `USER_PROFILE_STALE_TIME = 5 min` | `GET /api/users/me/profile` → `{user: {id, name, email, image: string|null, emailVerified?}}` (`user.ts:8-14, 71-80`); mapped to `{id, name, email, image}` | sidebar footer name/avatar (`sidebar-footer.tsx:125-131`; `canSignOut = profile.id !== ANONYMOUS_USER_ID`), billing gate viewer id. Prefetched (`prefetch-user-profile.ts:16-26`). |
| `useUpdateUserProfile` (`:45-76`) | `PATCH /api/users/me/profile` `{name? (min 1), image?: string|null (http://, https:// or /api/)}` (at least one) → `{success:true, user}` | optimistic merge, rollback, `onSettled` invalidate `profile()` |
| `useUpdateGeneralSetting` (`general-settings.ts:155-195`) | `PATCH /api/users/me/settings` `{<one key>: value}` (body schema `user.ts:158-175`; `timezone` validated as IANA, `null` clears) → `{success:true}` | optimistic `{...previous, [key]: value}`; for `theme` also `syncThemeToNextThemes(value)` immediately and on rollback; `onSettled` invalidate `settings()` |
| `useSignOutOtherDevices` (`:97-104`) | Better Auth `client.revokeOtherSessions()` = `POST /api/auth/revoke-other-sessions` | Phase 5 |

### 4.9 Workspace loaders

| Hook | Contract | Loader behaviour |
|---|---|---|
| `useCustomBlocks(ws)` / `useCanPublishCustomBlock(ws)` (`custom-blocks.ts:52-59`); key `['custom-blocks','list',ws]`; `CUSTOM_BLOCK_LIST_STALE_TIME = 60 s` | `GET /api/custom-blocks?workspaceId` → `{enabled, customBlocks: CustomBlock[]}`; `CustomBlock{id, organizationId, workflowId, workflowName, workspaceId: string|null, workspaceName: string|null, type, name, description, iconUrl: string|null, enabled, traceChildRuns, inputFields: {id?, name, type, description?, placeholder?, required?}[], exposedOutputs: ExposedOutput[]}` (`custom-blocks.ts:36-57, 77-89`; `exposedOutputSchema` lives in `lib/workflows/custom-blocks/settings-input.ts`, see §11) | `CustomBlocksLoader` (`custom-blocks-loader.tsx:557-595`): on every data change rebuild the client overlay with `hideFromToolbar: !block.enabled` and the org logo as fallback icon; disabled blocks stay resolvable. Mutations (`usePublishCustomBlock` `POST /api/custom-blocks`, `useUpdateCustomBlock` `PATCH /api/custom-blocks/[id]`, `useDeleteCustomBlock` `DELETE`) invalidate `lists()`. |
| `useBlockVisibility(ws)` (`block-visibility.ts:24-31`); key `['block-visibility','list',ws]`; `BLOCK_VISIBILITY_STALE_TIME = 60 s` | `GET /api/blocks/visibility?workspaceId` → `{revealed: string[], disabled: string[], previewTagged: string[]}` | `BlockVisibilityLoader` (`block-visibility-loader.tsx:614-641`): `data == null` (workspace switch) → `resetBlockVisibilityForSwitch()` (fail-closed, keep kill-switch entries); else `hydrateBlockVisibility(sets)` with a deep-equal guard. Route 401, 403 `Access denied`. |
| `useProviderModels(provider, ws?, {enabled})` (`providers.ts:113-122`); key `['provider-models','list',provider, ws ?? '']`; `PROVIDER_MODELS_STALE_TIME = 5 min` | `GET /api/providers/{base,ollama,vllm,litellm,openrouter}/models` (no query) and `GET /api/providers/{ollama-cloud,fireworks,together,baseten}/models?workspaceId?` → `{models: string[], modelInfo?: Record<id, {id, contextLength?, supportsStructuredOutputs?, supportsTools?, pricing?{input, output}}>}`; `openrouter/embeddings/models` exists but is not loaded by the loader. OpenRouter lists are de-duplicated client-side (`:50`). | `ProviderModelsLoader` (`provider-models-loader.tsx:447-538`): nine queries (`base, ollama, ollama-cloud, vllm, litellm, openrouter, fireworks, together, baseten`), enabled only on `/workspace/<id>`, `/home`, `/w[/…]`, `/chat[/…]` or while the search palette is open (`:447-464`); each result updates the providers store (`setProviderLoading`, `setProviderModels`, OpenRouter `setOpenRouterModelInfo`) and the registry's model option lists (`update*ProviderModels`). Errors are logged only; the `Query<T>` error does not block the shell. |
| `useGeneralSettings` | §4.2 | `SettingsLoader` just mounts the query (`settings-loader.tsx:421-424`). |
| `useWorkspacePermissionsQuery` | §4.3 | `WorkspacePermissionsProvider` (`workspace-permissions-provider.tsx:214-324`): exposes `{workspacePermissions, permissionsLoading, permissionsError: error?.message ?? null, updatePermissions (setQueryData), refetchPermissions, userPermissions}`; `isOfflineMode = operationQueue.hasOperationError`; `isJoinBlocked = blockedJoinWorkflowId === urlWorkflowId`; both force `canEdit=false, canAdmin=false`; persistent toasts: `'Reconnecting...'` after `isReconnecting` holds 2000 ms, kept ≥1500 ms (`useStableFlag`, `:121-122, 231-234`), `'Joining workflow...'` while `isRetryingWorkflowJoin`, `'Connection unavailable'` (+ description, Refresh action) while offline, `'Unable to connect to workflow'` while join-blocked; none of these while `isFileViewer`. |
| `useUserPermissionConfig(ws)` (`ee/access-control/hooks/permission-groups.ts:121-140`); key `['permissionGroups','userConfig',ws]`; `PERMISSION_GROUPS_STALE_TIME = 60 s`; retry ≤3 on 5xx only | `GET /api/permission-groups/user?workspaceId` → `{permissionGroupId: string|null, groupName: string|null, config: PermissionGroupConfig|null, entitled, organizationId: string|null, isOrgAdmin}` (`permission-groups.ts:92-112, 254-262`) | `usePermissionConfig` (`use-permission-config.ts:58-281`): `config = data.config ?? DEFAULT_PERMISSION_GROUP_CONFIG` (every restriction `false`, allowlists `null`, denylists `[]`); sidebar reads `hideCopilot`, `hideFilesTab`, `hideTablesTab`, `hideKnowledgeBaseTab`, `hideIntegrationsTab`; `isInvitationsDisabled = NEXT_PUBLIC_DISABLE_INVITATIONS || config.disableInvitations`; `isBlockAllowed`/`filterBlocks` feed the palette. Prefetched (`prefetch-access.ts:34-41`). Full key list: `generated/contracts/permission-groups.schema.json` (`permissionGroupFullConfigSchema` is registry-derived, §11). |
| `useIntegrationAvailability` (`integration-availability.ts:9-15`); key `['allowedIntegrations','env']`; `INTEGRATION_AVAILABILITY_STALE_TIME = 5 min` | `GET /api/settings/allowed-integrations` → `{allowedIntegrations: string[]|null, integrationAvailability: {type, state: 'ready'|'limited'|'unavailable'|'misconfigured', oauthAvailable}[], oauthServiceAvailability: {providerId, available}[] (≤1000)}` (`common.ts:56-84`) | palette block filtering; prefetched (`prefetch-access.ts:42-49`) |
| `useBlacklistedProviders` (`allowed-providers.ts:20-26`); key `['allowedProviders','blacklisted']`; 5 min | `GET /api/settings/allowed-providers` → `{blacklistedProviders: string[]}` | model pickers (Phase 2); listed for completeness of `settings/allowed-*` (`/api/settings/voice` → `{sttAvailable}` and `allowed-mcp-domains` are Phase 3/4) |
| `useWorkspaceAccessRequestFeatures` (`permission-access-boundary.tsx:17-24`) = `useDiscoverAccessRequests({kind:'workspace', workspaceId, targetKind:'feature', limit:100, offset:0})`; key `['accessRequests','discovery',<query object>]`; `ACCESS_REQUESTS_STALE_TIME = 15 s` | `GET /api/access-requests/discovery?kind=workspace&workspaceId&targetKind=feature&limit=100&offset=0` → `{enabled, organizationId: string|null, entries: {target, label, state: 'allowed'|'requestable'|'unavailable', reason: string|null, pendingRequestId: string|null}[], total, hasMore}` (`access-requests.ts:214-240, 310-315`) | sidebar: a hidden nav item stays visible-but-restricted when `enabled === true` (`sidebar.tsx:427, 769-847`); on `enabled` the hook also refetches `permissionGroupKeys.userConfig(ws)` and, when the cached usage gate is `member`-scoped and exceeded, `workspaceUsageKeys.gate(ws)` (`access-requests.ts:44-60`). Prefetched only when the policy hides at least one non-organization feature (`prefetch-access.ts:51-72`). |
| `useWhitelabelSettings(orgId)` (`whitelabel.ts:53-60`); key `['whitelabel','settings',orgId]`; `WHITELABEL_STALE_TIME = 60 s` | `GET /api/organizations/[id]/whitelabel` → `{data: OrganizationWhitelabelSettings, isEnterprise?}` (settings fields = PUT body `organization.ts:269-…`: `brandName (≤64)`, `logoUrl`, `wordmarkUrl`, `primaryColor`, `primaryHoverColor`, `accentColor`, … hex colours; see §11) | `BrandingProvider` (`branding-provider.tsx:36-66`): enabled only when `viewer.isHostOrganizationMember && hostOrganizationId`; `effectiveOrgSettings = query.settings ?? initialOrgSettings (server) ?? null`; `mergeOrgBrandConfig(settings, getBrandConfig())` + CSS variable overrides. A non-member of the host org gets instance branding only. |
| `useStatusPage({enabled})` (`status-page.ts:18-28`); key `['status-page','summary','sim']`; `STATUS_PAGE_STALE_TIME = 30 s`, `refetchInterval` 60 s, `refetchOnWindowFocus: true`, `retry: false` | external `GET https://status.sim.ai/api/v2/status.json` (no credentials, `Accept: application/json`, `cache: no-store`) → `{status: {description (1..200), indicator: 'none'|'minor'|'major'|'critical'}}` (`lib/status-page.ts:3-35`) | `StatusNotice` renders only for `major`/`critical`; mounted only when `hosted || NEXT_PUBLIC_STATUS_NOTICE_PREVIEW` and the sidebar is expanded (`sidebar.tsx:1849-1850`). Cross-origin; the Flutter web client calls it directly (not through the proxy). |
| `useMothershipChats(ws, {scope, enabled})` (`mothership-chats.ts:334-348`); key `['mothership-chats','list',ws,scope]`; `MOTHERSHIP_CHAT_LIST_STALE_TIME = 60 s` | `GET /api/mothership/chats?workspaceId&scope=active` → `{success:true, data: {mode: 'agent'|'assistant'|'plan', id, title: string|null, updatedAt, activeStreamId: string|null, lastSeenAt: string|null, pinned, deletedAt: string|null}[]}` (`mothership-chats.ts:273-295`); `mapChat` → `{id, name: title ?? 'New chat', mode, updatedAt: Date, isActive: activeStreamId != null, isUnread, isPinned, deletedAt}` | sidebar Chats section, enabled only when `chatEnabled && !hideCopilot` (`sidebar.tsx:907-910`); prefetched when `isChatEnabled` (`prefetch.ts:89-101`). The chat mutations (rename/pin/delete/mark read) are Phase 4. |
| `useOrganizationPlanSeats(orgId, {enabled})` (`organization-plan-seats.ts:25-30`); key `organizationKeys.planSeats(org) = ['organizations','detail',org,'billing','plan-seats']`; 30 s; `retry: shouldRetrySettingsRead`, `retryOnMount: true` | `GET /api/organizations/[id]/billing-plan` → `{success:true, data: {organizationId, subscriptionPlan: string|null, subscriptionStatus: string|null, totalSeats, usedSeats, membersTotal: int ≥0, hasEnterprisePlan}}` (`organization.ts:774-801`) | invite modal seat warning, enabled only `open && billingEnabled && canGrantOrganizationAdmin` (`invite-modal.tsx:196-220`) |

### 4.10 Organizations

| Hook | Contract | Notes |
|---|---|---|
| `listCreatorOrganizationsContract` (`organizations.ts:17-27`) | `GET /api/organizations` → `{organizations: {id, name, role}[], isMemberOfAnyOrg}` | no React Query hook imports it in Phase 1 chrome (grep: none); available for the Flutter entry resolution (§8) |
| `useOrganization(orgId)` (`organization.ts:146-151`); key `organizationKeys.detail(org)`; 30 s | Better Auth organization plugin `client.organization.getFullOrganization({query:{organizationId}})` = `GET /api/auth/organization/get-full-organization?organizationId=` | plan/settings surfaces; note the catch-all 404s `POST organization/*` except `check-slug`/`set-active` (`03-api-and-auth.md` §1), GETs pass |
| `useOrganizationRoster(orgId)` (`:80-85`); key `roster(org)`; 30 s | `GET /api/organizations/[id]/roster` → `{data: OrganizationRoster}`; 404 → `null` | teammates (Phase 5); invalidated by invitation mutations |
| `useCreateOrganization` (`:473-499`) | `POST /api/organizations` `{name, slug}` → `{success, organizationId, created}`, then `client.organization.setActive({organizationId})` (`POST /api/auth/organization/set-active`); `onSettled` invalidates `organizationKeys.lists()`, `workspaceKeys.lists()`, `router.refresh()` | Phase 5 |
| `useSubscriptionData({includeOrg})` (`subscription.ts:38-42`); key `['subscription','user',{includeOrg}]`; `SUBSCRIPTION_DATA_STALE_TIME = 5 min`; `retryOnMount: true` | `GET /api/billing?context=user&includeOrg=` → `SubscriptionApiResponse{success, context, data: {type: 'individual'|'organization', plan, currentUsage, usageLimit, percentUsed, isWarning, isExceeded, daysRemaining, creditBalance, billingInterval, isPaid, isPro, isTeam, isEnterprise, isOrgScoped, organizationId: string|null, status: string|null, seats: number|null, metadata, stripeSubscriptionId, periodEnd, cancelAtPeriodEnd, usage: {current, limit, percentUsed, isWarning, isExceeded, billingPeriodStart, billingPeriodEnd, lastPeriodCost, lastPeriodCopilotCost, daysRemaining, copilotCost}, billingBlocked, billingBlockedReason, blockedByOrgOwner, upgradeWorkspaceId, organization?: {id, role}}}` (`subscription.ts:39-99`, passthrough) | **not read by the Phase 1 sidebar** (the credits chip and upgrade page are Phase 5); the sidebar's billing gating uses only `deployment.billingEnabled` + host context (`canViewWorkspaceBillingSettings`) and `inviteUpgradeRequired` on the workspace row. Listed because `['subscription']` is an invalidation target after invitation accept. |

### 4.11 Help modal and contact

| Surface | Contract | Behaviour |
|---|---|---|
| Help modal (`help-modal.tsx:91-116, 136-148`) | raw `POST /api/help` multipart: `subject` (trim, min 1, no header control chars), `message` (min 1), `type ∈ bug|feedback|feature_request|other`, `workspaceId?`, `workflowId?`, `userAgent`, `image_<n>` files (jpeg/jpg/png/webp/gif, ≤20 MB each, compressed to ~2 MB client-side) (`help/route.ts:29-117`, body schema `common.ts:7-16`) → `{success: true, …}`; 401 `{error:'Authentication required'}`; 400 `{error, details}`; 413 oversized | footer state `Submitting... → Success (2 s) / Error`; images revoked on success |
| `useSubmitContact` (`contact.ts:17-25`) | `POST /api/contact` `{name (≤120), email (≤320, lowercased), company?, topic ∈ general|support|integration|feature_request|sales|partnership|billing|other, subject (≤200), message (≤5000), website? (honeypot), captchaToken?}` → `{success:true, message}` (`contact.ts:29-104`) | public marketing `/contact` form — **out of scope** (landing); the help modal does not use it |
| Integration request | `POST /api/help/integration-request` `{integrationName (≤200), email, useCase? (≤2000)}` → `{success:true, message}` (`common.ts:18-43`) | Phase 4 integrations |

### 4.12 Search palette sources (`search-modal.tsx`)

The palette performs no search request; it ranks in-memory lists. Sources and where they come from:
- blocks/tools/triggers: registry via `useSearchModalStore.initializeData(filterBlocks, isToolAllowed)` (`store.ts:85-110`), re-run when the custom-block overlay or provider models change (`sidebar.tsx:429-452`).
- workflows, chats, workspaces: props from the sidebar (`sidebar.tsx:730-752`; `useWorkflowMap`, `useMothershipChats`, `useOrderedWorkspacesQuery`).
- tables: `useTablesList(ws,'active')` = `GET /api/table?workspaceId` → `{success:true, data:{tables, totalCount}}`; files: `useWorkspaceFiles(ws,'active')` = `GET /api/workspaces/[id]/files`; knowledge bases: `useKnowledgeBasesQuery(ws)` = `GET /api/knowledge` → `{success, data}`; their folder maps via `useFolderMap(ws, 'table' | 'knowledge_base')` (`search-modal.tsx:189-205`). These three are fetched **only while the palette is open** (`enabled: open`) and are Phase 4 contracts; Phase 1 may stub the sections empty behind the same `enabled` gate (recorded in §11).
- logs: `useLogsList(ws, SEARCH_MODAL_LOG_FILTERS)` = `GET /api/logs` (Phase 4); connected accounts: `useWorkspaceCredentials` = `GET /api/credentials?workspaceId` (Phase 4); integrations: registry filtered by `isBlockAllowed` + `integrationAvailability`.
- pages/actions: static lists gated by `permissionConfig.hide*Tab`, `accessRequests.enabled`, `canEdit`, feature flags.

### 4.13 Recently deleted (account menu entry → settings section)

`useRecentlyDeletedItems({workspaceId, filter, search, sortBy, sortOrder})` (`recently-deleted.ts:24-52`): infinite query, key `['recentlyDeleted','list',ws,filter,search ?? '',sortBy,sortOrder]`, `staleTime 0`, `retry: shouldRetrySettingsRead`, `placeholderData` kept only within the same workspace. `GET /api/workspaces/[id]/recently-deleted?type=all|chat|table|file|knowledge|workflow|folder&search?(≤200)&sortBy=deleted|name|type&sortOrder=asc|desc&limit(1..100, default 50)&cursor?` → `{items: {id, name, type ∈ workflow|folder|table|table_folder|knowledge|knowledge_folder|file|workspace_folder|chat, deletedAt, parentId: string|null}[] (≤100), nextCursor: string|null}` (`recently-deleted.ts:37-91`). Restores: §4.5/§4.6 (`restore` endpoints) invalidate `recentlyDeletedKeys.lists()`.

## 5. Server prefetch vs. Flutter cold load

What the React workspace layout hydrates before the client renders (`layout.tsx:65-162`, `prefetch.ts`, `prefetch-access.ts`) and the Flutter equivalent:

| React (server) | Key hydrated | Flutter: fetch yourself |
|---|---|---|
| `getSession()`; `redirect('/login')` when absent | — | `GET /api/auth/get-session`; null → `/login` |
| `prefetchWorkspaceHostContext` (`null` → `WorkspaceAccessDenied`) | `workspaceHostKeys.detail(ws)` | `GET /api/workspaces/[id]/host-context`; 403 → access-denied page |
| `getOrgWhitelabelSettings(hostOrganizationId)` | passed as `initialOrgSettings` prop | `GET /api/organizations/[id]/whitelabel` when `viewer.isHostOrganizationMember` |
| `prefetchWorkspaceSidebar`: workflows (`active`), chats (`active`, only `isChatEnabled`), workflow folders (`active`), permissions, profile, workspace list (seeded only when non-empty) | `workflowKeys.list(ws,'active')`, `mothershipChatKeys.list(ws,'active')`, `folderKeys.list(ws,'active','workflow')`, `workspaceKeys.permissions(ws)`, `userProfileKeys.profile()`, `workspaceKeys.list('active')` | six requests, in parallel, after host context |
| Seven feature flags + `hasDesktopBackgroundExecutor` + `isDesktopBackgroundExecutorAvailable` as props | `FeatureFlagsProvider` | `GET /api/workspaces/[id]/feature-flags` |
| `resolveOrganizationEntryPath(session)` → `organizationHref` prop | — | §8 (surface-context) |
| `prefetchWorkspaceAccess`: user permission config, allowed integrations, access-request discovery (conditional) | `permissionGroupKeys.userConfig(ws)`, `integrationAvailabilityKeys.environments()`, `accessRequestKeys.discovery(q)` | three requests |
| `prefetchWorkspaceForkAvailability` (admins only) | `forkAvailabilityKeys.detail(ws)` | Phase 5 (settings nav) |
| `cookies().get('sidebar_collapsed') === '1'` | `initialSidebarCollapsed` prop | read the cookie through `SharedWebState` |

Not prefetched in React either (client-only on mount): general settings, provider models, custom blocks, block visibility, pinned items, whitelabel refetch, status page, credit availability / usage gate, pending invitations (dropdown open), admin workspaces / plan seats (invite modal open).

## 6. Invalidation map

Every mutation's invalidation prefix (React key → Flutter `QueryClient.invalidateQueries(prefix)`):

| Mutation | Optimistic | Rollback | Invalidates (prefixes) |
|---|---|---|---|
| record visit | reorder + `lastActiveWorkspaceId` | none | `['workspace','list']` (when last pending) |
| toggle workspace pin | `pinnedWorkspaceIds` | inverse toggle | `['workspace','list']` (when last pending) |
| create workspace | prepend row | — | `['workspace','list']`, `['workspace','adminList']` |
| update / delete workspace | — | — | `['workspace','list']`, `['workspace','detail',id]` |
| leave workspace | — | — | `['workspace','detail',id,'permissions']`, `['workspace','list']`, `['workspace','detail',id]` |
| batch invitations | — | — | per ws: `['invitations','list',ws]`, `['workspace','detail',ws,'permissions']`, `['workspace','detail',ws,'members']`; org: `['organizations','detail',org,'roster'|'billing']`, `['organizations','detail',org]` |
| accept my invitation | — | — | `['workspace','list']`, `['organizations']`, `workspaceCredentialKeys.all`, `['subscription']`, session refresh; settled: `['invitations','mine']` |
| decline my invitation | — | — | `['invitations','mine']` |
| cancel / resend workspace invitation | — | — | `['invitations','list',ws]` (+ org roster/billing on cancel) |
| remove member | — | — | permissions(ws), members(ws), `workspaceCredentialKeys.all`, org roster |
| update permissions | — | — | permissions(ws), org roster |
| create / duplicate workflow | insert temp row | snapshot | `['workflows','list',ws,'active']` (+`'archived'` on create), `selectorKeys.all` |
| update / reorder workflow | merge row | snapshot | `['workflows','list',ws,'active']`, selectors |
| delete workflow | remove row | snapshot | `['workflows','list',ws,'active'|'archived']`, selectors |
| restore workflow | — | — | `['recentlyDeleted','list']`, workflow lists active+archived, selectors |
| create / duplicate folder | insert temp row | snapshot | `['folders','list','workflow',ws,'active']` (+ workflow lists on duplicate) |
| update folder | — | — | `['folders','list',<type>]` |
| delete / restore folder | — | — | `['folders','list',<type>]` + cascaded resource lists (+ `['recentlyDeleted','list']` on restore) |
| reorder folders | apply updates | snapshot | `['folders','list',<type>,ws,'active']` |
| pin / unpin item | add / remove in affected lists | per-list snapshot | `['pinnedItems','list',ws]` |
| update profile | merge | snapshot | `['userProfile','profile']` |
| update setting | merge (+theme sync) | snapshot (+theme sync) | `['generalSettings','settings']` |
| custom block publish/update/delete | — | — | `['custom-blocks','list']` |
| `workspace-workflows-changed` socket event | — | — | workflow lists active+archived, selectors, workflow folders active+archived |
| usage settle (`scheduleUsageRefresh`, 1 s delay) | — | — | `['subscription','user']`, `['workspace-usage','credit-availability']`, `['workspace-usage','gate']` |

## 7. Loaders and providers → Flutter cubits

Mount order mirrors `layout.tsx:165-224`. "Refetch" lists the triggers beyond staleness.

| React provider | Loads | Refetches when | Exposes | Flutter cubit (GetIt, long-lived unless noted) |
|---|---|---|---|---|
| `SessionProvider` + `useSessionQuery` | `get-session` | focus (5 min stale), 60 s poll while impersonating (bypassing cookie cache), `refreshSessionQuery` after invite accept / signup / verify / `?upgraded=true` (which also tries `client.organization.list()` + `setActive` when exactly one org and none active, `session-provider.tsx:75-101`) | `{data, isPending, error, refetch}` | **SessionCubit**: state `{session: AuthSession?, status, error}`; wraps `AuthRepository.getSession`; `onFocus` hook; impersonation timer; `refresh({bypassCookieCache:true})`; emits a `sawSession → null` transition for `SessionExpired` (`session-expired.tsx:36-44`: armed only after a live session, never on `error`). |
| (root) `public-env` | `GET /api/public-env` | app start only | `getEnv(key)` | **DeploymentShapeCubit** (also holds public env): `publicEnv: Map<String,String>`, `shape: DeploymentShape` = `hostContext.deployment ?? fallbackFromPublicEnv()`; `seed(shape)` is a no-op on structural equality; `reset()` on workspace exit is **not** done upstream (the seeded shape persists, `deployment-shape.ts:123`). |
| `WorkspaceHostProvider` | host context | key change (workspace switch), 30 s stale | `WorkspaceHostContext`; 403 → access denied | **WorkspaceHostCubit**: `{context, status, accessDenied}`; feeds DeploymentShapeCubit, BrandingCubit, PermissionsCubit (viewer permission as the authorization proof), billing gate. |
| `FeatureFlagsProvider` | feature-flags endpoint | workspace switch (server props re-resolve per render) | `useFeatureFlag(name) → flags[name] ?? false` | **FeatureFlagsCubit**: `{flags: WorkspaceFeatureFlags (all false until loaded), desktopExecutor}`; per workspace. The organization surface variant adds `mothership-memory-spaces` and maps `mothership-plan-mode` to `benchmarkEnabled` (`o/[organizationId]/layout.tsx:100-110`). |
| `BrandingProvider` | whitelabel settings (member of host org only) | 60 s stale | `useOrgBrandConfig()` (merged `BrandConfig`), theme CSS | **BrandingCubit**: `{settings: OrganizationWhitelabelSettings?, brand: BrandConfig}`; instance defaults from public env (`getBrandConfig`, `ee/whitelabeling/branding.ts`, not mapped here). |
| `SettingsLoader` | general settings | 60 min stale; `refreshGeneralSettings` after organization chat; mutations | selector hooks `useAutoConnect` (true), `useSnapToGridSize` (0), `useShowActionBar` (true), `useAutoFocusOnClick` (true), `useBillingUsageNotifications` (true), `useTimezoneState` | **SettingsCubit**: `{settings: GeneralSettings?, status}`; applies `theme` to `SharedWebState['sim-theme']` on load and on optimistic change/rollback; `updateSetting(key, value)` optimistic. |
| `ProviderModelsLoader` | nine model lists | route gate (`:447-464`) or palette open; 5 min stale | providers store `{providers[name].{models,isLoading}, openRouterModelInfo}` | **ProviderModelsCubit**: `{byProvider: Map<ProviderName, {models, isLoading, error}>, openRouterModelInfo}`; `setEnabled(bool)` driven by the router + search cubit; updates the generated registry's option lists. |
| `CustomBlocksLoader` | custom blocks | workspace switch; `['custom-blocks','list']` invalidation | overlay (`hydrateClientCustomBlocks`) | **CustomBlocksCubit**: `{enabled, blocks, overlayVersion}`; overlay rebuild on every emit with the org logo fallback from BrandingCubit. |
| `BlockVisibilityLoader` | visibility projection | workspace switch; 60 s | overlay | **BlockVisibilityCubit**: `{revealed, disabled, previewTagged}` as sets; `resetForSwitch()` while `data == null`; deep-equal guard. |
| `GlobalCommandsProvider` | — | — | keyboard registry | not a data cubit (shell). |
| `ImpersonationBanner` | session | — | banner when `session.impersonatedBy` | SessionCubit + `stopImpersonating()` (admin plugin) then store reset preserving `recent-impersonations`. |
| `SessionExpired` | session | — | takeover when a live session settles to `null` | SessionCubit transition + `recoverFromStaleSession()`. |
| `WorkspacePermissionsProvider` | permissions | 30 s; `refetchPermissions()`; invalidations in §6 | `{workspacePermissions, permissionsLoading, permissionsError, updatePermissions, refetchPermissions, userPermissions{canRead, canEdit, canAdmin, userPermissions, isLoading, error, isOfflineMode}}` | **PermissionsCubit**: derives from `viewer.permissionType` (fallback: `users` by session email), combines with the operation-queue error flag and the socket join state; owns the three persistent toasts with the 2000/1500 ms anti-flicker. |
| `WorkspaceScopeSync` | workspace list (metadata) | — | switches the workflow registry scope (`switchToWorkspace`), PostHog groups (hosted) | **WorkspacesCubit** (list + metadata + switcher ordering + pins + creation policy + visit + create/update/delete/leave + pin toggle) and a scope-sync listener in the app shell. |
| `Sidebar` hooks | workflows, folders, pinned ids, chats, permission config, access-request discovery, profile | socket room, mutations, 60 s | tree data | **WorkflowsCubit** (`list(ws,'active')` + mutations + optimistic rows + `markWorkflowCreating/Created`), **FoldersCubit** (`list(ws,'active','workflow')` + mutations), **PinnedItemsCubit** (`list(ws,'workflow')`, `list(ws,'folder')`, pin/unpin), **InvitationsCubit** (`mine()` on dropdown open, accept/decline, batch send, workspace invitation list), plus the page-scoped search cubit for palette data. |
| `SettingsNavigationProvider` + dirty store | — | — | `requestLeave(cb)` guard | app cubit (not data). |

Store reset on sign-out (`stores/index.ts:23-64`, `reset-all-stores.ts:19-59`): remove every `localStorage` key except `next-favicon`, `sim-theme`, `sim-landing-theme` (and `recent-impersonations` when preserving); `sessionStorage.clear()`; reset operation queue, registered user-data stores, workflow registry/workflow/subblock stores, **`queryClient.clear()`**, execution, terminal console (+ persistence), mothership drafts/queue; `useSettingsDirtyStore.reset()`. Flutter: `QueryClient.instance.clear()`, `KeyValueStore` wipe with the same keep-list via `SharedWebState`, every GetIt cubit's `reset()`, `SimHttpClient.clearCookies()` on desktop (already in `AuthRepository.signOut`).

## 8. Entry resolution data needs (client-side port of `home/page.tsx`, `o/page.tsx`, `workspace/page.tsx`)

1. `/` and `/home`, `/o`: `resolveAppEntryPath(session)` = organization home when `resolveOrganizationLanding(userId, activeOrganizationId)` yields an organization **and** `isKnowledgeMemberAccessAvailable({organizationId})`; else `/workspace` (`resolve-app-entry.ts:11-32`). Both checks are server-only; the Flutter client must call `GET /api/organizations/[id]/surface-context` for the candidate organization (`session.activeOrganizationId`, else the single membership from `GET /api/organizations`) and treat a 403 or `!context.mothershipAvailable && !context.searchAccess.memberScoped` as "no organization home" (`o/[organizationId]/layout.tsx:63-67` applies the same redirect to `/workspace?redirect=settings`). The sidebar's `organizationHref` (account menu "Organization" entry, `sidebar.tsx:898-905`) comes from the same resolution. Recorded as an ambiguity in §11 (the exact `resolveOrganizationLanding` rule is not reproduced client-side).
2. `/workspace`: `GET /api/workspaces` (after the session is known); 401 → `recoverFromStaleSession`; empty + `creationPolicy.canCreate === false` → blocked card (copy per `blockedReasonCode`/`workspaceMode`, `workspace/page.tsx:182-199`); empty + allowed → `POST /api/workspaces {name:'My Workspace'}` then navigate; `?redirect_workflow=` → `GET /api/workflows/[id]` for its `workspaceId`; `?redirect=upgrade|settings` preserved (`:129-134`); target = `lastActiveWorkspaceId` match or `workspaces[0]`.
3. `/workspace/[id]`: `chatEnabled ? home : w` from the deployment shape (`[workspaceId]/page.tsx:19`); the host-context 403 is the access-denied page.
4. Middleware equivalents (`proxy.ts`, `03-api-and-auth.md` §7): no session → `/login` for app surfaces; session present on `/login`,`/signup` → `/home`.

## 9. Error handling summary (status → UI)

| Status / code | Where | UI |
|---|---|---|
| 401 on any workspace query after a live session | picker (`workspace/page.tsx`), `SessionExpired` | sign out + clear + `/login` (recovery); failure → "signing out failed, Try again" |
| 401 on `get-session` (Better Auth error envelope) | session query `error` | picker: error card "Could not load your workspaces"; `SessionExpired` ignores `error` |
| 403 host-context | `WorkspaceHostProvider` | `WorkspaceAccessDenied` (link to `/workspace`) |
| 403 feature-flags / surface-context `{error}` | new routes | flags: no access decision, every flag stays off (access is gated on the host context only, `layout.tsx`; corrected 2026-10-22) / surface-context: `OrganizationAccessDenied` |
| 404 permissions | `fetchWorkspacePermissions` | `Error('Workspace not found or access denied')` → `permissionsError` string in context |
| 409 create workspace | picker | one reload keyed in sessionStorage, then error card |
| 409 pin / 404 unpin | `useToggleWorkspacePin` | treated as success |
| 429 | any `defineInternalJsonRoute` route | `ApiClientError{status:429, retryAfter}`; `shouldRetrySettingsRead` retries once; otherwise surfaced like any error |
| 2xx with `failed[]` | batch invitations | partial failure message in the modal |
| Invitation codes | accept/reject | §4.4 tables (`invite.tsx:147-274`, `error-messages.ts:10-28`) |
| Better Auth codes | login/signup/verify | §4.1 |
| schema validation failure on 2xx | `requestJson` | `ApiClientError{status: 200, message: 'Response failed contract validation — …'}` |

## 10. Checklist (L4 contract tests, aspect `network`)

| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | network | `lib/api/client/request.ts:102-123` | every request carries `x-sim-client-id` (21-char nanoid, stable per app instance) and nothing else client-specific | | |
| 2 | network | `lib/api/client/request.ts:63-100` | query serialisation: empty skipped, scalar arrays repeated, object/array-of-object JSON-encoded | | |
| 3 | network | `lib/api/client/request.ts:223-242` | non-2xx → `ApiClientError{status, message: body.message ?? body.error, code}`; 2xx failing the schema → `ApiClientError{status: 200}` | | |
| 4 | network | `lib/core/rate-limiter/route-helpers.ts:27-42` | 429 body `{error:'Rate limit exceeded', retryAfter}` + `Retry-After`/`X-RateLimit-Reset` parsed into `RateLimitInfo` | | |
| 5 | network | `app/_shell/providers/get-query-client.ts:19` | no focus refetch on web except session and status page | | |
| 6 | network | `app/api/public-env/route.ts:16-22` | `GET /api/public-env` unauthenticated, `Cache-Control: no-store`, flat `NEXT_PUBLIC_*` object | | |
| 7 | network | `lib/api/contracts/public-env.ts:17-19` | a key without the prefix fails client validation | | |
| 8 | network | `app/api/auth/providers/route.ts:11-22` | `GET /api/auth/providers` → four booleans | | |
| 9 | network | `hooks/queries/session.ts:71-85` | `get-session` key `['session','detail']`, stale 5 min, no retry, focus refetch | | |
| 10 | network | `hooks/queries/session.ts:75-77` | impersonated session polls every 60 s with `disableCookieCache=true` | | |
| 11 | network | `hooks/queries/session.ts:33-42` | `refreshSessionQuery` bypasses the cookie cache and overwrites the cache entry | | |
| 12 | network | `app/(auth)/login/login-form.tsx:199-217` | `EMAIL_NOT_VERIFIED` → `/verify`; 403+message → policy error | | |
| 13 | network | `app/(auth)/signup/signup-form.tsx:286-295` | sign-up sends `x-captcha-response` only when a Turnstile token exists | | |
| 14 | network | `app/(auth)/verify/use-verification.ts:100-123` | verify-email then session refetch then navigation | | |
| 15 | network | `app/(auth)/verify/use-verification.ts:159-178` | resend uses `type:'email-verification'` | | |
| 16 | network | `app/(auth)/login/login-form.tsx:316-321` | forget-password `redirectTo` = `<origin>/reset-password` | | |
| 17 | network | `lib/api/contracts/user.ts:229-253` | reset-password policy enforced client- and server-side | | |
| 18 | network | `lib/api/contracts/auth.ts:106-118` | `POST /api/auth/sso/resolve` `{email}` → `{providerId}` | | |
| 19 | network | `lib/auth/sign-out.ts:8-21` | sign-out then `clearUserData`; `/login?fromLogout=true` | | |
| 20 | network | `stores/reset-all-stores.ts:46` | query cache cleared on sign-out; `sim-theme` kept | | |
| 21 | network | `app/workspace/[workspaceId]/prefetch.ts:32-42` | host context fetched before any other workspace query | | |
| 22 | network | `app/api/workspaces/[id]/host-context/route.ts:23-25` | 403 `{error:'Workspace access denied'}` → access-denied page, no fallback workspace | | |
| 23 | network | `hooks/queries/workspace-host.ts:14` | host context stale 30 s | | |
| 24 | network | `lib/core/config/deployment-shape.ts:97-120` | seeding an equal shape does not notify | | |
| 25 | network | `app/api/workspaces/[id]/feature-flags/route.ts:14-21` | `GET feature-flags` → `{flags(7 booleans), desktopExecutor{available,registered}}`; 401/403/404 | | |
| 26 | network | `app/api/organizations/[id]/surface-context/route.ts:14-23` | `GET surface-context` shape per §3.4; 403 non-member | | |
| 27 | network | `hooks/queries/workspace.ts:61-67` | `GET /api/workspaces?scope=active` normalised (invite fields defaulted) | | |
| 28 | network | `app/api/workspaces/route.ts:54-111` | empty active list creates "My Workspace" unless `creationPolicy.canCreate` is false | | |
| 29 | network | `app/api/workspaces/route.ts:92-94` | stale cookie → 401 → recovery | | |
| 30 | network | `hooks/queries/workspace.ts:156-186` | visit recorded on workspace entry; optimistic reorder; serialised | | |
| 31 | network | `hooks/queries/workspace.ts:213-280` | workspace pin → `POST /api/pinned-items` with `resourceType:'workspace'`; 409/404 are success | | |
| 32 | network | `hooks/queries/workspace.ts:289-316` | create workspace prepends and invalidates `lists`+`adminLists` | | |
| 33 | network | `app/workspace/page.tsx:266-277` | 409 on default workspace creation reloads once | | |
| 34 | network | `hooks/queries/workspace.ts:352-365` | PATCH workspace `{name}` trimmed; invalidates lists + detail | | |
| 35 | network | `.../sidebar/hooks/use-workspace-logo-upload.ts:53-66` | logo via upload session `purpose:'workspace_logo'` then PATCH `{logoUrl}` | | |
| 36 | network | `hooks/queries/workspace.ts:326-341` | DELETE workspace body `{}`; 400 "Cannot delete the only workspace" | | |
| 37 | network | `hooks/queries/workspace.ts:367-398` | permissions 404 → "Workspace not found or access denied"; stale 30 s | | |
| 38 | network | `hooks/use-user-permissions.ts:57-67` | `viewer.permissionType` drives `canEdit/canAdmin` | | |
| 39 | network | `hooks/queries/workspace.ts:415-422` | members list stale 5 min | | |
| 40 | network | `hooks/queries/workspace.ts:482-510` | admin workspaces derived from `/api/workspaces` (no scope param) | | |
| 41 | network | `hooks/queries/invitations.ts:156-162` | `GET /api/invitations` only when the switcher opens / modal open | | |
| 42 | network | `hooks/queries/invitations.ts:177-213` | accept echoes `disclosedWorkspaceIds` + `disclosedOutcome`; invalidation set | | |
| 43 | network | `app/api/invitations/[id]/accept/route.ts:36-58` | error kinds → statuses (409 `disclosure-outdated`, 402 `upgrade-required`, …) | | |
| 44 | network | `app/invite/[id]/invite.tsx:299-318` | token from `?token=` else `sessionStorage['inviteToken:<id>']`; query enabled only when signed in | | |
| 45 | network | `hooks/queries/invitations.ts:73-86` | invitation details keyed by viewer id, no retry | | |
| 46 | network | `hooks/queries/invitations.ts:241-286` | batch invitations body/response; per-workspace + org invalidation | | |
| 47 | network | `.../invite-modal/invite-modal.tsx:245-270` | partial failure surfaced from `failed[]` on a 2xx | | |
| 48 | network | `hooks/queries/invitations.ts:401-422` | leave = `DELETE /api/workspaces/members/[selfId]` `{workspaceId}` | | |
| 49 | network | `hooks/queries/invitations.ts:430-468` | PATCH permissions `{updates}`; first validation issue toasted | | |
| 50 | network | `hooks/queries/utils/workflow-list-query.ts:28-38` | workflows list `?workspaceId&scope=active`, stale 60 s, dates mapped | | |
| 51 | network | `hooks/queries/workflows.ts:176-316` | create workflow optimistic temp row with client id, `deduplicate:true`, navigate before response | | |
| 52 | network | `hooks/queries/workflows.ts:341-471` | duplicate workflow optimistic + `newId` | | |
| 53 | network | `hooks/queries/workflows.ts:480-524` | rename/move = PUT `/api/workflows/[id]` partial metadata, optimistic | | |
| 54 | network | `hooks/queries/workflows.ts:532-567` | delete optimistic removal, invalidates active+archived | | |
| 55 | network | `hooks/queries/workflows.ts:632-676` | reorder PUT `/api/workflows/reorder` `{workspaceId, updates}` | | |
| 56 | network | `hooks/queries/workflows.ts:697-708` | restore invalidates recently-deleted + lists | | |
| 57 | network | `hooks/queries/folders.ts:33-44` | folders list `?workspaceId&scope&resourceType=workflow`, stale 60 s | | |
| 58 | network | `hooks/queries/folders.ts:193-252` | create folder optimistic with `getTopInsertionSortOrder`; name "Folder N" from a list fetch | | |
| 59 | network | `hooks/queries/folders.ts:254-277` | update folder PUT `?resourceType=`; invalidates the resource prefix | | |
| 60 | network | `hooks/queries/folders.ts:279-296` | delete folder cascades: workflow lists active+archived | | |
| 61 | network | `hooks/queries/folders.ts:333-393` | duplicate folder POST `{workspaceId, name, parentId, newId}` | | |
| 62 | network | `hooks/queries/folders.ts:405-459` | reorder folders PUT `{workspaceId, resourceType, updates}` optimistic | | |
| 63 | network | `hooks/queries/pinned-items.ts:20-40` | pinned items list per `(ws, resourceType)`, stale 60 s | | |
| 64 | network | `hooks/queries/pinned-items.ts:94-154` | pin/unpin update both the typed and the untyped list; invalidate `workspaceLists(ws)` | | |
| 65 | network | `.../sidebar/hooks/use-workspace-workflows-room.ts:22-29` | socket `join-workspace-workflows` / `workspace-workflows-changed` → lists + folders invalidated | | |
| 66 | network | `app/workspace/[workspaceId]/hooks/use-workspace-invalidation-room.ts:56-63` | join error retry ≤3 when `retryable` | | |
| 67 | network | `hooks/queries/user-profile.ts:24-38` | profile stale 5 min; `{id,name,email,image}` | | |
| 68 | network | `hooks/queries/general-settings.ts:21-55` | settings stale 60 min; theme written to `sim-theme` | | |
| 69 | network | `hooks/queries/general-settings.ts:155-195` | setting PATCH one key, optimistic, theme rollback | | |
| 70 | network | `hooks/queries/custom-blocks.ts:31-54` | custom blocks `?workspaceId`, stale 60 s, overlay rebuilt | | |
| 71 | network | `hooks/queries/block-visibility.ts:16-31` | block visibility `?workspaceId`; reset fail-closed on switch | | |
| 72 | network | `app/workspace/[workspaceId]/providers/provider-models-loader.tsx:447-464` | nine provider-model queries gated by route / palette; workspace query only for ollama-cloud, fireworks, together, baseten | | |
| 73 | network | `ee/access-control/hooks/permission-groups.ts:121-140` | `GET /api/permission-groups/user?workspaceId`, stale 60 s, retry 5xx×3 | | |
| 74 | network | `hooks/queries/integration-availability.ts:9-15` | `GET /api/settings/allowed-integrations`, stale 5 min | | |
| 75 | network | `hooks/queries/allowed-providers.ts:20-26` | `GET /api/settings/allowed-providers` → `{blacklistedProviders}` | | |
| 76 | network | `ee/access-requests/components/permission-access-boundary.tsx:17-24` | discovery query `{kind:'workspace', workspaceId, targetKind:'feature', limit:100, offset:0}`, stale 15 s | | |
| 77 | network | `ee/whitelabeling/components/branding-provider.tsx:41-43` | whitelabel fetched only for host-org members | | |
| 78 | network | `hooks/queries/status-page.ts:18-28` | hosted only: external status JSON, 60 s poll, no retry | | |
| 79 | network | `hooks/queries/mothership-chats.ts:334-348` | chats list only when `chatEnabled && !hideCopilot` | | |
| 80 | network | `.../help-modal/help-modal.tsx:91-116` | `/api/help` multipart fields; 401/400 handling | | |
| 81 | network | `hooks/queries/recently-deleted.ts:24-52` | recently deleted cursor paging, stale 0 | | |
| 82 | network | `hooks/queries/organization-plan-seats.ts:13-30` | plan seats only for org admins with billing enabled | | |
| 83 | network | `hooks/queries/workspace-usage.ts:34-50` | credit availability / usage gate shapes, stale 30 s | | |
| 84 | network | `app/workspace/[workspaceId]/components/session-expired/session-expired.tsx:36-57` | live→null session transition triggers recovery; `error` never does | | |
| 85 | network | `app/workspace/[workspaceId]/components/impersonation-banner/impersonation-banner.tsx:36-44` | stop impersonating → reset (keep `recent-impersonations`) → `/home` | | |
| 86 | network | `lib/navigation/resolve-app-entry.ts:11-32` | entry resolution via surface-context (§8) | | |
| 87 | network | `app/workspace/[workspaceId]/page.tsx:19` | `/workspace/[id]` → `home` iff `chatEnabled` | | |
| 88 | network | `app/workspace/page.tsx:123-170` | `?redirect=upgrade|settings`, `?redirect_workflow=` honoured | | |

## 11. Ambiguities and untyped areas

1. **Organization entry (`organizationHref`)**: `resolveOrganizationLanding` and `isKnowledgeMemberAccessAvailable` are server-only; the surface-context endpoint answers per organization but does not say *which* organization is the landing one. Proposed rule (§8): `session.activeOrganizationId`, else the single membership from `GET /api/organizations`, verified by a surface-context call. Needs confirmation against `lib/organizations/surface.ts` `resolveOrganizationLanding` (not read here).
2. **Auth-page server props**: `registrationDisabled` is in `/api/auth/providers`, but `isEmailSignupDisabled` (`DISABLE_EMAIL_SIGNUP`), `isEmailVerificationEffectivelyEnabled`, `hasEmailService` and `isProd` (verify page copy) are server env values with no transport. Options: extend `/api/auth/providers` upstream, or infer (`hasEmailService` cannot be inferred). Recorded as an open server addition.
3. **Permission group config fields**: `permissionGroupFullConfigSchema` is `z.object(permissionGroupReadShape)` built from a registry (`lib/permission-groups/fields.ts`); the field list used by Phase 1 is `hideCopilot, hideFilesTab, hideTablesTab, hideKnowledgeBaseTab, hideIntegrationsTab, disableInvitations, disablePublicApi, allowedIntegrations, deniedModels, allowedModelProviders, deniedTools, defaultAgentModel`; the Dart DTO should be generated from `permission-groups.schema.json` rather than hand-listed.
4. **Passthrough schemas**: `pendingWorkspaceInvitationSchema`, `subscription*` schemas, `organizationBilling*`, `usageLimitDataSchema` are `.passthrough()`; the generated JSON schema has `additionalProperties: true` there. Dart DTOs must keep unknown fields (or at least not fail on them).
5. **`exposedOutputSchema`** (custom blocks) and the whitelabel settings body live in `lib/workflows/custom-blocks/settings-input.ts` and `organization.ts:269-…` (only partially read); take them from the JSON schema.
6. **Search palette data** for tables/files/knowledge bases/logs/credentials are Phase 4 contracts; Phase 1 can mount the sections empty behind the same `enabled: open` gates, but the palette parity test must account for the missing groups.
7. **Status page** is an external origin (`status.sim.ai`); not reachable in the docker stack; hosted-only, verify by review.
8. **Better Auth plugin endpoints** used without a Sim contract: `admin/stop-impersonating`, `revoke-other-sessions`, `organization/get-full-organization`, `organization/list`, `organization/set-active`. Their response shapes are the plugin's; `AuthRepository` additions should be typed loosely (`Map`).
9. **`WorkflowListItem.isDeployed`** is optional and `forkSyncExcluded` defaults to `false`; **`workspaceHostContext.deployment`/`features`** are optional for rolling compatibility — the Dart decoders must default rather than throw.
10. **`useRecordWorkspaceVisit` / `useToggleWorkspacePin` serialisation** relies on TanStack `scope` + `isMutating` counting; the Dart port needs an explicit per-key mutation queue to reproduce "invalidate only when last".
11. **Chat list prefetch** happens only when `isChatEnabled` at the server; the client hook is additionally gated by `hideCopilot`, so a prefetched list can exist for a viewer whose sidebar hides it (harmless).
12. **`x-sim-client-info`** is emitted only by desktop/CLI builds (`lib/api/client-info.ts`, not read); the web client sends none. If the Windows build should identify itself the header format must be taken from that file.
13. **Rate-limit buckets** for the legacy `withRouteHandler` routes are absent; only the two new routes (and socket-token/SSO launch) can answer 429 in Phase 1. The L4 case "429 handling" should target `/api/workspaces/[id]/feature-flags`.
