# Login
Upstream: `apps/sim/app/(auth)/login/**`, `apps/sim/app/(auth)/layout.tsx`, `apps/sim/app/(auth)/components/**`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

All paths below are relative to `apps/sim/` unless they start with `packages/`. Tailwind v4 default scale (4 px unit) and the tokens in `02-design-system.md` §1 apply. Light values are the only ones that matter here: the page pins the `light` token layer (see Tokens).

## Files
| File | Lines | Role |
|---|---|---|
| `app/(auth)/layout.tsx` | 16 | Wraps every `(auth)` route in `AuthShell`; mounts `AttributionCapture` (consent/analytics, hosted-only); `robots: noindex` |
| `app/(auth)/login/page.tsx` | 27 | Server page: `getOAuthProviderStatus()` + `isRegistrationDisabled` → props; `Suspense` fallback `LoginLoading`; `dynamic = 'force-dynamic'` |
| `app/(auth)/login/login-form.tsx` | 507 | The form (client). State, validation, `client.signIn.email`, forgot-password modal |
| `app/(auth)/login/loading.tsx` | 19 | Route skeleton |
| `app/(auth)/auth-redirect.ts` | 118 | `DEFAULT_POST_AUTH_ROUTE` (`/home`), `resolveAuthRedirect`, `buildAuthCrossLink`, `isOAuthAuthorizationCallback` |
| `app/(auth)/components/auth-shell.tsx` | 52 | Light page frame: logo header + centred 400 px column |
| `app/(auth)/components/auth-header.tsx` | 23 | Title + description block |
| `app/(auth)/components/auth-field.tsx` | 41 | Label row + control + error list |
| `app/(auth)/components/auth-input.tsx` | 20 | `ChipInput` at 36 px |
| `app/(auth)/components/password-input.tsx` | 37 | `ChipInput` with eye toggle |
| `app/(auth)/components/auth-submit-button.tsx` | 47 | Full-width primary `Chip` with spinner |
| `app/(auth)/components/social-login-buttons.tsx` | 78 | Google / Microsoft / GitHub chips |
| `app/(auth)/components/sso-login-button.tsx` | 43 | "Sign in with SSO" chip (gated by `isSsoEnabled`) |
| `app/(auth)/components/auth-divider.tsx` | 21 | "Or continue with" rule |
| `app/(auth)/components/auth-nav-prompt.tsx` | 27 | "Don't have an account? [Sign up]" |
| `app/(auth)/components/auth-legal-footer.tsx` | 26 | Terms / Privacy fine print |
| `app/(auth)/components/auth-text-link.tsx` | 57 | Inline link / button affordance |
| `app/(auth)/components/auth-form-message.tsx` | 28 | Form-level error / success copy |
| `app/(auth)/components/auth-loading-skeleton.tsx` | 58 | Skeleton shapes shared by the auth `loading.tsx` files |
| `app/(auth)/components/constants.ts` | 17 | `AUTH_CONTROL_HEIGHT = 'h-9'`, `AUTH_BUTTON_CLASS` |
| `app/(auth)/components/oauth-provider-checker.tsx` | 19 | Server: provider availability from env |
| `lib/auth/client.ts` | 70 | Better Auth browser SDK (`client.signIn.email`, `client.signIn.social`) |
| `lib/auth/social-sign-in.ts` | 29 | `startSocialSignIn` (PostHog capture + `client.signIn.social`) |
| `lib/core/security/input-validation.ts` | 932–943 | `validateCallbackUrl`: same-origin check |
| `lib/messaging/email/validation.ts` | 66–127 | `quickValidateEmail` reasons |
| `lib/api/contracts/user.ts` | 200–229 | `forgetPasswordContract` |
| `app/api/auth/forget-password/route.ts` | 93 | Forgot-password route (rate limits, enumeration-safe) |
| `app/api/auth/providers/route.ts` | 34 | `GET /api/auth/providers` (the client-side replacement for the server props; also carries `ssoEnabled`, `emailSignupEnabled`, `emailVerificationEnabled`, `emailServiceConfigured`, `isProd` for the other auth pages) |
| `proxy.ts` | 382–401 | `/login` redirect to `/home` when a session cookie exists |
| `app/_shell/providers/theme-provider.tsx` | 16–31, 70 | Forced light theme for `login` |
| emcn | | `Chip`, `ChipLink` (`packages/emcn/src/components/chip/chip.tsx`, `chrome.ts`), `ChipInput` (`chip-input/chip-input.tsx`), `Label` (`label/label.tsx`), `ChipModal*` (`chip-modal/chip-modal.tsx`), `Modal` (`modal/modal.tsx`), `Skeleton`, `Loader` (`icons/loader.tsx`), `SimWordmark` (`sim-wordmark/sim-wordmark.tsx`); landing `LogoMark` (`app/(landing)/components/navbar/components/logo-mark/logo-mark.tsx`) |

Hooks: `useSearchParams`, `useRouter`, `useCaptureWhenReady('login_page_viewed')` (`hooks/use-capture-when-ready.ts`, PostHog, hosted/consent-gated). No zustand store. No socket.

## Layout
Viewport assumptions: 1440×900 and 1280×800, no desktop title bar (`--desktop-title-bar-height: 0px`, `globals.css:406`), so `.desktop-title-bar-page` is exactly `min-h-screen` (`globals.css:509-516`).

### Shell (`auth-shell.tsx:35-50`) — parity `auth.shell`
- Root `div.light.desktop-title-bar-page.relative.flex.flex-col`, `bg --bg`, `color --text-primary`, min-height 100 vh.
- `auth.shell.header`: `<header><nav>` `mx-auto w-full max-w-[1446px] px-12 py-4` → padding 16 px top/bottom, 48 px left/right at ≥1024 px (32 px below `lg`, 20 px below `sm`); content height 30 px (`a.flex.h-[30px]`) → header box 62 px tall.
- `auth.shell.logo`: `<a href='/' aria-label='Sim home'>` 30 px tall; inside `LogoMark` (`logo-mark.tsx:34-68`, inline-flex, hover: scale 1.08 over 150 ms cubic-bezier(.23,1,.32,1), wordmark fades to 0 over 100 ms and a 28 px `ThinkingLoader` appears behind it) wrapping `SimWordmark` size `nav`: SVG 37×18 px, `-translate-y-[1.5px]`, fill `--text-body` (`sim-wordmark.tsx:11, 29-43`). Logo left edge at x = 48 px, vertical centre at y = 16 + 15 = 31 px (wordmark drawn 1.5 px above that).
- `auth.shell.column` container: `div.flex.flex-1.items-center.justify-center.px-4.pb-16` → remaining height (viewport − 62 px), the column is centred vertically inside that box minus the 64 px bottom padding (i.e. centre of content = 62 + (H − 62 − 64)/2). Inner `div.w-full.max-w-[400px]` → column width 400 px at both viewports, x = (W − 400)/2 (520 at 1440, 440 at 1280).
- `footer` slot unused on `/login` (`auth-shell.tsx:49`).

### Column (`login-form.tsx:376-465`) — parity `auth.login.root`
Vertical stack `space-y-6` → 24 px between each direct child, in this order (children only present under the conditions in States):
1. `auth.login.header` (`AuthHeader`, `auth-header.tsx:16-21`): `space-y-1` (4 px), `text-center`. `auth.login.title` `<h1>` "Sign in": 32 px, line-height 1.2 (38.4 px), weight 400, `--text-primary`, `text-balance`. `auth.login.description` `<p>` "Enter your details": 15 px (`--text-base`, `globals.css:104`), line-height 1.5 (22.5 px), `--text-muted`. Block height 38.4 + 4 + 22.5 ≈ 65 px.
2. `auth.login.ssoTop` (only `hasOnlySSO`): `SSOLoginButton variant='primary'` (see 7).
3. `auth.login.form` `<form class='space-y-6'>` (`login-form.tsx:382`):
   - `auth.login.fields` `div.space-y-5` (20 px gap, `:383`):
     - `auth.login.email.field` (`AuthField`, `auth-field.tsx:26-39`): `space-y-2` (8 px). Label row `flex items-center justify-between`: `auth.login.email.label` `Label` "Email" — 13 px (`--text-small`), `leading-none`, `--text-primary`, `inline-flex items-center` (`label.tsx:28`) → row height 13 px. Control `auth.login.email` (`AuthInput` = `ChipInput` + `h-9`, `auth-input.tsx:16`, `constants.ts:8`): wrapper `flex w-full h-[36px] items-center gap-1.5 px-2 rounded-lg border border-[var(--border-1)] bg-[var(--surface-5)]` (`chip-input.tsx:69-78`, `chrome.ts:9, 19, 21, 58`) → 400×36 px, radius 8 px (`--radius` 0.5 rem, `globals.css:1371`), 1 px border, 8 px horizontal padding; inner `<input>` `-ml-1 indent-1 size-full bg-transparent`, 14 px (`text-sm`), `--text-body`, placeholder "Enter your email" in `--text-muted`, no focus ring (`chrome.ts:41-42`). Field height 13 + 8 + 36 = 57 px (+ error list when shown: 8 px gap + n × 18 px lines, 12 px `text-caption` in `--text-error`, `space-y-1` 4 px between lines, `auth-field.tsx:33-37`).
     - `auth.login.password.field`: same, label "Password"; label row also contains `auth.login.forgot` (`AuthTextLink` as `<button type='button'>`, `auth-text-link.tsx:48-55`): "Forgot password?" 12 px (`text-caption`, `login-form.tsx:405`), `--text-secondary`, `underline-offset-4`, hover `--text-primary` + underline, right-aligned by `justify-between`. Control `auth.login.password` (`PasswordInput`, `password-input.tsx:20-35`): the same 36 px chip input, `type=password|text`, placeholder "Enter your password", `endAdornment` = `auth.login.password.toggle` `<button type='button' aria-label='Show password'|'Hide password'>` holding `Eye`/`EyeOff` at 14×14 px, `--text-icon`, hover `--text-primary` (`password-input.tsx:26-34`). The icon sits at the right inside the 8 px padding (right edge of icon at x = 400 − 8 − 1 = 391 px from the field's left edge).
   - `auth.login.policyError` (`AuthFormMessage type='error'`, `auth-form-message.tsx:18-26`): `space-y-1 text-caption` 12 px, `--text-error`, left-aligned, only when `policyError` (`login-form.tsx:426-430`).
   - `auth.login.resetSuccess` (`AuthFormMessage type='success'`): 12 px, `--brand-accent` (#33c482), text "Password reset successful. Please sign in with your new password." (`:432-436`, `:132-136`).
   - `auth.login.submit` (`AuthSubmitButton`, `auth-submit-button.tsx:29-45`): `Chip variant='primary' fullWidth type='submit'` + `AUTH_BUTTON_CLASS` (`h-9 justify-center [&>span]:flex-none`, `constants.ts:17`) → 400×36 px, radius 8 px, `bg --text-primary`, label `--text-inverse` 14 px centred (label span is `flex-none` so icon+label truly centre), hover `bg --text-body`; disabled `opacity-60 cursor-not-allowed` (`chip.tsx:66`). Loading content: `span.flex.items-center.gap-2` with `Loader` 16×16 (`size-4`, stroke 1.55, spinning 1 s) and text "Signing in…" (`auth-submit-button.tsx:37-42`).
4. `auth.login.divider` (`AuthDivider`, `auth-divider.tsx:10-20`, only `showDivider`): relative box whose height is one 14 px/20 px line; an absolutely-centred 1 px `border-t --border` rule at y = 10; label "Or continue with" 14 px `--text-muted` on a `bg --bg` chip with `px-4` (16 px) that knocks the rule out behind it.
5. `auth.login.social` (`SocialLoginButtons`, `social-login-buttons.tsx:62-76`, only `showBottomSection`): `div.grid.gap-3` (12 px) of `Chip fullWidth leftIcon` in the fixed order Google, Microsoft, GitHub (`:24-28`), each filtered by availability: `auth.login.social.google`, `auth.login.social.microsoft`, `auth.login.social.github`. Chip default variant (transparent, hover `bg --surface-hover`) + `AUTH_BUTTON_CLASS` + `border border-[var(--border)]` (`:68`) → 400×36 px, radius 8 px, 1 px `--border`; icon 16×16 (`chipContentIconClass`, `chrome.ts:68`; brand SVGs keep their own fills), gap 6 px, label 14 px `--text-body`; icon+label cluster centred. Label is "Connecting…" for the provider in flight (`:72`); all three disabled while any is in flight (`:69`).
   - `auth.login.sso` (`SSOLoginButton variant='outline'`, as the grid's last child, `login-form.tsx:454-456`, `sso-login-button.tsx:30-41`): same chip geometry, `border border-[var(--border-1)]`, label "Sign in with SSO".
6. `auth.login.signupPrompt` (`AuthNavPrompt`, `auth-nav-prompt.tsx:20-25`, only `emailEnabled && !registrationDisabled`): `flex items-center justify-center gap-1 text-sm` (4 px gap): span "Don't have an account?" 14 px `--text-muted`; `auth.login.signupLink` = `ChipLink` default variant + `border border-[var(--border-1)]`: 30 px tall (`chrome.ts:58`), radius 8 px, `px-2`, label "Sign up" 14 px `--text-body`, hover `--surface-hover`, inline-flex (width = 16 + text).
7. `auth.login.legal` (`AuthLegalFooter`, `auth-legal-footer.tsx:14-25`): `<p>` centred, 12 px `text-caption`, `leading-relaxed` (1.625 → 19.5 px), `--text-muted`: "By signing in, you agree to our Terms of Service and Privacy Policy"; the two links are `AuthTextLink external` (`--text-secondary`, hover `--text-primary` underline, `target=_blank rel=noopener noreferrer`, `auth-text-link.tsx:36-43`) to `/terms` and `/privacy` (`auth.login.legal.terms`, `auth.login.legal.privacy`).

Total column height with email enabled, three social + SSO, divider and prompt: 65 + 24 + (57 + 20 + 57 + 24 + 36) + 24 + 20 + 24 + (36×4 + 12×3) + 24 + 30 + 24 + 20 ≈ 701 px (no error rows). The column is centred, so at 900 px tall the top of the title is near y = 62 + (900 − 62 − 64 − 701)/2 ≈ 98 px.

### Forgot-password modal (`login-form.tsx:467-504`) — parity `auth.login.forgotModal`
`ChipModal size='md'` (default, `chip-modal.tsx:276`): overlay `fixed inset-0 z-[var(--z-modal)]` (200, `globals.css:443`) `bg-black/10 backdrop-blur-[2px]` (`modal.tsx:421`); content centred, `w-[90vw] max-w-[500px]` (`modal.tsx:454`), `max-h-[84vh]`, enter `zoom-in-95` 200 ms (`modal.tsx:627-631`). Surface (`chip-modal.tsx:234-243`): outer `rounded-xl` (12 px) `border --border-muted` (= `--border`) `bg --surface-4` `p-[3px]`; inner `rounded-lg border --border-1 bg --bg`.
- `auth.login.forgotModal.header` (`chip-modal.tsx:336-356`): `px-4 pt-3`, title "Reset Password" 14 px `--text-body`, close `X` 14 px `--text-icon` (ghost `Button`), then separator `h-px bg --border` with `mt-3`.
- Body (`:448`): `gap-4 px-2 pt-4 pb-4.5` (16 / 8 / 16 / 18 px): description `<p class='px-2 text-sm text-[var(--text-secondary)]'>` "Enter your email address and we'll send you a link to reset your password if your account exists." (`login-form.tsx:476-479`); `auth.login.forgotModal.email` = `ChipModalField type='email' title='Email' required placeholder='you@example.com'` (label 13 px + 9 px gap + 30 px `ChipInput`, field gutter `px-2`, per `02-design-system.md` §1e); success line `<p class='px-2 text-sm text-[var(--text-secondary)]'>` "Password reset link sent to your email" (`:488-490`); `auth.login.forgotModal.error` = `ChipModalError` `mt-1 px-2 text-caption --text-error` (`chip-modal.tsx:1735`).
- `auth.login.forgotModal.footer` (`chip-modal.tsx:1283-1294, 1341-1380`): separator + `bg --surface-3 px-4 pt-2 pb-2`, right-aligned `gap-2`: `auth.login.forgotModal.cancel` default `Chip` "Cancel" (30 px), `auth.login.forgotModal.submit` primary `Chip` "Send Reset Link" / "Sending…" (30 px).

### Loading skeleton (`login/loading.tsx:8-19`, `auth-loading-skeleton.tsx`) — parity `auth.login.loading`
Column `flex flex-col items-center`; `Skeleton` = `animate-pulse rounded-md bg --surface-active` (`skeleton.tsx:10-12`) with shape overrides (`auth-loading-skeleton.tsx:7-12`): title 80×38 px radius 4; `mt-8` field (label 40×14 r4, 8 px gap, control 400×44 r10); `mt-4` field (label 64×14); `mt-6` control 400×44; `mt-6` divider 400×1 r1; `mt-6` two controls side by side `gap-3` (each (400−12)/2 = 194×44); `mt-6` label 200×14. Note: skeleton controls are 44 px while the real controls are 36 px (`constants.ts:8`): a source fact, not a parity target.

## Tokens
| Element | Token(s) |
|---|---|
| Shell background / text | `--bg` #fefefe, `--text-primary` #1a1a1a (`auth-shell.tsx:35`), `.light` layer pinned so the visitor's dark theme never applies; `theme-provider.tsx:16-31, 70` additionally forces `light` on `<html>` for segment `login` (scrollbars, `color-scheme`, portals) |
| Wordmark | `--text-body` #434343 (`sim-wordmark.tsx:4`) |
| Title / description | `--text-primary`, `--text-muted` #7a7a7a |
| Label | `--text-primary`, 13 px (`--text-small`) |
| Chip input | `--surface-5` #f3f3f3 fill, `--border-1` (= `--border` #d8d8d8, `globals.css:730`) border, `--text-body` text, `--text-muted` placeholder; error border `--text-error` #ef4444 (`chip-input.tsx:74`) |
| Eye toggle | `--text-icon` #5a5a5a → hover `--text-primary` |
| Field errors, policy error | `--text-error` #ef4444, 12 px |
| Reset-success | `--brand-accent` #33c482 |
| Submit (primary chip) | `--text-primary` fill, `--text-inverse` #ffffff text, hover `--text-body` (`chip.tsx:72`, `chrome.ts:16-17`) |
| Social chips | transparent, `--border` border, hover `--surface-hover` #f2f2f2, label `--text-body`, icon slot `--text-icon` |
| SSO outline chip | `--border-1` border, otherwise as social |
| Divider | rule `--border`, label `--text-muted`, knock-out `--bg` |
| Nav prompt | `--text-muted` prompt; `ChipLink` `--border-1`, `--text-body` |
| Text links | `--text-secondary` #525252 → hover `--text-primary` |
| Legal | `--text-muted` |
| Skeleton | `--surface-active` #ececec |
| Modal | overlay rgba(0,0,0,.10) + 2 px blur; ring `--surface-4` #f5f5f5 / `--border-muted`; panel `--bg` / `--border-1`; footer `--surface-3` #f7f7f7; separators `--border` |
| Focus | chip inputs show no ring (`chrome.ts:42`); default chips get `focus-visible:bg --surface-hover` (`chip.tsx:89`) |
| Radii | chips/inputs 8 px (`--radius`), modal ring 12 px, skeleton 4/10/1 px |
| Motion | loader spin 1 s linear; skeleton pulse; modal zoom 200 ms; chip `transition-colors`; LogoMark hover 150 ms |

## States
Inputs the page needs before render (React gets them as server props; Flutter reads them from `GET /api/auth/providers` and `GET /api/public-env`):
- `githubAvailable`, `googleAvailable`, `microsoftAvailable` (`oauth-provider-checker.tsx:8-19`: client id+secret set and not `DISABLE_*_AUTH`).
- `registrationDisabled` = `DISABLE_REGISTRATION` (`login/page.tsx:23`).
- `ssoEnabled` = `isSsoEnabled` (`env-flags.ts:339-343`, enterprise feature; the browser side reads `NEXT_PUBLIC_SSO_ENABLED`). Flutter reads the server-resolved value as `ssoEnabled` on `GET /api/auth/providers` (optional boolean; falls back to `NEXT_PUBLIC_SSO_ENABLED` from `GET /api/public-env` when absent).
- `emailEnabled` = `NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED` not falsy (`login-form.tsx:363`; unset ⇒ enabled).

Derived (`login-form.tsx:362-368`): `hasSocial = github||google||microsoft`; `hasOnlySSO = sso && !email && !hasSocial`; `showTopSSO = hasOnlySSO`; `showBottomSection = hasSocial || (sso && !hasOnlySSO)`; `showDivider = (email || showTopSSO) && showBottomSection`.

| State | Rendering |
|---|---|
| Loading (route) | `LoginLoading` skeleton (`login/page.tsx:18`) |
| Default (email on, all social on, SSO on) | header, form, divider, 3 social + SSO outline, sign-up prompt, legal |
| Email disabled, social on | no form; header, (no divider since `email` false and `showTopSSO` false), social (+SSO), legal; no sign-up prompt (`:460`) |
| SSO only (`hasOnlySSO`) | header, primary SSO chip, legal (`:379`); no divider, no social, no prompt |
| Nothing available | header + legal only |
| `registrationDisabled` | sign-up prompt hidden (`:460`); everything else unchanged |
| `?resetSuccess=true` | green success line above submit until the next submit attempt (`:132-136`, cleared at `:212, 257, 267, 277`) |
| Field validation errors (after submit) | red lines under the field, field border red; cleared on the next keystroke in that field (`:144, 153`) |
| Credentials error | password field shows the server-mapped line(s) (`:219-259`), border red |
| Policy refusal (403 with message) | `auth.login.policyError` under the fields, no field marked (`:210-217`); clears on next submit (`:159`) |
| `EMAIL_NOT_VERIFIED` | no UI; `sessionStorage.verificationEmail = email`, `router.push('/verify')` (`:161-166, 199-203, 282-285`) |
| Submitting | submit disabled, spinner + "Signing in…" (`:438`) |
| Submit disabled | until `email.trim()` and `password` are both non-empty (`:372`) |
| Social in flight | that chip reads "Connecting…", all three disabled (`social-login-buttons.tsx:69-72`) |
| Forgot modal | closed / open / submitting ("Sending…", Cancel disabled, primary disabled) / success (line shown, auto-close after 2000 ms, `:347-350`) / error (`ChipModalError`) |
| Signed-in visitor | never sees the page: proxy redirects `/login` → `/home` when a session cookie exists, except when `callbackUrl` (or `redirect`) is the same-origin `/api/auth/oauth2/authorize` and auth is not disabled (`proxy.ts:382-395`, `auth-redirect.ts:83-91`). Flutter: `GET /api/auth/get-session` on entry; a user → go to entry resolution. |
| Hosted-only | PostHog `login_page_viewed` (`:100`), `external_sign_in_started` (`social-sign-in.ts:27`), `AttributionCapture` (`layout.tsx:13`): verified by review only |
| Captcha | none on login (only signup mounts Turnstile) |
| Desktop title bar | `DesktopTitleBarLane` is a 0-height no-op outside the Electron shell (`auth-shell.tsx:36`, `globals.css:406`) |

Error-line mapping on `client.signIn.email` failure (`login-form.tsx:219-259`; first line is always "Invalid email or password", a second line is appended by the first matching branch, matched with `includes`): code `BAD_REQUEST` or message "Email and password sign in is not enabled" → "Email sign in is currently disabled."; code `INVALID_CREDENTIALS` or message "invalid password" → "Invalid email or password. Please try again."; code `USER_NOT_FOUND` or message "not found" → "No account found with this email. Please sign up first."; `MISSING_CREDENTIALS` → "Please enter both email and password."; `EMAIL_PASSWORD_DISABLED` → "Email and password login is disabled."; `FAILED_TO_CREATE_SESSION` → "Failed to create session. Please try again later."; code contains "too many attempts" → "Too many login attempts. Please try again later or reset your password."; code contains "account locked" → "Your account has been locked for security. Please reset your password."; code contains "network" → "Network error. Please check your connection and try again."; message contains "rate limit" → "Too many requests. Please wait a moment before trying again."; otherwise only the first line. If `onError` did not run but `result.error` is set, the password field shows `result.error.message` or "Login failed. Please try again." (`:264-274`). Ambiguity: Better Auth's own bad-credential code is `INVALID_EMAIL_OR_PASSWORD` with message "Invalid email or password" (not verifiable in this checkout: no `node_modules`); with that payload none of the branches match and the single first line is shown. A 429 from Better Auth's default limiter (active only when `NODE_ENV=production`; `lib/auth/auth.ts` sets no `rateLimit`) carries no code and its message does not contain "rate limit", so it also renders the single line: the "Too many requests" copy only appears if the body message literally contains "rate limit".

## Interactions
- Typing in Email: `setEmail`, re-validates (`validateEmailField`: required → "Email is required."; `quickValidateEmail(normalizeEmail(v))` reasons "Invalid email format" / "Missing domain" / "Disposable email addresses are not allowed" / "Email contains suspicious patterns" / "Invalid domain format", `validation.ts:66-127`) but hides errors until submit (`:138-145`).
- Typing in Password: validates required/non-empty (`:59-84`), hides errors until submit (`:147-154`).
- Eye toggle: toggles `type` between password/text; label flips (`password-input.tsx:17, 27-29`). Does not submit (`type='button'`).
- Submit (`Enter` in either field or click): native form submit (`:382`); sequence in Network. Validation of both fields happens first; any error stops before the request (`:172-183`).
- "Forgot password?": opens the modal (`:404`), initial focus goes to the modal's first text input (`chip-modal.tsx:138-152`). In the modal: `Enter` in the email field fires the primary action (`ChipModalField` email branch), `Escape` / outside click / X / Cancel close it (all refused only when `dismissDisabled`, which login never sets; Cancel is disabled while sending, `:497`). Primary disabled until the field is non-empty (`:501`). Clicking Send with an invalid address shows "Please enter a valid email address" / empty → "Please enter your email address" without a request (`:294-309`).
- Social chip: `startSocialSignIn` → browser leaves for the provider (`social-login-buttons.tsx:46-55`). Failure is only logged; label resets.
- SSO chip: `router.push('/sso?callbackUrl=<encoded>')` (`sso-login-button.tsx:24-27`; always carries the resolved `callbackUrl`, which defaults to `/home`).
- "Sign up": client navigation to `signupHref` = `/signup` + `invite_flow=true` (if `?invite_flow=true`) + `callbackUrl=<validated>` (`:116-119`, `auth-redirect.ts:107-118`).
- Terms / Privacy: new tab.
- Logo: full document navigation to `/` (`auth-shell.tsx:39`).
- Focus order (DOM order): logo → email → "Forgot password?" → password → eye toggle → Sign in → Google → Microsoft → GitHub → SSO → Sign up → Terms → Privacy.
- No keyboard shortcuts, no drag and drop, no context menus.
- Query handling: `callbackUrl` is accepted only if `validateCallbackUrl` passes (`new URL(url, window.location.origin).origin === origin`, `input-validation.ts:932-943`; relative paths pass, other origins fail); an invalid value is logged once and replaced by `/home` (`:107-114`). Login reads only `callbackUrl` (not `redirect`); the proxy and signup accept both (`auth-redirect.ts:75`). `invite_flow=true` only affects the sign-up link. `resetSuccess=true` shows the green line.

## Network and realtime
Flutter replacements for server props are marked (F). Order on a cold load, then per action.
1. (F) `GET /api/public-env` → `NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED`, `NEXT_PUBLIC_SSO_ENABLED`, `NEXT_PUBLIC_APP_URL` (plan §3).
2. (F) `GET /api/auth/providers` → `{ githubAvailable, googleAvailable, microsoftAvailable, registrationDisabled, emailSignupEnabled?, emailVerificationEnabled?, emailServiceConfigured?, ssoEnabled?, isProd? }` (`providers/route.ts:18-34`, contract `lib/api/contracts/auth.ts:11-31, 135-142`). The five optional booleans are the auth pages' server-only props (`!DISABLE_EMAIL_SIGNUP`, `isEmailVerificationEffectivelyEnabled()`, `hasEmailService()`, `isSsoEnabled`, `isProd`); login uses `ssoEnabled`.
3. (F) `GET /api/auth/get-session` → `{ session, user } | null`; a user ⇒ leave for entry resolution (replaces `proxy.ts:390-395`, except the OAuth re-auth case).
4. Submit: `POST /api/auth/sign-in/email`, JSON `{ email: normalizeEmail(email), password, callbackURL: callbackUrl }` (`login-form.tsx:189-194`; `callbackURL` must be same-origin or Better Auth rejects it, `03-api-and-auth.md` §1). Success 200: `Set-Cookie better-auth.session_token` (+ `session_data`), body `{ redirect: false, token, user }`; the client then does `window.location.href = callbackUrl` (`:280`, full document navigation on purpose). Errors: 403 `{ code: 'EMAIL_NOT_VERIFIED', message }` → `/verify`; 403 `{ message }` from the policy hooks (`lib/auth/auth.ts:1099-1159`: registration disabled on sign-up paths, email/password disabled, allowlist/access-control refusals; `lib/auth/session-hooks.ts:32-40`: suspended / blocked account; `lib/auth/sso-policy.ts:109-125`: `{ code: 'SSO_REQUIRED', message: 'Your organization requires single sign-on. Sign in through your identity provider.' }`) → `auth.login.policyError`; 401 bad credentials → field lines; 429 → see States.
5. "Forgot password" send: `POST /api/auth/forget-password` `{ email: forgotPasswordEmail, redirectTo: `${getBaseUrl()}/reset-password` }` (`:316-321`; `redirectTo` must be an absolute same-origin URL, `user.ts:200-215`) → 200 `{ success: true }` whether or not the account exists (`forget-password/route.ts:71, 80-84`); 400 `{ message }` on validation (mapped: "Invalid body parameters"/"invalid email" → "Please enter a valid email address", "Email is required" → "Please enter your email address", "user not found" → "No account found with this email address", `:323-337`); 429 from the IP limiter or the per-recipient bucket (5 per 15 min, `:19-23, 55-60`); 500 `{ message: 'Failed to send password reset email. Please try again later.' }`. `ApiClientError.message` = `body.message ?? body.error` (`03-api-and-auth.md` §2).
6. Social: `POST /api/auth/sign-in/social` `{ provider: 'google'|'microsoft'|'github', callbackURL }` → `{ url, redirect: true }`; the SDK navigates the top-level browser to `url`; the provider returns to `/api/auth/callback/<provider>` which sets the cookie and 302s to `callbackURL` (or to `/oauth-error?error=…` on failure, see `auth-oauth-pages.md`). On Windows the desktop handoff replaces this (plan §3).
7. SSO chip: no request; navigation to `/sso`.
No socket traffic. No cache invalidation (no React Query on this page; the session query is refetched by the destination page after the document navigation).

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | auth-shell.tsx:35-48 | `auth.shell` fills viewport, bg `--bg`; header 62 px (py 16 + 30 content); column 400 px wide, centred, `pb-16` | | |
| 2 | layout | auth-shell.tsx:38-43; sim-wordmark.tsx:11 | `auth.shell.logo` at x=48, 30 px tall; wordmark 37×18, fill `--text-body`, offset −1.5 px | | |
| 3 | layout | auth-header.tsx:16-21 | `auth.login.title` 32 px / 1.2 / 400 centred; description 15 px / 1.5 `--text-muted`; 4 px gap | | |
| 4 | layout | login-form.tsx:376, 382-383 | 24 px between column children; 24 px form gap; 20 px between fields | | |
| 5 | layout | auth-field.tsx:26-30; label.tsx:28 | label row 13 px `leading-none`, 8 px to control; forgot link right-aligned in the same row | | |
| 6 | layout | auth-input.tsx:16; chip-input.tsx:69-78; chrome.ts:58 | `auth.login.email` 400×36, radius 8, border 1 `--border-1`, padding 8, text 14 px | | |
| 7 | layout | password-input.tsx:26-34 | eye toggle 14×14 at right inside padding; `aria-label` flips Show/Hide | | |
| 8 | layout | auth-submit-button.tsx:29-36; constants.ts:17 | `auth.login.submit` 400×36, radius 8, label centred | | |
| 9 | layout | auth-divider.tsx:12-18 | 20 px tall, 1 px rule at mid-height, label on `--bg` with 16 px side padding | | |
| 10 | layout | social-login-buttons.tsx:62-73 | grid gap 12; chips 400×36 with 16 px icons, gap 6, order Google, Microsoft, GitHub | | |
| 11 | layout | auth-nav-prompt.tsx:20-24 | prompt + 30 px `ChipLink`, gap 4, centred | | |
| 12 | layout | auth-legal-footer.tsx:15 | 12 px / 19.5 px line, centred, `--text-muted` | | |
| 13 | layout | login/loading.tsx:10-18; auth-loading-skeleton.tsx:7-12 | skeleton geometry (80×38 r4, 400×44 r10 …) and spacings mt-8/4/6 | | |
| 14 | layout | chip-modal.tsx:234-243; modal.tsx:421, 454 | modal 500 px max, 12 px ring `--surface-4` + 3 px, inner `--bg`; overlay black 10 % + 2 px blur | | |
| 15 | token | auth-shell.tsx:35; theme-provider.tsx:16-31, 70 | page is light regardless of `sim-theme` (`.light` wrapper and forced `<html>` theme) | | |
| 16 | token | chrome.ts:9, 41-42; chip-input.tsx:74 | input fill `--surface-5`, border `--border-1`, placeholder `--text-muted`, error border `--text-error`, no focus ring | | |
| 17 | token | chip.tsx:72; chrome.ts:16-17 | submit fill `--text-primary`, text `--text-inverse`, hover `--text-body`, disabled opacity .6 | | |
| 18 | token | social-login-buttons.tsx:68; chip.tsx:86-90 | social chip border `--border`, hover `--surface-hover`, label `--text-body` | | |
| 19 | token | auth-form-message.tsx:22 | policy error `--text-error`; reset success `--brand-accent` | | |
| 20 | token | auth-text-link.tsx:7-8 | links `--text-secondary` → hover `--text-primary` + underline, offset 4 | | |
| 21 | state | login-form.tsx:362-368, 379-458 | section visibility matrix (email/social/SSO/hasOnlySSO/divider) | | |
| 22 | state | login-form.tsx:460; login/page.tsx:23 | sign-up prompt hidden when `registrationDisabled` or email disabled | | |
| 23 | state | login-form.tsx:132-136, 432-436 | `?resetSuccess=true` shows the green line; cleared on next submit | | |
| 24 | state | login-form.tsx:138-154, 172-183 | validation errors appear only after submit, clear on next keystroke; field border red while shown | | |
| 25 | state | login-form.tsx:372, 438 | submit disabled until both fields filled; spinner + "Signing in…" while in flight | | |
| 26 | state | login-form.tsx:199-203, 282-285 | `EMAIL_NOT_VERIFIED` → store email in sessionStorage, go to `/verify` | | |
| 27 | state | login-form.tsx:210-217 | 403 with message → form-level `auth.login.policyError`, fields unmarked | | |
| 28 | state | login-form.tsx:219-259 | credential error lines (table in States) under the password field | | |
| 29 | state | social-login-buttons.tsx:69-72 | "Connecting…" on the clicked provider, all disabled meanwhile | | |
| 30 | state | login-form.tsx:342-350, 488-503 | modal success line then auto-close after 2 s; "Sending…" label; Cancel disabled while sending | | |
| 31 | interaction | login-form.tsx:107-114; input-validation.ts:932-943 | invalid `callbackUrl` replaced by `/home`; valid relative/same-origin kept | | |
| 32 | interaction | login-form.tsx:116-119; auth-redirect.ts:107-118 | sign-up link carries `invite_flow` and `callbackUrl` | | |
| 33 | interaction | sso-login-button.tsx:24-27 | SSO chip navigates to `/sso?callbackUrl=<encoded>` | | |
| 34 | interaction | auth-shell.tsx:39; auth-legal-footer.tsx:17-23 | logo → `/` (document navigation); legal links open new tab | | |
| 35 | keyboard | login-form.tsx:382 | Enter in email or password submits the form | | |
| 36 | keyboard | chip-modal.tsx:138-152, 166-191 | modal: initial focus in email field, Enter sends, Escape closes | | |
| 37 | keyboard | DOM order | tab order logo → email → forgot → password → eye → submit → social → SSO → sign up → terms → privacy | | |
| 38 | network | providers/route.ts:18-34; login-form.tsx:362-363 | (F) `GET /api/auth/providers` (incl. `ssoEnabled`) and public env drive the same visibility as the server props | | |
| 39 | network | login-form.tsx:189-194 | `POST /api/auth/sign-in/email` body `{email, password, callbackURL}`, email normalised | | |
| 40 | network | login-form.tsx:280 | success → full navigation to `callbackUrl` (default `/home`) | | |
| 41 | network | login-form.tsx:316-321; user.ts:200-229 | `POST /api/auth/forget-password` `{email, redirectTo: <origin>/reset-password}`; 200 `{success:true}` even for unknown accounts | | |
| 42 | network | social-login-buttons.tsx:49; social-sign-in.ts:28 | `POST /api/auth/sign-in/social` `{provider, callbackURL}` then top-level navigation to `url` | | |
| 43 | network | proxy.ts:382-395 | signed-in visitor is sent to `/home` unless `callbackUrl` is `/api/auth/oauth2/authorize` | | |
| 44 | state | layout.tsx:13; login-form.tsx:100 | hosted-only analytics (`AttributionCapture`, `login_page_viewed`) — verified-by-review | | |

Colour anchors (light; the page has no dark variant): `auth.shell @ (8,8)` → `--bg` #fefefe · `auth.login.email @ (3,18)` → `--surface-5` #f3f3f3 · `auth.login.email @ (0,18)` → `--border-1` #d8d8d8 (1 px border) · `auth.login.submit @ (6,18)` → `--text-primary` #1a1a1a · `auth.login.social.google @ (392,18)` → `--bg` #fefefe (transparent chip) and `@ (0,18)` → `--border` #d8d8d8 · `auth.login.divider @ (2,10)` → `--border` #d8d8d8 (1 px rule at mid-height) · error state: `auth.login.email @ (0,18)` → `--text-error` #ef4444.
