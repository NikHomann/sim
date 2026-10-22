/**
 * Converts registry objects into JSON-serialisable data for the Flutter port.
 *
 * Functions cannot cross the language boundary, so every function-valued field
 * is replaced by a marker the consumer can look up (`{"$fn": "<owner>.<path>"}`
 * or `{"$icon": "<set>/<name>"}`) and reported to the caller through
 * `onFunction`, which builds the closure inventory.
 */

export type Portable = null | boolean | number | string | Portable[] | { [key: string]: Portable }

export type AnyFunction = (...args: never[]) => unknown

export interface PortableContext {
  /** Replacement value for a function found at `path`; `path` is relative to the owner. */
  onFunction: (path: string[], fn: AnyFunction) => Portable
}

export function isFunction(value: unknown): value is AnyFunction {
  return typeof value === 'function'
}

/** Builds the dotted path used in `$fn` markers and the closure inventory. */
export function joinPath(owner: string, path: string[]): string {
  return [owner, ...path].join('.')
}

function hasStringId(value: unknown): value is { id: string } {
  return (
    typeof value === 'object' &&
    value !== null &&
    typeof (value as { id?: unknown }).id === 'string' &&
    (value as { id: string }).id.length > 0
  )
}

/**
 * Array elements with a string `id` are addressed by that id (`subBlocks.model`)
 * so markers stay stable when a list is reordered; duplicates fall back to the
 * id suffixed with the index.
 */
function arraySegment(items: unknown[], index: number): string {
  const item = items[index]
  if (!hasStringId(item)) return String(index)
  const duplicate = items.some(
    (other, i) => i !== index && hasStringId(other) && other.id === item.id
  )
  return duplicate ? `${item.id}#${index}` : item.id
}

export function toPortable(
  value: unknown,
  path: string[],
  ctx: PortableContext,
  stack: object[] = []
): Portable | undefined {
  if (value === undefined || typeof value === 'symbol') return undefined
  if (value === null) return null
  if (typeof value === 'string' || typeof value === 'boolean') return value
  if (typeof value === 'number') return Number.isFinite(value) ? value : null
  if (typeof value === 'bigint') return value.toString()
  if (isFunction(value)) return ctx.onFunction(path, value)
  if (value instanceof RegExp) return { $regex: value.source, flags: value.flags }
  if (value instanceof Date) return value.toISOString()
  if (typeof value !== 'object') return null
  if (stack.includes(value)) return { $cycle: path.join('.') }

  const next = [...stack, value]
  if (Array.isArray(value)) {
    return value.map((item, index) => {
      const portable = toPortable(item, [...path, arraySegment(value, index)], ctx, next)
      return portable === undefined ? null : portable
    })
  }
  if (value instanceof Set) {
    return toPortable([...value], path, ctx, next)
  }
  if (value instanceof Map) {
    return toPortable(Object.fromEntries(value), path, ctx, next)
  }

  const out: { [key: string]: Portable } = {}
  for (const key of Object.keys(value)) {
    const portable = toPortable((value as Record<string, unknown>)[key], [...path, key], ctx, next)
    if (portable !== undefined) out[key] = portable
  }
  return out
}
