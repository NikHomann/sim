# sim_workflow

Pure-Dart workflow domain for the Sim Flutter port (plan: `docs/port/00-plan.md`
§4.4). No Flutter imports. Every exported symbol names the upstream TypeScript
file it ports in its doc comment; the baseline commit is in
`docs/port/UPSTREAM_COMMIT`.

Entry points:

- `package:sim_workflow/sim_workflow.dart` — model, rules, text, serializer.
- `package:sim_workflow/sim_workflow_realtime.dart` — realtime protocol
  vocabulary and operation queue (owned separately; see `lib/src/realtime/`).

## Layout

| Directory | Upstream source | Contents |
|---|---|---|
| `lib/src/model/` | `packages/workflow-types/src/workflow.ts`, `blocks.ts`; `apps/sim/blocks/types.ts`; `apps/sim/blocks/registry.ts` | `WorkflowState`, `BlockState`, `SubBlockState`, `Edge` (the `@xyflow` fields upstream uses), `Loop`, `Parallel`, `Variable`, `BlockData`, `BlockRetryConfig`, `SubBlockType` (48 ids), `BlockConfig` / `SubBlockConfig` / `ToolsConfig` / `OutputFieldDefinition`, `BlockRegistry`, `ToolMetadataLookup` |
| `lib/src/rules/` | `packages/workflow-persistence/src/subblocks.ts`, `subflow-helpers.ts`; `packages/workflow-types/src/workflow.ts`; `packages/workflow-renderer/src/dimensions.ts`; `apps/sim/lib/workflows/dynamic-handle-topology.ts`; `apps/sim/lib/workflows/subblocks/visibility.ts`, `dependencies.ts` | `mergeSubblockState`, `generateLoopBlocks` / `generateParallelBlocks`, `wouldCreateCycle`, `filterAcyclicEdges`, `filterUniqueWorkflowEdges`, `getWorkflowEdgeScopeDropReason`, handle ids and healing, `HandlePositions` / `BlockDimensions` / `ContainerDimensions`, canonical pair resolution, condition DSL evaluator, `dependsOn` helpers, name conflicts, lock checks |
| `lib/src/text/` | `packages/workflow-renderer/src/formatted-text.tsx`; `packages/utils/src/workflow-references.ts` | `tokenizeDisplayText` (spans: plain / blockReference / envReference / invalid, UTF-16 offsets, search-highlight range), `findWorkflowReferenceTokens` |
| `lib/src/serializer/` | `apps/sim/serializer/index.ts`, `types.ts`, `errors.ts`; `apps/sim/tools/param-shape.ts` (`expandSubBlockValueToParams`) | `WorkflowSerializer.serializeWorkflow` / `deserializeWorkflow` / `extractBlockParams` / `collectBlockFieldIssues` / `selectToolId`, `SerializedWorkflow` types |

## Design notes

- Value semantics: every model type is immutable with `copyWith` (sentinel
  semantics, so an optional field can be cleared), `==` / `hashCode`, and
  JSON (de)serialisation that keeps unknown keys in `extra` and round-trips the
  upstream wire shape (`test/model/fixtures/workflow_state.json`).
- `SubBlockState.type` and `SubBlockConfig.type` are raw strings with a typed
  `SubBlockType?` view: upstream spreads a `trigger-config` sub-block that is
  not one of the 48 ids.
- `BlockState.outputs` stays raw JSON (persisted rows carry legacy shapes);
  `OutputFieldDefinition.tryParse` gives the typed view.
- Function-valued `BlockConfig` fields are strategy objects: `ToolSelector`
  (`DecisionTableToolSelector` for the extraction's decision tables,
  `CallbackToolSelector` for hand ports), `DynamicOptions`, `DynamicCondition`,
  `ValueProvider`. `tools.config.params` is execution-side and only its name is
  kept.
- Deployment facts the visibility rules read (`hosted`, `NEXT_PUBLIC_*`) are
  injected through `SubBlockEnvironment`.
- Known, documented divergences from JavaScript: a condition declared with
  `value: null` matches a missing field (Dart has no `undefined`); unknown
  `loopType` / `parallelType` / `canonicalModes` wire values are dropped on
  read instead of being passed through.

## Checks

```
dart format --set-exit-if-changed lib/src/model lib/src/rules lib/src/text lib/src/serializer test/model test/rules test/text test/serializer
dart analyze --fatal-infos lib/src/model lib/src/rules lib/src/text lib/src/serializer lib/sim_workflow.dart test/model test/rules test/text test/serializer
dart test test/model test/rules test/text test/serializer
```

Each test file opens with its failure-mode list; every entry is one test.

## TODO (not ported yet)

1. `apps/sim/lib/workflows/migrations/greenhouse-agent-inputs.ts`
   (`migrateGreenhouseAgentInputs`) and
   `apps/sim/lib/workflows/migrations/mcp-operation-controls.ts`
   (`migrateMcpOperationControls`, which needs `normalizeMcpBlockValues` /
   `normalizeMcpToolAttachments` from `apps/sim/lib/mcp/workflow-config.ts`).
   The serializer runs them before `serializeBlock` and `extractBlockParams`
   upstream; inject ports through `WorkflowSerializer(migrations: [...])`.
2. `tools.config.tool` closures that are not pure switches (the extraction's
   `closures.json`): hand-port as `CallbackToolSelector`s with sampled-output
   tests. `tools.config.params` is not needed client-side.
3. `options` / `condition` / `required` functions (9 + 6 + 6 files) as
   `DynamicOptions` / `DynamicCondition` with sampled-output tests; the
   deployment-shape read in `function.ts` through `SubBlockEnvironment`.
4. `source-cursor-*` temporary handle mapping
   (`workflow-block/source-handle.ts` in the editor) — file not found at the
   baseline path, locate before Phase 2 canvas work.
5. Fixture conformance against the extraction's dumped upstream serializer /
   loop outputs once `generated/fixtures/*.json` exists; the current fixtures
   are hand-copied from the type definitions.
6. `reindexToolCanonicalModes` (object-identity variant) is intentionally
   omitted; use `reindexCanonicalModesByPosition` with an explicit index map.
