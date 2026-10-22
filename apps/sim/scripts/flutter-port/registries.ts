/**
 * Exports the block, tool and trigger registries as portable JSON and builds
 * the closure inventory (every function-valued field that still needs a Dart
 * port) on the way.
 */

import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { compareStrings } from '@sim/utils/string'
import { BLOCK_META_REGISTRY, BLOCK_REGISTRY } from '@/blocks/registry-maps'
import type { BlockConfig } from '@/blocks/types'
import {
  type AnyFunction,
  isFunction,
  joinPath,
  type Portable,
  toPortable,
} from '@/scripts/flutter-port/portable'
import {
  hasToolSelector,
  type SelectorTable,
  sampleToolSelector,
} from '@/scripts/flutter-port/selectors'
import { tools as TOOL_REGISTRY } from '@/tools/registry'
import { TRIGGER_REGISTRY } from '@/triggers/registry'

export type ClosureClass =
  | 'tool-selector'
  | 'tool-params'
  | 'options'
  | 'condition'
  | 'required'
  | 'hidden'
  | 'value'
  | 'icon'
  | 'other'

export type ClosurePortStatus = 'decision-table' | 'constant' | 'hand-port' | 'not-ported'

export interface ClosureRecord {
  /** Owning registry entry: a block type, tool id or trigger id. */
  owner: string
  registry: 'blocks' | 'tools' | 'triggers'
  path: string
  class: ClosureClass
  portStatus: ClosurePortStatus
  /** Param keys the function read when probed with an empty params Proxy. */
  accessedKeys: string[]
  /** Result of calling the function with empty params, when that produced JSON. */
  sampledValue?: Portable
  source: string
}

export interface RegistryExport {
  blocks: Record<string, Portable>
  tools: Record<string, Portable>
  triggers: Record<string, Portable>
  selectorTables: SelectorTable[]
  closures: ClosureRecord[]
  /** Function-valued tool fields (execution side), counted by field name. */
  toolFunctionFields: Record<string, number>
}

const PROBED_CLASSES: ReadonlySet<ClosureClass> = new Set([
  'value',
  'condition',
  'required',
  'options',
])

/** Classes whose zero-input result replaces the function when it reads no params. */
const CONSTANT_CLASSES: ReadonlySet<ClosureClass> = new Set(['value', 'condition', 'required'])

interface FunctionProbe {
  accessedKeys: string[]
  value?: Portable
}

/**
 * Calls a config function with a recording Proxy as its params. A `value`,
 * `condition` or `required` function that reads nothing and returns plain data
 * is a constant in disguise (`() => 'send_message'`), which the port can inline.
 */
function probeFunction(fn: AnyFunction): FunctionProbe {
  const accessed = new Set<string>()
  const proxy = new Proxy<Record<string, unknown>>(
    {},
    {
      get(_target, prop) {
        if (typeof prop === 'string') accessed.add(prop)
        return undefined
      },
      has(_target, prop) {
        if (typeof prop === 'string') accessed.add(prop)
        return false
      },
    }
  )
  try {
    const result = (fn as (params: unknown) => unknown)(proxy)
    if (isFunction(result) || result === undefined) return { accessedKeys: [...accessed] }
    const value = toPortable(result, [], { onFunction: () => ({ $fn: 'nested' }) })
    return { accessedKeys: [...accessed].sort(compareStrings), value }
  } catch {
    return { accessedKeys: [...accessed].sort(compareStrings) }
  }
}

function containsMarker(value: Portable | undefined, marker: string): boolean {
  if (value === undefined || value === null || typeof value !== 'object') return false
  if (Array.isArray(value)) return value.some((item) => containsMarker(item, marker))
  if (marker in value) return true
  return Object.values(value).some((item) => containsMarker(item, marker))
}

function classify(path: string[]): ClosureClass {
  const joined = path.join('.')
  if (joined === 'tools.config.tool') return 'tool-selector'
  if (joined === 'tools.config.params') return 'tool-params'
  const last = path[path.length - 1]
  if (path[0] === 'subBlocks' && path.length === 3) {
    if (last === 'options') return 'options'
    if (last === 'condition') return 'condition'
    if (last === 'required') return 'required'
    if (last === 'hidden') return 'hidden'
    if (last === 'value') return 'value'
  }
  if (last === 'icon') return 'icon'
  return 'other'
}

function portStatus(cls: ClosureClass, pureSelector: boolean): ClosurePortStatus {
  if (cls === 'tool-selector') return pureSelector ? 'decision-table' : 'hand-port'
  if (cls === 'tool-params') return 'not-ported'
  return 'hand-port'
}

function sortedKeys<T>(record: Record<string, T>): string[] {
  return Object.keys(record).sort(compareStrings)
}

/**
 * Builds the `onFunction` replacement for one registry entry. Icon components
 * become `$icon` markers; everything else becomes a `$fn` marker and a closure
 * record.
 */
function makeContext(
  registry: ClosureRecord['registry'],
  owner: string,
  iconRefs: Map<AnyFunction, string>,
  closures: ClosureRecord[],
  pureSelector: boolean
) {
  return {
    onFunction: (path: string[], fn: AnyFunction): Portable => {
      const iconRef = iconRefs.get(fn)
      if (iconRef !== undefined) return { $icon: iconRef }
      const cls = classify(path)
      const marker = joinPath(owner, path)
      const probe = PROBED_CLASSES.has(cls) ? probeFunction(fn) : { accessedKeys: [] }
      const constant =
        CONSTANT_CLASSES.has(cls) &&
        probe.accessedKeys.length === 0 &&
        probe.value !== undefined &&
        !containsMarker(probe.value, '$fn')
      closures.push({
        owner,
        registry,
        path: path.join('.'),
        class: cls,
        portStatus: constant ? 'constant' : portStatus(cls, pureSelector),
        accessedKeys: probe.accessedKeys,
        ...(probe.value !== undefined ? { sampledValue: probe.value } : {}),
        source: fn.toString(),
      })
      return constant ? { $const: probe.value ?? null } : { $fn: marker }
    },
  }
}

export function exportRegistries(iconRefs: Map<AnyFunction, string>): RegistryExport {
  const closures: ClosureRecord[] = []
  const selectorTables: SelectorTable[] = []

  const blocks: Record<string, Portable> = {}
  for (const type of sortedKeys(BLOCK_REGISTRY)) {
    const block: BlockConfig = BLOCK_REGISTRY[type]
    const table = hasToolSelector(block) ? sampleToolSelector(block) : undefined
    if (table) selectorTables.push(table)
    const ctx = makeContext('blocks', type, iconRefs, closures, table?.pure ?? false)
    const portable = toPortable(block, [], ctx) ?? {}
    const meta = BLOCK_META_REGISTRY[type]
    if (meta !== undefined && typeof portable === 'object' && !Array.isArray(portable)) {
      const metaPortable = toPortable(meta, ['$meta'], ctx)
      if (metaPortable !== undefined) portable.$meta = metaPortable
    }
    blocks[type] = portable
  }

  // Tool functions (request builders, transformResponse, internal operation
  // handlers) are execution-side and never ported; they are counted by path
  // instead of inventoried, and `request` is dropped wholesale.
  const tools: Record<string, Portable> = {}
  const toolFunctionFields: Record<string, number> = {}
  for (const id of sortedKeys(TOOL_REGISTRY)) {
    const tool = TOOL_REGISTRY[id] as unknown as Record<string, unknown>
    const functionFields = new Set<string>()
    const ctx = {
      onFunction: (path: string[], fn: AnyFunction): Portable => {
        const iconRef = iconRefs.get(fn)
        if (iconRef !== undefined) return { $icon: iconRef }
        const field = path.join('.')
        functionFields.add(field)
        toolFunctionFields[field] = (toolFunctionFields[field] ?? 0) + 1
        return { $fn: joinPath(id, path) }
      },
    }
    const { request, ...staticFields } = tool
    if (request !== undefined) {
      functionFields.add('request')
      toolFunctionFields.request = (toolFunctionFields.request ?? 0) + 1
    }
    const portable = toPortable(staticFields, [], ctx)
    if (portable && typeof portable === 'object' && !Array.isArray(portable)) {
      portable.$functionFields = [...functionFields].sort(compareStrings)
    }
    tools[id] = portable ?? {}
  }

  const triggers: Record<string, Portable> = {}
  for (const id of sortedKeys(TRIGGER_REGISTRY)) {
    const ctx = makeContext('triggers', id, iconRefs, closures, false)
    triggers[id] = toPortable(TRIGGER_REGISTRY[id], [], ctx) ?? {}
  }

  closures.sort(
    (a, b) =>
      compareStrings(a.registry, b.registry) ||
      compareStrings(a.owner, b.owner) ||
      compareStrings(a.path, b.path)
  )
  selectorTables.sort((a, b) => compareStrings(a.block, b.block))

  return {
    blocks,
    tools,
    triggers,
    selectorTables,
    closures,
    toolFunctionFields: Object.fromEntries(
      Object.entries(toolFunctionFields).sort((a, b) => compareStrings(a[0], b[0]))
    ),
  }
}

const SUBBLOCK_TYPE_FILE = 'packages/workflow-types/src/blocks.ts'

/** Reads the `SubBlockType` union members from source so the list never drifts from the type. */
export function readSubBlockTypes(repoRoot: string): string[] {
  const source = readFileSync(join(repoRoot, SUBBLOCK_TYPE_FILE), 'utf8')
  const start = source.indexOf('export type SubBlockType =')
  if (start < 0) throw new Error(`SubBlockType union not found in ${SUBBLOCK_TYPE_FILE}`)
  const members: string[] = []
  for (const line of source.slice(start).split('\n').slice(1)) {
    const match = /^\s*\|\s*'([^']+)'\s*$/.exec(line)
    if (!match) break
    members.push(match[1])
  }
  if (members.length === 0) throw new Error('SubBlockType union is empty')
  return members
}

export interface SubBlockTypeUsage {
  type: string
  blocks: number
  subBlocks: number
}

export function subBlockTypeUsage(types: string[]): SubBlockTypeUsage[] {
  const usage = new Map<string, { blocks: Set<string>; subBlocks: number }>()
  for (const type of types) usage.set(type, { blocks: new Set(), subBlocks: 0 })
  const count = (owner: string, subType: string) => {
    const entry = usage.get(subType) ?? { blocks: new Set<string>(), subBlocks: 0 }
    entry.blocks.add(owner)
    entry.subBlocks += 1
    usage.set(subType, entry)
  }
  for (const block of Object.values(BLOCK_REGISTRY)) {
    for (const sub of block.subBlocks ?? []) count(block.type, sub.type)
  }
  for (const trigger of Object.values(TRIGGER_REGISTRY)) {
    for (const sub of trigger.subBlocks ?? []) count(`trigger:${trigger.id}`, sub.type)
  }
  return [...usage.entries()]
    .sort((a, b) => compareStrings(a[0], b[0]))
    .map(([type, entry]) => ({ type, blocks: entry.blocks.size, subBlocks: entry.subBlocks }))
}
