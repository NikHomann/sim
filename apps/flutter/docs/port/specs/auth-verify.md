# Verify email (OTP)
Upstream: `apps/sim/app/(auth)/verify/**`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

Shares `AuthShell`, `AuthHeader`, `AuthFormMessage`, `AuthSubmitButton`, `AuthTextLink`, `AuthNavPrompt` with `auth-login.md`.

## Files
| File | Lines | Role |
|---|---|---|
| `app/(auth)/verify/page.tsx` | 23 | Server page: props `hasEmailService = hasEmailService()`, `isProduction = isProd`, `isEmailVerificationEnabled = isEmailVerificationEffectivelyEnabled()`; `force-dynamic` |
| `app/(auth)/verify/verify-content.tsx` | 173 | `VerificationForm` (OTP UI, resend countdown), `VerificationFormFallback`, `VerifyContent` (Suspense) |
| `app/(auth)/verify/use-verification.ts` | 247 | State machine: `idle | verifying | verified | error`; verify, resend, auto-submit, verification-disabled skip, redirect resolution |
| `app/(auth)/verify/loading.tsx` | 15 | Route skeleton |
| `app/(auth)/auth-redirect.ts` | 8, 17 | `POST_AUTH_REDIRECT_STORAGE_KEY = 'postAuthRedirectUrl'`, `DEFAULT_POST_AUTH_ROUTE = '/home'` |
| `lib/auth/constants.ts` | 104-107 | `SSO_REQUIRED_ERROR_CODE = 'SSO_REQUIRED'` |
| `lib/auth/auth.ts` | 865, 1402-1470 | `autoSignInAfterVerification: true`; `emailOTP` plugin: `otpLength 6`, `expiresIn 15 min`, `overrideDefaultEmailVerification`, OTP logged to the server console when no mail service, `disableSignUp` |
| `lib/messaging/email/mailer.ts` | 46-48 | `hasEmailService()` = at least one provider configured |
| `app/api/auth/providers/route.ts` | 34 | `GET /api/auth/providers`: carries the page's three server props for Flutter — `emailServiceConfigured` (`hasEmailService()`), `isProd`, `emailVerificationEnabled` (`isEmailVerificationEffectivelyEnabled()`) — as optional booleans (contract `lib/api/contracts/auth.ts:11-31`) |
| emcn | | `InputOTP`, `InputOTPGroup`, `InputOTPSlot` (`packages/emcn/src/components/input-otp/input-otp.tsx`, on the `input-otp` library) |

Hooks: `useSearchParams` (`redirectAfter`, `fromSignup` is read by nobody), `useSession()` (`data.user.email`, `refetch`). No store, no socket.

## Layout
Shell as login. Column (`verify-content.tsx:62-145`) `space-y-6` — parity `auth.verify.root`:
1. `auth.verify.header` (`AuthHeader`): `auth.verify.title` "Verify your email" (or "Email Verified" once verified); `auth.verify.description` one of: "Your email has been verified. Redirecting to dashboard..." (verified) · "Email verification is disabled. Redirecting to dashboard..." (`!isEmailVerificationEnabled`) · "A verification code has been sent to {email || 'your email'}" (mail service) · "Development mode: Check your console logs for the verification code" (no mail service, not production) · "Error: Email verification is enabled but no email service is configured" (no mail service, production) (`:63-76`).
2. `auth.verify.body` `div.space-y-6` only while `!isVerified && isEmailVerificationEnabled` (`:78-143`):
   - inner `div.space-y-5` (`:80`):
     - `auth.verify.hint` `<p class='text-center text-sm text-[var(--text-muted)]'>` "Enter the 6-digit code to verify your account." + " If you don't see it in your inbox, check your spam folder." when a mail service exists (`:81-84`). 14 px / 20 px.
     - `auth.verify.otp`: `div.flex.justify-center` → `InputOTP maxLength=6` container `flex items-center gap-2` (`input-otp.tsx:42`), group `flex items-center gap-2` (`:58`), six `auth.verify.otp.slot.0..5`: each `size-12` (48×48 px), `rounded-sm` (4 px), `border --border-1`, `bg --surface-5`, `--text-primary`, `text-lg` (18 px) (`input-otp.tsx:78`); active slot `z-10 border --text-muted ring-1 ring --text-muted` (`:79`); fake caret `h-6 w-px bg --text-primary` blinking 1 s (`:85-89`); invalid state adds `border --text-error` to every slot (`verify-content.tsx:93`); container `opacity-50` while disabled (`input-otp.tsx:42`). Row width 6×48 + 5×8 = 328 px, centred in the 400 px column (x offset 36).
     - `auth.verify.error` `AuthFormMessage type='error' align='center'` (12 px `--text-error`, centred) when `errorMessage` (`:100-104`).
   - `auth.verify.submit` `AuthSubmitButton type='button'` "Verify Email" / "Verifying…", disabled until 6 digits (`:107-115`). 400×36.
   - `auth.verify.resend` `<p class='text-center text-sm text-[var(--text-muted)]'>` "Didn't receive a code? " then either `<span>Resend in <span class='text-[var(--text-primary)]'>{n}s</span></span>` or `auth.verify.resendLink` `AuthTextLink` button "Resend" (`--text-secondary`, hover `--text-primary` underline; disabled `opacity-50 cursor-not-allowed`) (`:117-130`). Only when `hasEmailService`.
   - `auth.verify.backPrompt` `AuthNavPrompt href='/signup' linkLabel='Back to signup'` (no lead text; 30 px `ChipLink`) (`:132-141`).

Column height (default, mail service): 65 + 24 + [ (40 + 20 + 48) + 24 + 36 + 24 + 20 + 24 + 30 ] ≈ 355 px (hint may wrap to two lines at 400 px: the sentence is ~95 characters at 14 px, so it is 2 lines → 40 px as counted).

`VerificationFormFallback` (`:148-157`) — parity `auth.verify.fallback`: `text-center`, `animate-pulse`: block 192×32 `rounded` (`rounded` = `--radius-md`? No: Tailwind `rounded` = `var(--radius)`? In v4 `rounded` = `--radius` 0.25 rem default; globals does not override `--radius-DEFAULT`, so 4 px) `bg --surface-4` `mx-auto mb-4` then 256×16 `bg --surface-4`. Route skeleton (`verify/loading.tsx:8-14`) — parity `auth.verify.loading`: title 180×38 r4; `mt-3` label 300×14; `mt-1` label 240×14; `mt-8` control 400×44 r10.

## Tokens
| Element | Token(s) |
|---|---|
| Hint, resend copy | `--text-muted`, 14 px |
| Countdown number | `--text-primary` |
| OTP slot | fill `--surface-5` #f3f3f3, border `--border-1` #d8d8d8, text `--text-primary`, 18 px; active border + 1 px ring `--text-muted` #7a7a7a; error border `--text-error` #ef4444; caret `--text-primary`; disabled 50 % opacity |
| Error message | `--text-error` 12 px centred |
| Submit, link, chip link | as login |
| Fallback blocks | `--surface-4` #f5f5f5 |
| Motion | caret blink 1 s (`animate-caret-blink`, `02-design-system.md` §1f: 1.25 s keyframe with `duration-1000`), pulse, loader spin |

## States
Inputs (server props in React; Flutter reads them from `GET /api/auth/providers`, `providers/route.ts:29-32`): `hasEmailService` = `emailServiceConfigured`, `isProduction` = `isProd`, `isEmailVerificationEnabled` = `emailVerificationEnabled`. All three are optional on the contract: treat an absent `emailVerificationEnabled` as `false` (skip path), an absent `emailServiceConfigured` as `false`, an absent `isProd` as `true` (the error sentence rather than the dev-console hint). The email comes from `session.user.email` (if a session exists) else `sessionStorage.verificationEmail` (`use-verification.ts:86-91`).

| State | Rendering / behaviour |
|---|---|
| Verification not enforceable (`!isEmailVerificationEnabled`) | header description renders as "Your email has been verified. Redirecting to dashboard..." (the "Email verification is disabled…" sentence exists in `:63-76` but the same effect sets `status='verified'` before first paint, so it never shows; verified by the implementer and reviewer 2026-10-21), no body; effect sets `status='verified'`, resolves destination, removes `postAuthRedirectUrl`, `refetchSession()`, then `window.location.href = destination ?? '/home'` immediately (`:209-231`). The title stays "Email Verified" because `isVerified` is true. |
| idle (default) | OTP empty, submit disabled, resend link enabled, no error |
| typing | slots fill left to right; on reaching 6 chars any error state is cleared (`:185-191`) and an auto-verify fires after 300 ms unless verifying/verified/resending (`:193-207`) |
| verifying | slots disabled (opacity .5), submit shows spinner "Verifying…", resend link disabled (`isLoading`, `:46`) |
| verified | title "Email Verified", description "Your email has been verified. Redirecting to dashboard...", body hidden; after `refetchSession()` the page waits 1000 ms then `window.location.href = destination` (`:107-123`) |
| error | slots bordered red, OTP cleared (`:137, 156`), centred message: `SSO_REQUIRED` with message → that message; other API error → "Invalid verification code. Please check and try again."; thrown error containing "expired" → "The verification code has expired. Please request a new one."; "invalid" → "Invalid verification code. Please check and try again."; "attempts" → "Too many failed attempts. Please request a new code."; else "Verification failed. Please check your code and try again." (`:124-156`) |
| resending | `isResending` true: slots and submit disabled, "Resend" disabled; countdown 30 s starts immediately on click regardless of outcome (`:56-59`); failure sets "Failed to resend verification code. Please try again later." with status still `idle` (`:173`) |
| countdown | "Resend in {n}s", n from 30 down by 1 each second (`:48-54`) |
| no email known | `verifyCode` and `resendCode` are no-ops (`:95, 160`); description reads "…sent to your email" |
| no mail service, dev | description tells the user to read the server console (OTP is logged, `auth.ts:1438-1445`); resend row hidden; hint without the spam sentence |
| no mail service, production | description is the error sentence; resend hidden |
| Back to signup | clears `verificationEmail` and `postAuthRedirectUrl` from sessionStorage, client navigation to `/signup` (`:135-140`) |
| Signed-in visitor | `/verify` is not an app-surface path, so the proxy does not redirect it; the page works with a session (email from session) or without |

Destination resolution (`resolveRedirectUrl`, `:24-41`): stored `postAuthRedirectUrl` if it passes `validateCallbackUrl` (an unsafe stored value is removed), overridden by `?redirectAfter=` when that passes validation; `null` ⇒ `/home`. The two sessionStorage keys are removed after a successful verify (`:117-118`).

## Interactions
- OTP input: `input-otp` renders one hidden `<input inputmode=numeric autocomplete=one-time-code maxlength=6>` over the six slots; typing, paste (6 chars fill all slots), Backspace, arrow keys move the active slot. `maxLength=6`; only `value.length === 6` enables submit and auto-verify.
- Click "Verify Email" or auto-verify (300 ms after the sixth digit): `verifyCode()`.
- "Resend": `resendCode()` + 30 s countdown. Disabled while verifying/resending.
- "Back to signup": chip link.
- Focus order: logo → OTP input → Verify Email → Resend → Back to signup.
- Keyboard: Enter inside the OTP input does nothing (no form element; submit is `type='button'`).

## Network and realtime
0. (F) `GET /api/auth/providers` → `emailServiceConfigured`, `isProd`, `emailVerificationEnabled` (replaces the server props; unauthenticated, `force-dynamic`, no cache header).
1. `GET /api/auth/get-session` (session provider; supplies `user.email` when the sign-in that bounced here created a session, which with `requireEmailVerification` it does not; after signup there is no session either, so the email usually comes from sessionStorage).
2. Verify: `POST /api/auth/email-otp/verify-email` `{ email: normalizeEmail(email), otp }` (`:100-105`) → 200 `{ status: true, token, user }`; with `autoSignInAfterVerification: true` (`auth.ts:865`) the response sets the session cookie. Error body `{ code, message }`: `INVALID_OTP`, `OTP_EXPIRED`, `TOO_MANY_ATTEMPTS` (Better Auth emailOTP codes; the client only inspects `error.code === 'SSO_REQUIRED'` on the response path and the message text on the thrown path), 403 `{ code: 'SSO_REQUIRED', message }` from the session hook (`sso-policy.ts:109-125`).
3. `GET /api/auth/get-session` (refetch after success, `:109-113`).
4. Navigate: full document navigation to the destination after 1000 ms (`:121-123`).
5. Resend: `POST /api/auth/email-otp/send-verification-otp` `{ email, type: 'email-verification' }` (`:166-171`); the catch-all allows this type only (`03-api-and-auth.md` §1); 200 `{ success: true }`; when `disableSignUp` is on and the email is unknown Better Auth answers success without sending (enumeration-safe, `auth.ts:1456-1466`).
6. Verification-disabled branch: `GET /api/auth/get-session` then full navigation (`:216-228`).
No socket, no invalidations.

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | verify-content.tsx:62-76 | header title/description variants, centred, 32 px / 15 px | | |
| 2 | layout | verify-content.tsx:78-84 | body stack 24 px; inner 20 px; hint 14 px centred `--text-muted` with/without spam sentence | | |
| 3 | layout | verify-content.tsx:86-98; input-otp.tsx:42, 58, 78 | six 48×48 slots, 8 px gaps, row 328 px centred, radius 4, 18 px digits | | |
| 4 | layout | input-otp.tsx:79, 85-89 | active slot: border + 1 px ring `--text-muted`; blinking 24×1 caret | | |
| 5 | layout | verify-content.tsx:107-115 | submit 400×36 "Verify Email" below the group | | |
| 6 | layout | verify-content.tsx:117-130 | resend row 14 px centred; countdown number in `--text-primary` | | |
| 7 | layout | verify-content.tsx:132-141 | "Back to signup" 30 px chip link, no lead text | | |
| 8 | layout | verify/loading.tsx:8-14 | skeleton: 180×38, 300×14 (mt-3), 240×14 (mt-1), 400×44 (mt-8) | | |
| 9 | layout | verify-content.tsx:148-157 | fallback: 192×32 and 256×16 `--surface-4` pulsing blocks | | |
| 10 | token | input-otp.tsx:78 | slot `--surface-5` / `--border-1` / `--text-primary` | | |
| 11 | token | verify-content.tsx:93 | error state: every slot border `--text-error` | | |
| 12 | token | input-otp.tsx:42 | disabled group opacity .5 | | |
| 13 | token | auth-form-message.tsx:22-23 | centred error in `--text-error` 12 px | | |
| 14 | state | use-verification.ts:91 | email = session email, else sessionStorage `verificationEmail` | | |
| 15 | state | use-verification.ts:92; verify-content.tsx:113 | submit disabled until 6 chars | | |
| 16 | state | use-verification.ts:193-207 | auto-verify 300 ms after the sixth char, not while verifying/verified/resending | | |
| 17 | state | use-verification.ts:185-191 | reaching 6 chars clears error state and message | | |
| 18 | state | use-verification.ts:124-156 | error copy mapping (SSO_REQUIRED message, invalid, expired, attempts, generic); OTP cleared | | |
| 19 | state | use-verification.ts:107-123 | verified: header swap, body hidden, session refetch, 1000 ms then navigate | | |
| 20 | state | verify-content.tsx:48-59 | 30 s countdown starts on Resend click; link returns at 0 | | |
| 21 | state | use-verification.ts:159-178 | resend failure message; status stays idle | | |
| 22 | state | use-verification.ts:209-231; verify-content.tsx:68; providers/route.ts:29 | verification disabled (`emailVerificationEnabled === false` from `GET /api/auth/providers`): "…disabled. Redirecting…" copy, no body, immediate navigation after session refetch | | |
| 23 | state | verify-content.tsx:69-76; providers/route.ts:30, 32 | no mail service copy (dev vs production, from `emailServiceConfigured` and `isProd` on `GET /api/auth/providers`); resend row hidden | | |
| 31 | network | providers/route.ts:18-34 | (F) `GET /api/auth/providers` supplies `emailServiceConfigured`, `isProd`, `emailVerificationEnabled` before render | | |
| 24 | interaction | use-verification.ts:24-41 | destination: stored `postAuthRedirectUrl` (validated) overridden by `?redirectAfter` (validated), else `/home` | | |
| 25 | interaction | verify-content.tsx:135-140 | Back to signup clears both sessionStorage keys | | |
| 26 | interaction | use-verification.ts:117-118, 220 | sessionStorage keys consumed on success and on the skip path | | |
| 27 | keyboard | input-otp library | typing/paste/Backspace/arrows across slots; hidden input `inputmode=numeric`, `autocomplete=one-time-code` | | |
| 28 | network | use-verification.ts:100-105 | `POST /api/auth/email-otp/verify-email` `{email, otp}`, email normalised | | |
| 29 | network | use-verification.ts:166-171 | `POST /api/auth/email-otp/send-verification-otp` `{email, type:'email-verification'}` | | |
| 30 | network | use-verification.ts:109-113, 216-220 | `GET /api/auth/get-session` after verify and on the skip path | | |

Colour anchors: `auth.shell @ (8,8)` → #fefefe · `auth.verify.otp.slot.0 @ (6,6)` → `--surface-5` #f3f3f3 · `auth.verify.otp.slot.0 @ (0,24)` → `--border-1` #d8d8d8 · `auth.verify.submit @ (6,18)` → `--text-primary` #1a1a1a · error state: `auth.verify.otp.slot.5 @ (47,24)` → `--text-error` #ef4444 · active state: `auth.verify.otp.slot.0 @ (0,24)` → `--text-muted` #7a7a7a.
