# Sim workflow editor: architecture map (reference for the Flutter port)

Mapped from upstream commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c (v0.9.30). Paths relative to the repo root. Line counts exclude tests. `E` = `apps/sim/app/workspace/[workspaceId]/w/[workflowId]`.

## 1. Component inventory

### Canvas
- `E/workflow.tsx` (5,382 lines): wraps everything in `ReactFlowProvider`, renders `<ReactFlow>` with all node/connect/drag/selection/context-menu/pointer callbacks; `SelectionMode.Partial`, `ConnectionLineType.SmoothStep`, zoom 0.1–1.3, snap-to-grid from a setting, `onlyRenderVisibleElements={false}`.
- Mounts (each in `E/components`): `Cursors`, `WorkflowControls`, lazy `Chat`, `BlockMenu`, `CanvasMenu`, `CommandList`, `DiffControls`, `Terminal`, `Panel`, `WorkflowSearchReplace`, `FocusBlockDeepLink`.
- Owns copy/cut/paste, duplicate, auto-layout, dropping/reparenting blocks into loop/parallel containers.

### Node and edge types (`E/workflow-constants.ts`)
- Nodes: `workflowBlock`, `noteBlock` (lazy), `subflowNode`, `connectionBlockSelector`. Edges: `default`, `workflowEdge` → `WorkflowEdge`.
- `workflow-block/workflow-block.tsx` (1,353) connected wrapper; visuals in `packages/workflow-renderer/src/workflow-block/block-view.tsx` (1,095).
- `packages/workflow-renderer/src/workflow-block/border.tsx` (1,813): animated SVG path outline via rAF; a "swell" bulge follows the cursor along the perimeter, a drag can start a connection from anywhere on it; draws ports and run-status rings.
- `subflows/subflow-node.tsx` (100) wraps `packages/workflow-renderer/src/subflow/node-view.tsx` (719): resizable loop/parallel container.
- `note-block/note-block.tsx` (449): read view Streamdown markdown via `workflow-renderer/src/note/block-view.tsx` (1,205); edit view TipTap (`RichMarkdownField`).
- `workflow-edge/workflow-edge.tsx` (114) wraps `workflow-renderer/src/edge/workflow-edge-view.tsx` (307): `getSmoothStepPath` radius 8, hit width 30, animated dash for run state.
- `connection-block-selector` (566): temporary node when a connection is dropped on empty canvas; uses cmdk.

### Panel and tabs
- `panel/panel.tsx` (1,153): right panel, tabs `copilot | editor | toolbar` (`stores/panel/types.ts`).
- Block editor: `panel/components/editor/editor.tsx` (873); `sub-block/sub-block.tsx` (1,291) switches on subblock type (47 cases); ~45 editor components in `sub-block/components/*`. Largest: tool-input 2,026; tag-dropdown 1,739; condition-input 1,324; code 1,001; file-upload 999; messages-input 817; starter/input-format 802.
- `panel/components/toolbar/toolbar.tsx` (1,009): block palette (drag source).
- Deploy modal: `panel/components/deploy/**` (deploy-modal.tsx 928).
- Copilot tab: `panel/components/copilot/**` (1,605) reusing `MothershipChat` and `useChat` from `app/workspace/[workspaceId]/home` (`use-chat.ts` 5,462).

### Terminal and floating chat
- `terminal/terminal.tsx` (1,420): resizable bottom console virtualized with `@tanstack/react-virtual`; `output-panel/output-panel.tsx` (633) + `structured-output.tsx` (1,030) JSON tree viewer. Not xterm.
- `chat/chat.tsx` (1,181): floating draggable/resizable test chat (`hooks/float/*`), runs via `useWorkflowExecution`.

### Smaller editor components
action-bar 758 (hover actions on a block) · variables 571 · search-replace 686 · canvas-menu 205 · block-menu 314 · command-list 227 · diff-controls 105 · cursors 90 (remote cursors via `useViewport` + translate3d) · wand-prompt-bar 158 · workflow-controls 246.

### Hooks
- `E/hooks`: use-workflow-execution.ts (2,677) + `utils/workflow-execution.ts` (1,255); use-node-utilities (475), use-wand (360), use-auto-layout, use-block-dimensions, use-dynamic-handle-refresh.
- Shared: `apps/sim/hooks/use-collaborative-workflow.ts` (2,373), `use-undo-redo.ts` (2,045), `use-execution-stream.ts` (645), `use-canvas-viewport.ts` (220), `apps/sim/app/workspace/providers/socket-provider.tsx` (1,398).

### Outside the editor page (`apps/sim/app/workspace/[workspaceId]/w/components`)
Sidebar 13.8k lines total (sidebar.tsx 1,958; search-modal 1,419 cmdk; use-drag-drop.ts 820). Read-only preview 3.8k. workflow-diff 2.3k (comparison modal + change list).

### Third-party deps the editor relies on
`@xyflow/react` 12.12 (31 imports), zustand (~25 stores), `@tanstack/react-query`, `socket.io-client` 4.8, `react-simple-code-editor` + `prismjs` for every code field (`Code` in `packages/emcn/src/components/code`), cmdk, streamdown (markdown), TipTap (notes only), `@tanstack/react-virtual`, Radix + framer-motion via emcn, `diff`, es-toolkit, idb-keyval (console persistence).
Not in the editor: Monaco (only `files/.../text-editor.tsx`), xterm (only `home/.../terminal-session.tsx`), TipTap (notes only).

### Hard in Flutter
SVG perimeter-swell border with magnetized connection starts · text inputs overlaying highlighted `<block.output>` / `{{ENV}}` tokens on a transparent native input with synced scroll (`short-input.tsx`, `formatted-text`) · Prism code editors with per-field undo (`stores/undo-redo/code`) · React Flow parent/child nodes (`parentId`, `extent: 'parent'`) with drag-to-reparent.

## 2. Data model

WorkflowState (`packages/workflow-types/src/workflow.ts`):
```ts
{ blocks: Record<id, BlockState>, edges: Edge[] /* @xyflow Edge */, loops: Record<id, Loop>,
  parallels: Record<id, Parallel>, variables?: Record<id, Variable>, lastSaved?, metadata? }
```
- BlockState: `id, type, name, position, subBlocks: Record<id,{id,type,value}>, outputs, enabled, horizontalHandles?, errorEnabled?, retry?, advancedMode?, triggerMode?, locked?, layout, data` (`parentId, extent, width, height`, loop/parallel config, `canonicalModes`).
- Loops/parallels: containers are blocks of type `loop`/`parallel`; the `loops`/`parallels` maps are generated (`generateLoopBlocks`) with `nodes[]`, `loopType` (for/forEach/while/doWhile), `iterations`, `parallelType`/`batchSize`.
- Variables: `{id, name, type: string|number|boolean|object|array|plain, value}`.

Two stores on purpose (`.claude/rules/sim-stores.md`): `useWorkflowStore` (`stores/workflows/workflow/store.ts`, 1,346) holds structure; `useSubBlockStore` (`stores/workflows/subblock/store.ts`) holds live field values. Merge: a key present in the subblock store wins, `null` there means "cleared", otherwise the structure's value (`mergeSubblockState`, `@sim/workflow-persistence/subblocks`).

Block UI from the registry: `apps/sim/blocks/types.ts` `BlockConfig`: `type, name, category (blocks|tools|triggers), bgColor, icon (SVG React component), subBlocks: SubBlockConfig[], tools {access[], config.tool(params), config.params(params)}, inputs, outputs, triggers, canvasPresentation` (`canvasPresentation.sentences` = prose sentence on the card with live value chips, see `blocks/AGENTS.md`). Lookup `blocks/registry.ts` (`getBlock`, `getAllBlocks`), backed by `blocks/registry-maps.ts`; ~371 block files.
SubBlockConfig: `type, title, mode (basic|advanced|both|trigger|trigger-advanced), canonicalParamId, condition/required ({field, value, not?, and?} or function), dependsOn, options (static or function), selectorKey (remote options), wandConfig, password, language, generationType, reactiveCondition, hidden, placeholder, min/max/step`.

SubBlockType: 48 variants (`packages/workflow-types/src/blocks.ts`): short-input, long-input, dropdown, combobox, slider, table, code, switch, tool-input, skill-input, checkbox-list, grouped-checkbox-list, condition-input, eval-input, time-input, oauth-input, webhook-config, schedule-info, file-selector, sheet-selector, project-selector, channel-selector, user-selector, folder-selector, knowledge-base-selector, knowledge-tag-filters, document-selector, document-tag-entry, mcp-server-selector, mcp-tool-selector, mcp-dynamic-args, input-format, response-format, filter-builder, sort-builder, file-upload, input-mapping, variables-input, messages-input, workflow-selector, workflow-output-selector, workflow-input-mapper, text, router-input, table-selector, model-fallback-list, column-selector, modal.
Output fields typed `PrimitiveValueType` (string, number, boolean, json, array, file, file[], any), may carry a condition.

Tools: `ToolConfig` (`apps/sim/tools/types.ts`): `id` (snake_case), `params` schema with visibility, `outputs`, `oauth`, `request {url, method, headers, body}` as functions of params. Blocks reference tools by id in `tools.access`, pick one at serialization via `tools.config.tool(params)`.

Connections and handles: canonical ids `target` (left), `source` (right), `error` (bottom; shown when `errorEnabled` or an error edge exists), `condition-{conditionId}` / `router-{routeId}` (one per row, right side, y = 58 + 28·row, `HANDLE_POSITIONS` in `packages/workflow-renderer/src/dimensions.ts`), `loop-start-source` / `loop-end-source` and parallel equivalents. Temporary `source-cursor-*` handles map back to canonical ids (`workflow-block/source-handle.ts`). Edge rules shared client/server: `wouldCreateCycle` (DAG), `filterUniqueWorkflowEdges` (no dupes/self-loops), `getWorkflowEdgeScopeDropReason` (edges only within same container or container↔direct child); note blocks take no edges.

Dimensions (`packages/workflow-renderer/src/dimensions.ts`): blocks width 250, header 40, rows 20, gap 8, sentence line 24; notes 320 wide, height 70–240; containers default 500×300, min 400×200, padding 24/80/24/80. Real heights measured from the DOM (`updateBlockLayoutMetrics`).

Serializer (`apps/sim/serializer/index.ts`, `Serializer.serializeWorkflow`): WorkflowState → `SerializedWorkflow {version, blocks[{id, position, config:{tool, params}, inputs, outputs, metadata, enabled, canonicalModes, retry}], connections[{source, target, sourceHandle, targetHandle}], loops, parallels}`; resolves canonical pair member, picks tool id, validates required fields (`collectBlockFieldIssues`). `deserializeWorkflow` reverses.

## 3. Collaboration and realtime

Auth handshake: client POSTs `/api/auth/socket-token` (rate-limited) → Better Auth one-time token; `io(NEXT_PUBLIC_SOCKET_URL, {transports:['websocket','polling'], withCredentials:true, auth: cb({token})})`, fresh token every reconnect. Server (`apps/realtime/src/middleware/auth.ts`) `auth.api.verifyOneTimeToken` → attaches userId, userName, userImage, activeOrganizationId.
Rooms (`packages/realtime-protocol/src/rooms.ts`): workflow room name = bare workflowId; other room types `${type}:${id}`. State in Redis (`rooms/redis-manager.ts`) with in-memory fallback.
Joining (`apps/realtime/src/handlers/workflow.ts`): emit `join-workflow {workflowId, tabSessionId}` → server checks role (read/write/admin), leaves previous room, cleans stale/same-tab sockets, joins, records presence → replies `join-workflow-success {workflowId, socketId, presenceUsers[]}`, then `workflow-state {id, state,…}`, then broadcasts `presence-update`; failure `join-workflow-error {workflowId, error, code, retryable}`. On `workflow-state` the client re-fetches `GET /api/workflows/[id]/state` (`stores/workflows/sync-local-draft.ts`) and only applies the raw payload if that fetch fails.

Client → server (`socket-provider.tsx:1090-1280`):
| Event | Payload |
|---|---|
| join-workflow | {workflowId, tabSessionId} |
| leave-workflow | none |
| workflow-operation | {workflowId, operation, target, payload, timestamp, operationId} |
| subblock-update | {workflowId, blockId, subblockId, value, timestamp, operationId} |
| variable-update | {workflowId, variableId, field, value, timestamp, operationId} |
| cursor-update | {cursor:{x,y}|null} throttled 33ms, flow coords |
| selection-update | {selection:{type:'block'|'edge'|'none', id?}} |

workflow-operation vocabulary (`packages/realtime-protocol/src/constants.ts`, zod in `schemas.ts`):
- target block: update-position (with `commit`; uncommitted moves coalesce on 33ms timer), update-name, toggle-enabled, update-parent, update-advanced-mode, update-error-enabled, update-retry, update-canonical-mode, replace-canonical-modes, toggle-handles
- target blocks: batch-update-positions, batch-add-blocks ({blocks, edges, loops, parallels, subBlockValues}), batch-remove-blocks ({ids}), batch-toggle-enabled, batch-toggle-handles, batch-update-parent, batch-toggle-locked
- target edge: add, remove · target edges: batch-add-edges, batch-remove-edges
- target subblock: subblock-batch-update ({updates:[{blockId, subblockId, value, expectedValue?}]}), subblock-update-with-canonical-modes
- target subflow: update ({id, type, config}) · target variable: add, remove · target workflow: replace-state ({state})

Server → client (typed in `packages/realtime-protocol/src/events.ts`): join-workflow-success / join-workflow-error; workflow-state; presence-update (UserPresence[]: userId, userName, socketId, tabSessionId, role, avatarUrl, cursor, selection, joinedAt, lastActivity); workflow-operation (sender envelope + senderId, userId, userName, metadata{workflowId, operationId, isPositionUpdate?}; room minus sender); subblock-update; variable-update; cursor-update / selection-update ({socketId, userId, userName, avatarUrl, cursor|selection}); operation-confirmed ({operationId, serverTimestamp}); operation-failed ({operationId, error, retryable?}); operation-error, operation-forbidden; workflow-deleted / workflow-reverted / workflow-updated ({workflowId, message, timestamp}; triggered by Sim app via realtime HTTP `routes/http.ts` POST /api/workflow-*); workflow-deployed ({workflowId, timestamp}); access-revoked; room-access-revoked ({room, message, timestamp}).

Server persistence: `apps/realtime/src/database/operations.ts` (2,240) writes to Postgres; subblock updates debounced ~25ms per block+field (`handlers/subblocks.ts`); position moves broadcast first, persist after.

Operation queue (`stores/operation-queue/store.ts`, 730): `executeQueuedOperation` in `use-collaborative-workflow.ts` queues `{id, operation, workflowId, userId}` then applies locally; one operation in flight at a time awaiting confirmation; timeouts 15s subblock/variable, 5s structural; retries subblock/variable up to 5 with linear backoff ≤3s, structural up to 3; non-retryable failure → offline mode; pending writes to the same field superseded, duplicate content dropped; remote changes applied under `isApplyingRemoteChange` guard.
Presence: `stores/presence/store.ts`; `components/cursors` applies viewport transform.

## 4. Execution
- Trigger: `POST /api/workflows/{id}/execute` body `{…, stream:true}`; fields `input, workflowInput, selectedOutputs, startBlockId, stopAfterBlockId, triggerType, useDraftState, isClientSession, workflowStateOverride, sourceSnapshot`. Response is SSE; execution id in `X-Execution-Id` header (`hooks/use-execution-stream.ts`).
- Reconnect: `GET /api/workflows/{id}/executions/{executionId}/stream?from={eventId}` (Redis replay). Fallback `GET /api/workflows/{id}/executions/{executionId}?includeOutput=true`. Cancel `POST .../executions/{executionId}/cancel`.
- SSE events (`lib/workflows/executor/execution-events.ts`): run-level `execution:started|completed|paused|error|cancelled` (terminal ones carry `finalBlockLogs`); block-level `block:started` (blockId, blockName, blockType, executionOrder, iterationCurrent/Total/Type/ContainerId, parentIterations, child-workflow fields), `block:completed` / `block:error` (+ input, output|error, durationMs, startedAt, endedAt); `block:childWorkflowStarted`; live-only (not replayed): `stream:chunk, stream:chunk_reset, stream:done, stream:thinking, stream:tool`.
- Canvas state (`stores/execution`): activeBlockIds, pendingBlocks, lastRunPath Map<blockId,'success'|'error'>, lastRunEdges, currentExecutionId → block rings + animated edges.
- Terminal (`stores/terminal/console/store.ts`): one ConsoleEntry per block execution (blockName/Type, executionOrder, duration, input, output, error, warning, isRunning/isCanceled, iteration/child nesting, agent thinking + tool-call stream); persisted in IndexedDB (idb-keyval); virtualized list + JSON tree.

## 5. Undo/redo, diff, copilot
- Undo/redo (`stores/undo-redo/store.ts`, `hooks/use-undo-redo.ts`): one stack per (workflow, user) in localStorage; capacity 100, ≤5 stacks; entries store forward op + inverse as snapshots (BatchAddBlocks, BatchMoveBlocks before/after, BatchUpdateSubblocks, apply/accept/reject-diff…); replayed through collaborative ops so they sync. Code fields have their own stack (`stores/undo-redo/code`).
- Diff (`stores/workflow-diff/store.ts`, `lib/workflows/diff/engine.ts` 842): status none|staged|showing; `setProposedChanges(state, analysis)` keeps a baseline, computes `DiffAnalysis {new_blocks, edited_blocks, deleted_blocks, field_diffs, edge_diff}`, marks `is_diff: 'new'|'edited'`; DiffControls accept/reject/toggle; socket ops suppressed while baseline shown.
- Copilot: panel tab uses `useChat` streaming SSE from `/api/mothership/chat` (stop `/api/mothership/chat/stop`, reconnect `/api/mothership/chat/stream`). After `edit_workflow` tool success the client fetches `GET /api/workflows/{id}/state` and calls `setProposedChanges(fresh, undefined, {baselineWorkflow, skipPersist:true})` (`panel.tsx:396-419`); server already saved, diff only overlays.
- Wand (AI fill for one field): `use-wand.ts` → `wandGenerateStreamContract` (`/api/wand`).

## 6. Ten hardest things to rebuild in Flutter (ranked)
1. React Flow graph editor: pan/zoom, partial marquee selection, multi-select keys, snap-to-grid, nested parent/child nodes with `extent:'parent'`, drop-into-container highlighting and reparenting, handles by DOM measurement, smooth-step routing. `workflow.tsx` alone is 5.4k lines on top of it.
2. Animated SVG border (`border.tsx` 1.8k): perimeter sampling, cursor swell, drag-from-anywhere connections, ring pulses → CustomPainter path math + hit-testing.
3. Collaborative protocol client: Socket.IO, one-time-token per reconnect, confirm/timeout/retry queue with superseding, generation-guarded joins, remote-apply guard, HTTP re-sync after join, offline mode; must match server exactly.
4. Two-store value model: structure/subblock split, null-means-cleared merge, every write via `collaborativeSetSubblockValue`, canonical basic/advanced pairs.
5. ~45 subblock editors driven by registry config: conditional visibility DSL, dependsOn, remote selectors, tool-input (2k, nested tool params), condition/router inputs creating handles dynamically.
6. Reference-token text fields: `<block.output>` / `{{ENV}}` highlight overlay on a transparent input with synced scroll; tag dropdown (1.7k) with scoped reference resolution, keyboard nav, tag drag-and-drop.
7. Code editors: Prism highlighting, AI fill, per-field undo, search highlights, password masking; needs grammars for js/ts/python/json/sql.
8. Block registry with React icons: ~371 configs + SVG icon components, options/conditions as TS closures → port or generate.
9. Execution streaming UX: SSE over POST, reconnect `?from=eventId`, live chunk/thinking/tool streams, nested iteration/child grouping in a virtualized console, JSON tree viewer.
10. Diff overlay, undo/redo inverses, copilot chat (5.4k-line `useChat` streaming protocol); notes need markdown rendering + rich editor.
