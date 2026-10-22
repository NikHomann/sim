# Phase 1 auth pages — review v1

Scope: `lib/features/auth/**`, `test/features/auth/**` against `docs/port/specs/auth-login.md`, `auth-signup.md`, `auth-verify.md`, `auth-reset-password.md`, `auth-sso.md`, `auth-oauth-pages.md`, `invite-accept.md`, `entry-resolution.md` §2/§8 and the React source at the pinned commit. Read-only review; nothing was changed.

Reported state confirmed: `flutter analyze --fatal-infos lib/features/auth test/features/auth` → no issues; `flutter test test/features/auth` → 136 tests, all passing. Neither `flutter build web` nor a Windows build was run; the web/desktop judgement below is static.

## Findings (most severe first)

### 1. Blocker — every `AuthShell` page renders its column top-aligned instead of vertically centred
- Spec: auth-login.md §Shell + row 1 (`auth.shell.column` … "the column is centred vertically inside that box minus the 64 px bottom padding"); same shell for signup row 1, verify row 1, reset row 1, sso rows 1–2, consent row 1, invite row 1. React `app/(auth)/components/auth-shell.tsx:46-47` (`flex flex-1 items-center justify-center px-4 pb-16`).
- Flutter: `lib/features/auth/shared/widgets/auth_shell.dart:130-152` places the page under `Expanded → Center`, which hands the child *loose but bounded* height. Every page column is a `Column` with the default `mainAxisSize: MainAxisSize.max` (`login_page.dart:127`, `signup_page.dart:120, 162`, `verify_page.dart:89`, `reset_password_page.dart:82`, `sso_page.dart:119`, `consent_page.dart:85, 118` and the refusal `AuthHeader` at `:65`, `invite_page.dart:302, 324`), so the column stretches to the full remaining height and its children start at the top.
- Evidence: `test/features/auth/goldens/ci/auth_reset_password.png` shows the title at y≈80 of 900 (header 62 px + 18); the React capture `docs/port/parity/phase-1/react/auth-reset-password-light.jpg` shows it at ≈24 % of the viewport (card centred in the area below the header). This is the coordinator's observation; verdict: **bug, not expected**. The `LogoShell` pages (oauth-error, chat-complete, credential-connected) are *not* affected because `StatusCard` uses `mainAxisSize: MainAxisSize.min` (`auth_shell.dart:300`).
- Fix (one place): in `AuthShell`, wrap the page in an intrinsically sized container so the inner column receives unbounded height, e.g. replace `child: child` at `auth_shell.dart:146` with `child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[child])`. (Alternatively add `mainAxisSize: MainAxisSize.min` to each of the nine page columns listed above.) Then regenerate the seven `AuthShell` goldens and compare them against the React captures; add a geometry assertion (see finding 2).

### 2. Major — the goldens certify the bug in finding 1; the golden test cannot catch what its header promises
- `test/features/auth/goldens/auth_goldens_test.dart:1-6` says a golden diff must catch "column width and centring", but the recorded CI goldens were produced from the top-aligned layout, so the suite is green on the broken code and would go *red* on the fix. The goldens were never checked against `docs/port/parity/phase-1/react/*.jpg` (04-test-plan §1 L2/L6: goldens prove structure *of the design system*; "looks the same" is L6).
- Fix: after finding 1, re-record the goldens and, in `auth_goldens_test.dart` or the page tests, assert the column's vertical centre at 1440×900 explicitly, e.g. `tester.getRect(byParityId('auth.reset.root')).center.dy` ≈ `62 + (900 − 62 − 64) / 2` within the spec's tolerance, so the test fails on the pre-fix code.

### 3. Major — a signed-out `/invite/<id>` deep link shows the signed-out card instead of bouncing to login
- Spec: invite-accept.md row 31 ("signed-out deep link bounces to `/login?callbackUrl=…&invite_flow=true` (Flutter guard does the same client-side)") and the States note that the signed-out card "appears only when the request carried `callbackUrl` or after a client-side sign-out". React `proxy.ts:260-286`.
- Flutter: `lib/features/auth/invite/invite_cubit.dart:353-356` emits `InvitePhase.signedOut` for every signed-out visitor; `invite_page.dart:107-141` renders the card. No guard exists.
- Fix: in `load()`, when `session == null` and `query['callbackUrl']` is absent, `_navigator.go(loginHref())` (which already builds `/login?invite_flow=true&callbackUrl=%2Finvite%2F<id>%3Ftoken%3D…`) and return; keep the card for the `callbackUrl`-present / post-sign-out case. Add the failure mode to `invite_cubit_test.dart` ("signed out without `callbackUrl` leaves for login; with it, the card shows").

### 4. Major — absent server flags default the opposite way from the spec, and signup infers the verification route from the response
- Spec: auth-verify.md §States ("treat an absent `emailVerificationEnabled` as `false` (skip path), an absent `emailServiceConfigured` as `false`, an absent `isProd` as `true`"); auth-signup.md §States ("absent `emailVerificationEnabled` as `false`") and §Network 4 ("so the routing decision matches React **without inferring it from the sign-up response**").
- Flutter: `verify_cubit.dart:183` (`?? true`), `:188` (`?? true`), `auth_api.dart:41` (`isProd ?? false`, doc at `:64` even says "treated as true"), `signup_cubit.dart:258-260` (`?? (!result.hasToken && session == null)`); `signup_cubit_test.dart:180-196` pins the inference.
- Impact today is low (the pinned `providers/route.ts` always sends the five optional booleans) but against an older server `/verify` would show an OTP form no mail can satisfy, and signup would route by a heuristic the spec forbids.
- Fix: `emailVerificationEnabled ?? false`, `emailServiceConfigured ?? false`, `isProd ?? true` in `AuthPageOptions.fromResponses` / the cubits; drop the `SignUpResult.hasToken`-based inference (and the `hasToken` field if nothing else uses it); update the two tests and the doc comments.

### 5. Minor — post-auth default destination is `/` where every spec row names `/home`
- Spec: entry-resolution.md §8 ("the Flutter login page navigates to the validated callback or `/home`"), §2; auth-login.md rows 40/43; auth-signup.md row 29; auth-verify.md row 24; invite-accept.md row 17 ("Manage Team Settings → `/home`"); auth-oauth-pages.md E ("Open Sim → `/home`").
- Flutter: `auth_redirect.dart:15, 117-120` (`flutterEntryRoute = '/'`), used by `login_cubit.dart:139`, `signup_cubit.dart:158`, `invite_cubit.dart:484`, `status_pages.dart:170` (whose `Semantics(value: '/home')` at `:165` contradicts the navigation). `AppRoutes.home = '/home'` exists in `lib/app/router.dart:11`. Tests assert `/` (`auth_redirect_test.dart:518`, `login_cubit_test.dart:92, 177`, …).
- The request body still carries `callbackURL: '/home'` (correct). Either is defensible only if `/` and `/home` resolve identically inside the bundle; today both are placeholders. Fix: use `AppRoutes.home` as `flutterEntryRoute` (spec wording), or record the `/` decision in entry-resolution.md §8 / known-gaps.md and fix the `/home` semantics value. Pick one before the entry-resolution work lands.

### 6. Minor — `isPolicyRefusal` treats every 403 as a policy refusal
- React `login-form.tsx:210` requires `ctx.error.message` to be truthy. `ApiClientError.message` is never empty (`api_client_error.dart:105` falls back to `Request failed with 403`, and `{error:'Forbidden'}` bodies become the message), so `packages/sim_api/lib/src/auth/auth_repository.dart:13` (`status == 403 && message.isNotEmpty`) routes a message-less 403 into `auth.login.policyError` with "Request failed with 403" instead of the two-line credential copy (row 27/28).
- Fix: `status == 403 && body is Map && (body['message'] is String) && (body['message'] as String).isNotEmpty`; add the failure mode ("403 without a message is a credential error") to `login_cubit_test.dart`.

### 7. Minor — a validated absolute same-origin callback leaves the Flutter bundle
- `auth_redirect.dart:112` (`location.startsWith('http')`) makes `goToDestination('http://<origin>/workspace/x')` a top-level navigation, which lands on the React route, while the relative spelling stays in-app. entry-resolution.md §8 keys the decision on the *path* ("a callback under the Flutter prefix is a client route"). The deny-list (`/api/`, `/cli/`, …) also sends React-only paths (e.g. `/credential-groups`) into `router.go`, i.e. the GoRouter error page.
- Fix: resolve the location against the origin; when the origin matches, decide on the path, and decide from the router's route table (allow-list) rather than a prefix deny-list.

### 8. Minor — SSO page does not remount on a query change (row 23)
- `sso_page.dart:50` keys the `BlocProvider`, but the cubit is created once in `didChangeDependencies` (`:28-39`) and never rebuilt from a new `widget.query`; go_router 16.2.5 keys pages by matched path (`match.dart:250`), so `/sso` → `/sso?error=…` in-app keeps the old `formError`/`callbackUrl`/`testProviderId`. Same construction on every page (`login_page.dart:31-44`, …). Only reachable via in-app navigation to the same route with a different query, which nothing does today, so the key is misleading rather than harmful.
- Fix: key the page widget at the route (`routes.dart`: `SsoPage(key: ValueKey(state.uri.query), …)`) or rebuild the cubit in `didUpdateWidget` when `widget.query` changes; drop the no-op key on the provider.

### 9. Minor — chat-complete fallback navigates with `assign` instead of `replace`
- React `chat-complete-handoff.tsx:61` uses `window.location.replace`; `status_pages.dart:123` calls `openTopLevel` (`window.assign`, `browser_web.dart:11`), leaving the self-closing page in history. Fix: add `replaceTopLevel` to `AuthNavigator` backed by `BrowserWindow.replace` (already present, currently unused).

### 10. Minor — invite: cache invalidation, `clearUserData` and the branded support address are not ported
- invite-accept.md rows 26, 29 and Files (`useBrandConfig().supportEmail`). `invite_cubit.dart:427-434` refreshes the session only (no `subscription`/`organizations`/`workspaces` invalidation); `:459-470` always `go`s after sign-out (React falls back to a full `assign` when the in-memory reset failed) and has no store reset; `:486` hard-codes `help@sim.ai` while `SupportFooter.supportEmail` (`auth_bits.dart:278`) is never passed. Acceptable until the Phase 1 stores and brand config exist, but record it in known-gaps.md so it is not forgotten.

### 11. Minor — Turnstile is a placeholder
- auth-signup.md row 20/27: `signup_page.dart:236-240` renders an empty `Semantics` and `signup_cubit.dart:230-234` never sends `x-captcha-response`. known-gaps.md row 4 covers hosted-only surfaces in general; note explicitly that a hosted deployment with `TURNSTILE_SECRET_KEY` will refuse every Flutter sign-up.

### 12. Minor — SSO legacy input is 35 px, spec says 34
- auth-sso.md row 3 (`py-1.5` + 14/20 px line + borders = 34). `sso_page.dart:291-296` uses `sim.text.sm` whose default line height is 1.5 (`text_styles.dart:53`) → 21 px + 12 + 2 = 35. Fix: `style(14, height: 20 / 14)` for this input (the chip inputs are unaffected: fixed 36 px).

### 13. Minor — spec-vs-source note on `/verify` with verification disabled (no code change)
- auth-verify.md row 22 expects the copy "Email verification is disabled. Redirecting…"; `use-verification.ts:209-231` sets `status='verified'` in the same effect, so React shows "Your email has been verified…" after the first paint, exactly as `VerifyState.description` (`verify_cubit.dart:53-58`) does. Source wins; the spec row should be amended, and `verify_cubit_test.dart:616-628` should assert the description it claims to cover ("verification disabled: copy" asserts only the title).

### 14. Minor — dead code and small conventions
- `ResetPasswordLoadingSkeleton` (`reset_password_page.dart:168-190`) is never rendered (the page has no loading phase); either wire it or delete it.
- `SupportFooter.supportEmail` (`auth_bits.dart:273-280`) is dead (see 10).
- `LoginState.callbackUrl = '/home'` and `SsoState.callbackUrl = '/home'` literals should be `defaultPostAuthRoute`.
- `OtpInput(autofocus: true)` (`verify_page.dart:124`): the React `InputOTP` does not autofocus; spec row 27 does not ask for it. Harmless but undocumented.
- `invite_page_test.dart:655` and `auth_goldens_test.dart:790` import fixtures from `invite_cubit_test.dart`; move `invitation()`/`preview` to `test/features/auth/support/`.

### 15. Minor — test quality (04-test-plan §1)
- Headers overclaim in three places: `login_cubit_test.dart:16-18` ("cancel while sending is impossible (canSend false)" — Cancel is gated by `!submitting` in `forgot_password_modal.dart:291`, never tested; `canSend` is the Send button), `login_page_test.dart:454-455` ("Escape closes it and the cubit agrees" — `cubit.state.forgot.open` is never asserted), `verify_cubit_test.dart:386` (see 13). Goldens: see 2.
- `AuthPageOptions.fromResponses` (`auth_api.dart:21-46`) is the only place the visibility matrices are derived from network data (login row 38, signup row 14) and has no test: `'false'`/`'0'`/`false` vs unset, `ssoEnabled` falling back to `NEXT_PUBLIC_SSO_ENABLED`, `emailEnabled` as the AND of both flags, a non-map `public-env`. Add a failure-mode-first unit test.
- `HttpAuthApi` (`auth_api.dart:365-578`) is bypassed by `FakeAuthApi` and `packages/sim_api/test_contract/phase1_contract_test.dart` covers none of `sso/resolve`, `sign-in/sso`, `oauth2/public-client/prelogin`, `oauth2/consent`, `forget-password`, `reset-password`, `email-otp/*`. The request-shape rows (login 39/41/42, sso 26/27, oauth 22/23, invite 28) are therefore verified by reading only; add them to the L4 contract suite as the test plan assigns.
- Positive: every test file opens with an honest failure-mode list; the cubit tests drive fakes and timers rather than mocks-asserting-mocks; `mapLoginError`/`validateSignupPassword` tables exercise branch logic (code vs message, all-rules-at-once) rather than restating constants.

## Web / desktop
- Conditional import `browser.dart` → `browser_stub.dart` / `browser_web.dart` keyed on `dart.library.js_interop` is correct for JS and Wasm; no other `dart:html`/`dart:io`/`package:web` use in the feature. `dart:ui ImageFilter`, `BackdropFilter`, `MemoryImage(googleIconPng)` and the pure-Dart SVG path parser are web-safe. Nothing found that would break `flutter build web`.
- Windows: `AuthDependencies.resolve` falls back to memory stores and `url_launcher` for top-level navigation; social/SSO/OAuth legs open the system browser and never return to the app (plan §3 desktop handoff is Phase 6) — expected for Phase 1, not a finding.

## Spec rows verified as correctly implemented (static reading)
- auth-login.md: 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 28, 29, 30, 31, 32, 33, 34, 35, 38, 39, 41, 42. Partial: 1 (finding 1), 27 (finding 6), 40/43 (finding 5), 14 (structure verified; the `SimLayout.modal*` constants were not re-checked), 36 (Enter/Escape verified by test; initial focus not verified), 37 (plausible from widget order, not verified). 44: hosted-only, not implemented.
- auth-signup.md: 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27, 28. Partial: 1 (finding 1), 29 (finding 4), 20 (finding 11). N/A: 10 (Suspense fallback), 30 (server), 31 (hosted).
- auth-verify.md: 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 24, 25, 26, 28, 29, 30, 31. Partial: 22/23 (behaviour and copy correct, absent-flag defaults per finding 4; copy note in 13), 27 (digits-only, paste, length limit, `one-time-code` hint verified; Backspace/arrow slot movement and the autofocus difference not verified). N/A: 9 (Suspense fallback).
- auth-reset-password.md: 2, 3, 4, 5, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20, 22, 23, 24, 25. Partial: 1 (finding 1), 6 (geometry correct but never rendered, finding 14), 21 (plausible, not verified). N/A: 7, 18 (server).
- auth-sso.md: 1, 2, 4, 5, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 24, 25, 26, 27. Partial: 3 (finding 12), 6/12 (rely on `resolveButtonPaint` outline/md tokens, not re-checked), 23 (finding 8). N/A: 28, 29.
- auth-oauth-pages.md: 2, 3, 4, 5, 6, 7, 8, 10, 11 (signed-out bounce, tampered/unsigned/expired; auth-disabled N/A), 12, 13, 14, 15, 16, 17, 18, 20, 21, 23, 24. Partial: 1 (finding 1), 9 (ring tokens from `resolveChipPaint`, not re-checked), 19 (finding 9), 22 (endpoint path and `client_name` mapping verified; the React query key/stale time have no Flutter equivalent), 25 (plausible).
- invite-accept.md: 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 18, 19, 20, 21, 22, 23, 24, 25, 27, 28, 30. Partial: 1 (finding 1), 9 (route skeleton not implemented; the loading card is shown instead), 16/26 (finding 10), 17 (finding 5), 29 (finding 10), 31 (finding 3).

## Rows not verifiable statically
Colour anchors and hover/focus token resolution (`resolveChipPaint`, `resolveButtonPaint`, `SimChipChrome.fieldSurface`, modal ring/overlay constants), exact wordmark glyph geometry, tab order, modal initial focus, OTP slot keyboard navigation, the real request bodies sent by `HttpAuthApi` (no contract test), and everything marked hosted-only in the specs (analytics, Turnstile, attribution).
