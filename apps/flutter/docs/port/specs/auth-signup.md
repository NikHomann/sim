# Signup
Upstream: `apps/sim/app/(auth)/signup/**` (+ shared `app/(auth)/components/**`, `app/(auth)/layout.tsx`), commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

Shares the shell, field, button, divider, social, SSO, nav-prompt, legal and skeleton components with `auth-login.md`; their measurements and tokens are not repeated here, only the differences.

## Files
| File | Lines | Role |
|---|---|---|
| `app/(auth)/signup/page.tsx` | 50 | Server page: `isRegistrationDisabled` branch → `RegistrationDisabled`; else provider status, `emailSignupEnabled = !isEmailSignupDisabled`, `emailVerificationEnabled = isEmailVerificationEffectivelyEnabled()` → `SignupForm`; `force-dynamic` |
| `app/(auth)/signup/signup-form.tsx` | 533 | The form (client): name/email/password validation, Turnstile, `client.signUp.email`, post-signup routing |
| `app/(auth)/signup/registration-disabled.tsx` | 31 | "Account creation is disabled" page |
| `app/(auth)/signup/search-params.ts` | 23 | nuqs server parsers `redirect`, `callbackUrl`, `invite_flow` |
| `app/(auth)/signup/loading.tsx` | 20 | Route skeleton |
| `app/(auth)/auth-redirect.ts` | 118 | `resolveAuthRedirect` (`redirect` wins over `callbackUrl`; `/invite/` prefix implies invite flow), `resolvePostSignupDestination`, `VERIFY_FROM_SIGNUP_ROUTE = '/verify?fromSignup=true'`, `POST_AUTH_REDIRECT_STORAGE_KEY = 'postAuthRedirectUrl'` |
| `lib/messaging/email/verification.ts` | 15 | `isEmailVerificationEffectivelyEnabled = EMAIL_VERIFICATION_ENABLED && hasEmailService()` |
| `lib/core/config/env-flags.ts` | 235, 653 | `isRegistrationDisabled` (`DISABLE_REGISTRATION`), `isEmailSignupDisabled` (`DISABLE_EMAIL_SIGNUP`) |
| `app/api/auth/providers/route.ts` | 34 | `GET /api/auth/providers`: carries the page's server props for Flutter — `emailSignupEnabled` (`!isEmailSignupDisabled`), `emailVerificationEnabled` (`isEmailVerificationEffectivelyEnabled()`), `ssoEnabled` (`isSsoEnabled`) next to the four original booleans (contract `lib/api/contracts/auth.ts:11-31`) |
| `lib/auth/auth.ts` | 914-915, 1375-1382, 1099-1101 | `disableSignUp: isEmailSignupDisabled`, `requireEmailVerification`, Turnstile `captcha` plugin on `/sign-up/email` when `TURNSTILE_SECRET_KEY`, 403 "Registration is disabled, please contact your admin." on `/sign-up*` when `DISABLE_REGISTRATION` |
| `@marsidev/react-turnstile` | | `Turnstile` widget, `execution: 'execute'`, `appearance: 'execute'` (invisible until executed) |
| Hooks | | `useSession().refetch`, `usePostHog`, `useTrackingConsent`, `useCaptureWhenReady('signup_page_viewed')` (hosted/consent) |

## Layout
Same `AuthShell` and 400 px column as login. Column (`signup-form.tsx:407-509`), `space-y-6`:
1. `auth.signup.header`: title "Create an account" (32 px / 1.2), description "Create an account or log in" (15 px / 1.5 `--text-muted`) (`:408`).
2. `auth.signup.ssoTop`: primary SSO chip, only `hasOnlySSO` (`:410-412`).
3. `auth.signup.form` `space-y-6` (`:415`), fields `space-y-5` (`:416`):
   - `auth.signup.name.field` / `auth.signup.name`: label "Full name", `AuthInput type='text' autoCapitalize='words' autoComplete='name'`, placeholder "Enter your name", `title` tooltip "Name can only contain letters, spaces, hyphens, and apostrophes" (`:417-430`). 400×36.
   - `auth.signup.email.field` / `auth.signup.email`: label "Email", placeholder "Enter your email"; initial value from `?email=` (`:121`) (`:431-443`).
   - `auth.signup.password.field` / `auth.signup.password`: label "Password", `PasswordInput autoComplete='new-password'`, placeholder "Enter your password" (`:444-456`). No "Forgot password?" action.
   - `auth.signup.turnstile`: `Turnstile` only when `NEXT_PUBLIC_TURNSTILE_SITE_KEY` is set (`:127, 459-465`); `appearance: 'execute'` renders nothing until `execute()` is called, so no box in the layout in the normal case (an interactive challenge, if Cloudflare demands one, appears as the widget's own iframe at this position between the fields and the submit, inside the 24 px form gap).
   - `auth.signup.formError`: `AuthFormMessage type='error'` 12 px `--text-error`, only for the captcha failure (`:467-471`).
   - `auth.signup.submit`: "Create account" / "Creating account…" (`:473-479`).
4. `auth.signup.divider` "Or continue with" (`:483`).
5. `auth.signup.social` (`view='signup'`) with `auth.signup.social.google|microsoft|github` and `auth.signup.sso` outline child (`:485-500`).
6. `auth.signup.loginPrompt` "Already have an account?" + `auth.signup.loginLink` `ChipLink` "Sign in" → `buildAuthCrossLink('/login', { callbackUrl: redirectUrl || null, isInviteFlow })` (`:502-506`). Always rendered (unlike login's prompt).
7. `auth.signup.legal` "By creating an account, you agree to our Terms of Service and Privacy Policy" (`:508`).

Column height (3 fields, 3 social + SSO): 65 + 24 + (57×3 + 20×2 + 24 + 36) + 24 + 20 + 24 + 180 + 24 + 30 + 24 + 20 ≈ 779 px.

`RegistrationDisabled` (`registration-disabled.tsx:68-80`) — parity `auth.signup.disabled`: `space-y-6`: `AuthHeader` title "Account creation is disabled", description "Ask your admin to create an account for you."; `AuthNavPrompt` "Already have an account?" + `ChipLink` "Sign in" → `/login` with `invite_flow`/`callbackUrl` carried over (`page.tsx:23-36`).

Suspense fallback inside the form (`:520-532`): `div.flex.min-h-[320px].items-center.justify-center` with the text "Loading…" (plain, inherits 16 px? No: inherits the body `text-sm`? It has no size class, so it renders at the shell's inherited size, which is the browser default 16 px in Season Sans). Route skeleton (`signup/loading.tsx:12-24`) — parity `auth.signup.loading`: title 100×38; three fields (label widths 40, 40, 64) at `mt-8`, `mt-4`, `mt-4`; control `mt-6`; divider + two controls; label 220×14 `mt-6`.

## Tokens
As login. Additional: none. Name field has no special chrome. Turnstile iframe is third-party content (not themed).

## States
Inputs (React server props → Flutter: `GET /api/auth/providers` for `githubAvailable|googleAvailable|microsoftAvailable|registrationDisabled` plus the server-only props `emailSignupEnabled` (`!DISABLE_EMAIL_SIGNUP`, `page.tsx:46`), `emailVerificationEnabled` (`EMAIL_VERIFICATION_ENABLED && hasEmailService()`, `page.tsx:47`) and `ssoEnabled` (`isSsoEnabled`); `GET /api/public-env` for `NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED`, `NEXT_PUBLIC_SSO_ENABLED`, `NEXT_PUBLIC_TURNSTILE_SITE_KEY`). The three extra fields are optional booleans on the contract (`lib/api/contracts/auth.ts:11-31`, route `providers/route.ts:28-31`): treat an absent `emailSignupEnabled` as `true` (the page's default when `DISABLE_EMAIL_SIGNUP` is unset) and an absent `emailVerificationEnabled` as `false`.

`emailEnabled = !isFalsy(NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED) && emailSignupEnabled` (`:388-389`); `hasOnlySSO`, `showBottomSection`, `showDivider` as login (`:390-393`).

| State | Rendering |
|---|---|
| `registrationDisabled` | whole page replaced by `RegistrationDisabled` (`page.tsx:23-37`); social sign-in for unknown identities is also refused server-side (`lib/auth/constants.ts:85-97`) and ends on `/oauth-error?error=signup_disabled` |
| Loading | route skeleton; inner Suspense "Loading…" box 320 px tall |
| Default | header, 3 fields, submit, divider, social + SSO, login prompt, legal |
| Email signup disabled (`DISABLE_EMAIL_SIGNUP` or public flag falsy) | no form; the rest as login's matrix; login prompt still shown |
| Name errors (after submit) | "Name is required." / "Name cannot be empty." (early return) / "Name can only contain letters, spaces, hyphens, and apostrophes." (regex `^[\p{L}\s\-']+$`u on the trimmed value) / "Name cannot contain consecutive spaces." (`:59-76, 171-193`); plus "Name will be truncated to 100 characters. Please shorten your name." when trimmed length > 100 (`:261-266`) |
| Email errors | as login's `validateEmailField` (lower-cased, trimmed, `:78-92`); plus server `emailError` line (`USER_ALREADY_EXISTS` → "An account with this email already exists. Please sign in instead."; `BAD_REQUEST` or message "Email and password sign up is not enabled" → "Failed to create account"; `INVALID_EMAIL` → "Failed to create account") shown while no client validation error is displayed (`:396-402`), cleared on the next keystroke (`:221-223`); the border is red for either (`:441`) |
| Password errors | every failing rule is listed at once (not early-return): "Password must be at least 8 characters long." (`/.{8,}/`), "…include at least one uppercase letter." (`[A-Z]`), "…lowercase letter." (`[a-z]`), "…one number." (`[0-9]`), "…one special character." (`[#?!@$%^&*-]`) (`:42-57, 145-169`). Shown only after submit; cleared on the next keystroke (`:195-202`). Server: `PASSWORD_TOO_SHORT` → ["Failed to create account", "Password must be at least 8 characters long."], `PASSWORD_TOO_LONG` → [... "Password must be less than 128 characters long."], code contains "network" → network line, code contains "rate limit" → "Too many requests. Please wait a moment before trying again.", anything else → ["Failed to create account"] (`:296-341`) |
| Captcha failure | `auth.signup.formError` "Captcha verification failed. Please try again." (`:276-281`) |
| Submitting | submit disabled, "Creating account…" (`:473-479`) |
| Submit disabled | until `name.trim()`, `email.trim()` and `password` are non-empty (`:404`) |
| Success, verification enforceable | `sessionStorage.verificationEmail = email`, `postAuthRedirectUrl = redirectUrl` (if any), `router.push('/verify?fromSignup=true')` (`:360-375`) |
| Success, verification not enforceable | `window.location.href = redirectUrl || '/home'` (`:376-380`) |
| Signed-in visitor | proxy sends `/signup` → `/home` when a cookie exists (same rule and OAuth exception as login, `proxy.ts:382-395`) |
| Hosted-only | Turnstile (needs `NEXT_PUBLIC_TURNSTILE_SITE_KEY` + `TURNSTILE_SECRET_KEY`), PostHog `signup_page_viewed` / `signup_failed {error_code}` (`:115, 276, 340`), Google `sign_up` and Freebuff conversions under consent (`:350-351`) — verified by review |

## Interactions
- Name/email/password typing: validate-on-change but errors only surface after a submit (`:195-224`).
- Submit (`Enter` in any field or click): `e.preventDefault()`; reads `FormData` (`:230-234`); validates name (trimmed), email (trimmed, lower-cased), password; shows all three error lists; stops on any error or on name > 100 (`:236-266`). Then, if a site key is configured, `widget.reset(); widget.execute(); token = await widget.getResponsePromise()` (`:268-283`); then the request.
- After success: `refetchSession()` (`GET /api/auth/get-session`) before deciding the destination (`:353-358`); clears `verificationEmail` and `postAuthRedirectUrl` from sessionStorage first (`:362-366`).
- Social / SSO: as login, with `callbackURL = redirectUrl || '/home'` (`:411, 491, 495`).
- "Sign in" link: client navigation to `/login[?invite_flow=true][&callbackUrl=…]`.
- Query handling (`:128-139`): `redirect` wins over `callbackUrl`; `invite_flow=true` or a destination starting with `/invite/` marks the invite flow; the destination is kept only when `validateCallbackUrl` passes (else logged once and dropped). `email` pre-fills the email field (`:121`).
- Focus order: logo → name → email → password → eye → Create account → social → SSO → Sign in → Terms → Privacy.

## Network and realtime
1. (F) `GET /api/public-env`, `GET /api/auth/providers` (as login; here `emailSignupEnabled`, `emailVerificationEnabled`, `ssoEnabled` are read as well), `GET /api/auth/get-session`.
2. Submit: `POST /api/auth/sign-up/email`, JSON `{ email, password, name }` (`:286-291`), header `x-captcha-response: <turnstile token>` when a token was obtained (`:293-295`; the server `captcha` plugin verifies it only when `TURNSTILE_SECRET_KEY` is set, `auth.ts:1375-1382`). Success 200 `{ token, user: { id, … } }` (session cookie set when verification is not required; with `requireEmailVerification` Better Auth creates the user and returns `token: null`, which is why the page continues to `/verify`). Errors: 403 "Registration is disabled, please contact your admin." (`auth.ts:1099-1101`); 422/400 `USER_ALREADY_EXISTS`, `INVALID_EMAIL`, `PASSWORD_TOO_SHORT` (< 8), `PASSWORD_TOO_LONG` (> 128, Better Auth defaults); 403 "Sign-ups from this email domain are not allowed." (MX check, `auth.ts:1127-1140`); 403 allowlist / access-control refusals (`:1099-1123`); 400 `BAD_REQUEST` when email sign-up is disabled (`disableSignUp`, `auth.ts:914`) → "Failed to create account" on the email field. Captcha failure → Better Auth captcha error (shown as the generic "Failed to create account" line since no branch matches).
3. `GET /api/auth/get-session` (refetch, `:354`).
4. Destination: `resolvePostSignupDestination({ emailVerificationEnabled, redirectUrl })` (`auth-redirect.ts:43-49`): verification enabled → `/verify?fromSignup=true` (client navigation); else `redirect` → full navigation to `redirectUrl`; else `/home`. Flutter takes `emailVerificationEnabled` from `GET /api/auth/providers` (step 1), the same `isEmailVerificationEffectivelyEnabled()` value the React page receives, so the routing decision matches React without inferring it from the sign-up response.
5. Social: `POST /api/auth/sign-in/social` `{ provider, callbackURL }` (as login).
No socket, no invalidations.

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | signup-form.tsx:407-408 | 400 px column, 24 px stack; title "Create an account", description "Create an account or log in" | | |
| 2 | layout | signup-form.tsx:416-456 | three 57 px fields with 20 px gaps, labels "Full name", "Email", "Password" | | |
| 3 | layout | signup-form.tsx:418-429 | name input `type=text`, placeholder "Enter your name", `title` tooltip text | | |
| 4 | layout | signup-form.tsx:473-479 | submit 400×36 "Create account" | | |
| 5 | layout | signup-form.tsx:483-500 | divider + social grid (gap 12) + SSO outline as login | | |
| 6 | layout | signup-form.tsx:502-506 | "Already have an account?" + 30 px "Sign in" chip, always present | | |
| 7 | layout | signup-form.tsx:508 | legal line "By creating an account, …" | | |
| 8 | layout | signup/loading.tsx:14-22 | skeleton: title 100×38, three fields, control, divider pair, label 220×14 | | |
| 9 | layout | registration-disabled.tsx:68-80 | disabled page: header copy + "Sign in" chip, nothing else | | |
| 10 | layout | signup-form.tsx:520-523 | inner fallback: 320 px tall centred "Loading…" | | |
| 11 | token | as login #15-#20 | same tokens; name field uses the chip input tokens | | |
| 12 | token | signup-form.tsx:441, 396 | email border red for server `emailError` as well as client errors | | |
| 13 | state | signup/page.tsx:23-37 | `registrationDisabled` replaces the page; `callbackUrl`/`invite_flow` carried to `/login` | | |
| 14 | state | signup-form.tsx:388-393, 410-500; providers/route.ts:28, 31 | visibility matrix incl. `emailSignupEnabled` and `ssoEnabled` (from `GET /api/auth/providers`) and the public flag | | |
| 15 | state | signup-form.tsx:42-57, 145-169 | all failing password rules listed at once, in rule order | | |
| 16 | state | signup-form.tsx:59-76, 171-193, 261-266 | name rules incl. unicode letters, consecutive spaces, >100 chars | | |
| 17 | state | signup-form.tsx:78-92 | email rules; value trimmed + lower-cased before validation and submit | | |
| 18 | state | signup-form.tsx:195-224 | errors appear on submit, vanish on next keystroke; server `emailError` cleared on typing | | |
| 19 | state | signup-form.tsx:301-338 | server error mapping (`USER_ALREADY_EXISTS` on email; `PASSWORD_TOO_*` on password; default "Failed to create account") | | |
| 20 | state | signup-form.tsx:268-283, 467-471 | captcha failure line; hosted-only (site key) — verified-by-review | | |
| 21 | state | signup-form.tsx:404, 473-479 | submit disabled until three fields filled; "Creating account…" in flight | | |
| 22 | state | signup-form.tsx:121 | `?email=` pre-fills the email field | | |
| 23 | interaction | signup-form.tsx:128-139; auth-redirect.ts:71-80 | `redirect` beats `callbackUrl`; `/invite/` prefix ⇒ invite flow; invalid dropped | | |
| 24 | interaction | signup-form.tsx:504 | "Sign in" link = `buildAuthCrossLink('/login', {callbackUrl, isInviteFlow})` | | |
| 25 | interaction | signup-form.tsx:411, 491-497 | social and SSO use `redirectUrl || '/home'` as callback | | |
| 26 | keyboard | signup-form.tsx:415 | Enter in any field submits | | |
| 27 | network | signup-form.tsx:286-295 | `POST /api/auth/sign-up/email` `{email, password, name}` + optional `x-captcha-response` | | |
| 28 | network | signup-form.tsx:353-358 | `GET /api/auth/get-session` refetched after success before routing | | |
| 29 | network | signup-form.tsx:360-380; auth-redirect.ts:43-49; providers/route.ts:29 | verify hop when `emailVerificationEnabled` (from `GET /api/auth/providers`) is true (sessionStorage keys set); else full navigation to destination | | |
| 30 | network | auth.ts:1099-1101; constants.ts:85-97 | 403 "Registration is disabled…" on the API; social sign-up refused → `/oauth-error?error=signup_disabled` | | |
| 31 | state | signup-form.tsx:115, 276, 340, 350-351 | PostHog / Google / Freebuff events — hosted-only, verified-by-review | | |

Colour anchors: `auth.shell @ (8,8)` → #fefefe · `auth.signup.name @ (3,18)` → `--surface-5` #f3f3f3 · `auth.signup.name @ (0,18)` → `--border-1` #d8d8d8 · `auth.signup.submit @ (6,18)` → `--text-primary` #1a1a1a · `auth.signup.social.google @ (392,18)` → #fefefe · `auth.signup.divider @ (2,10)` → `--border` #d8d8d8.
