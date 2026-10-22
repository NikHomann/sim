# Flutter port of the Sim frontend: architecture and phase plan

Status: v2 (2026-10-21), revised after three independent reviews (`reviews/*-v1.md`). **Phase 0 completed 2026-10-21**: all five spikes passed (`spikes.md`), the L0 gate (`tools/ci.ps1`) is green across `sim_workflow` (223 tests), `sim_design` (48), `sim_api` (95 + 3 live contract tests), `sim_canvas` (49), `tools/seed` (12) and the app, `generated/` is populated and verified by `check_generated.dart`, the reference stack runs from the prebuilt images with seeded data, and the three upstream endpoints are written and type-checked (runtime verification needs a locally built app image). Open: the `blocks.g.dart` size decision (§4.5 note in `spikes.md`).

**Phase 1 completed 2026-10-22** (auth pages, entry resolution, workspace chrome, sidebar with workflow tree, search palette, workspace switcher, workspace modals, data layer). Verified by `tools/verify_phase.ps1` in one sequential run: L0 gate green across all packages; parity 24/24 variants PASS (8 screens × 1440x900/1280x800 × light/dark where applicable; max box delta 0.69 px, max ΔE 0.4, SSIM ≥ 0.998; report `docs/port/parity/phase-1/index.html`); L5 e2e smoke 7/7 (UI sign-in through the Flutter login, workspace home, seeded tree, Ctrl+K, filter, Enter opens the workflow); L4 contract 13 pass + 3 skipped (the three new upstream endpoints need a server image that contains them; a local Next build is not feasible on this machine). Specs and reviews: `specs/*.md`, `reviews/phase1-*-review-v1.md`; accepted gaps: `known-gaps.md` rows 7–17. Nothing is committed yet. Companion docs: `01-editor-architecture.md`, `02-design-system.md`, `03-api-and-auth.md`, `04-test-plan.md`.
Upstream baseline: commit `27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c` (v0.9.30, main), recorded in `docs/port/UPSTREAM_COMMIT`.

## 1. Goal and definition of done

Build `apps/flutter`, a Flutter application that reproduces the Sim **product app** (not the marketing site) so that, screen by screen, it looks and behaves the same as the React app in a desktop browser, and also ships as a Windows desktop app. The React app remains the reference; the Flutter app is a client of the Sim backend plus three small server additions (section 5).

"Looks and works the same" is made testable per screen by a parity checklist (`04-test-plan.md` §4): identical layout boxes and resolved tokens at parity anchors, identical states and transitions, identical network and socket traffic for the same user actions, and structural image similarity on non-text regions.

## 2. Decisions and assumptions

Decided by the user on 2026-10-21: product app only, phased; Flutter Web (desktop widths) + Windows; existing backend with small additions allowed; location `apps/flutter` in the monorepo.

In scope (routes): everything under `app/(auth)`, `app/workspace/**`, `app/o/**`, `app/account/**`, `app/selfhost/**`, `app/invite`, `app/home`, `app/workspace` (picker), `app/o` (entry), `app/access-requests`, `app/upgrade`, `app/knowledge/github/setup`, `app/f/[token]`, `app/unsubscribe`, `app/enterprise/claim/[id]`, `app/oauth-error`, `app/oauth/*` return pages, `app/(interfaces)/chat/[identifier]` (deployed chat UI) and `app/(interfaces)/resume/**`.
Out of scope: `app/(landing)/**`, `app/desktop/**`, `app/cli/**`, `app/slack-search/**`, `app/credential-groups/**`, `app/benchmark`, `app/o/[id]/benchmark` (redirects there), `app/playground`, emails, `.well-known`, `llms*.txt`, `ingest`, sub-768px mobile layouts, desktop-shell-only settings sections (`desktop`, `browser`, `terminal`) and desktop-only stores (`browser-session`, `copilot-terminal`, desktop update state, computer-use status).

Assumptions (flag if wrong):
- Conventions follow the sibling OttoFrontend app: BLoC/Cubit + `flutter_bloc`, GetIt, go_router, Dio, `very_good_analysis`, a design package, `alchemist` goldens, `integration_test` e2e, `dart_mappable`/`json_serializable` for DTOs. Reusable OttoFrontend code is ported, not depended on: the fetch streaming `HttpClientAdapter` (`lib/infrastructure/api/web_streaming/`), the loopback auth server (`localhost_auth_server.dart`), the e2e seams (`integration_test/support/`).
- English only (no i18n upstream).
- Whitelabeling (`ee/whitelabeling`, `BrandedLayout`) is in scope because self-hosted deployments use it. Consent banner (c15t) and PostHog/GA are hosted-only and are built from the React code but verified by review only.
- Toolchain: Flutter 3.38.9 stable / Dart 3.10.8 as installed. Every package is pinned to a version that resolves on Dart 3.10 (e.g. `desktop_drop` 0.8.4) and recorded in `docs/port/TOOLCHAIN.md`; upgrading Flutter is a separate decision for the user.

## 3. Runtime and serving model

**Web: same origin, path prefix `/app/`.** Cookie sessions, Better Auth's origin check and the single-origin CORS policy require it (`03-api-and-auth.md` §7). `web/index.html` hard-codes `<base href="/app/">`; `flutter build web --base-href /app/`; `usePathUrlStrategy`; go_router routes are declared **without** the `/app` prefix (the base href supplies it). Routes mirror the React paths 1:1, so `/app/workspace/{id}/w/{workflowId}` is the Flutter twin of `/workspace/{id}/w/{workflowId}`. Links the backend emits to React paths are rewritten by prefix on navigation.
- Production/self-host: `docker/flutter.Dockerfile` builds the bundle; `docker-compose.flutter.yml` adds a Caddy service routing `/app/*` → static bundle (with the CSP the Flutter page needs: `wasm-unsafe-eval`, `connect-src` for the socket origin; COOP/COEP left `unsafe-none`, CanvasKit renderer), `/socket.io/*` → realtime:3002, everything else → simstudio:3000.
- Development: `apps/flutter/tools/dev_proxy.mjs` (Node built-ins only) on `http://localhost:3001` does the same routing, strips `/app` when forwarding to the Flutter dev server, passes WebSocket upgrades, keeps SSE unbuffered, and can log requests for parity. The app runs with `flutter run -d web-server -t lib/main_dev.dart --web-port 8087 --web-hostname localhost`: the dev server honours the base href and serves under `/app/` itself (the proxy forwards the prefix unchanged), DWDS connects through the proxy and hot restart (`R`) works. `-d chrome --web-launch-url http://localhost:3001/app/` does not work (DWDS cannot establish its app connection for a page on another origin); verified in `spikes.md` (a). `TRUSTED_ORIGINS=http://localhost:3001` in the stack's `.env` makes Better Auth accept sign-in from the proxied origin; `3001` is already the CORS fallback origin in `proxy.ts`.

**Windows desktop.** Same codebase; `window_manager` for the frame. Dio uses a persistent cookie jar (`cookie_jar` + `dio_cookie_manager`, `dart:io`-only via conditional import, stored under `flutter_secure_storage`). Sign-in reuses the existing desktop handoff instead of a new flow: system browser → `/desktop/auth?...` → loopback listener (RFC 8252, ported from OttoFrontend) → one-time token redeemed at `/api/auth/one-time-token/verify` into a separate desktop session (`apps/sim/app/api/desktop/auth/handoff/route.ts`, `lib/auth/desktop-handoff.ts`, port validation in `app/desktop/auth/validation.ts`). This covers email, social and SSO on desktop in one flow. Direct `POST /api/auth/sign-in/email` from Dio is an optional fast path, and "a request without an Origin header passes Better Auth" is a Phase 0 contract test, not an assumption. Socket.IO on Windows is websocket-only (`socket_io_client` native builds), which the server lists first.

**Runtime config.** Required server addition `GET /api/public-env` (section 5) returns the `NEXT_PUBLIC_*` transport before login; `GET /api/auth/providers` gives login options; after login, `GET /api/workspaces/[id]/host-context` gives the deployment shape and the new `GET /api/workspaces/[id]/feature-flags` the server-resolved feature flags.

**Entry resolution the server does today, replicated client-side:** `/home` and `/o` → `resolveAppEntryPath` (`lib/navigation/resolve-app-entry.ts`); `/workspace/[id]` → `home` or `w` by `chatEnabled` (`workspace/[workspaceId]/page.tsx:20`); `/workspace` picker with stale-session recovery and `?redirect=upgrade|settings` (`workspace/page.tsx:128-232`); `/o/[id]` redirect; `home/layout.tsx` redirect when chat is disabled; legacy settings redirects (`settings/[section]/layout.tsx:17-24`); superuser flag for `/account/settings/admin`.

## 4. Architecture

```
apps/flutter/
├── pubspec.yaml                      # app: sim_app
├── web/index.html                    # <base href="/app/">, flutter_bootstrap.js (CanvasKit)
├── lib/
│   ├── main_web.dart, main_windows.dart, main_dev.dart
│   ├── bootstrap.dart                # error handling, BlocObserver, GetIt locator
│   ├── app/                          # router, locator, theme mode, shell wiring, entry resolution
│   ├── features/<feature>/           # cubit/ + view/ per feature, mirroring React route folders
│   │   ├── auth/, workspace_shell/, workflows/{list,editor,preview,diff}/
│   │   ├── workflows/editor/subblocks/<type>/   # one directory per subblock type (47)
│   │   ├── chat_engine/              # MothershipChat + stream v1 client (shared by copilot and Home)
│   │   ├── home/, chat/, logs/, knowledge/, tables/, files/, skills/, integrations/,
│   │   │   tests/, dashboards/, changelog/, settings/, upgrade/, access_requests/
│   │   ├── account/, organization/, selfhost/, invite/, oauth_return/, public_share/
│   │   └── interfaces/{chat,resume}/ # deployed chat UI and resume pages
│   └── shared/
├── packages/
│   ├── sim_design/     # tokens, themes, fonts, icons, emcn-equivalent widgets (no sim_* deps)
│   ├── sim_workflow/   # pure Dart: workflow types, generated registry, serializer, edge rules,
│   │                   # dimensions, diff engine, realtime protocol vocabulary + abstract transport,
│   │                   # operation queue, undo/redo model, reference-token tokenizer
│   ├── sim_api/        # Dio client, fetch stream adapter, DTOs/contracts, SSE decoders, uploads,
│   │                   # socket transport (socket_io_client), auth, KeyValueStore, Query<T>
│   └── sim_canvas/     # graph editor engine (viewport, node layer, edge painter, selection, DnD)
├── generated/          # output of the upstream extraction script (committed)
├── tools/              # dev_proxy.mjs, gen/ (Dart codegen), seed/, parity/, ci.ps1|sh, checks
├── test/, test_contract/, integration_test/
└── docs/port/          # these documents, specs/<screen>.md, parity/, known-gaps.md, TOOLCHAIN.md
```

Dependency direction: `sim_design` → Flutter + third-party only; `sim_workflow` → Dart only; `sim_api` → `sim_workflow`; `sim_canvas` → `sim_design`, `sim_workflow`; app → all. The realtime vocabulary lives in `sim_workflow` so the operation queue and undo/redo stay pure Dart; `sim_api` implements the transport.

### 4.1 State management
- Cubits per feature. React global zustand stores become GetIt-registered long-lived cubits (session, workspaces, sidebar, theme, toasts, modals, operation queue, presence, execution, terminal console, undo/redo, workflow diff, feature flags, branding, tool permission, mothership queue/drafts/effort, pinned items, resource list preferences, settings dirty state); page-scoped stores become page cubits.
- Editor state keeps the React split exactly: `WorkflowStructureCubit` (blocks, edges, loops, parallels) and `SubBlockValuesCubit` (live values, `null` = cleared), merged by the `mergeSubblockState` rules; every write goes through the collaborative path. To avoid the 200-block rebuild problem: per-block `BlocSelector`/`context.select` on identity-stable sub-objects (only replaced entries get a new identity; no deep equality over the block map), live drag positions in per-node `ValueNotifier`s committed at drag end (mirrors the 33 ms coalescing), subblock values keyed `(workflowId, blockId, subblockId)` in persistent maps (`fast_immutable_collections`).
- Server data: `Query<T>` in `sim_api` (cache keyed like the React query keys, staleTime, invalidation, cancellation, focus refetch), wrapped by cubits.
- URL state: a `UrlStateCubit` per page owns filters/tabs/selection and writes `router.replace` throttled; pages derive from the cubit so query churn does not rebuild the screen. Keys match the React nuqs keys.
- Persistence: `KeyValueStore` abstraction (IndexedDB via `package:web` on web; file/sqlite on Windows) for console entries, undo stacks, drafts, autosave. React-shared keys (`sim-theme`, `sidebar-state` in localStorage, `sidebar_collapsed` cookie) are read and written through `package:web` directly so both apps agree. Store reset on sign-out mirrors `reset-all-stores` / `user-data-reset-registry`.

### 4.2 Design system (`sim_design`)
- `SimTokens`: every value in `02-design-system.md` §1 as constants; light/dark `ThemeExtension`s; text scale as named styles that set `fontVariations: [FontVariation('wght', n)]` (variable fonts ignore `FontWeight`); radii, shadows, z-order ladder, motion durations/curves (zeroed under the e2e define).
- Fonts: Season Sans converted WOFF2 → TTF by the extraction step (Flutter does not load WOFF2); Inter variable bundled; mono fallback. License check is an open question (section 9).
- Widgets mirroring emcn with the same names and variants (chip family, 12 button variants, dropdown/context menu, popover, cursor-following tooltip, toast stack, modal family, inputs, badge, skeleton, table, tab strip, details panel, scroll fade, overflow text, code editor on `re_editor` + `re_highlight`, charts on `fl_chart`).
- Icons: 191 emcn icons and ~370 brand icons extracted to SVG, precompiled with `vector_graphics_compiler` to `.vec` (runtime parsing of 560 SVGs is too slow); gradients are supported, the one `<filter>`, one `<mask>` and 16 raster `<image>` icons get a PNG@2x fallback recorded by the script; `currentColor` via `SvgTheme`.
- `OverlayManager` implementing the z-index ladder; keyboard shortcuts via handled `KeyEvent`s with `preventDefault` for browser-reserved combos (Mod+L, Mod+K).
- Semantics are enabled (`SemanticsBinding.ensureSemantics`) so parity ids and e2e finders work on web.

### 4.3 API layer (`sim_api`)
- `SimHttpClient` (Dio): base URL = page origin on web, configured origin on desktop; `withCredentials` on web; cookie jar on desktop; header `x-sim-client-id` (the only client header upstream sends); error envelope → `ApiClientError{status, message, code, body}`; rate-limit headers surfaced.
- Streaming: a fetch-based `HttpClientAdapter` on `package:web` (ReadableStream, AbortController, credentials) ported from OttoFrontend, with a `dart:io` stub; Dio's XHR adapter cannot stream. `SseDecoder` handles `data:` frames split across chunks, comments, named events, bare and JSON-quoted `[DONE]`; typed decoders for the execution stream, API-flavour stream, mothership stream v1, table events, wand.
- Contracts: one Dart file per upstream contract file (`apps/sim/lib/api/contracts/**`), DTOs generated from the exported JSON schemas where possible.
- Uploads: `UploadSession` implementing the signed-session protocol (put and multipart, 3 concurrent parts, retries, abort).
- Realtime: `SocketTransport` over `socket_io_client` (fresh one-time token per connect via `setAuthFn`, `enableForceNew` on re-creation, websocket-only on desktop, websocket+polling on web); unknown events (e.g. Yjs file-doc rooms) are tolerated. The queue semantics live in `sim_workflow`.
- Auth: `AuthRepository` for the Better Auth endpoints (`03-api-and-auth.md` §1), desktop handoff, session cubit with focus refetch.
- Runtime loaders mirroring React providers: deployment shape, feature flags, block visibility (`/api/blocks/visibility`), custom blocks (`/api/custom-blocks`, overlaying the registry), provider models (feeds the agent model lists), settings, branding, workspace permissions (with the "Reconnecting…" anti-flicker timing), workspace scope sync.

### 4.4 Workflow domain (`sim_workflow`, pure Dart)
- Types ported from `packages/workflow-types` (48 subblock type ids; 47 have editors, `webhook-config` is configured through the webhook management hook instead).
- Block registry: generated data for 369 blocks and 83 triggers. Function-valued config is handled per class, with counts from the review: `tools.config.tool` (292 files) is what the client needs for serialisation and validation; the extraction samples each with every `operation` option and emits a decision table when the function is a pure switch on params (the common case), and lists the rest for Dart ports. `tools.config.params` (274 files) is execution-side and not ported. `options` functions (9 files, mostly provider model lists → fed by the provider-models loader), `condition` functions (6 files), `required` functions (6 files) and the deployment-shape read in `function.ts` are hand-ported with sampled-output tests. Icons are generated assets.
- Ported algorithms with the upstream file in the doc comment: `mergeSubblockState`, `generateLoopBlocks`, edge rules, handle ids and `HANDLE_POSITIONS`, dimensions, serializer (`serializeWorkflow`/`deserializeWorkflow`, `collectBlockFieldIssues`), canonical pairs, diff engine, undo/redo entries, auto-layout, the reference-token tokenizer (`<block.output>`, `{{ENV}}`), condition DSL (`{field, value, not, and}`), `dependsOn` cascades.
- Realtime protocol vocabulary (`packages/realtime-protocol`) and the operation queue (one in flight, 5 s/15 s timeouts, retries, superseding, offline mode, remote-apply guard, join generation guard).
- Fixture conformance: the extraction dumps sample workflows and their upstream serializer/diff/loop outputs so ports are tested against upstream results.

### 4.5 Extraction and codegen (re-runnable per upstream version)
`apps/sim/scripts/export-flutter-port.ts` (server addition 1) runs inside a one-off container built from the repo with bun (not the runtime app image, which ships no sources) and writes `apps/flutter/generated/`: `blocks.json`, `tools.json`, `triggers.json`, `subblock-types.json`, `tool-selector-tables.json`, `closures.json` (what must be hand-ported), `icons/{emcn,brand}/*.svg` (+ raster fallbacks), `tokens.json`, `css-measurements.json` (computed styles of emcn variants from rendered React), `fonts/*.ttf`, `fixtures/*.json`, `contracts/*.schema.json`. `tools/gen/` turns these into Dart. `tools/check_generated.dart` verifies counts, determinism and the recorded upstream commit. Generated files are committed.

### 4.6 Canvas engine (`sim_canvas`)
Own implementation. Viewport: pan/zoom 0.1–1.3 around the cursor, wheel/trackpad/keyboard, fit-to-view, snap-to-grid. Node layer: a custom render object (or a Stack sized to the content bounds with an origin offset) so nodes outside the viewport box stay hit-testable; one `RepaintBoundary` per node; raster-cached transform during gestures, crisp repaint at rest. Edge layer: `CustomPainter` with the smooth-step port (radius 8), explicit `hitTest` sampling `PathMetrics` at hit width 30 in canvas units, animated dash for run state. Handles with canonical ids and positions; connection drag from handles and from the perimeter "swell" border (port of `border.tsx` path math); partial marquee selection; multi-select modifiers; drag with 33 ms coalesced position updates; nested containers (`parentId`/`extent: parent`, drop highlight, reparent, clamping); remote cursors; context menus at cursor; dynamic handles for condition/router rows. A Phase 0 spike with 200 synthetic nodes sets the architecture before any screen depends on it.

### 4.7 Hard pieces and chosen approaches
| Piece | Approach |
|---|---|
| Reference-token fields | `TextEditingController.buildTextSpan` colouring tokens in place; tag dropdown as a `Popover` with the same scoped resolution (Phase 3); tokenizer in `sim_workflow` from Phase 0. |
| Code fields | `re_editor` + `re_highlight` (js, ts, python, json, sql); per-field undo in memory (React persists it: recorded in `known-gaps.md` unless a custom controller is budgeted); search highlight; password masking. |
| Rich markdown (TipTap) in notes, files, skills | `gpt_markdown` for rendering; a markdown editor with toolbar for editing. No Dart Yjs: live co-editing of files and skills is a declared gap; notes are single-editor and unaffected. |
| Monaco text editor (files) | `re_editor`. |
| xterm terminal session (home) | `xterm` 4.0.0, compile-checked in Phase 0 (no release since 2024). |
| Charts | `fl_chart` styled to emcn. |
| Virtualised lists / table grid | `ListView.builder`; `two_dimensional_scrollables` `TableView`. |
| HTML5 drag and drop | `Draggable`/`DragTarget` with the same visual states; `desktop_drop` 0.8.4 for OS file drops. |
| Clipboard | Flutter `Clipboard` (text/JSON); `super_clipboard` only if image/HTML paste is needed. |
| Downloads (CSV export, files) | `package:web` anchor click on web; save dialog on Windows. |
| Speech to text | `/api/speech/token` + Web Speech on web; desktop gap until a plugin is chosen. |

## 5. Server-side additions (each a separate upstream PR)
1. `apps/sim/scripts/export-flutter-port.ts` (dev-only extraction, §4.5).
2. **Required:** `GET /api/public-env` (the `NEXT_PUBLIC_*` transport as JSON), `GET /api/workspaces/[id]/feature-flags` (the flags `workspace/[workspaceId]/layout.tsx:140-180` resolves server-side: dashboards, workflow-tests, changelog, mothership model selector / computer use / plan mode, projects, desktop background executor), `GET /api/organizations/[id]/surface-context` (membership, mothership availability, search access, benchmark/admin bits from `o/[organizationId]/layout.tsx`), and a superuser/platform-admin flag (via `get-session` custom session or `/api/users/me/profile`). Without these the sidebar, tests gate, mothership options and `/o/*` cannot be gated correctly.
3. `docker/flutter.Dockerfile` and `docker-compose.flutter.yml` overlay (Caddy, Mailpit, `POSTGRES_DB=simstudio_test`, `TZ=UTC`, `TRUSTED_ORIGINS`).

## 6. Phases

Each phase ends with: specs and parity checklists complete for its screens, L0 gate green, suites green against a freshly seeded stack with JSON reports, reviewer sign-off, parity report in `docs/port/parity/<phase>/`.

**Phase 0: Foundation (≈12 %).** Scaffold app + four packages, `TOOLCHAIN.md`, CI gate; spikes with pass/fail: (a) dev proxy + `flutter run -d chrome` behind `/app/`, (b) SSE over POST on web through the fetch adapter against `/execute`, (c) 200-node canvas pan benchmark on CanvasKit and Windows, (d) Better Auth sign-in from desktop without an Origin header, (e) `xterm` compile; tokens, `FontVariation` text styles, fonts (WOFF2→TTF), themes; icon extraction + `.vec` precompilation; emcn widget set with goldens; `sim_api` client, fetch adapter, SSE decoders, `Query<T>`, `KeyValueStore`, auth repository, session cubit, runtime loaders; `sim_workflow` types, tokenizer, protocol vocabulary, operation queue; extraction script + generated registry + closure inventory; docker overlay (Caddy, Mailpit), SQL seed + cookie minting; the three required endpoints (PR to upstream).

**Phase 1: Auth and workspace shell (≈10 %).** Auth pages (login, signup, verify OTP, reset-password, SSO, OAuth consent/sign-in, oauth-error, forced light); entry resolution (`/`, `/home`, `/workspace`, `/workspace/[id]`, `/o`); workspace chrome (sidebar resize/collapse/hover-peek, workspace header + switcher with pinned items, search palette, help modal, account/help menus, theme switching, toasts, shortcuts), sidebar workflow list with folders (tree, DnD, context menus, inline rename, duplicate, delete, reorder, presence avatars), workspace create/settings/invite modals, invite accept page, session-expired, impersonation banner, workspace/organization access-denied pages, whitelabeling/branding, settings navigation guard (dirty state), paste admission guard, store reset on sign-out, feature-flag and custom-block loaders, placeholder pages for every in-scope route.

**Phase 1.5: Chat engine and Home chat (decided by the user 2026-10-22; Phases 2 and 3 keep their scope).** The Mothership chat engine moved forward from Phase 3/4: the stream v1 client and `useChat` state machine (`app/workspace/[workspaceId]/home/hooks/**`, `use-chat.ts`), reconnect and stop, tool calls with the permission flow (`stores/tool-permission`), queued messages and drafts (`stores/mothership-queue`, `mothership-drafts`), effort (`mothership-effort`), the chat events SSE (`use-mothership-chat-events`), chat CRUD; message rendering (`home/components/message-content/**`: markdown, thinking, agent groups, sources, special tags, questions/options, watch activity); the Home page (`home/**`: hero, suggested actions, user input with prompt editor, mentions/contexts, plus menu, skills menu, attachments via upload sessions, mic on web, credits chip, the resources panel `mothership-view/**`) and `/workspace/[id]/chat/[chatId]`; the sidebar Chats section then shows live chats. The editor's copilot tab (Phase 3) reuses this engine. Testing (user decision 2026-10-22): both a local mock server replaying stream-v1 sessions (deterministic e2e/CI, `tools/mock_copilot`) and the user's real `COPILOT_API_KEY` in the stack's `.env` for live manual testing and a live parity pass. Out of scope here: anything that needs the canvas (edit_workflow diffs land with Phase 3), Phase 4 resource types beyond what the resources panel needs to render a placeholder.

*Phase 1.5 status (2026-10-22): complete against the mock copilot.* Specs `specs/{chat-engine,chat-messages,chat-input,home-page,agent-service-protocol}.md`; code in `lib/features/chat/{engine,messages,input,integration}` and `lib/features/home`, client in `packages/sim_api/lib/src/mothership`. Two review rounds (engine, UI) fixed 13 defects with regression tests. `tools/verify_phase.ps1` green: gate, parity 32/32 (the `home-chat-seeded` SSIM gate leaves out the panel body until Phase 4, known-gaps row 45) and e2e `phase1_smoke_test` + `phase15_chat_test`. The e2e flow needs the stack's agent service on `tools/mock_copilot` (README there; the app container is recreated with `SIM_AGENT_API_URL`/`COPILOT_API_KEY` set in the shell only). Not yet done: the live pass with a real `COPILOT_API_KEY`, and the permission card against a server with `COPILOT_TOOL_PERMISSIONS_ENABLED=true` (the compose copy does not pass that variable through). Gaps: known-gaps rows 18–45. Voice input is not ported.

**Phase 2: Workflow editor core (≈20 %).** Canvas engine; block, note (read view), subflow nodes; edges incl. dynamic condition/router handles; toolbar palette with drag-to-canvas and sandbox constraints; block editor panel with 19 subblock types (short-input with token highlighting, long-input, dropdown, combobox, switch, slider, code, table, file-upload, file-selector, project-selector, folder-selector, oauth-input display + connect, tool-input basic, skill-input, messages-input, input-format, condition-input, router-input), covering every core block (starter, agent, function, condition, router, api, loop, parallel); realtime collaboration end to end (join, operations, queue, presence, cursors, selections, offline mode, deleted/reverted/deployed/access-revoked notices); undo/redo; run with execution SSE, rings, animated edges, terminal console with JSON tree and `KeyValueStore` persistence; variables; action bar, context menus, workflow controls, command list; deploy modal (deploy/undeploy/versions).

**Phase 3: Editor completeness and chat engine (≈25 %).** Remaining 28 subblock editors; tag dropdown; wand; search and replace; diff view and controls; the shared chat engine (`MothershipChat`, `useChat` stream v1, tool permission flow, queued messages, drafts, effort) and the copilot panel on it; floating test chat; note editing; auto-layout; workflow preview and version diff; focus-block deep links; canvas mode; workflow tests surface.

**Phase 4: Workspace surfaces (≈20 %, parallelisable after Phase 3).** Home (on the chat engine: resources panel, attachments, suggested actions, voice on web, chat events SSE with rotating source, organization chat mode), Chat pages, Logs (list, filters, details with snapshot and trace, dashboard, export, panel width persistence), Knowledge (bases, documents, chunks, tags, connectors incl. GitHub setup page, uploads, connector-setup drafts surviving OAuth), Tables (grid, cell editors, columns, views + pin, filters, groups, imports with tray, exports, enrichments, live events, undo/redo), Files (list, folders, viewer, `/view` route, text/markdown editing with autosave, share modal, public share page `/f/[token]`), Skills (list, `new`, `[skillId]`, rich editor with autosave, members), Integrations (showcase, per-block pages, connected credentials, OAuth connect, service-account and Slack-bot modals, OAuth return hooks), Tests, Dashboards, workspace Changelog, add-to-chat.
**Phase 4b: Public interfaces.** `(interfaces)/chat/[identifier]` (email OTP, password and SSO auth modes, header, input, message rendering, API-flavour stream, error/loading states; voice gap on desktop) and `(interfaces)/resume/**`.

**Phase 5: Settings, account, organization (≈8 %).** 28 workspace-plane settings sections (31 in `components/settings/navigation.ts` minus the 3 desktop-only) with their gating rules (`requiresHosted`, `requiresEnterprise`, `requiresMax`, `requiresSuperUser`, `requiresAdminRole`, `selfHostedOverride`, `organizationSection`) ported as data; detail routes (`settings/secrets/[credentialId]`, `settings/usage/events`, `settings/billing/credit-usage`); 17 organization settings sections and their detail routes (`integrations/{secrets, providers/[connectorType], sources/[connectorId]}`, `usage/events`) plus organization home/chat/search/integrations/providers/skills/access-requests; 5 account sections + `billing/credit-usage`; 3 self-host sections; upgrade and billing with fullscreen-origin return; access requests; recently deleted; custom tool editor; credential detail; `unsubscribe`; `enterprise/claim/[id]`.

**Phase 6: Windows desktop (≈5 %).** Window chrome, cookie jar, desktop handoff sign-in, file pickers and drops, clipboard, packaging (MSIX, signing cert, ATL for `flutter_secure_storage`), Windows smoke e2e.

Sequencing: 0 → 1 → 2 → 3 strictly; Phase 4 surfaces in parallel after 3 (Home needs the chat engine); 4b and 5 in parallel after 1 (5 needs the flags endpoint); 6 after 1 for the shell, closing after 3.

## 7. Agent orchestration

Roles (fresh agents with written briefs pointing at these docs and the upstream files):
- **Mapper** (read-only): per-screen spec before it is built: React files, measurements, parity ids and anchors, every state, every network/socket call, every interaction. Output `docs/port/specs/<screen>.md` ending in the parity checklist.
- **Implementer**: one spec or one package area on disjoint files (one directory per subblock type, one package per owner); writes the failure-mode list before any pure-Dart module; runs the L0 gate and its tests before hand-back.
- **Reviewer** (fresh, never the implementer; given the code and the spec, not conclusions): fidelity against the React source, conventions, test quality; findings → fixes → re-check.
- **Verifier**: runs suites against the docker stack, produces parity and e2e reports, fills checklists. The React source wins over the spec on disagreement.

Rules: two writers never touch the same files; generated files are regenerated, never hand-edited; accepted gaps go to `docs/port/known-gaps.md` with the reason; upstream re-baseline cadence: once per phase, recorded in `UPSTREAM_COMMIT`, with `check_generated.dart` diffing the registry.

Session plan: Phases 0 to 2 run from this session. Phases 3 to 6 are large enough to run as their own sessions per surface, each starting from this plan and the specs.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Canvas fidelity and performance | Phase 0 spike (200 nodes) decides render-object vs Stack, RepaintBoundary and raster-cache strategy before Phase 2. |
| Realtime protocol divergence | Fixture-driven queue tests; contract test replaying recorded React socket sessions; Flutter↔React co-editing e2e. |
| Block registry drift | Re-runnable extraction; `check_generated.dart` against `UPSTREAM_COMMIT`; re-baseline once per phase. |
| TypeScript closures (292 `tool` selectors, 21 option/condition/required functions) | Decision tables for pure switches; hand ports with sampled-output tests; visible "unsupported field" marker for anything unported. |
| SSE over POST on web | Fetch adapter spike in Phase 0. |
| Yjs live co-editing (files, skills) | Declared gap. |
| Font rendering differences (browser vs Skia) | Parity compares layout boxes, tokens, anchor colours and SSIM on non-text regions, not raw pixels. |
| Hosted-only features untestable locally | Verified by review; marked in checklists. |
| Toolchain age (Flutter 3.38.9) vs package floors | Pinned versions in `TOOLCHAIN.md`; upgrade is a user decision. |
| Bundle weight (main.dart.js + CanvasKit ≈ 4–6 MB) vs Next route chunks | Deferred loading per feature; measured in Phase 1; noted as a difference, not a parity failure. |
| CSP / COOP on `/app` | Caddy sets the Flutter page's CSP; CanvasKit default, no COEP. |
| Upstream churn (weekly moves of large files) | Specs cite commit-pinned paths; re-baseline cadence above. |
| Windows packaging (signing, ATL) | Phase 6 prerequisites listed early. |

## 9. Questions for the user and their answers
1. Season Sans license: **answered 2026-10-21: may be bundled** in the web bundle and the Windows installer (recorded in `packages/sim_design/LICENSES.md`). No license file exists in the repo; the decision is the user's.
2. Dev proxy port 3001: no objection raised; in use.
3. Flutter upgrade: staying on 3.38.9 with caret ranges and `pubspec.lock` pins (`TOOLCHAIN.md`).
4. Live co-editing of files and skills (Yjs): **answered 2026-10-21: accepted gap** for the first release (`known-gaps.md` row 1).
5. Public chat interface and resume pages: in scope as Phase 4b (no objection raised).
