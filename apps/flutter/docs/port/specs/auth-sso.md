# SSO sign-in
Upstream: `apps/sim/app/(auth)/sso/**` (page, loading, `sso/launch/[providerId]/route.ts`), `apps/sim/ee/sso/components/sso-form.tsx`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

## Files
| File | Lines | Role |
|---|---|---|
| `app/(auth)/sso/page.tsx` | 24 | Server page: `redirect('/login')` when `!isSsoEnabled`; renders `SSOForm registrationDisabled` in `Suspense`; `force-dynamic` |
| `app/(auth)/sso/loading.tsx` | 17 | Route skeleton |
| `app/(auth)/sso/launch/[providerId]/route.ts` | 89 | IdP-initiated login entry (server route, GET) |
| `ee/sso/components/sso-form.tsx` | 312 | The form: email → `POST /api/auth/sso/resolve` → `client.signIn.sso` |
| `lib/api/contracts/auth.ts` | 106-118 | `resolveSsoProviderContract` (`POST /api/auth/sso/resolve` `{email, providerId?}` → `{providerId}`) |
| `app/api/auth/sso/resolve/route.ts` | 72 | Resolver: IP limiter 30/min; 400 "Enter a valid work email address"; 404 `{error, code:'SSO_NO_PROVIDER'}` |
| `lib/auth/sso/idp-initiated-login.ts` | | `isIdpInitiatedLoginAllowed(providerId, issuer)` (server) |
| `lib/core/config/env-flags.ts` | 339-343 | `isSsoEnabled` (`SSO_ENABLED` / `NEXT_PUBLIC_SSO_ENABLED`, enterprise) |
| Shared | | `AuthShell`, `AuthFormMessage`, `AuthSubmitButton`; emcn `Label`, `Input` (`input/input.tsx`), `Button` (`button/button.tsx`) — this form predates the chip family and uses the legacy `Input`/`Button` |

Hooks: `useSearchParams` (`error`, `email`, `callbackUrl`, `provider`), PostHog `external_sign_in_started` (hosted). No store.

## Layout
Shell as login (400 px column). The form is keyed on the full search string so a changed query remounts it (`sso-form.tsx:69`). Column — parity `auth.sso.root` (not a `space-y` stack; each block carries its own margin):
1. `auth.sso.header` `div.space-y-1.text-center` (`:191-206`): `auth.sso.title` `<h1>` "Sign in with SSO" 40 px, line-height 110 % (44 px), `tracking-[-0.02em]`, `--text-primary`, `text-balance`; `auth.sso.description` `<p>` "Enter your work email to continue" 18 px (`text-lg`), line-height 125 % (22.5 px), `tracking-[0.02em]`, colour `color-mix(in srgb, var(--text-muted) 60%, transparent)` (60 % alpha #7a7a7a over `--bg` ≈ #ccc). Block ≈ 44 + 4 + 22.5 = 70.5 px. (Different scale from the other auth pages: this is the landing hero scale.)
2. `auth.sso.form` `<form class='mt-8 space-y-8'>` (32 px above, 32 px between children) (`:208`):
   - `auth.sso.formError` `div[role=alert]` → `AuthFormMessage type='error'` (12 px `--text-error`, left) when `formError` (`:209-213`).
   - `div.space-y-6` → `div.space-y-2` (`:215-247`): label row `flex items-center justify-between` with `Label` "Work email" (13 px, `--text-primary`); `auth.sso.email` = emcn `Input` (`input.tsx:31-32`): `w-full rounded-sm (4 px) border --border-1 bg --surface-5 px-2 py-1.5 text-sm --text-primary`, placeholder "Enter your work email" `--text-muted`; height = 6 + 20 + 6 + 2 = 34 px (14 px text at line-height 20 + 1.5 padding + 1 px borders); error → `border --text-error` (also on focus) (`:232-234`); `auth.sso.email.errors` `div#sso-email-errors[role=alert]` `mt-1 space-y-1 text-caption --text-error` (`:236-246`).
   - `auth.sso.submit` `AuthSubmitButton` "Continue with SSO" / "Redirecting to SSO provider…" (400×36 primary chip) (`:250-252`).
3. `auth.sso.divider` (only `emailEnabled`, `:255-264`): `div.relative.my-6.font-light` (24 px above and below): 1 px `--border` rule centred; label "Or" 14 px `--text-muted` on `--bg` with `px-4`.
4. `auth.sso.emailLink` (only `emailEnabled`, `:266-274`): `div.space-y-3` → `Link` to `/login?callbackUrl=<encoded>` wrapping `Button variant='outline' type='button' className='w-full rounded-[10px]'`: legacy button `md` size `px-2 py-1.5 text-[12px]` (`button.tsx:54`), `inline-flex items-center justify-center`, `border --text-muted`, transparent, `--text-secondary` text, hover border `--text-secondary` + text `--text-primary` (`button.tsx:37-38`); radius overridden to 10 px; height = 6 + 12×(line-height 1.5 → 18) + 6 + 2 = 32 px. Label "Sign in with email".
5. `auth.sso.signupPrompt` (only `emailEnabled && !registrationDisabled`, `:278-288`): `div.pt-6.text-center.font-light.text-base` (24 px above, 15 px text): span "Don't have an account? " (`font-normal`) + `Link` "Sign up" (`--text-primary`, `underline-offset-4`, hover underline) to `/signup?callbackUrl=<encoded>`.
6. `auth.sso.legal` (`:290-309`): `div.absolute.right-0.bottom-0.left-0.px-8.pb-8.text-center.font-normal.text-sm.leading-relaxed --text-muted md:px-[44px]` — absolutely positioned at the bottom of the nearest positioned ancestor, which is the `AuthShell` root (`relative`, `auth-shell.tsx:35`): so the legal line sits 32 px above the viewport bottom spanning the full width with 44 px side padding (≥768 px), 14 px / 22.75 px line: "By signing in, you agree to our Terms of Service and Privacy Policy" with `--text-muted` links (hover `--text-primary` underline, new tab). Note it is not inside the 400 px column.

Column height (email enabled, registration allowed): 70.5 + 32 + (13 + 8 + 34) + 32 + 36 + 24 + 20 + 24 + 32 + 24 + 22.5 ≈ 372 px.

Skeleton (`sso/loading.tsx:7-16`) — parity `auth.sso.loading`: title 120×38; `mt-3` label 260×14; `mt-8` field (label 80×14 + control 400×44); `mt-6` control 400×44; `mt-6` label 120×14.

## Tokens
| Element | Token(s) |
|---|---|
| Title | `--text-primary`, 40 px / 110 % / −0.02 em |
| Description | `color-mix(--text-muted 60 %, transparent)`, 18 px / 125 % / +0.02 em |
| Label | `--text-primary` 13 px |
| Input | `--surface-5` fill, `--border-1` border, `--text-primary` text (legacy `Input`, not `--text-body`), `--text-muted` placeholder, radius 4 px; error `--text-error` |
| Form / field errors | `--text-error` 12 px |
| Submit | primary chip tokens |
| Divider | `--border` rule, `--text-muted` label on `--bg` |
| "Sign in with email" | outline button: border `--text-muted`, text `--text-secondary`, hover border `--text-secondary` / text `--text-primary`, radius 10 px, 12 px label |
| Sign up link | `--text-primary` |
| Legal | `--text-muted`, links `--text-muted` → `--text-primary` |
| Weights | `font-light` (300) on the divider and prompt wrappers but overridden by `font-normal` on the visible spans; the "Sign up" link inherits 300 (`:278-287`) |

## States
Inputs: `isSsoEnabled` (server + `NEXT_PUBLIC_SSO_ENABLED`), `registrationDisabled` (`GET /api/auth/providers`), `emailEnabled = !isFalsy(NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED)` (`:100`). Query: `error`, `email` (pre-fill), `callbackUrl` (validated, default `/home`, invalid logged), `provider` (test-link provider id) (`:58-76, 108-117`).

| State | Rendering / behaviour |
|---|---|
| SSO disabled | server `redirect('/login')` (`sso/page.tsx:15-17`); Flutter: route guard on the flag |
| Default | header, form, divider, email button, sign-up prompt, legal |
| `?error=` | form-level error pre-filled: `account_not_found` → "No account found. Please contact your administrator to set up SSO access."; `sso_failed` → "SSO authentication failed. Please try again."; `invalid_provider` → "SSO provider not configured correctly."; `sso_no_seats` → "Your organization has no available seat capacity. Ask an administrator to increase capacity or remove an unused member."; `sso_account_conflict` → "This Sim account is already a member of another organization. Leave that organization before trying again, or ask an administrator for external workspace access."; `sso_provisioning_failed` → "SSO succeeded, but organization access could not be set up safely. No session was created; please try again or contact your administrator."; any other value → "SSO authentication failed. Please try again." (`:25-35, 60-65`). Cleared on the first keystroke (`:124`) |
| `?email=` | pre-fills the field (`:71, 95`) |
| `?provider=` (test link) | sent as `providerId` to the resolver; a 404 then reads "This sign-in link is not set up for your email domain. Ask your administrator for the right link." (`:74, 159`) |
| Email validation (after submit) | "Email is required." / `quickValidateEmail` reasons under the field; red border (`:37-51, 138-145`); hidden on next keystroke (`:126`) |
| Resolver 404 (no provider) | "No SSO provider is configured for this email domain. Ask your administrator." (`:21-22, 157-160`) |
| Resolver other error / sign-in error / thrown | "Unable to start SSO. Check your email and try again." (`:20, 160, 177-186`) |
| Submitting | "Redirecting to SSO provider…" with spinner (`:250`); submit is never explicitly disabled except via `loading` |
| Email disabled | no divider, no email button, no sign-up prompt (`:255, 278`) |
| `registrationDisabled` | sign-up prompt hidden (`:278`) |
| Signed-in visitor | `/sso` is not proxied; the page renders; the launch route redirects a signed-in visitor to `/home` (`launch/route.ts:34-37`) |

## Interactions
- Typing: clears `formError`, revalidates silently (`:119-127`).
- Submit (`Enter` or click): trims + lower-cases, validates, resolves provider, starts SSO (`:129-187`). On success the browser leaves the page (Better Auth navigates to the IdP `url`); `finally` resets `isLoading`.
- "Sign in with email": client navigation to `/login?callbackUrl=…` (always carries the resolved callback, default `/home`).
- "Sign up": `/signup?callbackUrl=…`.
- Terms / Privacy: new tab.
- Focus order: logo → email → Continue with SSO → Sign in with email → Sign up → Terms → Privacy.

## Network and realtime
1. (F) `GET /api/public-env` (`NEXT_PUBLIC_SSO_ENABLED`, `NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED`), `GET /api/auth/providers` (`registrationDisabled`), `GET /api/auth/get-session`.
2. Submit: `POST /api/auth/sso/resolve` JSON `{ email: <trimmed lower-cased>, providerId?: <?provider> }` (`:151-155`; contract trims/lower-cases again, max 320) → 200 `{ providerId }`; 400 `{ error: 'Enter a valid work email address' }`; 404 `{ error, code: 'SSO_NO_PROVIDER' }`; 429 (30 per minute per IP, `resolve/route.ts:32-37`).
3. `POST /api/auth/sign-in/sso` (Better Auth SSO plugin via `client.signIn.sso`) JSON `{ email, providerId, callbackURL: <validated callback or '/home'>, errorCallbackURL: '/sso?error=sso_failed[&provider=<id>]&callbackUrl=<encoded callback>' }` (`:165-175`) → 200 `{ url, redirect: true }` plus `Set-Cookie` for the signed OAuth/SAML `state`; the SDK navigates the top-level window to `url`. On return the IdP callback (`/api/auth/sso/callback/<providerId>` or `/api/auth/sso/saml2/callback/<providerId>`) sets the session cookie and 302s to `callbackURL`, or to `errorCallbackURL` with `?error=` on failure. Admission failures (`sso_no_seats`, `sso_account_conflict`, `sso_provisioning_failed`, `account_not_found`) are appended by `buildSsoAdmissionErrorUrl` in `auth.ts` (`:1370`).
4. Hosted: PostHog `external_sign_in_started {provider:'sso', surface:'sso_page'}` (`:164`).

### Flutter replacement for the launch route
`GET /sso/launch/[providerId]?iss=<issuer>` is a **server** route (`launch/route.ts:26-89`) that: redirects to `/login` when SSO is off (`:32`); redirects a signed-in visitor to `/home` (`:34-37`); rate-limits 30/min per IP → `/sso?provider=<id>` (`:40-45`); requires `iss` and `isIdpInitiatedLoginAllowed(providerId, iss)` else `/sso?provider=<id>` (`:47-50`); calls `auth.api.signInSSO({ providerId, callbackURL: '/home', errorCallbackURL: '/sso?error=sso_failed&provider=<id>&callbackUrl=%2Fhome' })` server-side (`:57-68`); on failure redirects to that `errorCallbackURL` (`:69-80`); on success 302s to the IdP `url` **forwarding Better Auth's `Set-Cookie` headers** (the signed `state` cookie) onto the redirect (`:82-88`). It exists for identity-provider dashboards (OIDC third-party-initiated login); only an IdP ever opens it.

The Flutter app cannot run this route and does not need to: it stays served by Next at `/sso/launch/[providerId]` (outside the `/app/` prefix). The Flutter app must (a) handle the places the route lands: `/home` (entry resolution) and `/sso?error=…&provider=…&callbackUrl=…` / `/sso?provider=…` (this form), and (b) for its own SSO form do what `sso-form.tsx` does: `POST /api/auth/sso/resolve` then `POST /api/auth/sign-in/sso` and navigate the browser to the returned `url`. Because the `/api/auth/sign-in/sso` XHR is same-origin with credentials, the browser stores the `state` `Set-Cookie` from that response itself; no cookie forwarding is needed on web. On Windows the desktop handoff (plan §3) replaces the whole leg. Navigating the browser to `/sso/launch/<id>` without `iss` only bounces back to `/sso?provider=<id>`, so it is not a substitute for the sign-in call.

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | sso-form.tsx:191-206 | title 40 px / 110 % / −0.02 em; description 18 px / 125 % / +0.02 em; 4 px gap; centred | | |
| 2 | layout | sso-form.tsx:208 | form 32 px below header; 32 px between form children | | |
| 3 | layout | sso-form.tsx:216-235; input.tsx:31-32 | label "Work email" 13 px; 8 px gap; legacy input 400×34, radius 4, padding 8/6 | | |
| 4 | layout | sso-form.tsx:250-252 | submit 400×36 "Continue with SSO" | | |
| 5 | layout | sso-form.tsx:257-264 | divider with 24 px margins, "Or" label | | |
| 6 | layout | sso-form.tsx:266-274; button.tsx:37-38, 54 | "Sign in with email" outline button 400×32, radius 10, 12 px label | | |
| 7 | layout | sso-form.tsx:278-288 | prompt 24 px below, 15 px text, "Sign up" link | | |
| 8 | layout | sso-form.tsx:290-309; auth-shell.tsx:35 | legal line absolutely at the shell bottom: 32 px bottom padding, 44 px side padding, full width, 14 px | | |
| 9 | layout | sso/loading.tsx:7-16 | skeleton 120×38, 260×14, field (80 label), control, 120×14 | | |
| 10 | token | sso-form.tsx:193-205 | description colour = 60 % `--text-muted` over `--bg` | | |
| 11 | token | input.tsx:32; sso-form.tsx:232-234 | input `--surface-5` / `--border-1` / `--text-primary`; error border `--text-error` incl. focus | | |
| 12 | token | button.tsx:37-38 | outline button border `--text-muted`, text `--text-secondary`, hover `--text-secondary` border + `--text-primary` text | | |
| 13 | token | sso-form.tsx:283, 296, 304 | sign-up link `--text-primary`; legal links `--text-muted` → `--text-primary` | | |
| 14 | state | sso/page.tsx:15-17 | SSO off ⇒ `/login` | | |
| 15 | state | sso-form.tsx:25-35, 60-65 | `?error` code → message table; unknown code → generic | | |
| 16 | state | sso-form.tsx:71, 95 | `?email` pre-fill | | |
| 17 | state | sso-form.tsx:108-117 | `callbackUrl` validated; invalid logged and replaced by `/home` | | |
| 18 | state | sso-form.tsx:37-51, 138-145 | email errors under the field after submit; cleared on typing | | |
| 19 | state | sso-form.tsx:157-160 | 404 → "No SSO provider is configured…" (or the test-link copy when `?provider`) | | |
| 20 | state | sso-form.tsx:177-186 | sign-in failure → "Unable to start SSO…" | | |
| 21 | state | sso-form.tsx:250 | in flight: "Redirecting to SSO provider…" | | |
| 22 | state | sso-form.tsx:255, 278 | email disabled hides divider/button/prompt; registration disabled hides prompt | | |
| 23 | interaction | sso-form.tsx:69 | form remounts (state reset) when the query string changes | | |
| 24 | interaction | sso-form.tsx:268, 282 | links carry `callbackUrl` (encoded) | | |
| 25 | keyboard | sso-form.tsx:208 | Enter submits | | |
| 26 | network | sso-form.tsx:151-155; resolve/route.ts | `POST /api/auth/sso/resolve` `{email, providerId?}` → `{providerId}` | | |
| 27 | network | sso-form.tsx:165-175 | `POST /api/auth/sign-in/sso` `{email, providerId, callbackURL, errorCallbackURL}` then top-level navigation to `url` | | |
| 28 | network | launch/route.ts:26-89 | launch route stays server-side; Flutter handles its landings `/home` and `/sso?…` — verified-by-review | | |
| 29 | state | sso-form.tsx:164 | PostHog `external_sign_in_started` — hosted-only, verified-by-review | | |

Colour anchors: `auth.shell @ (8,8)` → #fefefe · `auth.sso.email @ (3,17)` → `--surface-5` #f3f3f3 · `auth.sso.email @ (0,17)` → `--border-1` #d8d8d8 · `auth.sso.submit @ (6,18)` → `--text-primary` #1a1a1a · `auth.sso.emailLink @ (0,16)` → `--text-muted` #7a7a7a (1 px border) and `@ (6,16)` → #fefefe · `auth.sso.divider @ (2,10)` → `--border` #d8d8d8.
