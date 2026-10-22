# Reset password
Upstream: `apps/sim/app/(auth)/reset-password/**` (token form) and the request form inside `app/(auth)/login/login-form.tsx:467-504` (forgot-password modal), commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1

The "request" half is the modal on `/login` (measured in `auth-login.md`, repeated here only as a flow); the "token" half is `/reset-password?token=…`.

## Files
| File | Lines | Role |
|---|---|---|
| `app/(auth)/reset-password/page.tsx` | 10 | Re-exports `ResetPasswordPage`; `force-dynamic` |
| `app/(auth)/reset-password/reset-password-content.tsx` | 89 | Reads `?token`, submits, success/error status, redirect to `/login?resetSuccess=true` |
| `app/(auth)/reset-password/reset-password-form.tsx` | 133 | `SetNewPasswordForm`: two password fields, client policy, submit |
| `app/(auth)/reset-password/loading.tsx` | 17 | Route skeleton |
| `app/(auth)/login/login-form.tsx` | 293-360, 467-504 | Request form (modal) |
| `lib/api/contracts/user.ts` | 200-255 | `forgetPasswordContract`, `resetPasswordContract` (policy: 8–100 chars, upper, lower, digit, non-alphanumeric) |
| `app/api/auth/forget-password/route.ts` | 93 | Request route |
| `app/api/auth/reset-password/route.ts` | 76 | Token route: 400 "This reset link is invalid or has expired. Please request a new one.", 500 "Failed to reset password…", IP limiter 10 per 15 min |
| Shared | | `AuthShell`, `AuthHeader`, `AuthField`, `PasswordInput`, `AuthFormMessage`, `AuthSubmitButton`, `AuthNavPrompt` |

## Layout
Shell as login. Column (`reset-password-content.tsx:64-78`) `space-y-6` — parity `auth.reset.root`:
1. `auth.reset.header`: title "Reset your password", description "Enter a new password for your account" (`:66`).
2. `auth.reset.form` `<form class='space-y-6'>` (`reset-password-form.tsx:78`):
   - `div.space-y-5` (`:79`):
     - `auth.reset.password.field` / `auth.reset.password`: label "New Password", `PasswordInput id='password' autoComplete='new-password'`, placeholder "Enter new password", 400×36, eye toggle (`:80-93`).
     - `auth.reset.confirm.field` / `auth.reset.confirm`: label "Confirm Password", placeholder "Confirm new password" (`:94-107`).
     - `auth.reset.validation` `AuthFormMessage type='error'` listing every failing rule, one `<p>` per rule, 12 px `--text-error`, `space-y-1` (`:109-115`). Inside the 20 px stack (so 20 px above it, not 24).
     - `auth.reset.status` `AuthFormMessage` success (`--brand-accent`) or error (`--text-error`) (`:117-121`).
   - `auth.reset.submit` "Reset Password" / "Resetting…" (`:124-130`).
3. `auth.reset.backPrompt` `AuthNavPrompt href='/login' linkLabel='Back to login'` (30 px chip link, no lead text) (`:76`).

Note the field errors here are form-level (`AuthFormMessage`), not per-field lists: `AuthField` is used without `errors`, and both inputs get `error={hasValidationErrors}` so both borders turn red together (`:92, 106`).

Column height (no messages): 65 + 24 + (57 + 20 + 57 + 24 + 36) + 24 + 30 ≈ 337 px.

Skeleton (`reset-password/loading.tsx:7-16`) — parity `auth.reset.loading`: title 160×38; `mt-3` label 280×14; `mt-8` field (label 40×14 + control 400×44); `mt-6` control 400×44; `mt-6` label 120×14. Inner Suspense fallback (`reset-password-content.tsx:81-89`): 320 px tall centred "Loading…".

## Tokens
As login: inputs `--surface-5` / `--border-1` / `--text-body`; error borders `--text-error`; validation and error status `--text-error`; success status `--brand-accent` #33c482; submit primary chip; chip link `--border-1`.

## States
| State | Rendering / behaviour |
|---|---|
| No `?token` | `tokenError` "Invalid or missing reset token. Please request a new password reset link." shown as the error status; both inputs disabled (`opacity-50`), submit disabled (`reset-password-content.tsx:28-30, 73-74`; `reset-password-form.tsx:86, 100, 127`) |
| Token present, idle | fields enabled; submit disabled until both fields non-empty (`:127`) |
| Client validation failed | list of all failing rules (in this order): "Password must be at least 8 characters long", "Password must not exceed 100 characters", "Password must contain at least one uppercase letter", "…lowercase letter", "…one number", "…one special character" (`[^A-Za-z0-9]`), "Passwords do not match" (`:38-64`); both borders red; no request. The list persists until the next submit (not cleared on typing). |
| Submitting | fields disabled, submit "Resetting…", status cleared (`:35-36` in content) |
| Success | status "Password reset successful! Redirecting to login..." in green; after 1500 ms `router.push('/login?resetSuccess=true')` (`reset-password-content.tsx:45-52`) |
| Expired / reused token | 400 `{ message: 'This reset link is invalid or has expired. Please request a new one.' }` → red status with that message (`reset-password/route.ts:59-66`; `getErrorMessage(error)` = `ApiClientError.message` = `body.message`) |
| Policy rejected server-side | 400 `{ message: <zod messages joined by ' '> }` (`route.ts:38-42`) — only reachable if the client list is bypassed |
| Rate limited | 429 from `enforceIpRateLimit` (10 tokens / 15 min, `route.ts:18-22`) → red status with the limiter's message |
| Server failure | 500 "Failed to reset password. Please try again or request a new reset link." |
| Signed-in visitor | `/reset-password` is not proxied; works signed in or out |
| Request flow (modal on `/login`) | states in `auth-login.md`: idle / sending / success (auto-close 2 s) / error; always "Password reset link sent to your email" on 200 whether or not the account exists |

## Interactions
- Typing never validates; validation runs on submit only (`reset-password-form.tsx:33-73`).
- Submit (`Enter` in either field or click): `preventDefault`, build the error list, stop if non-empty, else `onSubmit(password)` (`:33-73`).
- Eye toggles per field.
- "Back to login": chip link, client navigation.
- Focus order: logo → password → eye → confirm → eye → Reset Password → Back to login.
- Query: `token` read verbatim (`reset-password-content.tsx:17`). The email link produced by Better Auth is `${redirectTo}?token=<token>` where `redirectTo` was `${origin}/reset-password` (`login-form.tsx:319`); Better Auth may append `&callbackURL=` — the page ignores anything but `token`.

## Network and realtime
Request half (from `/login`): `POST /api/auth/forget-password` `{ email, redirectTo }` — see `auth-login.md` Network 5.
Token half:
1. (no load-time requests beyond the session provider's `GET /api/auth/get-session`)
2. Submit: `POST /api/auth/reset-password` JSON `{ token, newPassword: password }` (`reset-password-content.tsx:38-43`; contract `user.ts:231-255`) → 200 `{ success: true }`; 400 `{ message }`; 429; 500 `{ message }`.
3. After 1500 ms: client navigation to `/login?resetSuccess=true` (the login page then shows the green line).
No socket, no invalidations.

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | reset-password-content.tsx:64-66 | column 400 px; title "Reset your password", description "Enter a new password for your account" | | |
| 2 | layout | reset-password-form.tsx:78-107 | two 57 px password fields, 20 px apart, labels "New Password" / "Confirm Password" | | |
| 3 | layout | reset-password-form.tsx:109-121 | validation list and status message inside the 20 px stack, 12 px lines with 4 px gaps | | |
| 4 | layout | reset-password-form.tsx:124-130 | submit 400×36 "Reset Password", 24 px below the stack | | |
| 5 | layout | reset-password-content.tsx:76 | "Back to login" 30 px chip link, 24 px below the form | | |
| 6 | layout | reset-password/loading.tsx:7-16 | skeleton 160×38, 280×14 (mt-3), field (mt-8), control (mt-6), 120×14 (mt-6) | | |
| 7 | layout | reset-password-content.tsx:81-89 | inner fallback 320 px "Loading…" | | |
| 8 | token | reset-password-form.tsx:92, 106 | both borders `--text-error` while any rule fails | | |
| 9 | token | auth-form-message.tsx:22 | success `--brand-accent`, error `--text-error` | | |
| 10 | token | chip-input.tsx:75 | disabled fields at 50 % opacity (no token / submitting) | | |
| 11 | state | reset-password-content.tsx:28-30, 73-74 | missing token: error status text, fields and submit disabled | | |
| 12 | state | reset-password-form.tsx:127 | submit disabled until both fields non-empty | | |
| 13 | state | reset-password-form.tsx:38-69 | all failing rules listed in rule order incl. "Passwords do not match"; list stays until next submit | | |
| 14 | state | reset-password-content.tsx:35-36, 53-58 | status cleared on submit; error status = server `message` | | |
| 15 | state | reset-password-content.tsx:45-52 | success copy then `/login?resetSuccess=true` after 1500 ms | | |
| 16 | state | reset-password/route.ts:59-66 | expired/reused token copy "This reset link is invalid or has expired. Please request a new one." | | |
| 17 | state | login-form.tsx:342-350 | request modal success copy + 2 s auto-close | | |
| 18 | state | forget-password/route.ts:71, 80-84 | request answers 200 for unknown accounts (no enumeration) | | |
| 19 | interaction | reset-password-form.tsx:33-37 | no validation while typing; Enter submits | | |
| 20 | interaction | reset-password-content.tsx:17 | only `token` is read from the query | | |
| 21 | keyboard | DOM order | tab order password → eye → confirm → eye → submit → back link | | |
| 22 | network | reset-password-content.tsx:38-43; user.ts:231-255 | `POST /api/auth/reset-password` `{token, newPassword}` | | |
| 23 | network | login-form.tsx:316-321 | `POST /api/auth/forget-password` `{email, redirectTo: <origin>/reset-password}` | | |
| 24 | network | reset-password/route.ts:26-31 | 429 after 10 attempts per 15 min per IP surfaces as the error status | | |
| 25 | state | reset-password-form.tsx:109-115 | validation errors are form-level (one list), not per field | | |

Colour anchors: `auth.shell @ (8,8)` → #fefefe · `auth.reset.password @ (3,18)` → `--surface-5` #f3f3f3 · `auth.reset.password @ (0,18)` → `--border-1` #d8d8d8 · `auth.reset.submit @ (6,18)` → `--text-primary` #1a1a1a · validation state: `auth.reset.confirm @ (0,18)` → `--text-error` #ef4444 · no-token state: `auth.reset.password @ (3,18)` → #f3f3f3 at 50 % over `--bg` ≈ #f9f9f9.
