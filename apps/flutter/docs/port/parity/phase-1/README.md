# Phase 1 parity outputs (L6)

Produced by `tools/parity/capture.mjs` + `tools/parity/compare.mjs` from `tools/parity/screens.json` (docs/port/04-test-plan.md §4, §5).

- `index.html`: summary table and, per screen/theme/viewport, React | Flutter | pixelmatch diff with the rows that do not pass.
- `<screen>.json`: every measure per variant (layout rows with React/Flutter rects, deltas, text, React computed styles; child counts; colour anchors with ΔE76 vs React and vs the spec token; SSIM regions; route).
- `summary.json`: the §5 report schema (`suite: parity`).
- `<screen>/<theme>-<WxH>-{react,flutter,diff}.png`: captures at deviceScaleFactor 1.

Re-run (stack, proxy on :3001 and `flutter run -d web-server --web-port 8087` up), from `tools/parity`:

    SIM_SEED_PATH=<seed.json> node capture.mjs [--screens a,b] [--viewports 1440x900] [--themes light]
    SIM_SEED_PATH=<seed.json> node compare.mjs        # exit 1 on any gate failure; PARITY_REPORT_PATH overrides summary.json

Gates: rect delta ≤ 1 px per parity id (an id not exposed in the Flutter semantics tree fails as `id-missing`), ΔE76 ≤ 2 Flutter vs React at each anchor, SSIM ≥ 0.98 over the configured regions with text and icon pixels masked, same final route.

`auth-verify`: on this stack email verification is disabled, so both apps take the skip path (`/verify` → `/home` → `/login` without a session); the OTP form needs the Mailpit profile.
