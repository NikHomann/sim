# Chat engine (Mothership stream v1 client, `useChat` state machine)
Upstream: `app/workspace/[workspaceId]/home/hooks/**`, `hooks/queries/mothership-chats.ts`, `hooks/use-mothership-chat-events.ts`, `stores/{mothership-queue,mothership-drafts,mothership-effort,tool-permission}`, the routes under `app/api/mothership/**` and `app/api/copilot/{chat/*,tool-permission}`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c (v0.9.30)
Phase: 1.5 (plan §3 "Phase 1.5", §4.1, §4.3; `03-api-and-auth.md` §4.3–4.4)

Data/protocol spec: sections are Files, Protocol, Endpoints, State machine, Persistence, Failure modes, Checklist, Ambiguities. Message rendering (`home/components/message-content/**`), the Home page layout, the composer and the resources panel are out of scope here (separate screen specs); this spec stops at the data each of them reads. Facts only. Paths relative to `apps/sim/` unless prefixed with `flutter/` (= `apps/flutter/`). Abbreviations: `H/` = `app/workspace/[workspaceId]/home/`, `U` = `H/hooks/use-chat.ts`, `S/` = `H/hooks/stream/`, `Q` = `hooks/queries/mothership-chats.ts`, `P` = `lib/mothership/chat/post.ts`.

## 1. Files

### 1.1 Client (React) sources mapped

| File | Lines | Role |
|---|---|---|
| `U` | 5462 | `useChat`: send, optimistic pair, stream loop, reconnect, stop, finalize, queue dispatch, handoffs, hydration |
| `S/turn-model.ts` | 796 | pure reducer `reduceEvent` (envelope → `TurnModel`), `applyTurnTerminal` |
| `S/turn-model-serialize.ts` | 476 | `modelToContentBlocks`, `modelMainText`, `contentBlocksToModel` |
| `S/stream-context.ts` | 394 | loop state, `flush`/`flushText`/`forceFlush`, snapshot write targets |
| `S/dispatch-stream-event.ts` | 71 | reduce first, then per-type side-effect handler |
| `S/handle-{session,text,tool,span,resource,run,error,complete}-event.ts` | 84/13/229/100/366/13/17/29 | side effects per envelope type |
| `S/stream-helpers.ts`, `S/refresh-settings.ts` | 487, 23 | `finalizeResidualToolCalls`, tool-name sets; settings refresh |
| `H/hooks/stream-protocol.ts` | 179 | batch parse, cursor predicates, `StreamGoneError`, `buildReplayStream` |
| `H/hooks/message-reconcile.ts` | 373 | snapshot message, live-turn reconcile, `markMessageStopped`, replay selection, hydration key |
| `H/hooks/send-queue-policy.ts` | 127 | requeue policy, retry backoff, resend verdict |
| `H/hooks/send-handoff.ts` | 313 | sessionStorage queued-send handoff + claim |
| `H/hooks/chat-url.ts` | 12 | `/workspace/<id>/chat/<chatId>` URL builder |
| `H/hooks/use-mothership-chat-older-messages.ts` | 48 | pages older transcript into the detail cache |
| `H/types.ts` | 227 | `ChatMessage`, `ContentBlock`, `ToolCallInfo`, `ToolCallStatus`, `QueuedMessage`, `SendPayload` |
| `H/home.tsx` | 507 | the Home/chat page wiring of `useChat` (mark-read, handoff consume, submit) |
| `Q` | 895 | query keys, staleTimes, chat history read, CRUD mutations, effort save |
| `hooks/use-mothership-chat-events.ts` | 307 | `task_status` SSE → cache invalidations |
| `lib/events/rotating-event-source.ts` | 111 | make-before-break `EventSource` rotation |
| `stores/mothership-queue/{store,types}.ts` | 379, 120 | per-chat send queue, sessionStorage |
| `stores/mothership-drafts/store.ts` | 95 | composer drafts, localStorage |
| `stores/mothership-effort/store.ts` | 110 | model selection (persisted) + per-chat effort picks (memory) |
| `stores/tool-permission/store.ts` | 60 | awaiting/submitted tool-permission ids (memory) |
| `H/components/message-content/components/agent-group/tool-permission-card.tsx` | 231 | Allow / Don't ask again / Skip / Allow all / Skip all |
| `lib/core/utils/sse.ts` | 297 | `readSSELines` (client decode), `SSE_HEADERS`, `encodeSSEComment` |
| `lib/mothership/chat/{display-message,persisted-message,error-tag,live-message-id}.ts` | 235/916/19/22 | persisted ↔ display mapping, error tag, live assistant id |
| `lib/mothership/model-options.ts` | 65 | effort/model options and defaults |
| `lib/core/utils/browser-storage.ts` | 449 | `MothershipHandoffStorage` (localStorage) |

### 1.2 Server sources mapped (read-only for the port; the backend is reused)

| File | Lines | Role |
|---|---|---|
| `lib/mothership/generated/mothership-stream-v1.ts` | 604 | wire types |
| `lib/mothership/request/session/{contract,event,types,sse,buffer}.ts` | 526/75/56/20/570 | envelope validation, `createEvent`, replay envelopes, SSE encoder, seq/cursor allocation |
| `lib/mothership/generated/{protocol,resources}.ts` | 585/115 | `StreamTextPosition` etc., resource payload |
| `app/api/mothership/chat/{route,stream,stop,abort,resources}/route.ts` | 25/13/12/12/36 | shims onto `P` and `app/api/copilot/chat/*` |
| `P` | 1619 | `ChatMessageSchema`, `handleUnifiedChatPost` |
| `app/api/copilot/chat/{stream,stop,abort}/route.ts` | 619/115/29 | reconnect stream/batch, stop-persist, abort |
| `lib/mothership/request/lifecycle/{start,finalize,stream-retry}.ts`, `lib/mothership/request/go/stream.ts` | 815/241/162/786 | SSE body, terminal events, worker errors |
| `lib/mothership/request/tools/permission.ts`, `app/api/copilot/tool-permission/route.ts` | 352/213 | permission gate and decision endpoint |
| `app/api/mothership/chats/**`, `app/api/mothership/events/route.ts` | — | chat CRUD, status, events SSE |

### 1.3 Existing Dart to build on (do not duplicate)

| flutter/ file | What it already does | Delta this spec requires |
|---|---|---|
| `packages/sim_api/lib/src/sse/sse_decoder.dart` | SSE frames, comments dropped, `[DONE]` | idle timeout must count raw chunks incl. comments (§6 F1) |
| `packages/sim_api/lib/src/sse/mothership_stream.dart` | `MothershipStreamEnvelope.fromJson` (checks `v`, `type`, `seq`, `stream`), `MothershipSeqTracker` | React rejects more (ts string, payload object, known type, per-type checks, §2.2); unknown type is fatal in React, `unknown` in Dart; React does not act on seq gaps (§2.5) |
| `packages/sim_api/lib/src/sse/named_events.dart` | `RotatingEventSource` (port of `lib/events/rotating-event-source.ts`) | use for `/api/mothership/events` (§3.9) |
| `packages/sim_api/lib/src/client/sim_http_client.dart` | `send`, `requestJson`, `stream()` (headers first, body bytes; non-2xx → `ApiClientError` with body) | 409 body must be read from `ApiClientError.body` (§4.6) |
| `packages/sim_api/lib/src/uploads/upload_session.dart` | upload sessions | `fileAttachments` items come from it (§3.1) |
| `packages/sim_api/lib/src/query/query_client.dart` | `Query<T>`, invalidate/cancel/remove/setData | keys of §3.6 |
| `packages/sim_api/lib/src/storage/shared_web_state.dart` (+ `platform/*_web.dart`) | `localStorage` + cookie for theme/sidebar | extend with the §5 keys (sessionStorage needed too) |
| `lib/features/workspace_shell/sidebar/chats/http_chats_source.dart`, `chat_models.dart` | list `GET /api/mothership/chats?workspaceId&scope=active` (60 s), rename/pin/unread PATCH, read POST, DELETE; `mapChat` flags | must also react to `task_status` (§3.9) and to engine-side invalidations (§3.6) |
| `lib/data/core/{load_state,mutations,query_keys}.dart` | cubit/query patterns | add mothership keys (§3.6) |

## 2. Protocol (stream v1)

### 2.1 Framing
- Server encoder: `encodeSSEEnvelope` writes `data: <JSON>\n\n`; for `type:'resource'` the payload's `resource` is passed through `presentChatResourceForBrowser` first (`lib/mothership/request/session/sse.ts:7-15`). Response headers: `SSE_HEADERS` (`Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`, `X-Accel-Buffering: no`, `lib/core/utils/sse.ts:4-9`) plus `Content-Encoding: none` (`session/sse.ts:17-20`).
- Comments: `: <text>\n\n` (`lib/core/utils/sse.ts:24-26`). Live POST stream: `: keepalive` every 15 s (`session/writer.ts:16,109-121`). Reconnect stream: first `: accepted`, then `: keepalive` when 15 s passed without a write (`app/api/copilot/chat/stream/route.ts:55,485,574-576`).
- Client decode `readSSELines`: splits on `\n`, strips trailing `\r`, only `data:` lines, one optional space after `data:`, skips `[DONE]`, each `data:` line is one event (no multi-line join), optional idle timeout that rejects with `SSEIdleTimeoutError` and cancels the reader (`lib/core/utils/sse.ts:137-195`). Chat uses `idleTimeoutMs = 45_000` (`U:343,2427`); comments reset it because they are chunks.
- No `event:` names and no `id:` on this stream.

### 2.2 Envelope shell and client validation
`{v:1, type, seq, ts, stream:{streamId, chatId?, cursor?}, trace?:{requestId, goTraceId?, spanId?}, scope?:{lane:'subagent', agentId?, parentSpanId?, parentToolCallId?, spanId?}, payload}` (`generated/mothership-stream-v1.ts:44-80`). Server `createEvent` always sets `stream.cursor` and `trace.requestId`, `chatId` only when known, `ts` ISO now (`session/event.ts:39-60`).

Client validation, `parsePersistedStreamEventEnvelope` (`session/contract.ts:233-366,484-509`), used on every live frame (`U:2433-2445`) and every batch event (`H/hooks/stream-protocol.ts:61-115`):
- shell: object, `v===1`, `seq` finite number, `ts` string, `stream.streamId` non-empty string, `chatId`/`cursor` optional strings, `trace` (if present) has string `requestId`, `scope` (if present) has `lane==='subagent'`, `type` ∈ 8 known types, `payload` object (`contract.ts:233-251`);
- `session`: `kind` ∈ start|chat(needs `chatId`)|title(needs `title`)|trace(needs `requestId`) (`:253-268`);
- `text`: `channel` assistant|thinking, `text` string, optional `textOffset` safe int ≥ 0 (`:270-280`);
- `tool`: `replay` absent or `true`, string `toolCallId` and `toolName`, `phase` call|args_delta|result (`:282-292`); or a synthetic file-preview payload (`:398-441`);
- `span`: `kind` subagent|structured_result|subagent_result (`:294-301`);
- `resource`: `ResourcePayload` zod (`:303-305`);
- `run`: `kind` ∈ generated `MothershipStreamV1RunKind` (incl. `steering_applied`) and valid `activityReceipt` (`:311-333`);
- `error`: string `message` or string `error` (`:335-337`);
- `complete`: string `status` and valid `activityReceipt` (`:339-341`).
- A failure throws `StreamSchemaValidationError` ("Client stream schema enforcement failed. …") which aborts the read (`U:2435-2444`, `stream-protocol.ts:32-49`).

### 2.3 Payloads by type

| type | payload | Source |
|---|---|---|
| session | `{kind:'start', data?:{responseId?}}` · `{kind:'chat', chatId}` · `{kind:'title', title}` · `{kind:'trace', requestId, spanId?}` | `generated/mothership-stream-v1.ts:54-123` |
| text | `{channel:'assistant'|'thinking', text, textOffset?}` | `:134-137`, `generated/protocol.ts:269-272` |
| tool call | `{phase:'call', toolCallId, toolName, executor:'go'|'sim'|'client', mode:'sync'|'async', arguments?, partial?, status?, activityDescription?, execName?, ui?:{hidden?, internal?, clientExecutable?, simExecutable?, inbandOwned?}, replay?, workspaceId?, deadlineMs?}` | `:148-170`, `protocol.ts:279-300` |
| tool args_delta | `{phase:'args_delta', toolCallId, toolName, executor, mode, argumentsDelta}` | `:181-188` |
| tool result | `{phase:'result', toolCallId, toolName, executor, mode, success, status?, output?, error?, replay?}` | `:199-209` |
| tool (synthetic preview) | `{toolName:'prepare_file_edit', toolCallId, previewPhase:'file_preview_start'|'file_preview_target'|'file_preview_edit_meta'|'file_preview_content'|'file_preview_complete', …}` | `session/contract.ts:30-131` |
| span | `{kind:'subagent', event:'start'|'end', agent?, data?}` · `{kind:'structured_result', agent?, data?}` · `{kind:'subagent_result', agent?, data?}`; `data.pending===true` on an `end` = pause, `data.error` = failure, `data.name` = display name, `data.tool_call_id`/`toolCallId` | `:220-271`, `S/turn-model.ts:583-662` |
| resource | `ResourceChange & {effectId?, replay?}`: `op` upsert(`resource: ResourceAddress`, `readOnly?`, `searchResult?`) · remove · clear_view(table only) · refresh(`resource` type/owner/workspaceId/id or `SettingsRefresh`) | `generated/resources.ts:44-114` |
| run | `checkpoint_pause{checkpointId, executionId, runId, pendingToolCallIds, frames?}` · `resumed` · `compaction_start` · `compaction_done{data?:{summary_chars}}` · `task_armed{taskId, taskKind:'timer'|'workflow_run', target, note}` · `task_delivered{taskId, status:'completed'|'failed'|'stopped'|'expired', summary}` · `steering_applied` (kind only in the enum); optional `activityReceipt{emitterId, sequence}` | `:317-406,507-524`, `protocol.ts:264-266` |
| error | `{message, error?, displayMessage?, code?, provider?, data?}` | `:417-424` |
| complete | `{status:'complete'|'error'|'cancelled', reason?, response?, usage?, cost?, textLength?, activityReceipt?}`; server adds `partialContent?`, `partialContentLen?`, `toolCallCount?` on cancel/error (`lifecycle/finalize.ts:94-104,159-168`) | `:435-454` |

ToolStatus: generating|awaiting_approval|executing|success|error|cancelled|skipped|rejected (`:33-41`). Completion: complete|error|cancelled (`:42`).

### 2.4 seq and cursor
- Server allocates `seq` per stream from a Redis counter; `cursor = String(seq)` (`session/buffer.ts:119-129`).
- Client cursor of an event: `stream.cursor ?? String(seq)` (`U:2453`); an event whose numeric cursor ≤ `lastCursorRef` is dropped before dispatch (`stream-protocol.ts:134-147`, `U:2454-2456`); otherwise `lastCursorRef = cursor` (`U:2457-2459`).
- The reducer independently no-ops `seq ≤ model.lastSeq` (`S/turn-model.ts:467`).
- Batch events carry `eventId = seq` (`session/types.ts:33-38`); after a seed replay the client sets the cursor to the last `eventId` (`U:2738`).
- Log re-sync: response header `x-mothership-stream-replay: log` means cursors restart at 1; client resets cursor to `'0'`, rebuilds from an empty model and sends `&source=log` on every later read for that stream (`U:2789-2794,367-369`, `constants.ts:86-92`).
- No client-side seq-gap detection exists: the client never compares `seq` to `last+1`. Gaps are handled server-side (ring/log, `stream/route.ts:305-311`).

### 2.5 Server emission order of a turn (`POST /api/mothership/chat`)
1. `: keepalive` comments start (`lifecycle/start.ts:391`).
2. `session{kind:'chat', chatId}` when a chat id exists and not recovery (`start.ts:393-400`).
3. Title generation fires in parallel; when the chat had no title it later emits `session{kind:'title', title}` and publishes `task_status renamed` (`start.ts:679-716`).
4. Worker events (text/tool/span/resource/run) forwarded via `publisher.publish` (`start.ts:440-458`).
5. Terminal: success → `complete{status:'complete'}`; error → `error{message, error, displayMessage, code?, data:{displayMessage}}` then `complete{status:'error'}`; stop → `complete{status:'cancelled', partialContent?, …}` (`lifecycle/finalize.ts:75-195`). Usage/billing refusal → synthetic `text` carrying a `<usage_upgrade>` tag then `complete{status:'complete'}` (`lib/mothership/request/tools/billing.ts:26-60`).

## 3. Endpoints

### 3.1 `POST /api/mothership/chat` (send)
Request built by the client (`U:3946-3984`), JSON, signal = the send's `AbortController`:

| Field | Value sent by React | Server schema (`P:275-374`) |
|---|---|---|
| `message` | text (empty allowed only with attachments + org) | string ≤ `MAX_CHAT_MESSAGE_LENGTH`; refine: non-empty or (org + attachments) (`P:371-374`) |
| `workspaceId` / `organizationId` | one of them | optional strings |
| `userMessageId` | `resumeUserMessageId ?? generateId()` (`U:3592-3593`) | ≤ 128 chars; server default `generateId()` (`P:957`); becomes `streamId` |
| `createNewChat` | `!requestChatId` | default false |
| `chatId` | when known | optional |
| `fileAttachments` | `[{id,key,filename,media_type,size,path?}]` when non-empty | `FileAttachmentSchema` (`P:118-125`) |
| `resourceAttachments` | `buildResourceAttachments(resources, activeResourceId, desktopScopeId, tableViews)` unless assistant mode | array, unaddressable ids dropped (`P:296-298`) |
| `contexts` | when non-empty (table contexts get `currentView`) (`U:3558-3564`) | `ChatContextSchema` kinds `past_chat…project` (`P:174-273`), ≤ `MAX_CHAT_CONTEXTS` |
| `mode` | `requestMode` (`'agent'|'assistant'|'plan'`) | default `'agent'` |
| `assistantSearch`, `assistantSearchLevel` | assistant mode only | assistant-only refinements (`P:337-366`) |
| `workflowId` | non-assistant and hook has `workflowId` (copilot panel) | optional |
| `desktopCapabilities` | from `getDesktopChatCapabilities`; `{}` on plain web (`lib/desktop/index.ts:181-260`) | optional |
| `userTimezone` | `Intl…timeZone` | optional |
| `modelSelection` | non-assistant: `resolveMothershipModelSettings(effortStore|planEffortStore, modelSelectorEnabled, plan).modelSelection` | optional |
| `effort` | non-assistant and a pick exists: chat pick ?? cached detail `effort`; new chat → `newChatEffort` (`U:3620-3630`) | `none|low|medium|high|xhigh|max` |
| (not sent) `model`, `provider`, `commands`, `clientCapabilities`, `prefetch`, `implicitFeedback`, `workflowName`, `assistantFast` | — | `model` default `'claude-opus-4-8'` (`P:113`); missing `clientCapabilities` ⇒ `clientToolPickupExpected=true` (`P:1352-1357`) |

Pre-validation shim: `mothershipChatPostEnvelopeSchema` (passthrough) via `validateShimEnvelope` (`app/api/mothership/chat/route.ts:21-22`, `lib/api/contracts/mothership-chats.ts:173-182`).

Responses (`P:904-1619`):

| Case | Status / body |
|---|---|
| no session | 401 `{error:'Unauthorized'}` (`route.ts:16-19`) |
| zod failure | 400 `validationErrorResponse(…,'Invalid request data')` (`P:1556-1565`) |
| plan mode off / assistant + workspace resources / bad branch | 400 `{error:…}` (`P:944,953-955,799,809`) |
| duplicate `userMessageId` (claim taken) | 409 `{error:'This message was already sent.', activeStreamId:userMessageId, chatId?}` (`P:890-902,962-965`) |
| `copilot.use` withheld | 403 `capabilityRefusalResponse` (`P:1048-1058`) |
| `chatId` given but not found | 404 `{error:'Chat not found'}` (`P:1127-1130`) |
| chat busy (lock) | 409 `{error:'A response is already in progress for this chat.', activeStreamId?}` (`P:1148-1166`) |
| superseded claim | 409 `{error:'This message was already sent.', activeStreamId:userMessageId}` (`P:1572-1577`) |
| forbidden/not_found application error | 403 `{error:'Conversation access denied'}` (`P:1578-1580`) |
| other orchestration error | `statusForOrchestrationError(code)` `{error}` (`P:1581-1586`) |
| workspace access | 403 `{error:'Workspace access denied'}` (`P:1587-1589`) |
| unexpected | 500 `{error:<message>}` (`P:1595-1601`) |
| success | 200 SSE; headers `traceparent: 00-<trace>-<span>-<flags>`, `x-mothership-chat-id: <chatId>` when a chat exists, `x-mothership-desktop-executor: device` when bound (`P:1534-1548`, `constants.ts:95-101`) |

### 3.2 `GET /api/mothership/chat/stream?streamId&after[&source=log]` (live tail)
Shim → `app/api/copilot/chat/stream/route.ts` (`app/api/mothership/chat/stream/route.ts:6-13`). Query: `streamId` (required, 400 `{error:'streamId is required'}`), `after` (default `''`→`'0'`), `batch` (`'true'`), `source` `ring|log` (`lib/api/contracts/copilot.ts:189-198`, `stream/route.ts:153-157`). Client sends header `traceparent` when it has one (`U:2770-2774`).
- 401 unauthenticated; 404 `{error:'Stream not found'}` when no run (`stream/route.ts:248-252`) → client `StreamGoneError`; 503 `{error:'Stream replay is unavailable'}` when log replay cannot open (`:324-333`).
- Body: `: accepted`, ring events after the cursor (as `toReplayEnvelope`: resource payloads and tool results get `replay:true`, upsert drops `searchResult`, `session/types.ts:13-31`), polled at 250 ms rising to 2 s when quiet (`:53-54,546-550`), keepalive comment after 15 s silence, ends after the run is terminal (emitting a synthetic `error`+`complete` if the ring had none, codes `resume_terminal_status`, `resume_run_unavailable`, `resume_internal`, `:93-138,429-453,520-591`), or at `MAX_STREAM_MS = 59 min` without terminal (`:63`).
- Header `x-mothership-stream-replay: log` when the reader is re-synced from the worker log (`:612-617`).

### 3.3 `GET …/chat/stream?streamId&after&batch=true[&source=log]` (batch)
200 `{success:true, events:[{eventId, streamId, event}], previewSessions:[FilePreviewSession], status:<run status>, chatId?, desktopToolsOnDevice?}`; `events` is `[]` when the ring cannot serve the cursor (`stream/route.ts:255-293`). Client: raw `fetch` with 10 s timeout, `traceparent` header if known, 404 → `StreamGoneError`, other non-2xx → `Error('Stream resume batch failed: <status>')`, body validated by `parseStreamBatchResponse` (`U:2564-2593`, `stream-protocol.ts:61-115`).

### 3.4 Stop: `POST /api/copilot/chat/abort` and `POST /api/mothership/chat/stop`
- Abort (React calls `copilotChatAbortContract` = `/api/copilot/chat/abort`, not the `/api/mothership/chat/abort` shim, `U:4801-4813`): body `{streamId, workspaceId|organizationId, chatId?}`, header `traceparent?`, `keepalive:true`, 15 s timeout. Response `{aborted, settled, forceReleased?}` (`lib/api/contracts/copilot.ts:529-545`). Server `abortRun`: no run → `{aborted:true, settled:true}`; not settled → `{aborted:true, settled:false, forceReleased:true}` (`lib/mothership/request/application/controls.ts:144-193`).
- Stop-persist (`stopPath = '/api/mothership/chat/stop'`, `U:773-774`): raw `fetch` POST `{chatId, streamId, requestId?}` with `traceparent?`, 15 s timeout (`U:3338-3386`). Server schema `{chatId, streamId, content='' , contentBlocks?, requestId?}` (`copilot.ts:200-211`); React sends no content, so the server reads the stopped message from the replay (`app/api/copilot/chat/stop/route.ts:60-79`). Inaccessible chat → `{success:true}`; errors 401/400/500 (`stop/route.ts:35-45,50,109-113`). Non-2xx → client throws `payload.error ?? 'Failed to persist partial response'`.

### 3.5 `GET /api/mothership/chats/[chatId]/stream-status`
200 `{success:true, activeStreamId: string|null}` (`lib/api/contracts/mothership-chats.ts:498-509`); used only by `awaitPersistedTurn` (`U:2034-2038`, `Q:425-434`).

### 3.6 Chat CRUD, query keys, staleTimes, invalidations

Keys (`Q:110-133`): `['mothership-chats']`; lists `[…,'list', workspaceId ?? '', scope]`, org lists `[…,'list','organization', orgId ?? '', scope]`; `ownerLists(owner)` = the list prefix without scope; detail `[…,'detail', chatId ?? '']`; older pages `[…,'older-messages', chatId, cursor]`. staleTime: list 60 s, detail 30 s (`Q:192-193`). List uses `keepPreviousData` (`Q:345`).

| Operation | Request | Client cache effect | Source |
|---|---|---|---|
| List | `GET /api/mothership/chats?workspaceId=&scope=active|archived` → `{success, data:[{mode,id,title,updatedAt,activeStreamId,lastSeenAt,pinned,deletedAt}]}` | `mapChat`: `name=title??'New chat'`, `isActive=activeStreamId!==null`, `isUnread=activeStreamId===null && (lastSeenAt===null || updatedAt>lastSeenAt)` | `Q:301-366`, contract `:273-295` |
| Detail | `GET /api/mothership/chats/[chatId]?window=latest` first, then `?from=<windowStartCursor>` | `{chat:{id,title,mode,messages,activeStreamId,resources,effort?,createdAt,updatedAt,streamSnapshot?{events:[],previewSessions,status},olderCursor?,windowStartCursor?}}`; reload joins cached older messages; 404 `{success:false,error:'Chat not found'}`, 400 `Invalid cursor` | `Q:370-422,436-448`, route `app/api/mothership/chats/[chatId]/route.ts:38-139` |
| Older page | `GET …/[chatId]/messages?before=<cursor>` → `{messages, olderCursor}`; retries: network/5xx/408/429 always, 404 ≤ 8 times, backoff 1–30 s, gcTime 0 | prepends into detail; failure sets `olderMessagesFailed` | `Q:451-504`, `H/hooks/use-mothership-chat-older-messages.ts` |
| Rename | `PATCH …/[chatId]` `{title}` (trim, 1–200) | optimistic list name; onError rollback; onSettled invalidate ownerList + detail | `Q:591-630`, contract `:52-63` |
| Pin | `PATCH` `{pinned}` | optimistic, pinned partition first; invalidate ownerList | `Q:736-782` |
| Unread | `PATCH` `{isUnread:true}` | optimistic flag, no list invalidation | `Q:637-731` |
| Read | `POST /api/mothership/chats/read` `{chatId}` | optimistic `isUnread=false`, no invalidation; server publishes `updated` | `Q:632-701`, `app/api/mothership/chats/read/route.ts:19-52` |
| Delete | `DELETE …/[chatId]` → `{success:true}` (also for inaccessible) | onSuccess: suspend desktop scopes, `removeQueries(detail)`, queue `clearChat`; onSettled invalidate ownerLists | `Q:510-533`, route `:244-283` |
| Batch delete | one DELETE per id, `Promise.allSettled`; partial failure → `MothershipChatDeleteError(deletedChatIds)` | same per success | `Q:567-590` |
| Restore | `POST …/[chatId]/restore` → `{success:true}`; 404/403/500 | lift queue delete token; invalidate recently-deleted lists + ownerLists | `Q:535-562`, `app/api/mothership/chats/[chatId]/restore/route.ts:18-49` |
| Fork | `POST …/[chatId]/fork` `{upToMessageId}` → `{success, id, failedFileCopies?}`; 404/400/409/413/500 | optimistic list row `Fork | <name>` inserted after pinned; invalidate ownerList | `Q:850-895`, route `app/api/mothership/chats/[chatId]/fork/route.ts:18-50`; live ids `live-assistant:*` are not forkable (`lib/mothership/chat/live-message-id.ts:12-14`) |
| Effort | `PUT …/[chatId]/effort` `{effort}` | mutation scope `mothership-chat-effort:<chatId>`; onMutate `setChatEffort` token; onError drops pick + toast "Couldn't change reasoning effort"; onSuccess sets detail `effort` | `Q:784-848` |
| Create (not used by Home send) | `POST /api/mothership/chats` `{workspaceId|organizationId, mode?}` → `{success,id}` | — | contract `:65-68,426-434` |
| Resources | `POST|PATCH|DELETE /api/mothership/chat/resources` | add (persistence queue), reorder (400 ⇒ drop pending order), remove (`streaming-file` cleanup) | `U:845-866,1214-1272,1517,2083-2092` |

Engine-side invalidations: `session chat` → invalidate owner list (`S/handle-session-event.ts:23-33`); `session title` → invalidate owner list + `onTitleUpdate` (`:76-82`); `finalize` → invalidate detail (unless a queued follow-up) and owner list (`U:3388-3403,3527-3530`); stop → same in `finally` (`U:4886-4892`); `refreshMothershipChatDetail` coalesces bursts with a 30 s hold doubling per replacement (`Q:135-190`).

### 3.7 Tool permission: `POST /api/copilot/tool-permission`
Body `{decisions:[{toolCallId, decision:'allow'|'allow_chat'|'always_allow'|'skip'}]}` 1–50 items (`copilot.ts:71-93`). Response `{success:true, results:[{toolCallId, decision, applied}]}` (`:448-466`). 404 when `COPILOT_TOOL_PERMISSIONS_ENABLED` is off or no matching tool call (`tool-permission/route.ts:159-161,193-195`); `applied:false` when another tab answered first (`:70-77`). `always_allow` persists per user, `allow_chat` per chat (`:115-131`).

### 3.8 `POST /api/copilot/confirm` (client-executed tool completion)
Used by client-executed tools only (workflow run tools `run_workflow|run_workflow_until_block|run_block|run_from_block` and desktop tools, `lib/mothership/tools/client-executed-tools.ts:3-24`, `lib/mothership/tools/client/completion.ts:72,146`). Workflow runs need the execution engine (Phase 3); see §9.

### 3.9 `GET /api/mothership/events?workspaceId=` (chat status SSE)
`event: task_status` `data:{chatId, type:'started'|'completed'|'created'|'deleted'|'renamed'|'updated', streamId?, ownChat?, timestamp}` plus `event: rotate` (`app/api/mothership/events/route.ts:25-37`, `hooks/use-mothership-chat-events.ts:25-34`). 404 when Chat is disabled (`events/route.ts:41`). Client (`use-mothership-chat-events.ts:263-307`): opened only when owner set and `chatEnabled && !permissionConfig.hideCopilot` (sidebar mount, `w/components/sidebar/sidebar.tsx:913-917`); on `reconnect`, or `initial` after an earlier subscription of the same owner in this process, invalidate ownerLists. Per event (`:111-169`): always invalidate ownerLists; `deleted` → suspend desktop scopes, `removeQueries(detail)`, queue `clearChat`; `created` → `reopenRestoredChat`; `renamed` → invalidate detail with `refetchType:'none'`; `started`/`completed` → invalidate detail unless `shouldSkipDetailInvalidationForStreamEvent` (`:70-84`); a `completed` of the cached live stream uses `refetchType:'none'` (`:161-168`).

### 3.10 What the client sees when `COPILOT_API_KEY` / `SIM_AGENT_API_URL` are unset
- `SIM_AGENT_API_URL` unset → `https://www.copilot.sim.ai` (`lib/mothership/constants.ts:3-11`). `COPILOT_API_KEY` unset → the `x-api-key` header is omitted (`lib/mothership/request/headers.ts:17`); no route checks it before the send. Chat surfaces are governed by `NEXT_PUBLIC_CHAT_DISABLED` only (`lib/core/config/env-flags.ts:67-82`).
- The POST still admits the turn: 200 SSE, `session{kind:'chat'}` (new chats also get the `x-mothership-chat-id` header) (`start.ts:393-400`).
- The worker call fails: no connection → `WorkerUnreachableError` "The agent service is temporarily unavailable. Please try again." retried for up to 120 s (`go/stream.ts:77-83,248-250`, `stream-retry.ts:20,79-87`); HTTP 5xx → same message, ≤ 3 retries within 30 s; HTTP 4xx (e.g. a rejected key) → `CopilotBackendError` with the worker's short reason or "The agent service could not process this request.", not retried (`go/stream.ts:69-126,261-279`, `stream-retry.ts:149-161`); 402 → billing card path (§2.5).
- Terminal frames: `error{message, error, displayMessage, data:{displayMessage}}` + `complete{status:'error'}` (`finalize.ts:116-175`). Title generation fails silently (`start.ts:780-813`), so the chat stays untitled ("New chat").
- React Home: the reducer appends `<mothership-error>{"message":…}</mothership-error>` to the assistant text (`S/turn-model.ts:729-745`, `lib/mothership/chat/error-tag.ts:12-18`), rendered as one italic secondary line (`message-content/components/special-tags/special-tags.tsx:3439-3443`); `finalize({error:true})`; the hook's `error` string is set but the workspace Home and copilot panel do not render it (no consumer in `H/home.tsx`, `w/[workflowId]/components/panel/panel.tsx:422-436`); the organization home toasts it (`app/o/[organizationId]/home/organization-home.tsx:223-224`).

## 4. State machine

### 4.1 Message model
- `ChatMessage {id, role:'user'|'assistant', requestMode?, content, origin?:'task', contentBlocks?, attachments?, contexts?, requestId?}` (`H/types.ts:188-199`).
- `ContentBlock {type: text|thinking|tool_call|subagent|subagent_end|subagent_text|subagent_thinking|options|stopped|task, content?, task?, subagent?, subagentName?, toolCall?, options?, timestamp?, endedAt?, error?, parentToolCallId?, spanId?, parentSpanId?}` (`:107-145`).
- `ToolCallInfo {id, name, status, displayTitle?, activityDescription?, integrationDescription?, params?, calledBy?, result?{success, output?, error?}, streamingArgs?, startedAtMs?}`; `ToolCallStatus` executing|awaiting_approval|success|error|cancelled|skipped|rejected|interrupted (`:50-100`).
- Persisted wire (`PersistedMessage {id, role, requestMode?, content, timestamp, origin?, requestId?, contentBlocks?, fileAttachments?, contexts?}` `lib/mothership/chat/persisted-message.ts:119-131`; blocks `{type: <stream type>|'task', lane?, agent?, channel?, phase?, kind?, lifecycle?, status?, content?, name?, toolCall?{id,name,state,…}, task?, timestamp?, endedAt?, error?, parentToolCallId?, spanId?, parentSpanId?}` `lib/api/contracts/copilot-messages.ts:12-67`) maps to display via `toDisplayMessage` (`lib/mothership/chat/display-message.ts:21-235`): tool state map incl. `pending/executing→executing`, `aborted→cancelled`, `failed→error`; a stored assistant row with an unsettled tool → `interrupted`; cancelled → `displayTitle 'Stopped by user'`; `complete{status:cancelled}` block → `stopped`; `apply_file_edit` folds into the preceding `prepare_file_edit` row of the same span; hidden tools dropped; result memoized per message object.
- Live assistant id: `live-assistant:<streamId>` (`live-message-id.ts:1-3`); `streamId === userMessageId`.
- Inline special tags in text (parsed by the renderer, listed for the data contract): `thinking, options, usage_upgrade, credential, mothership-error, workspace_resource, question, source` (+ runtime `file`) (`special-tags.tsx:434-459`). Selecting an option or answering a question submits the option id as a new user message via `onSubmit` (`H/components/mothership-chat/mothership-chat.tsx:770-772`), only on the last row (`:953`).
- `SUBAGENT_LABELS` display fallbacks (`H/types.ts:201-227`).

### 4.2 Turn model reducer (`S/turn-model.ts`)
`TurnModel {status: streaming|complete|error|cancelled, nodes, order, agentBySpanId, openTextByKey, bufferedResults, toolAlias, lastSeq}` (`:122-171`). Node kinds tool/agent/text/task with `spanId` lane (`'main'` = `MAIN_SPAN`), `seq`, `startedAtMs` from `ts` (`:51-120`).
- Idempotency: `seq ≤ lastSeq` → no-op (`:467`). Lane = `scope.spanId ?? 'main'` (`:471`).
- text: ensure subagent lane, append to the open node of `<span>::<channel>` or open `text:<seq>`; opening one channel closes the other channel's open text and stamps `endedAtMs` (`:303-332,474-479`).
- tool call: `apply_file_edit` folds into the latest `prepare_file_edit` in the same span (alias kept on replays) and reopens it; a new `prepare_file_edit` settles older running ones as success; `upsertToolNode` (new node closes the lane's text, drains a buffered result); integration rebind (`call_integration_tool` → resolved name, keeps `description`); `activityDescription`; `status:'awaiting_approval'` moves a live non-terminal node without result to `awaiting_approval`; `status:'executing'` moves `awaiting_approval` back to `running`; `arguments` replace `args`; `ui.hidden` hides (`:480-553`).
- tool args_delta: append to `streamingArgs`, refine `sim_cli`/`cli_*` names (`:554-570`).
- tool result: `resolveStreamToolOutcome` (cancelled when `output.reason==='user_cancelled'|cancelledByUser|status cancelled`; explicit statuses; `aborted→cancelled`, `failed→error`; else `success?success:error`) and `result`; result before call is buffered (`:398-416,571-580`, `lib/mothership/chat/stream-tool-outcome.ts:17-47`).
- span subagent start: close parent lane text, create/reconcile `AgentNode` (id = `scope.spanId ?? span:<toolCallId> ?? span:<seq>`); end: `data.pending` → ignore; else status error/success, `endSeq`, settle still-running tools in that lane (`:583-662`). Other span kinds ignored.
- run: `task_armed`/`task_delivered` → task node `task:<taskId>`; `compaction_start` → tool node `context_compaction` running; `compaction_done` → settles it success (or creates one) (`:665-727`). Other run kinds: no model change.
- error: append error tag to the lane's open assistant text (once) or open a new text node; does not end the turn (`:729-745`).
- complete: `response.async_pause` → ignore; else `applyTurnTerminal(cancelled|error|complete)` which sets running/awaiting_approval tool and agent nodes to cancelled/error/success and closes agents (`:747-796`).
- Serialization to blocks: main-lane text → `text`/`thinking`; subagent text → `text`/`subagent_thinking` with `subagent`, `spanId`, `parentSpanId`; tool → `tool_call` (`running→executing`); agent → `subagent` + `subagent_end` at `endSeq`; sorted by seq; `timestamp = startedAtMs ?? seq` (`S/turn-model-serialize.ts:35-240`). `content` = main-lane assistant text (`:242-252`).

### 4.3 Side effects per envelope (after reduce, `S/dispatch-stream-event.ts:49-83`)
- session chat: if no `chatIdRef` → `adoptResolvedChatId`; else set ref (+ resolved id when selected); invalidate owner list; for a new chat seed `detail(chatId)` = `{id, title:null, messages:[pendingUserMsg, liveAssistantSnapshot], activeStreamId, resources}`, clear pending messages, and `history.replaceState` to `chatUrl(...)` unless a workflow copilot (`S/handle-session-event.ts:9-73`, `H/hooks/chat-url.ts:4-12`: keeps only the `resource` query param).
- session title: invalidate owner list, `onTitleUpdate()` (`:76-83`).
- text, args_delta: paced `flushText` (`S/handle-text-event.ts`, `S/handle-tool-event.ts:181-184`).
- tool: preview phases → file-preview controller only; result → resource extraction + query invalidations (deployments, folders, credentials, workflow lists, resource queries), file tab promotion, `onToolResult`; call → starts client-executed tools when allowed (`S/handle-tool-event.ts:63-229`).
- span: browser-agent run tracking; file subagent start seeds a pending preview session; end reconciles `streaming-file` (`S/handle-span-event.ts`).
- resource: `upsert` with `readOnly` ignored; `settings` refresh (`S/refresh-settings.ts`); replay/deferred → one chat detail refresh; otherwise add/remove/clear_view/refresh resources and `onResourceEvent` (`S/handle-resource-event.ts:90-366`).
- error: `sawStreamError=true`, `setError(displayMessage||message||error||'An error occurred')` (`S/handle-error-event.ts:9-17`).
- complete: `sawCompleteEvent=true`, `completionStatus=status`, clear browser runs; assistant mode removes an unopened interim search resource (`S/handle-complete-event.ts:9-29`).

### 4.4 Snapshot flush (`S/stream-context.ts`)
`flush` serializes the model into `streamingBlocksRef`/`streamingContentRef`; with no chat id it upserts the assistant row into `pendingMessages`; with a chat id it writes the detail cache via `reconcileLiveAssistantTurn` and sets `activeStreamId` unless a terminal persisted assistant already exists (`:271-338`). `flushText` is rAF-scheduled with a 50 ms minimum interval (`:33,348-376`). `deferFlushes` (batch replay) suppresses intermediate flushes; `forceFlush` at the end also runs deferred detail refreshes (`:377-391`). A stale generation (`streamGenRef !== expectedGen` or `shouldContinue()===false`) makes every flush a no-op (`:256-258`).

### 4.5 Transport flags
`setTransportIdle` (sending=false, reconnecting=false), `setTransportStreaming` (true,false), `setTransportReconnecting` (true,true) (`U:1093-1109`). `isSending` drives the Stop button; `isReconnecting` the reconnect indicator. The message list = detail messages (or `pendingMessages` before a chat id) with the active turn's optimistic user + live assistant spliced in (`U:1393-1419`).

### 4.6 Send (`sendMessage` → `startSendMessage`)
1. `sendMessage` (`U:4337-4436`): empty text without attachments → return. Editing a queued id → `replaceAt` in place, clear editing, kick dispatch if idle. `shouldQueueOutgoingMessage(sending || pendingAdmission, stopPending, queuedAhead>0)` → `enqueue` (kick dispatch if stop pending or queue non-empty and idle) (`U:644-650,4387-4400`). Else `startSendMessage`; a withdrawn result is re-queued at its live position with `requeuedFields(reason)` (chatless + `withdrawn` → cross-surface handoff instead).
2. `startSendMessage` (`U:3550-4320`): `setError(null)`, streaming; `userMessageId = resume ?? new`; `admissionUnknown = reused && entry.admissionUnknown !== false`; `requestChatId = handoff.chatId ?? selected ?? chatIdRef`; read effort; write queued-send handoff (if a handoff seed); build `cachedUserMsg` (persisted shape) and optimistic user/assistant (`assistantId = live-assistant:<userMessageId>`); `beginSend` (gen++, `streamIdRef = userMessageId`, cursor `'0'`, reset buffers, `activeTurnRef`, new `AbortController`, pending admission) unless waiting on a stop; `applyOptimisticSend` (detail: drop same ids, append user + empty assistant, `activeStreamId = userMessageId`, drop `streaming-file`; `pendingMessages`: append both) (`U:3753-3775`).
3. Pending stop / handoff stop: await the stop (or POST abort for `supersededStreamId`, must be `settled`), resolve the chat id if needed, then re-apply optimistic send; failure → rollback, `setError`, return `{reason:'stop-failed'}` (`U:3835-3913`).
4. `admissionUnknown = true`, rewrite handoff, POST (§3.1). Network `TypeError` sets `postFailedAtNetwork` (`U:3984-3987`).
5. On response: admitted chat id = `x-mothership-chat-id ?? requestChatId` (ok only); generation moved and not 409 → cancel body, return. New chat → `adoptNewChatEffort`, `adoptResolvedChatId(id, {replaceHomeHistory, invalidateList})` (`U:3989-4008`). Store `traceparent`, call `onRequestStarted({requestId: traceId, userMessageId})` (`U:4011-4024`).
6. 409 (`U:4027-4141`): conflict equals the superseded stream of a handoff → rollback, `{stop-failed}` + error "Previous response is still shutting down; queued message was restored."; conflict is another stream (or none) → `releaseRefusedSend` (rollback, gen++, abort, idle), set the chat's `activeStreamId` to the conflict id, `recoverActiveStream('busy_refusal')` (or mark detail stale if the view moved), return `{busy, admissionUnknown:false}`; conflict equals this id (duplicate) → check the stream exists via batch (gone/failed → `{busy}`), adopt `errorData.chatId` if chatless, `streamIdRef = conflictStreamId`, `retryReconnect`, finalize error if it fails.
7. Other non-2xx: `setError(errorData.error ?? 'Request failed: <status>')`, `finalize({error:true})` (`U:4144-4155`).
8. 2xx: clear queued handoff; `processSSEStream(body)`; stream error → finalize error; `sawComplete` → finalize; else `resumeOrFinalize` from the last cursor, then finalize if still sending (`U:4158-4199`).
9. Catch (`U:4200-4294`): abort with reason `unmount:client_cleanup` before any response → rollback, `{withdrawn}`; other aborts → return; schema error → setError + finalize error; no response (`!sendReachedServer`) → rollback, gen++, abort `send_unreachable:no_response`, idle, error "Message not sent: Sim could not be reached. Retrying." (online) / "… It will send when you are back online." (offline) or the error message, return `{unreachable|offline}`; response then failure → `retryReconnect` on `streamIdRef`, else setError + `finalize({error:true, streamTerminal:false})`.

### 4.7 Stream loop (`processSSEStream`, `U:2305-2531`)
Builds the context (§4.3), drops the reader if stale; `readSSELines` with 45 s idle timeout; per frame: ignore after complete, validate (§2.2), adopt `trace.requestId` (flush), set `streamIdRef` from `stream.streamId`, cursor dedupe (§2.4), dispatch, stop reading after `complete`. Finally: on stream error clear browser activity; error without complete → `applyTurnTerminal('error')` + flush; flush pending text; batch replay → `forceFlush`. Verdict: `sawStreamError = completionStatus==='complete' ? false : (sawStreamError || completionStatus==='error')` (`U:2499-2507`).

### 4.8 Reconnect and resume
- `resumeOrFinalize` (`U:2885-2970`): replay selection (keep state only if cursor > 0 and live content exists, else cursor `'0'` and fresh model, `message-reconcile.ts:338-349`); batch fetch; terminal status → replay batch (deferred flushes, suppress re-running completed client tools) then `finalize({error: status==='error'})`; else `attachToExistingStream` then finalize.
- `attachToExistingStream` (`U:2677-2883`): loop while gen unchanged: replay seed events → if terminal status return (`error` sets `RECONNECT_TAIL_ERROR`) → open tail `GET …/stream?streamId&after` (404 → gone; non-2xx → error) → log header reset → stream → complete returns; tail ended without terminal → batch from last cursor, seed again; empty non-terminal batch → sleep 1 s.
- `retryReconnect` (`U:2972-3134`): up to `MAX_RECONNECT_ATTEMPTS = 10` attempts, delay `min(1000·2^(n-1), 30000)` ms, attempts reset to 1 when the cursor advanced; `StreamGoneError` → finalize (transcript authoritative); schema error → setError, return false; exhausted → `setError(RECONNECT_TAIL_ERROR)` = "Live reconnect failed before the stream finished. The latest response may be incomplete." and one recheck after 30 s (`U:335-341,3101-3132`).
- Load-time reconnect (`U:2063-2302`): on each new hydration key, when `activeStreamId` is set, not sending, not the locally terminal stream, and `streamSnapshot.status` not terminal → gen++, abort previous, `streamIdRef = activeStreamId`, reconnecting, reset buffers and cursor `'0'`, `retryReconnect` targeting the chat; afterwards finalize/idle, or `finalize({error, streamTerminal:false})` on failure.
- Browser return (`U:3136-3336`): on `visibilitychange→visible`, `pageshow`, `online` (and `exhausted_recheck`, `busy_refusal`) with a chat selected: reload detail (10 s timeout), skip while an un-admitted POST is in flight, pick `activeStreamId` (or the locally running stream), skip if a stop is pending or the stream is locally terminal, gen++, supersede reader/controller, `resumeOrFinalize` from the last cursor when same stream else `'0'`, `retryReconnect` on failure.
- `resolveChatIdForStream` (`U:2595-2645`): batch from `'0'` until a chat id appears, 10 s deadline, 250 ms→2 s backoff.

### 4.9 Finalize (`U:3468-3548`)
Error → settle residual tool blocks as error and write the snapshot; desktop notification on success without queued follow-up (desktop only); reconcile preview sessions; clear resource activity; record `locallyTerminalStreamId` unless `streamTerminal:false`; `clearActiveTurn`; idle; invalidate detail (skipped when a follow-up is queued) + owner list; `awaitPersistedTurn(chatId, streamId)`: up to 120 s, backoff 250 ms–5 s, polls `stream-status` and refetches detail until `activeStreamId` ≠ the stream (`U:2018-2061`); `notifyTurnEnded` → `onStreamEnd` and queue drain (`U:3417-3433`).

### 4.10 Stop (`stopGeneration`, `U:4642-4937`)
Re-entrant (returns the pending stop; a `queued-handoff` stop while a normal one runs throws). `sid = streamIdRef ?? activeTurn.userMessageId ?? pendingAdmission.userMessageId ?? cached activeStreamId`. Snapshot blocks; `locallyTerminalStreamId = sid`; clear resource activity, stop desktop tools; gen++; `clearActiveTurn`; cancel reader; abort the controller with `user_stop:client_stopGeneration` (not a pending admission's); idle; snap smooth text. Mark the assistant stopped in the detail cache (`markMessageStopped`: stamp `endedAt`, unsettled tools → `cancelled` 'Stopped by user', append `complete{cancelled}` block, `message-reconcile.ts:148-190`) or in `pendingMessages` (cancel residual tools, append `stopped`). Cancel client workflow runs of the stopped tool ids. Stop barrier within 15 s: POST abort (§3.4); wait for a pending admission's chat id then abort it; resolve chat id; `persistStoppedResponse` when it was sending; retry abort once if not settled ("Previous response is still shutting down."); success → `notifyTurnEnded` (queue drain skipped for `queued-handoff`); finally invalidate (detail too unless a successful handoff) and reset preview state. Failure → setError, reject.

### 4.11 Queue (`stores/mothership-queue`, `U:4939-5420`)
- Keys: chat id, or `pending::<shortId>` before a chat exists (`lib/desktop/chat-scope.ts:19`, `U:870`); migrated to the chat id on adoption with `migratedTo` bookkeeping (`store.ts:254-279`).
- Entry: `QueuedMessage` + `queuedSendHandoff?{id, chatId?, supersededStreamId, stopRequired?}`, `hold?: 'user'|'online'`, `heldSurface?`, `retry?{attempt, notBefore}`, `resumeUserMessageId?`, `admissionUnknown?` (`types.ts:8-52`, `H/types.ts:39-48`). Any entry with `resumeUserMessageId` and no `admissionUnknown` is stored as `admissionUnknown:true` (`store.ts:66-71`).
- Requeue policy: offline → `hold:'online'`; unreachable/busy → `retry` backoff 1–30 s; stop-failed/failed → `hold:'user'`; withdrawn → none (`send-queue-policy.ts:48-66`).
- Auto-drain effect: queue non-empty, head not held, `notBefore` passed (timer otherwise), not sending, no stop, no running dispatch, history loaded when a chat is selected, no remote `activeStreamId` → `send_head` (`U:5353-5380`). Dispatch loop skips stale epochs, pending admission, held/delayed heads, a head being edited; `checkResend` re-reads history (staleTime 0) for `admissionUnknown` entries: accepted → drop, unreadable → `deferRetry`, else send (`U:5106-5178`, `send-queue-policy.ts:93-127`).
- `dispatchQueuedMessage`: re-reads the live entry, removes it when the optimistic pair applies, restores it on failure at its position (unless the user removed it meanwhile, or the chat was cleared) (`U:4939-5104`).
- Send now: drops the head if history shows it accepted, else stops the running turn (`queued-handoff`) and dispatches with a handoff seed (`U:5196-5287`). Edit: refused for `admissionUnknown` or mid-dispatch entries; clears stored handoff (`U:5289-5310`); edits drop `resumeUserMessageId`/hold/retry (`store.ts:207-238`).
- Online: `releaseHeldUntilOnline` on mount (if online) and on `online`; chatless mounts adopt held sends of the same surface `<scopeKey>:<workflowId|'home'>` (`U:783,5321-5332`). Unmount: chatless queue → `holdForSurface`; an un-answered first send is re-queued at the head (`U:5381-5420`).
- Accepted-recovery cleanup: a queued entry whose `resumeUserMessageId` is in history is discarded (`U:5333-5343`).
- Chat deleted: `clearChat` sets a delete token; no write recreates the queue until `liftDelete`/`reopenRestoredChat` (`store.ts:332-353`).

### 4.12 Chat identity, URL, navigation
- New chat: `createNewChat:true` creates the chat server-side; the client learns the id from `x-mothership-chat-id` (adopt + `replaceState`) or from `session chat` (`U:3989-4008`, `S/handle-session-event.ts:23-72`). URL: `/workspace/<ws>/chat/<chatId>` (+ `?resource=` kept), via `history.replaceState` (no router navigation) and only when not in the workflow copilot (`U:1355-1366`).
- Adoption also migrates queue/desktop scopes, clears `newChatEffort`, flushes pending resources (`U:1284-1383`).
- Route `/workspace/[ws]/chat/[chatId]` mounts `Home key={chatId}` (`app/workspace/[workspaceId]/chat/[chatId]/page.tsx:37`).
- Changing chats while sending detaches the stream without cancelling it server-side (gen++, cancel reader, idle, invalidate the abandoned detail); a new-chat stream keeps resolving its chat id in the background (`U:1843-1931`).
- Home marks the chat read when `resolvedChatId` changes and when `isSending` goes true→false (`H/home.tsx:147,193-200`).
- Cross-surface sends: `MOTHERSHIP_SEND_MESSAGE_EVENT` window event and `MothershipHandoffStorage.consume(workspaceId)` on the new-chat surface (`H/home.tsx:236-301`).

### 4.13 Effort and model
- Options: efforts low|medium|high|xhigh|max (simple picker without max), models `gpt-6-astra`, `gpt-6-sol`, `claude-opus-5-5`; default effort `high` (plan `medium`); `none → low`; without the model selector flag Build sends no `modelSelection`, `max → xhigh`, Plan forces `{model:'claude-opus-5-5', fastMode:false}` (`lib/mothership/model-options.ts:6-65`).
- Picks: existing chat → `useSetMothershipChatEffort` (PUT, §3.6) + `chatEfforts[chatId]`; new chat → `newChatEffort`, adopted onto the chat after admission and saved if it changed during the send (`model-selector.tsx:41-55`, `U:3631-3640`). `newChatEffort` cleared on unmount of a new-chat surface and on adoption (`U:1026-1029,1300-1305`).

### 4.14 Tool permission
- Server gate only when `COPILOT_TOOL_PERMISSIONS_ENABLED` (`env-flags.ts:84-102`): call frame stamped `status:'awaiting_approval'`; the turn blocks until a decision or 60 min (`PERMISSION_WAIT_TIMEOUT_MS`, `constants.ts:40`); allow → re-emitted call `status:'executing'`; skip → synthetic result `status:'skipped', success:true, output{skipped, reason:'user_declined', message}`; timeout/stop → result `status:'cancelled', error` (`lib/mothership/request/tools/permission.ts:107-350`).
- Client: a `tool_call` with `awaiting_approval` renders `ToolPermissionCard` instead of the row (`agent-group/tool-call-item.tsx:138-147`). Card registers in `useToolPermissionStore` on mount; the first outstanding card shows "N tools need permission · Allow all · Skip all" when > 1 outstanding; buttons Allow / Don't ask again (For this chat = `allow_chat`, For every chat = `always_allow`) / Skip; submit marks ids submitted (buttons disabled), POST §3.7; `always_allow` invalidates general settings; 404 → "<title> — this request is no longer active"; other error → toast "Could not record your choice. Please try again." and re-enable (`tool-permission-card.tsx:78-231`, `stores/tool-permission/store.ts`).
- Turn end with an unanswered prompt → node becomes the turn-terminal status (`S/turn-model.ts:777-796`).

### 4.15 Errors surfaced
Inline error tag (stream `error`), `setError` strings (not rendered on workspace Home, §3.10), `isReconnecting`, chat history error string "Failed to load chat history. Refresh to try again." in the returned `error` (`U:5427-5428`).

## 5. Persistence (shared with React)

| Store | Key | Format | Source |
|---|---|---|---|
| sessionStorage | `mothership-queue` | zustand persist `{"state":{"queues":{<chatKey>:[QueuedMothershipMessage…]}},"version":0}`; `editing` not persisted; on read legacy fields `retryRequired/heldUntilOnline/sendRetries/notBefore/queuedSendHandoff.userMessageId` are migrated and the admission guard applied | `stores/mothership-queue/store.ts:15-45,124-160,366-377` |
| localStorage | `mothership-drafts:v1` | `{"state":{"drafts":{<key>:{text, searchQuery?, fileAttachments?, contexts?}}},"version":1}`; empty payload deletes the key; v0 `<ws>:workflow-copilot:<wf>` keys dropped on migrate | `stores/mothership-drafts/store.ts:6-95` |
| draft keys | — | Home `<workspaceId>:<chatId|'new'>`; copilot panel `<workspaceId>:workflow-copilot:<workflowId>:<chatId|'new'>`; organization keys include user/org/surface | `H/home.tsx:405`, `drafts/store.ts:14-19` |
| draft writes | — | restore once on mount (contexts, attachments, text unless typed before hydration); save debounced 200 ms, flushed on unmount; cleared on submit (`clearComposer`) | `H/components/user-input/user-input.tsx:170-262,485-495` |
| localStorage | `mothership-effort`, `mothership-plan-effort` | `{"state":{"modelSelection":{"model":…,"fastMode":bool}},"version":0}`; invalid → default (`gpt-6-astra` / `claude-opus-5-5`, fastMode false); `newChatEffort`/`chatEfforts` memory only | `stores/mothership-effort/store.ts:40-104` |
| sessionStorage | `copilot_active_stream:queued-send-handoff` | `QueuedSendHandoffState {id, chatId?, supersededStreamId, stopRequired?, workspaceId?, organizationId?, userMessageId, message, fileAttachments?, contexts?, requestMode?, assistantSearch?, assistantSearchLevel?, requestedAt, resolveAttempts?, admissionUnknown?}`, TTL 5 min | `H/hooks/send-handoff.ts:23-43,144-240`, `constants.ts:82` |
| sessionStorage | `copilot_active_stream:queued-send-handoff-claim` | `{id, ownerId, claimedAt}`, TTL 30 s; cleared on `pagehide`/`beforeunload` | `send-handoff.ts:24-26,242-313`, `U:4439-4451` |
| localStorage | `sim_mothership_handoff` | `{message?, contexts, fileAttachments?, resumeUserMessageId?, requestMode?, assistantSearch?, assistantSearchLevel?, workspaceId?, organizationId?, timestamp}`, max age 60 s, consumed once | `lib/core/utils/browser-storage.ts:115,250-400` |
| memory only | tool-permission ids, effort picks, `TurnModel`, cursors, `locallyTerminalStreamId` | — | — |

## 6. Failure modes

| # | Situation | React behaviour | Source |
|---|---|---|---|
| F1 | Network cut mid-stream (live POST) | read throws or 45 s silence (`SSEIdleTimeoutError`) → catch path → `retryReconnect` from `lastCursor` (tail/batch) → finalize | `U:2427,4280-4294` |
| F2 | Tail ends without terminal | batch from cursor, replay, reopen tail; 1 s pacing on empty batches | `U:2833-2856` |
| F3 | seq gap | not detected client-side; server serves the ring or re-syncs from the log (`x-mothership-stream-replay: log` → reset to cursor 0, rebuild) | `stream/route.ts:305-311`, `U:2789-2794` |
| F4 | Duplicate envelopes after reconnect | dropped by cursor ≤ last (`isAlreadyProcessedStreamCursor`) and by reducer `seq ≤ lastSeq`; replayed tool results/resources carry `replay:true` and skip side effects (file tab promotion, preview cleanup); completed client tools not re-run | `U:2454`, `S/turn-model.ts:467`, `S/handle-tool-event.ts:170-171`, `message-reconcile.ts:351-373` |
| F5 | Stream gone (404 on tail/batch) | finalize, refetch persisted transcript, no error | `U:3068-3080` |
| F6 | Schema-invalid frame | `StreamSchemaValidationError` → setError(message) + finalize error; reconnect halts | `U:2433-2445,3081-3091,4227-4236` |
| F7 | Stop during tool call | local: tools cancelled ('Stopped by user'), `stopped`/`complete{cancelled}` block; server: abort → `complete{cancelled}`; gated prompt → result `cancelled` "Stopped before the user approved this tool."; client workflow runs cancelled | `U:4746-4787`, `permission.ts:262-298` |
| F8 | Stop abort not settled | retry once; then error "Previous response is still shutting down." and the stop rejects; a queued handoff send is restored (`hold:'user'`) | `U:4864-4880,3906-3912` |
| F9 | Permission denied (Skip) | result `skipped` (success) → row status `skipped`; model continues | `permission.ts:320-341` |
| F10 | Permission POST 404 / other error | 404 → expired line; else toast + retry possible | `tool-permission-card.tsx:117-132` |
| F11 | Send 409 busy (other tab/turn) | rollback, queue entry with `retry` backoff, attach to the running turn (`busy_refusal`) | `U:4063-4097` |
| F12 | Send 409 duplicate | verify stream exists; adopt `chatId`; reconnect to own stream | `U:4098-4141` |
| F13 | Send 4xx/5xx other (incl. 429, 403, 404 chat deleted) | `setError(body.error ?? 'Request failed: <status>')`, `finalize({error:true})`; optimistic pair stays until the detail refetch; no retry | `U:4144-4155` |
| F14 | Send without response (offline/DNS) | rollback; queue `hold:'online'` (offline) or `retry` (online, `TypeError`); message "Message not sent: Sim could not be reached. …" | `U:4237-4269` |
| F15 | Worker error mid-turn | inline error tag; `complete{error}` ⇒ error verdict; a `complete{complete}` after an error frame ⇒ success verdict | `U:2499-2507` |
| F16 | Chat deleted elsewhere | `task_status deleted` → detail removed, queue cleared and blocked; open chat reload → 404 → history error string | `use-mothership-chat-events.ts:125-134`, `Q:370-380` |
| F17 | Two tabs on one chat | second tab hydrates `activeStreamId` and tails the same stream (read-only); a send from it gets 409 busy (F11); tool permission answer from both → first wins (`applied:false` for the second, card ignores `results`) | `U:2063-2302`, `tool-permission/route.ts:70-77` |
| F18 | Reconnect exhausted (10 attempts) | `RECONNECT_TAIL_ERROR`, finalize error (`streamTerminal:false` keeps the stream recoverable), 30 s recheck, browser-return recovery | `U:3101-3132` |
| F19 | Turn finished but transcript not yet saved | `awaitPersistedTurn` polls `stream-status` ≤ 120 s | `U:2018-2061` |
| F20 | Unmount mid-POST | abort `unmount:client_cleanup`; withdrawn send re-queued/handed off under the same `userMessageId` (server dedups) | `U:4210-4224,5381-5420` |
| F21 | Usage limit | `<usage_upgrade>` text + `complete{complete}` | `tools/billing.ts:26-60` |
| F22 | `COPILOT_API_KEY` unset | §3.10 | — |

## 7. Parity checklist

| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | network | `lib/core/utils/sse.ts:137-195` | `data:` lines decoded one per event, `\r` stripped, `[DONE]` skipped, comments ignored | | |
| 2 | network | `U:343,2427` | 45 s idle timeout reset by any chunk incl. `: keepalive` | | |
| 3 | network | `session/contract.ts:233-251` | envelope shell validation (v, seq, ts string, stream, trace, scope, known type, payload object) | | |
| 4 | network | `session/contract.ts:253-341` | per-type payload validation incl. `steering_applied` accepted | | |
| 5 | state | `U:2433-2445` | invalid frame aborts the stream with "Client stream schema enforcement failed…" | | |
| 6 | state | `U:2453-2459` | cursor = `stream.cursor ?? String(seq)`; ≤ last dropped | | |
| 7 | state | `S/turn-model.ts:467` | reducer no-op for `seq ≤ lastSeq` | | |
| 8 | network | `U:3946-3984` | POST body fields exactly as §3.1 (no `model`, no `clientCapabilities`) | | |
| 9 | network | `U:3953` | `createNewChat = !requestChatId` | | |
| 10 | network | `U:3592-3593` | `userMessageId` reused on retries, else fresh id | | |
| 11 | network | `U:3969` | `userTimezone` from the device time zone | | |
| 12 | network | `U:3970-3981` | `modelSelection` + `effort` only for non-assistant; effort only when picked | | |
| 13 | state | `U:3753-3775` | optimistic user + empty assistant `live-assistant:<id>`; detail `activeStreamId = userMessageId` | | |
| 14 | state | `U:3989-4008` | chat id from `x-mothership-chat-id`; adopt + `replaceState` to `/workspace/<ws>/chat/<id>` | | |
| 15 | state | `S/handle-session-event.ts:23-72` | `session chat` adopts chat, seeds detail cache, clears pending, URL replace | | |
| 16 | network | `U:4011-4024` | `traceparent` stored and echoed on stream GET / abort / stop | | |
| 17 | state | `S/handle-session-event.ts:76-83` | `session title` invalidates the list and calls `onTitleUpdate` | | |
| 18 | state | `S/turn-model.ts:303-332` | text appends per lane+channel; channel switch closes the other channel's segment | | |
| 19 | state | `S/turn-model.ts:474-479,432-458` | subagent-scoped content before span start creates the lane | | |
| 20 | state | `S/turn-model.ts:492-513` | `apply_file_edit` folds into the latest `prepare_file_edit` of the span | | |
| 21 | state | `S/turn-model.ts:534-540` | `awaiting_approval` / `executing` call-status transitions | | |
| 22 | state | `S/turn-model.ts:554-570` | args_delta appends `streamingArgs`, CLI name refinement | | |
| 23 | state | `stream-tool-outcome.ts:17-47` | result status resolution incl. `user_cancelled`, `aborted`, `failed` | | |
| 24 | state | `S/turn-model.ts:398-416` | result before call buffered and drained | | |
| 25 | state | `S/turn-model.ts:583-662` | span start/end, `pending` pause ignored, end settles running tools | | |
| 26 | state | `S/turn-model.ts:665-727` | task_armed/delivered node, compaction start/done | | |
| 27 | state | `S/turn-model.ts:729-745` | error envelope appends `<mothership-error>` tag once | | |
| 28 | state | `S/turn-model.ts:747-796` | complete → turn terminal propagated; `async_pause` ignored | | |
| 29 | state | `S/turn-model-serialize.ts:85-240` | blocks serialization order and fields | | |
| 30 | state | `S/stream-context.ts:271-338` | flush target: pendingMessages before chat id, detail cache after | | |
| 31 | state | `S/stream-context.ts:33,348-376` | text flush ≥ 50 ms apart, frame-aligned | | |
| 32 | state | `U:2499-2507` | verdict: complete{complete} beats error frames; complete{error} is error | | |
| 33 | state | `S/handle-error-event.ts:9-17` | error text = displayMessage ‖ message ‖ error ‖ 'An error occurred' | | |
| 34 | state | `S/handle-resource-event.ts:108-122` | readOnly upsert ignored; settings refresh by scope | | |
| 35 | state | `S/handle-tool-event.ts:63-159` | result side effects skipped on replay where React skips them | | |
| 36 | network | `U:2564-2593` | batch GET 10 s timeout; 404 → gone | | |
| 37 | network | `U:2768-2786` | tail GET with `after` cursor; non-2xx → reconnect error | | |
| 38 | network | `U:367-369,2789-2794` | `x-mothership-stream-replay: log` → reset to 0 and `&source=log` thereafter | | |
| 39 | state | `message-reconcile.ts:338-349` | replay keeps state only with cursor > 0 and live content | | |
| 40 | state | `U:2833-2856` | tail without terminal → batch → seed; 1 s pause on empty batch | | |
| 41 | state | `U:2972-3134` | 10 attempts, 1 s·2^n ≤ 30 s, reset on progress | | |
| 42 | state | `U:3101-3132` | exhausted → "Live reconnect failed before the stream finished…", 30 s recheck | | |
| 43 | state | `U:3068-3080` | stream gone → finalize without error | | |
| 44 | state | `U:2063-2302` | load-time reconnect when `activeStreamId` and snapshot not terminal; from cursor 0 | | |
| 45 | state | `U:3301-3336` | recover on visible/pageshow/online | | |
| 46 | state | `U:3136-3299` | recovery skipped while an un-admitted POST is in flight or a stop is pending | | |
| 47 | state | `U:3468-3548` | finalize: settle residual tools on error, idle, invalidate detail+list, await persisted turn | | |
| 48 | network | `U:2018-2061` | `stream-status` polling ≤ 120 s, 250 ms–5 s backoff | | |
| 49 | state | `U:4027-4097` | 409 busy → rollback + requeue `retry` + attach to running turn | | |
| 50 | state | `U:4098-4141` | 409 duplicate → batch existence check → reconnect own stream | | |
| 51 | state | `U:4144-4155` | other non-2xx → error message + finalize(error) | | |
| 52 | state | `U:4237-4269` | no response → rollback, offline hold vs online retry, message text | | |
| 53 | state | `U:4210-4224` | unmount abort before response → withdrawn, same id reused later | | |
| 54 | network | `U:4801-4813` | Stop: POST `/api/copilot/chat/abort` `{streamId, workspaceId, chatId?}` keepalive, 15 s | | |
| 55 | network | `U:3338-3386,4852-4859` | Stop: POST `/api/mothership/chat/stop` `{chatId, streamId, requestId?}` when it was sending | | |
| 56 | state | `U:4721-4787` | Stop local effects: gen++, reader cancelled, idle, message marked stopped | | |
| 57 | state | `U:4864-4880` | abort not settled → retry once → error | | |
| 58 | state | `U:4337-4400` | queue when sending/stop pending/queue non-empty | | |
| 59 | state | `U:5353-5380` | auto-drain conditions incl. remote `activeStreamId` blocks | | |
| 60 | state | `send-queue-policy.ts:48-66` | requeue policy per reason | | |
| 61 | state | `U:5106-5131` | resend check for `admissionUnknown` entries (drop/wait/send) | | |
| 62 | state | `U:5196-5287` | Send now stops the running turn (`queued-handoff`) then dispatches | | |
| 63 | state | `U:5289-5310`, `store.ts:207-238` | edit refused for admissionUnknown; edit strips resume/hold/retry | | |
| 64 | state | `U:5321-5332` | held-online sends released on `online`; chatless surfaces adopt held sends | | |
| 65 | persistence | `mothership-queue/store.ts:366-377` | sessionStorage `mothership-queue` envelope v0 `{queues}` read/written compatibly | | |
| 66 | persistence | `mothership-queue/store.ts:66-160` | legacy-field migration and admission guard on restore | | |
| 67 | persistence | `mothership-queue/store.ts:254-279` | `pending::` key migrated to chat id; `migratedTo` followed by later writes | | |
| 68 | persistence | `mothership-drafts/store.ts:57-95` | localStorage `mothership-drafts:v1` v1 envelope; empty draft deletes key | | |
| 69 | persistence | `H/home.tsx:405` | draft key `<ws>:<chatId|'new'>` | | |
| 70 | persistence | `user-input.tsx:215-262` | draft save debounce 200 ms, flush on unmount, clear on submit | | |
| 71 | persistence | `mothership-effort/store.ts:83-99` | localStorage `mothership-effort`/`mothership-plan-effort` `{modelSelection}` v0 | | |
| 72 | persistence | `send-handoff.ts:23-26` | sessionStorage handoff + claim keys, TTL 5 min / 30 s | | |
| 73 | persistence | `browser-storage.ts:115,294-400` | localStorage `sim_mothership_handoff`, 60 s, consumed once on the new-chat surface | | |
| 74 | state | `U:1026-1029,1300-1305` | `newChatEffort` cleared on new-chat unmount and on chat adoption | | |
| 75 | network | `Q:784-848` | effort PUT, per-chat serial scope, rollback + toast on error | | |
| 76 | state | `model-options.ts:39-59` | effort/model resolution (no selector: max→xhigh, plan forced Opus) | | |
| 77 | network | `copilot.ts:71-93,448-466` | tool-permission body/response shapes | | |
| 78 | state | `tool-permission-card.tsx:100-104` | bulk "Allow all/Skip all" only on the first outstanding card when >1 | | |
| 79 | state | `tool-permission-card.tsx:117-132` | 404 → "this request is no longer active"; else toast + re-enable | | |
| 80 | network | `Q:110-133,192-193` | query keys and staleTimes (list 60 s, detail 30 s) | | |
| 81 | network | `Q:370-422` | detail read `window=latest`, then `from=windowStartCursor`, join older messages | | |
| 82 | network | `Q:451-504` | older-message paging with retry policy | | |
| 83 | network | `Q:510-533` | delete: remove detail, clear queue, invalidate owner lists | | |
| 84 | network | `Q:850-895` | fork: optimistic `Fork | <name>` row after pinned | | |
| 85 | network | `Q:535-562` | restore: lift delete token, invalidate recently-deleted + lists | | |
| 86 | network | `use-mothership-chat-events.ts:263-307` | events SSE opened from the sidebar with rotation; resync lists on reconnect | | |
| 87 | state | `use-mothership-chat-events.ts:111-169` | per-type invalidations incl. skip rules | | |
| 88 | state | `Q:301-315` | sidebar running (`isActive`) and unread dots from list rows | | |
| 89 | network | `H/home.tsx:193-200` | mark read on chat change and on send end | | |
| 90 | state | `U:1843-1931` | switching chats mid-stream detaches without server cancel | | |
| 91 | state | `display-message.ts:21-235` | persisted → display mapping (interrupted, Stopped by user, fold, hidden) | | |
| 92 | state | `mothership-chat.tsx:770-772,953` | option/question answer submits the id as a message, last row only | | |
| 93 | state | §3.10 | missing worker key → inline error tag, chat untitled, no banner on workspace Home | | |

## 8. Ambiguities
1. The worker's exact response without `x-api-key` (401 vs 403, body text) is outside this repo; only the Sim-side mapping (4xx → short reason or "The agent service could not process this request.", unreachable → "temporarily unavailable") is known (`go/stream.ts:69-126`).
2. What the persisted assistant row holds after a worker error (error tag or empty) depends on `buildOnError` → `finalizeAssistantTurn`, not mapped here; after `finalize` the detail refetch replaces the live row with it.
3. The hook's `error` is not rendered on workspace Home or the copilot panel (§3.10); only the organization home toasts it. Whether Flutter should show it is a product call; parity says no.
4. `MothershipSeqTracker` in Dart reports gaps "which the chat engine turns into a reconnect", but React never reacts to gaps (§2.4). Parity says ignore gaps client-side.
5. Dart `MothershipStreamEnvelope.fromJson` maps unknown types to `unknown` and tolerates a missing `ts`/non-object payload; React aborts the stream on these. Parity says reject.
6. Client-executed tools (`run_workflow…`, desktop/browser/terminal/computer) are started from call frames in React; workflow runs need the Phase 3 execution engine and desktop tools need the desktop bridge. Their Phase 1.5 behaviour on web (leave the call running until the server times it out, or report an error via `/api/copilot/confirm`) is undecided.
7. `allow_chat`/`always_allow` are labelled "Don't ask again → For this chat / For every chat"; the brief's "Deny" corresponds to `skip` ("Skip"). There is no explicit deny decision.
8. `task_status` for organization owners omits `ownChat` (`events/route.ts:60-66`); Phase 1.5 covers workspaces only.
9. The `/api/mothership/chat/abort` shim exists but React calls `/api/copilot/chat/abort`; both reach the same handler (`app/api/mothership/chat/abort/route.ts:7-12`).
10. Steering (`/api/copilot/chat/steer`, `run steering_applied`) exists server-side but `useChat` never calls it.
11. Resource-panel side effects of `resource` events and file-preview phases are listed but their panel rendering is specified elsewhere; this spec does not fix how a Phase 1.5 placeholder panel consumes them.
