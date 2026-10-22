# mock_copilot

A deterministic stand-in for the Sim copilot agent service (the "mothership" worker behind `SIM_AGENT_API_URL`). The Sim server talks to it exactly as it talks to `https://www.copilot.sim.ai`, so the browser (React or Flutter) sees real stream-v1 SSE from `POST /api/mothership/chat`, produced by the real Sim server, with scripted content.

Protocol reference: `apps/flutter/docs/port/specs/agent-service-protocol.md`.

Node built-ins only, no install:

```powershell
node apps/flutter/tools/mock_copilot/server.mjs                    # port 4010, MOCK_SPEED=real
$env:MOCK_SPEED='fast'; node apps/flutter/tools/mock_copilot/server.mjs
```

| Env | Default | Meaning |
|---|---|---|
| `PORT` | `4010` | listen port |
| `HOST` | `0.0.0.0` | listen address (must not be 127.0.0.1, the Docker container connects via `host.docker.internal`) |
| `MOCK_SPEED` | `real` | `real` (delays as scripted), `fast` (×0.1), `instant` (no delays). A message can override it with `speed=fast` etc. |
| `MOCK_API_KEY` | unset | when set, POSTs without this `x-api-key` get 401 (to test a rejected key) |
| `MOCK_LOG_BODY` | unset | `1` logs full request bodies instead of a summary |
| `MOCK_POLL_HOLD_MS` | `20000` | how long `/api/sim-transport/poll` holds before answering `{requests:[]}` |

Every request is logged to stdout as one JSON line (`event:"request"`, then `event:"response"`); every stream leg adds `event:"leg_end"` with its outcome (`complete`, `error`, `parked`, `dropped`, `stopped:explicit-abort`, `stopped:client-closed`). The `x-api-key` value is never logged, only `present`/`absent`/`match`/`mismatch`. The transport long poll is not logged.

## Scenarios

Pick one by starting the chat message with `#scenario:<name>` (optionally followed by `speed=real|fast|instant`). Any other message gets `plain`. `#scenario:list` lists them in the chat itself; an unknown name answers with the known names. Each scenario also gets a title (`Mock: <name>`, or `Mock: <first words>` for plain messages) from `/api/generate-chat-title`.

| Message | What happens | Sim executes something? |
|---|---|---|
| (anything) / `#scenario:plain` | Markdown answer with heading, table, Dart code block, list, link; 2-word chunks every 45 ms | no |
| `#scenario:thinking` | `thinking`-channel text, then the answer | no |
| `#scenario:tool` | `list_workspaces` call with `executor:'sim'`, `checkpoint_pause`; Sim runs it, POSTs `/api/tools/resume`, the answer prints the result Sim sent | yes, read-only |
| `#scenario:tool-go` | worker-executed `web_search` (executor `go`): generating call, two `args_delta`, final call, success result | no |
| `#scenario:tool-error` | worker-executed `web_fetch` with a `success:false` result, answer continues | no |
| `#scenario:tool-error-sim` | `list_workspaces` with `{limit:0}` (schema minimum is 1): Sim rejects the arguments and resumes with `success:false` | yes, fails validation |
| `#scenario:permission` | `list_workspaces` call frame with `status:'awaiting_approval'`; the answer reports whether it ran or was skipped | yes, after Allow |
| `#scenario:subagent` | main-lane `search` tool, `span` subagent start/end (`Search agent`) with thinking, text and three nested `go` tools (one fails), parent result, summary | no |
| `#scenario:error` | some text, then `error{code:'provider_overloaded'}` and the body ends | no |
| `#scenario:long` | 60 numbered paragraphs, about 64 s at `real` (6.4 s at `fast`), for Stop mid-stream | no |
| `#scenario:title` | short answer; the title endpoint answers after 4 s with "Mock title scenario" | no |
| `#scenario:title-fail` | short answer; the title endpoint answers 500, the chat stays untitled | no |
| `#scenario:drop` | first attempt closes the body without a terminal frame; Sim re-attaches with the same `messageId` and the mock re-sends the whole response (offsets let Sim drop the duplicate prefix) | no |
| `#scenario:flaky` | first attempt answers 503 JSON, Sim's retry gets an answer | no |
| `#scenario:http-500` | every attempt answers 500 JSON (Sim retries 3×, then "The agent service is temporarily unavailable") | no |
| `#scenario:http-400` | 400 `{error:'The mock agent rejected this request.'}`, shown as the error, not retried | no |
| `#scenario:http-402` | 402, Sim shows its usage-limit card | no |
| `#scenario:list` | table of all scenarios | no |

Notes:
- `permission` only shows the Allow/Skip card when the Sim server runs with `COPILOT_TOOL_PERMISSIONS_ENABLED=true` (add it to `upstream/.env`); otherwise Sim runs the tool without asking and the scenario behaves like `tool`.
- Stop: Sim calls `POST /api/streams/explicit-abort`; the mock stops writing and closes the leg (logged as `stopped:explicit-abort`). The browser gets Sim's own `complete{status:'cancelled'}`.

## Endpoints implemented

`POST /api/mothership`, `/api/copilot`, `/api/mothership/execute` (scenario SSE) · `POST /api/tools/resume` · `POST /api/generate-chat-title` · `POST /api/streams/explicit-abort` (`{settled:true}`) · `POST /api/streams/steer` (acknowledged, no effect) · `POST /api/streams/replay` (re-sends the recorded frames of a known stream, 404 otherwise) · `POST /api/sim-transport/poll` (holds, then `{requests:[]}`) and `/reply` · `POST /api/validate-key/*` (empty key list) · `POST /api/tasks/status` (404) · `GET /healthz`. Everything else answers 404 JSON.

## Pointing the running stack at the mock

The stack is shared: do this only when nobody else depends on the real copilot, and expect the `simstudio` container to restart (about a minute).

1. Start the mock on the host: `node apps/flutter/tools/mock_copilot/server.mjs` (keep it running; `HOST` must stay `0.0.0.0`). Allow Node through the Windows firewall for private networks if Windows asks. Check from the container: `docker exec upstream-simstudio-1 curl -s http://host.docker.internal:4010/healthz`.
2. In `C:\Dev\deutz\sim\upstream\.env` add:
   ```
   SIM_AGENT_API_URL=http://host.docker.internal:4010
   COPILOT_API_KEY=mock-copilot-key
   # optional, for #scenario:permission
   COPILOT_TOOL_PERMISSIONS_ENABLED=true
   ```
   The compose copy passes `SIM_AGENT_API_URL` and `COPILOT_API_KEY` through `environment:` and loads the rest via `env_file: .env`; it already maps `host.docker.internal` with `extra_hosts: host.docker.internal:host-gateway`, so the name resolves inside the container.
3. Recreate only the app container:
   ```powershell
   docker compose -p upstream --project-directory C:\Dev\deutz\sim\upstream -f C:\Users\Niklas\AppData\Local\Temp\claude\C--Dev-deutz-sim\6ee4a102-5a2d-43d3-b69b-5a93d3be791b\scratchpad\compose.prod.yml up -d --force-recreate simstudio
   ```
4. Verify: the mock logs a `/api/sim-transport/poll` long poll shortly after boot (not printed; its absence of errors in `docker logs upstream-simstudio-1` is the check), and sending "hello" in Chat logs `event:"request" path:"/api/mothership"` and `/api/generate-chat-title`.

## Switching back to the real copilot

1. In `upstream/.env` remove `SIM_AGENT_API_URL` (empty means `https://www.copilot.sim.ai`) and replace `COPILOT_API_KEY` with the real key (and drop `COPILOT_TOOL_PERMISSIONS_ENABLED` unless wanted).
2. Run the same `docker compose … up -d --force-recreate simstudio` command.
3. Stop the mock.

## What the mock cannot reproduce

- Real model output, real integrations and real worker-side tools (`web_search`, `web_fetch`, integration calls, subagent reasoning): all are scripted frames.
- Sim-executed tools beyond read-only ones: the scripts only call `list_workspaces`. Workflow edits, file edits (`prepare_file_edit` previews), tables, knowledge, deploy, `run_code`/`run_function` (need a sandbox), media generation and OAuth tools are not scripted.
- Client-executed tools (`run_workflow*`, browser/terminal/desktop tools) and `POST /api/copilot/confirm`: not scripted.
- `resource` events (panel open/refresh), `run` compaction/task/steering frames, per-subagent concurrent resume chains, inline images.
- `direct` transport mode: the mock never calls back into Sim (`/api/copilot/tools/execute` etc.); the sim-transport poll never delivers control requests.
- Steering has no effect on the running script; replay serves only streams from the mock's own memory (lost on restart).
- Billing (usage/cost) is a fixed token count; hosted billing headers are ignored.
