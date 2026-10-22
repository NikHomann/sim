/**
 * Samples every block's `tools.config.tool` selector into a decision table.
 *
 * The selector runs at serialisation time on the block's param map. For most
 * blocks it is a switch on one dropdown (`operation`), so calling it with every
 * option combination reproduces it exactly. The params object is a Proxy that
 * records which keys the selector reads: a table is `pure` only when every read
 * key is a sampled dropdown or switch, every sample returned a string, and the
 * selector never enumerated the params.
 */

import { compareStrings } from '@sim/utils/string'
import type { BlockConfig, SubBlockConfig } from '@/blocks/types'
import type { AnyFunction } from '@/scripts/flutter-port/portable'

type ToolSelector = (params: Record<string, unknown>) => unknown

export interface SelectorRow {
  params: Record<string, string | boolean>
  toolId: string
}

export interface SelectorTable {
  block: string
  pure: boolean
  /** Sampled subblock ids, in the order their values appear in each row. */
  dimensions: string[]
  /** Option ids sampled for each dimension. */
  dimensionValues: Record<string, Array<string | boolean>>
  rows: SelectorRow[]
  /** Result when every dimension is unset, or null when that throws or returns a non-string. */
  fallback: string | null
  /** Every params key the selector read across all samples. */
  accessedKeys: string[]
  /** Read keys that are free-form fields (no finite option set). */
  freeInputs: string[]
  /** Read keys whose dropdown options come from a function at runtime. */
  dynamicOptions: string[]
  /** Read keys with no matching subblock on the block. */
  unknownKeys: string[]
  /** Selector results not listed in `tools.access`. */
  unknownToolIds: string[]
  enumeratedParams: boolean
  truncated: boolean
  errors: string[]
  source: string
}

const MAX_COMBINATIONS = 4096
const MAX_DISCOVERY_ROUNDS = 6

interface Dimension {
  values: Array<string | boolean>
}

interface Probe {
  result: unknown
  error?: string
  accessed: Set<string>
  enumerated: boolean
}

function probe(selector: ToolSelector, values: Record<string, unknown>): Probe {
  const accessed = new Set<string>()
  let enumerated = false
  const target: Record<string, unknown> = { ...values }
  const proxy = new Proxy(target, {
    get(obj, prop) {
      if (typeof prop !== 'string') return undefined
      accessed.add(prop)
      return obj[prop]
    },
    has(obj, prop) {
      if (typeof prop !== 'string') return false
      accessed.add(prop)
      return prop in obj
    },
    ownKeys(obj) {
      enumerated = true
      return Reflect.ownKeys(obj)
    },
    getOwnPropertyDescriptor(obj, prop) {
      enumerated = true
      return Reflect.getOwnPropertyDescriptor(obj, prop)
    },
  })
  try {
    return { result: selector(proxy), accessed, enumerated }
  } catch (error) {
    return {
      result: undefined,
      error: error instanceof Error ? error.message : String(error),
      accessed,
      enumerated,
    }
  }
}

type Classification =
  | { kind: 'dimension'; values: Array<string | boolean> }
  | { kind: 'free' }
  | { kind: 'dynamic' }
  | { kind: 'unknown' }

function classifyKey(key: string, subBlocks: SubBlockConfig[]): Classification {
  const matches = subBlocks.filter((sub) => sub.id === key || sub.canonicalParamId === key)
  if (matches.length === 0) return { kind: 'unknown' }
  for (const sub of matches) {
    if ((sub.type === 'dropdown' || sub.type === 'combobox') && Array.isArray(sub.options)) {
      const ids = sub.options.map((option) => option.id)
      return { kind: 'dimension', values: [...new Set(ids)] }
    }
  }
  for (const sub of matches) {
    if (sub.type === 'switch') {
      return { kind: 'dimension', values: [true, false] }
    }
  }
  if (matches.some((sub) => typeof sub.options === 'function')) return { kind: 'dynamic' }
  return { kind: 'free' }
}

function cartesian(
  dimensions: Array<[string, Dimension]>
): Array<Record<string, string | boolean>> {
  let combos: Array<Record<string, string | boolean>> = [{}]
  for (const [key, dimension] of dimensions) {
    const next: Array<Record<string, string | boolean>> = []
    for (const combo of combos) {
      for (const value of dimension.values) {
        next.push({ ...combo, [key]: value })
      }
    }
    combos = next
  }
  return combos
}

export function hasToolSelector(block: BlockConfig): boolean {
  return typeof block.tools?.config?.tool === 'function'
}

export function sampleToolSelector(block: BlockConfig): SelectorTable | undefined {
  const selector = block.tools?.config?.tool as ToolSelector | undefined
  if (typeof selector !== 'function') return undefined

  const subBlocks = block.subBlocks ?? []
  const dimensions = new Map<string, Dimension>()
  const freeInputs = new Set<string>()
  const dynamicOptions = new Set<string>()
  const unknownKeys = new Set<string>()
  const accessedKeys = new Set<string>()
  const errors: string[] = []
  let enumerated = false
  let truncated = false
  let rows: SelectorRow[] = []

  const classify = (key: string): boolean => {
    if (
      dimensions.has(key) ||
      freeInputs.has(key) ||
      dynamicOptions.has(key) ||
      unknownKeys.has(key)
    ) {
      return false
    }
    const classification = classifyKey(key, subBlocks)
    switch (classification.kind) {
      case 'dimension':
        dimensions.set(key, { values: classification.values })
        return true
      case 'free':
        freeInputs.add(key)
        return false
      case 'dynamic':
        dynamicOptions.add(key)
        return false
      default:
        unknownKeys.add(key)
        return false
    }
  }

  const initial = probe(selector, {})
  for (const key of initial.accessed) {
    accessedKeys.add(key)
    classify(key)
  }
  if (initial.enumerated) enumerated = true
  const fallback = typeof initial.result === 'string' ? initial.result : null

  for (let round = 0; round < MAX_DISCOVERY_ROUNDS; round += 1) {
    const ordered = [...dimensions.entries()].sort((a, b) => compareStrings(a[0], b[0]))
    const total = ordered.reduce((count, [, dim]) => count * dim.values.length, 1)
    if (total > MAX_COMBINATIONS) {
      truncated = true
      errors.push(`combination space ${total} exceeds ${MAX_COMBINATIONS}`)
      rows = []
      break
    }
    rows = []
    errors.length = 0
    let discovered = false
    for (const combo of cartesian(ordered)) {
      const sample = probe(selector, combo)
      if (sample.enumerated) enumerated = true
      for (const key of sample.accessed) {
        accessedKeys.add(key)
        if (classify(key)) discovered = true
      }
      if (sample.error !== undefined) {
        errors.push(`${JSON.stringify(combo)}: ${sample.error}`)
        continue
      }
      if (typeof sample.result !== 'string') {
        errors.push(`${JSON.stringify(combo)}: returned ${typeof sample.result}`)
        continue
      }
      rows.push({ params: combo, toolId: sample.result })
    }
    if (!discovered) break
  }

  const access = new Set(block.tools?.access ?? [])
  const unknownToolIds = [...new Set(rows.map((row) => row.toolId).filter((id) => !access.has(id)))]
  const dimensionKeys = [...dimensions.keys()].sort(compareStrings)
  const pure =
    !truncated &&
    !enumerated &&
    errors.length === 0 &&
    freeInputs.size === 0 &&
    dynamicOptions.size === 0 &&
    unknownKeys.size === 0

  return {
    block: block.type,
    pure,
    dimensions: dimensionKeys,
    dimensionValues: Object.fromEntries(
      dimensionKeys.map((key) => [key, dimensions.get(key)?.values ?? []])
    ),
    rows,
    fallback,
    accessedKeys: [...accessedKeys].sort(compareStrings),
    freeInputs: [...freeInputs].sort(compareStrings),
    dynamicOptions: [...dynamicOptions].sort(compareStrings),
    unknownKeys: [...unknownKeys].sort(compareStrings),
    unknownToolIds: unknownToolIds.sort(compareStrings),
    enumeratedParams: enumerated,
    truncated,
    errors,
    source: (selector as AnyFunction).toString(),
  }
}
