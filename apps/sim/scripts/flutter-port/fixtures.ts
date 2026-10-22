/**
 * Builds sample workflows and records what the upstream algorithms produce for
 * them, so the Dart ports of the serializer, loop generation, subblock merge
 * and diff engine are tested against upstream results rather than a reading
 * of the source.
 *
 * Every id is fixed and every non-deterministic value the upstream code mints
 * (edge UUIDs, timestamps) is normalised before the fixture is written.
 */

import { createLogger } from '@sim/logger'
import { getErrorMessage } from '@sim/utils/errors'
import { omit } from '@sim/utils/object'
import { mergeSubblockStateWithValues } from '@sim/workflow-persistence/subblocks'
import {
  generateLoopBlocks,
  generateParallelBlocks,
} from '@sim/workflow-persistence/subflow-helpers'
import type { BlockState, SubBlockState, WorkflowState } from '@sim/workflow-types/workflow'
import type { Edge } from '@xyflow/react'
import { WorkflowDiffEngine } from '@/lib/workflows/diff/engine'
import { getBlock } from '@/blocks/registry'
import type { Portable } from '@/scripts/flutter-port/portable'
import { toPortable } from '@/scripts/flutter-port/portable'
import {
  collectBlockFieldIssues,
  extractBlockParams,
  Serializer,
  WorkflowValidationError,
} from '@/serializer'

const logger = createLogger('FlutterPortFixtures')

export interface Fixture {
  name: string
  description: string
  state: Portable
  serialized: Portable
  serializedRequiredValidation: Portable
  deserialized: Portable
  loops: Portable
  parallels: Portable
  fieldIssues: Portable
  diff: Portable
}

export interface MergeCase {
  name: string
  description: string
  blocks: Portable
  values: Portable
  blockId?: string
  result: Portable
}

type Position = { x: number; y: number }

const PLAIN = { onFunction: () => null }

function portable(value: unknown): Portable {
  return toPortable(value, [], PLAIN) ?? null
}

/**
 * Builds a block the way the store does: subblock entries typed from the
 * registry (`short-input` when the registry has no entry, mirroring
 * `DEFAULT_SUBBLOCK_TYPE`) and outputs copied from the block config.
 */
function block(
  id: string,
  type: string,
  name: string,
  position: Position,
  values: Record<string, unknown>,
  extra: Partial<BlockState> = {}
): BlockState {
  const config = getBlock(type)
  const subBlocks: Record<string, SubBlockState> = {}
  for (const [subId, value] of Object.entries(values)) {
    const subType = config?.subBlocks.find((sub) => sub.id === subId)?.type ?? 'short-input'
    subBlocks[subId] = { id: subId, type: subType, value: value as SubBlockState['value'] }
  }
  return {
    id,
    type,
    name,
    position,
    subBlocks,
    outputs: (portable(config?.outputs ?? {}) ?? {}) as BlockState['outputs'],
    enabled: true,
    horizontalHandles: true,
    advancedMode: false,
    triggerMode: false,
    height: 0,
    layout: {},
    ...extra,
  }
}

function edge(
  source: string,
  target: string,
  sourceHandle = 'source',
  targetHandle = 'target'
): Edge {
  return {
    id: `edge-${source}-${sourceHandle}-${target}-${targetHandle}`,
    source,
    target,
    sourceHandle,
    targetHandle,
    type: 'workflowEdge',
  }
}

function workflow(blocks: BlockState[], edges: Edge[]): WorkflowState {
  const blockMap = Object.fromEntries(blocks.map((b) => [b.id, b]))
  return {
    blocks: blockMap,
    edges,
    loops: generateLoopBlocks(blockMap),
    parallels: generateParallelBlocks(blockMap),
  }
}

const UUID_A = '11111111-1111-4111-8111-111111111111'
const UUID_B = '22222222-2222-4222-8222-222222222222'

function linearFixture(): WorkflowState {
  const start = block('start', 'starter', 'Start', { x: 0, y: 0 }, { startWorkflow: 'manual' })
  const agent = block(
    'agent',
    'agent',
    'Agent 1',
    { x: 400, y: 0 },
    {
      model: 'claude-sonnet-5-5',
      messages: JSON.stringify([
        { id: 'm1', role: 'system', content: 'You are concise.' },
        { id: 'm2', role: 'user', content: '<start.input>' },
      ]),
      apiKey: '{{ANTHROPIC_API_KEY}}',
      temperature: 0.3,
    }
  )
  const fn = block(
    'function',
    'function',
    'Function 1',
    { x: 800, y: 0 },
    { language: 'javascript', code: 'return { text: <agent1.content> }' },
    { errorEnabled: true, retry: { enabled: true, maxTries: 3, waitBetweenTriesMs: 1000 } }
  )
  const api = block(
    'api',
    'api',
    'API 1',
    { x: 1200, y: 0 },
    {
      url: 'https://example.com/hook',
      method: 'POST',
      headers: [{ id: 'h1', cells: { Key: 'Content-Type', Value: 'application/json' } }],
      body: '<function1.text>',
    }
  )
  return workflow(
    [start, agent, fn, api],
    [edge('start', 'agent'), edge('agent', 'function'), edge('function', 'api')]
  )
}

function loopFixture(): WorkflowState {
  const start = block('start', 'starter', 'Start', { x: 0, y: 0 }, { startWorkflow: 'manual' })
  const loop = block(
    'loop',
    'loop',
    'Loop 1',
    { x: 400, y: 0 },
    {},
    { data: { loopType: 'for', count: 3, width: 500, height: 300, type: 'loop' } }
  )
  const fn = block(
    'function',
    'function',
    'Function 1',
    { x: 80, y: 80 },
    { language: 'javascript', code: 'return <loop.index>' },
    { data: { parentId: 'loop', extent: 'parent' } }
  )
  const agent = block(
    'agent',
    'agent',
    'Agent 1',
    { x: 380, y: 80 },
    {
      model: 'gpt-5.1',
      messages: JSON.stringify([{ id: 'm1', role: 'user', content: '<function1.result>' }]),
    },
    { data: { parentId: 'loop', extent: 'parent' } }
  )
  const after = block(
    'after',
    'function',
    'Function 2',
    { x: 1000, y: 0 },
    { language: 'python', code: 'return <loop.results>' }
  )
  return workflow(
    [start, loop, fn, agent, after],
    [
      edge('start', 'loop'),
      edge('loop', 'function', 'loop-start-source'),
      edge('function', 'agent'),
      edge('loop', 'after', 'loop-end-source'),
    ]
  )
}

function parallelFixture(): WorkflowState {
  const start = block('start', 'starter', 'Start', { x: 0, y: 0 }, { startWorkflow: 'manual' })
  const parallel = block(
    'parallel',
    'parallel',
    'Parallel 1',
    { x: 400, y: 0 },
    {},
    {
      data: {
        parallelType: 'collection',
        collection: '<start.input>',
        batchSize: 50,
        width: 500,
        height: 300,
        type: 'parallel',
      },
    }
  )
  const api = block(
    'api',
    'api',
    'API 1',
    { x: 80, y: 80 },
    { url: 'https://example.com/items/<parallel.currentItem>', method: 'GET' },
    { data: { parentId: 'parallel', extent: 'parent' } }
  )
  const after = block(
    'after',
    'function',
    'Function 1',
    { x: 1000, y: 0 },
    { language: 'javascript', code: 'return <parallel.results>' }
  )
  const disabled = block(
    'disabled',
    'function',
    'Function 2',
    { x: 1000, y: 300 },
    { language: 'javascript', code: '' },
    { enabled: false }
  )
  return workflow(
    [start, parallel, api, after, disabled],
    [
      edge('start', 'parallel'),
      edge('parallel', 'api', 'parallel-start-source'),
      edge('parallel', 'after', 'parallel-end-source'),
      edge('after', 'disabled'),
    ]
  )
}

function branchingFixture(): WorkflowState {
  const start = block('start', 'starter', 'Start', { x: 0, y: 0 }, { startWorkflow: 'manual' })
  const condition = block(
    'condition',
    'condition',
    'Condition 1',
    { x: 400, y: 0 },
    {
      conditions: JSON.stringify([
        { id: 'c-if', title: 'if', value: '<start.input> > 1' },
        { id: 'c-else-if', title: 'else if', value: '<start.input> === 1' },
        { id: 'c-else', title: 'else', value: '' },
      ]),
    }
  )
  const router = block(
    'router',
    'router',
    'Router 1',
    { x: 800, y: 200 },
    {
      prompt: 'Route the request: <start.input>',
      model: 'gpt-5.1',
      routes: JSON.stringify([
        { id: 'r-sales', title: 'sales', value: 'Questions about pricing' },
        { id: 'r-support', title: 'support', value: 'Bug reports' },
      ]),
    }
  )
  const agentA = block('agent-a', 'agent', 'Agent A', { x: 800, y: -200 }, { model: 'gpt-5.1' })
  const agentB = block('agent-b', 'agent', 'Agent B', { x: 1200, y: 100 }, { model: 'gpt-5.1' })
  const fn = block(
    'function',
    'function',
    'Function 1',
    { x: 1200, y: 300 },
    { language: 'javascript', code: 'return 1' }
  )
  return workflow(
    [start, condition, router, agentA, agentB, fn],
    [
      edge('start', 'condition'),
      edge('condition', 'agent-a', 'condition-c-if'),
      edge('condition', 'router', 'condition-c-else-if'),
      edge('router', 'agent-b', 'router-r-sales'),
      edge('router', 'function', 'router-r-support'),
      edge('agent-a', 'function', 'error'),
    ]
  )
}

function nestedFixture(): WorkflowState {
  const start = block('start', 'starter', 'Start', { x: 0, y: 0 }, { startWorkflow: 'chat' })
  const note = block(
    'note',
    'note',
    'Note 1',
    { x: 0, y: 300 },
    { content: '# Pipeline\n\nRuns **nightly**.', color: '#F59E0B' }
  )
  const loop = block(
    'loop',
    'loop',
    'Loop 1',
    { x: 400, y: 0 },
    {},
    {
      data: {
        loopType: 'forEach',
        collection: '<start.input>',
        width: 900,
        height: 500,
        type: 'loop',
      },
    }
  )
  const parallel = block(
    'parallel',
    'parallel',
    'Parallel 1',
    { x: 80, y: 80 },
    {},
    {
      data: {
        parentId: 'loop',
        extent: 'parent',
        parallelType: 'count',
        count: 2,
        width: 500,
        height: 300,
        type: 'parallel',
      },
    }
  )
  const fn = block(
    'function',
    'function',
    'Function 1',
    { x: 80, y: 80 },
    { language: 'javascript', code: 'return <loop.currentItem>' },
    { data: { parentId: 'parallel', extent: 'parent' }, advancedMode: true, locked: true }
  )
  const whileLoop = block(
    'while',
    'loop',
    'Loop 2',
    { x: 1400, y: 0 },
    {},
    {
      data: {
        loopType: 'while',
        whileCondition: '<function1.result> < 10',
        width: 500,
        height: 300,
        type: 'loop',
      },
    }
  )
  return workflow(
    [start, note, loop, parallel, fn, whileLoop],
    [
      edge('start', 'loop'),
      edge('loop', 'parallel', 'loop-start-source'),
      edge('parallel', 'function', 'parallel-start-source'),
      edge('loop', 'while', 'loop-end-source'),
    ]
  )
}

function clone<T>(value: T): T {
  return structuredClone(value)
}

/** Proposed states exercise rename, value edit, added block + edge, removed edge and re-parenting. */
function proposeChanges(name: string, baseline: WorkflowState): WorkflowState {
  const proposed = clone(baseline)
  switch (name) {
    case 'linear': {
      proposed.blocks.agent.subBlocks.model.value = 'gpt-5.1'
      proposed.blocks[UUID_A] = block(
        'ignored',
        'function',
        'Function 2',
        { x: 0, y: 300 },
        {
          language: 'javascript',
          code: 'return 2',
        }
      )
      proposed.blocks[UUID_A].id = UUID_A
      proposed.edges = proposed.edges.filter((e) => e.target !== 'api')
      proposed.edges.push(edge('function', UUID_A))
      break
    }
    case 'loop': {
      proposed.blocks.after.name = 'Summary'
      proposed.blocks.after.data = { parentId: 'loop', extent: 'parent' }
      proposed.edges = proposed.edges.filter((e) => e.target !== 'after')
      proposed.edges.push(edge('agent', 'after'))
      break
    }
    case 'parallel': {
      proposed.blocks = omit(proposed.blocks, ['disabled'])
      proposed.edges = proposed.edges.filter((e) => e.target !== 'disabled')
      proposed.blocks.parallel.data = { ...proposed.blocks.parallel.data, batchSize: 5 }
      break
    }
    case 'branching': {
      proposed.blocks.condition.subBlocks.conditions.value = JSON.stringify([
        { id: 'c-if', title: 'if', value: '<start.input> > 10' },
        { id: 'c-else', title: 'else', value: '' },
      ])
      proposed.edges = proposed.edges.filter((e) => e.sourceHandle !== 'condition-c-else-if')
      break
    }
    default: {
      proposed.blocks[UUID_B] = block(
        'ignored',
        'note',
        'Note 2',
        { x: 0, y: 600 },
        {
          content: 'Added by the diff fixture',
        }
      )
      proposed.blocks[UUID_B].id = UUID_B
      proposed.blocks.function.enabled = false
      break
    }
  }
  proposed.loops = generateLoopBlocks(proposed.blocks)
  proposed.parallels = generateParallelBlocks(proposed.blocks)
  return proposed
}

/** Edge ids minted with `generateId()` and timestamps are replaced so the fixture is stable. */
function normaliseDiff(result: Portable): Portable {
  if (typeof result !== 'object' || result === null || Array.isArray(result)) return result
  const diff = result.diff
  if (typeof diff !== 'object' || diff === null || Array.isArray(diff)) return result
  const idMap = new Map<string, string>()
  const state = diff.proposedState
  if (typeof state === 'object' && state !== null && !Array.isArray(state)) {
    if (Array.isArray(state.edges)) {
      for (const item of state.edges) {
        if (typeof item !== 'object' || item === null || Array.isArray(item)) continue
        const stable = `edge-${item.source}-${item.sourceHandle}-${item.target}-${item.targetHandle}`
        if (typeof item.id === 'string') idMap.set(item.id, stable)
        item.id = stable
      }
    }
    state.lastSaved = 0
  }
  const analysis = diff.diffAnalysis
  if (typeof analysis === 'object' && analysis !== null && !Array.isArray(analysis)) {
    const edgeDiff = analysis.edge_diff
    if (typeof edgeDiff === 'object' && edgeDiff !== null && !Array.isArray(edgeDiff)) {
      for (const key of Object.keys(edgeDiff)) {
        const list = edgeDiff[key]
        if (Array.isArray(list)) {
          edgeDiff[key] = list
            .map((id) => (typeof id === 'string' ? (idMap.get(id) ?? id) : id))
            .sort()
        }
      }
    }
  }
  const metadata = diff.metadata
  if (typeof metadata === 'object' && metadata !== null && !Array.isArray(metadata)) {
    metadata.timestamp = 0
  }
  return result
}

function serializeWithValidation(state: WorkflowState): Portable {
  try {
    const serialized = new Serializer().serializeWorkflow(
      state.blocks,
      state.edges,
      state.loops,
      state.parallels,
      true
    )
    return { ok: true, serialized: portable(serialized) }
  } catch (error) {
    if (error instanceof WorkflowValidationError) {
      return {
        ok: false,
        error: error.message,
        blockId: error.blockId ?? null,
        blockType: error.blockType ?? null,
        blockName: error.blockName ?? null,
      }
    }
    return { ok: false, error: getErrorMessage(error) }
  }
}

function fieldIssues(state: WorkflowState): Portable {
  const issues: Record<string, Portable> = {}
  for (const id of Object.keys(state.blocks).sort()) {
    const current = state.blocks[id]
    if (current.type === 'loop' || current.type === 'parallel') continue
    const config = getBlock(current.type)
    if (!config) continue
    try {
      const params = extractBlockParams(current)
      issues[id] = {
        params: portable(params),
        issues: portable(collectBlockFieldIssues(current, config, params)),
      }
    } catch (error) {
      issues[id] = { error: getErrorMessage(error) }
    }
  }
  return issues
}

async function buildFixture(
  name: string,
  description: string,
  state: WorkflowState
): Promise<Fixture> {
  const serializer = new Serializer()
  const serialized = serializer.serializeWorkflow(
    state.blocks,
    state.edges,
    state.loops,
    state.parallels
  )
  const deserialized = serializer.deserializeWorkflow(serialized)
  const proposed = proposeChanges(name, state)
  let diff: Portable
  try {
    const result = await new WorkflowDiffEngine().createDiffFromWorkflowState(
      proposed,
      undefined,
      state
    )
    diff = normaliseDiff(portable({ proposed, result }))
  } catch (error) {
    logger.warn('Diff engine failed for fixture', { name, error: getErrorMessage(error) })
    diff = { proposed: portable(proposed), error: getErrorMessage(error) }
  }
  return {
    name,
    description,
    state: portable(state),
    serialized: portable(serialized),
    serializedRequiredValidation: serializeWithValidation(state),
    deserialized: portable(deserialized),
    loops: portable(generateLoopBlocks(state.blocks)),
    parallels: portable(generateParallelBlocks(state.blocks)),
    fieldIssues: fieldIssues(state),
    diff,
  }
}

export async function buildFixtures(): Promise<Fixture[]> {
  return [
    await buildFixture(
      'linear',
      'starter → agent → function (error port, retry) → api',
      linearFixture()
    ),
    await buildFixture(
      'loop',
      'for-loop container with two children and an exit edge',
      loopFixture()
    ),
    await buildFixture(
      'parallel',
      'collection parallel with a child, exit edge and a disabled block',
      parallelFixture()
    ),
    await buildFixture(
      'branching',
      'condition rows and router rows with dynamic handles, error edge',
      branchingFixture()
    ),
    await buildFixture(
      'nested',
      'note, forEach loop containing a parallel containing a locked function, while loop',
      nestedFixture()
    ),
  ]
}

export function buildMergeCases(): MergeCase[] {
  const base = linearFixture().blocks
  const run = (
    name: string,
    description: string,
    values: Record<string, Record<string, unknown>>,
    blockId?: string
  ): MergeCase => ({
    name,
    description,
    blocks: portable(base),
    values: portable(values),
    ...(blockId ? { blockId } : {}),
    result: portable(mergeSubblockStateWithValues(base, values, blockId)),
  })
  return [
    run('override', 'a value present in the map replaces the structure value', {
      agent: { model: 'gpt-5.1' },
    }),
    run('null-clears', 'null in the map clears an existing subblock value', {
      agent: { model: null },
    }),
    run(
      'null-missing-ignored',
      'null never creates an entry for a subblock absent from the structure',
      {
        agent: { webhookId: null },
      }
    ),
    run('undefined-ignored', 'undefined is "no value recorded" and never overrides', {
      agent: { model: undefined },
    }),
    run(
      'structureless-added',
      'a non-null value for a missing subblock is added with the default shape',
      {
        api: { triggerPath: '/hooks/abc' },
      }
    ),
    run(
      'block-filter',
      'only the requested block is merged when blockId is given',
      {
        agent: { model: 'gpt-5.1' },
        function: { code: 'return 0' },
      },
      'function'
    ),
    run('unknown-block-ignored', 'values for a block id not in the structure are dropped', {
      ghost: { model: 'gpt-5.1' },
    }),
  ]
}
