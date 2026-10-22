# Agent service protocol (Sim server ↔ copilot "mothership" worker)
Upstream: `apps/sim/lib/mothership/**`, `app/api/mothership/**`, `app/api/copilot/**`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c (v0.9.30). The running `ghcr.io/simstudioai/simstudio:latest` image contains the same paths (`/api/tools/resume`, `/api/sim-transport/poll`, `X-Client-Version: 3.0.0`; checked by grepping `.next/server/chunks` in the container).
Companion of `chat-engine.md` (browser ↔ Sim). This file covers the hop the browser never sees: Sim → the agent service at `SIM_AGENT_API_URL`. The mock in `flutter/tools/mock_copilot/` implements it.

Facts only. Paths relative to `apps/sim/`. `M/` = `lib/mothership/`, `R/` = `M/request/`.

## 1. Base URL, auth, headers

- Base URL: `SIM_AGENT_API_URL` when it starts with `http://` or `https://`, else `https://www.copilot.sim.ai`; protocol version constant `SIM_AGENT_VERSION = '3.0.0'` (`M/constants.ts:3-11`). Per call it goes through `getMothershipBaseURL({userId})`, which only differs for an admin with super-user mode and a `COPILOT_{DEV,STAGING,PROD}_URL` selection (`M/server/agent-url.ts:39-42,61-93`).
- Headers of every chat-path call (chat, resume, title, steer, abort, replay, transport) come from `mothershipRequestHeaders` (`R/headers.ts:10-24`):
  - `Content-Type: application/json`
  - `X-Sim-Request-ID: <id>` (chat/resume legs only)
  - `x-api-key: <COPILOT_API_KEY>` only when the env var is set — it is never checked by Sim before calling
  - `X-Sim-Source-Env: dev|staging|prod` when `COPILOT_SOURCE_ENV` is set (`M/server/agent-url.ts:95-102`)
  - `X-Client-Version: 3.0.0`
  - hosted billing headers (hosted only).
- `/api/validate-key/*` and `/api/model-router` build their own headers: `Content-Type` + optional `x-api-key` (`M/server/api-keys.ts:63-72`, `lib/model-router/resolve.ts:225-230`).
- All calls go through `fetchGo` (`R/go/fetch.ts:29`), a traced `fetch`.

## 2. Endpoints Sim calls

| Method + path | Caller | Request body | Expected response |
|---|---|---|---|
| `POST /api/mothership` | Home chat turn (`goRoute`, `M/chat/post.ts:458,700,817`) | ChatRequest (§3) | SSE of stream-v1 envelopes (§4) |
| `POST /api/copilot` | workflow-panel copilot turn (`post.ts:409,747`) | same | same |
| `POST /api/mothership/execute` | headless/API execution (`R/lifecycle/run.ts:1184-1186,1846-1849`) | same | same |
| `POST /api/tools/resume` | after a `run.checkpoint_pause` (`run.ts:1632-1661`) | `{streamId, results:[{callId,name,data,success}], receivedTextChars, receivedActivity?}` | SSE, continues the same turn |
| `POST /api/generate-chat-title` | first accepted turn of an untitled chat (`R/lifecycle/start.ts:680-693,780-798`) | `TitleRequest` strict: `{message, context?, workspaceId?, organizationId?, chatId?, userId?, byokApiKey?}` (`M/generated/protocol.ts:492-503`) | JSON `{title}`; non-2xx or missing title → no title, logged only (`start.ts:800-813`) |
| `POST /api/streams/explicit-abort` | Stop (`R/session/explicit-abort.ts:13-76`) | `{messageId}` (uuid, `protocol.ts:416`) | JSON `{settled:boolean}`; `settled:false` is polled every 200 ms; non-2xx throws |
| `POST /api/streams/steer` | mid-turn steering (`R/session/steer.ts:18-65`, used by `R/application/controls.ts`) | `{messageId, steeringId, content}` | any; `ok` → queued |
| `POST /api/streams/replay` | reconnect when Sim's Redis replay ring lost the head (`R/session/run-replay.ts:23,48-90`, `app/api/copilot/chat/stream/route.ts:318`) | `{streamId, chatId, userId}` (`protocol.ts:426-431`) | SSE of the run's envelopes from cursor 1; 401/403/404 → falls back to `replay_gap`; may end with a `run{kind:'replay_end', reason:'parked'|'cap'|'stalled', textLength}` control frame |
| `POST /api/sim-transport/poll` | long-poll receiver started at boot when `COPILOT_API_KEY` is set and the transport mode is `checkpoint` (`M/transport/receiver.ts:59-135`, `instrumentation-node.ts:412-413`) | `{channelId, accepts:[kinds]}` | JSON `{requests: unknown[] (≤16)}` (`M/generated/sim-transport.ts:89`); 30 s client timeout; failure → retry after 1 s |
| `POST /api/sim-transport/reply` | answers a polled control request (`receiver.ts:88-99`) | `{channelId, id, result}` | 2xx or 410 |
| `GET /healthz` | file-owner protocol probe, only when a chat has file owners (`R/lifecycle/file-owner-protocol.ts:10-23`, `M/application/file-owner-context.ts:26-40`) | — | 200; header `X-Mothership-File-Owner-Protocol: 1` enables the protocol |
| `POST /api/tasks/status` | task status read (`M/tasks/application/read-status.ts:23-35`) | `{taskId}` | JSON `InternalTaskStatus`; 404 → not found |
| `POST /api/validate-key/{get-api-keys,generate,…}` | copilot API-key settings (`M/server/api-keys.ts:51-120`) | `{userId, …}` | JSON (array for get, `{id, apiKey}` for generate) |
| `POST /api/model-router` | `sim-auto` model choice in workflow blocks (`lib/model-router/resolve.ts:219-256`) | `{signals, candidates, …}` | JSON; non-OK → ignored |
| `POST /api/chats/fork`, `/api/tasks/cleanup`, `/api/memories/cleanup`, `/api/workbench/bootstrap`, `/api/admin/*` | fork, cleanup jobs, sandbox, admin proxy (`M/chat/fork-worker.ts:59,103`, `lib/cleanup/chat-cleanup.ts:271`, `M/memories/cleanup-outbox.ts:109`, `M/tools/sandbox-session.ts:80`, `app/api/admin/mothership/route.ts:196`) | — | not needed for chat; the mock answers 404 |

## 3. Chat request body (`/api/mothership`, `/api/copilot`)

Built by `buildCopilotRequestPayload` (`M/chat/payload.ts:321-520`), then `protocolVersion: 2` is added (`post.ts:1403`, `protocol.ts:25`), then the lifecycle adds (`run.ts:1183-1236,1320-1331`): `simConnection` (§6), `workspaceId`, `systemPromptOverride` (when `MSHIP_SYSPROMPT_OVERRIDE`), file-owner hints, `byokApiKey` (enterprise), and the receipt `receivedTextChars` (+ `receivedActivity`).

Fields (`payload.ts:465-519`): `entitlements`, `message`, `workflowId?`, `workspaceId?`, `organizationId?`, `userId`, `mode: 'assistant'|'plan'|'agent'`, `assistantSearchLevel?`, `assistantFast?`, `assistantSearch?`, `assistantImages?`, **`messageId`** (the user message id; also the stream id Sim uses everywhere after), `chatId?`, `context?: [{type, content, tag?, path?}]`, `integrationCatalog?: {mcpServerIds}`, `userTimezone?`, `effort?`, `modelSelection?`, `inventory?`, `desktop?`, `clientCapabilities: ['workflow-tool-pickup'?, 'tool-deadline']`.

A retry or recovery re-sends the same `messageId` with the current `receivedTextChars`; the worker treats it as a re-attach and re-sends the response, never a second run (`R/lifecycle/stream-retry.ts:13-21`, `R/session/stream-recovery.integration.ts:251-254`).

## 4. Response stream format

- `200` with an SSE body: `data: <JSON>\n\n` frames, `: comment` keepalives (the worker writes one after 10 s of silence; `M/constants.ts:13-22`), optional `data: [DONE]`. Parsed by `processSSEStream` over `readSSELines` (`R/go/parser.ts:31-68`); one unparseable `data:` line is fatal.
- Each frame is a **stream-v1 envelope**, the same shape the browser sees (`chat-engine.md` §2.2): `{v:1, type, seq, ts, stream:{streamId, chatId?, cursor?}, trace?:{requestId, goTraceId?}, scope?:{lane:'subagent', agentId?, parentToolCallId?, spanId?, parentSpanId?}, payload}`. Validated with `parsePersistedStreamEventEnvelope` (`R/go/stream.ts:407-420`, rules `R/session/contract.ts:233-341`); invalid → `FatalSseEventError`. Sim then re-sequences: it allocates its own `seq`/cursor when it republishes (`chat-engine.md` §2.4), so the worker's `seq` only has to be a finite number.
- Event types the worker sends and what Sim does with them:
  - `session{kind:'start'}` (forwarded). `session{kind:'chat'|'title'}` are Sim's own (`start.ts:393-400,707-710`).
  - `text{channel:'assistant'|'thinking', text, textOffset?}`. `textOffset` (UTF-16 units of main-lane assistant text across all legs of the turn) is reconciled before forwarding: offset > received → `StreamContinuityError` (retry); overlapping text must match exactly, the duplicate prefix is dropped (`R/go/text-receipt.ts:18-35`). Subagent-lane and thinking text are not counted (`R/handlers/text.ts:62-81`).
  - `tool{phase:'call'|'args_delta'|'result', toolCallId, toolName, executor:'go'|'sim'|'client', mode:'sync'|'async', arguments?, status?, partial?, ui?, …}`. Routing (`R/handlers/tool.ts:675-706`): a call is dispatched by Sim only if the catalog route is `sim` (`M/tool-executor/router.ts:12-14`) and `executor !== 'go'`, or `ui.simExecutable`/`ui.clientExecutable`, and not `ui.internal`/`ui.inbandOwned`. `executor:'go'` calls are display-only: the worker sends their `result` itself. Partial frames (`partial:true` or `status:'generating'`) only draw the row (`tool.ts:571-572,654`).
  - `span{kind:'subagent', event:'start'|'end', agent, data:{tool_call_id, name?, error?, pending?}}` with `scope.lane:'subagent'` (`R/handlers/span.ts:31-90`); frames inside the lane carry the same `scope`.
  - `run{kind:'checkpoint_pause', checkpointId, executionId, runId, pendingToolCallIds, frames?}` ends the leg (`R/handlers/run.ts:75-99`); other run kinds per `chat-engine.md` §2.3.
  - `resource{…}` (applied before forwarding; a failure is a continuity error, `stream.ts:508-516`).
  - `error{message|error, displayMessage?, code?, provider?, data?}`: logged, pushed to `context.errors`, ends the read (`stream.ts:452-468`, `R/handlers/error.ts:4-16`). Sim then finalizes with its own `error` + `complete{status:'error'}` (`R/lifecycle/finalize.ts:116-175`), so the browser sees two error frames.
  - `complete{status, textLength?, usage?{input_tokens, output_tokens}, cost?}`: ends the turn (`R/handlers/complete.ts:4-28`). `textLength` must equal the main-lane text Sim received: larger → continuity error, smaller → fatal (`text-receipt.ts:6-17`). Sim does not add another `complete` when it saw one (`finalize.ts:191`, `R/session/writer.ts:165`).
- Body closed without `complete`/`error`/`checkpoint_pause`: Sim checks the Redis abort marker; if Stop was pressed → cancelled, else `StreamEndedWithoutTerminalError` → retried as a re-attach (`stream.ts:551-576`).
- Non-2xx (`stream.ts:261-278`): 402 → `BillingLimitError` (usage-limit card, `chat-engine.md` §2.5); other 4xx → `CopilotBackendError` showing the body's `message` or `error` when it is a short plain sentence (no `snake_case`/`camelCase` token, ≤200 chars), else "The agent service could not process this request." (`stream.ts:101-126`); 5xx → "The agent service is temporarily unavailable. Please try again."
- Retries (`stream-retry.ts:10-21,74-131`): a reachable worker that failed (JSON 5xx, dropped body, continuity error) gets 3 retries within 30 s; unreachable (connection error, or non-JSON 502/503/504) is retried for 120 s; 4xx and fatal parse errors are not retried. Idle: 120 s without any byte fails the leg (`M/constants.ts:22`, `stream.ts:203-211`).

## 5. Tool round trip (checkpoint model)

1. Worker sends `tool{phase:'call', executor:'sim', mode:'async', toolCallId, toolName, arguments}`. Sim starts executing immediately (`tool.ts:861-960`) and emits its own `tool` result frame to the browser (the worker must not send one).
2. Worker sends `run{kind:'checkpoint_pause', pendingToolCallIds:[…]}` and ends the body (no `complete`).
3. Sim waits for the pending tools (watchdogs, `run.ts:1428-1595`), builds `results` from its own tool state (`run.ts:898-933`): `{callId: <worker's id>, name, data: <terminal output>, success}`, and POSTs `/api/tools/resume` with `{streamId: <messageId>, results, receivedTextChars, receivedActivity}` (`run.ts:1656-1661,1320-1331`).
4. The resume response is another SSE leg; text offsets continue from `receivedTextChars`; the turn ends with `complete` (example: `R/session/stream-recovery.integration.ts:280-340`).
5. A pause whose `frames[]` each carry their own `checkpointId` switches to per-subagent concurrent resume chains (`run.ts:779-798,1393-1426`); the mock does not use it.

Tool errors: an unknown handler returns `{success:false, error:'No handler for tool: …'}` (`M/tool-executor/executor.ts:289-292`); argument validation errors also come back as `success:false`. Either way the worker gets `success:false` in the resume.

Permission gate (`R/tools/permission.ts:66-105`, `tool.ts:949`): only when `COPILOT_TOOL_PERMISSIONS_ENABLED` is true and the turn is an interactive `/api/mothership*` turn (`run.ts:335-341`). A sim-dispatched call is held when the catalog says `requiresApproval` (e.g. `delete_workspace_mcp_server`, `run_code`, `deploy_as_api`) or when the call frame itself carries `status:'awaiting_approval'`. The user answers via `POST /api/copilot/tool-permission` (`chat-engine.md` §3.7). Allow → Sim re-emits the call as `executing` and runs it; Skip → Sim emits a `result` with `status:'skipped'` (its `success` is `true` for skipped, `permission.ts:148`) and the resume carries `data:{skipped:true, reason:'user_declined', message}` (`permission.ts:107-161`).

Client-executed tools (`run_workflow*`, `run_block`, `run_from_block`, desktop/browser/terminal tools; catalog route `client`) are run by the browser and reported through `POST /api/copilot/confirm`; Sim still resumes the worker the same way.

## 6. Does the worker call back into Sim?

- `simConnection` is added to every initial chat body (`run.ts:1183-1190`): self-hosted default `{mode:'checkpoint', channelId: HMAC-SHA256(INTERNAL_API_SECRET, 'mothership:sim-transport:v1')}`, hosted default `{mode:'direct'}`; overridable with `MOTHERSHIP_SIM_TRANSPORT` (`M/transport/connection.ts:7-16`, `lib/core/config/env.ts:615`).
- In `checkpoint` mode the worker never opens a connection to Sim: tools run through the pause/resume legs (§5) and any other control request travels over the outbound long poll `/api/sim-transport/poll` → `/api/sim-transport/reply` (§2).
- In `direct` mode (hosted) the worker calls Sim's internal routes, authenticated with `x-api-key: <INTERNAL_API_SECRET>` checked by `checkInternalApiKey` (`R/http.ts:94-111`): `POST /api/copilot/tools/execute` (in-band tool execution for background lanes, `app/api/copilot/tools/execute/route.ts:71-97`), `POST /api/billing/update-cost`, `POST /api/copilot/api-keys/validate`, `POST /api/copilot/byok/validate`, `POST /api/internal/file-doc/{seed,merge,persist}`. Not needed for a self-hosted mock.

## 7. Stop, steer, replay

- Stop: Sim writes its abort marker and calls `/api/streams/explicit-abort {messageId}`; it aborts its own fetch, and a body that closes after the marker reads as cancelled (`stream.ts:551-566`). The browser then gets Sim's `complete{status:'cancelled', partialContent?}` (`finalize.ts:75-110`).
- Steer: `/api/streams/steer`; the worker later reports `run{kind:'steering_applied'}`.
- Replay: §2; the worker replays from its durable log with cursors from 1, and Sim tells the browser via `x-mothership-stream-replay: log` (`chat-engine.md` §2.4).

## 8. Environment that controls this hop

| Var | Effect |
|---|---|
| `SIM_AGENT_API_URL` | base URL (§1); compose maps `${SIM_AGENT_API_URL:-}` |
| `COPILOT_API_KEY` | `x-api-key` on calls; also gates the transport receiver (`receiver.ts:125-126`) |
| `COPILOT_TOOL_PERMISSIONS_ENABLED` | permission gate (§5); comes only from `.env` (`env_file`) in the compose copy |
| `MOTHERSHIP_SIM_TRANSPORT` | `checkpoint` (self-hosted default) / `direct` |
| `COPILOT_SOURCE_ENV`, `COPILOT_{DEV,STAGING,PROD}_URL` | source header, super-user environment switch |
| `INTERNAL_API_SECRET` | `channelId` HMAC; auth of worker → Sim callbacks |
