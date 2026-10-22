/**
 * Emits a JSON Schema for every route contract under `lib/api/contracts/**`.
 *
 * Contracts are discovered by importing each module and keeping every export
 * (one level of plain-object nesting included) that carries `method` and
 * `path`. zod v4's `z.toJSONSchema` converts the schemas; request schemas use
 * the input side, responses the output side.
 */

import { readdirSync, statSync } from 'node:fs'
import { join, relative, sep } from 'node:path'
import { compareStrings } from '@sim/utils/string'
import { z } from 'zod'
import type { Portable } from '@/scripts/flutter-port/portable'

const CONTRACTS_DIR = 'apps/sim/lib/api/contracts'

export interface ContractSchemaFile {
  file: string
  source: string
  contracts: Record<string, Portable>
}

export interface ContractExport {
  files: ContractSchemaFile[]
  contractCount: number
  schemaErrors: number
}

interface ContractLike {
  method: string
  path: string
  params?: unknown
  query?: unknown
  body?: unknown
  headers?: unknown
  response?: unknown
  error?: unknown
}

function isContract(value: unknown): value is ContractLike {
  return (
    typeof value === 'object' &&
    value !== null &&
    typeof (value as { method?: unknown }).method === 'string' &&
    typeof (value as { path?: unknown }).path === 'string'
  )
}

function isZodSchema(value: unknown): value is z.ZodType {
  return typeof value === 'object' && value !== null && '_zod' in value
}

function listSourceFiles(dir: string): string[] {
  const files: string[] = []
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry)
    if (statSync(full).isDirectory()) {
      files.push(...listSourceFiles(full))
    } else if (entry.endsWith('.ts') && !entry.endsWith('.test.ts')) {
      files.push(full)
    }
  }
  return files
}

let schemaErrors = 0

function schemaToJson(schema: unknown, io: 'input' | 'output'): Portable | undefined {
  if (schema === undefined || schema === null) return undefined
  if (!isZodSchema(schema)) return { $unsupported: typeof schema }
  try {
    return z.toJSONSchema(schema, { io, unrepresentable: 'any', reused: 'inline' }) as Portable
  } catch (error) {
    schemaErrors += 1
    return { $error: error instanceof Error ? error.message : String(error) }
  }
}

function responseToJson(response: unknown): Portable | undefined {
  if (typeof response !== 'object' || response === null) return undefined
  const value = response as Record<string, unknown>
  const out: Record<string, Portable> = {}
  if (typeof value.mode === 'string') out.mode = value.mode
  if (value.status !== undefined) out.status = value.status as Portable
  const schema = schemaToJson(value.schema, 'output')
  if (schema !== undefined) out.schema = schema
  if (typeof value.statusSchemas === 'object' && value.statusSchemas !== null) {
    const statusSchemas: Record<string, Portable> = {}
    for (const [status, statusSchema] of Object.entries(value.statusSchemas)) {
      const json = schemaToJson(statusSchema, 'output')
      if (json !== undefined) statusSchemas[status] = json
    }
    out.statusSchemas = statusSchemas
  }
  return out
}

function contractToJson(contract: ContractLike): Portable {
  const out: Record<string, Portable> = { method: contract.method, path: contract.path }
  const params = schemaToJson(contract.params, 'input')
  if (params !== undefined) out.params = params
  const query = schemaToJson(contract.query, 'input')
  if (query !== undefined) out.query = query
  const body = schemaToJson(contract.body, 'input')
  if (body !== undefined) out.body = body
  const headers = schemaToJson(contract.headers, 'input')
  if (headers !== undefined) out.headers = headers
  const response = responseToJson(contract.response)
  if (response !== undefined) out.response = response
  const error = schemaToJson(contract.error, 'output')
  if (error !== undefined) out.error = error
  return out
}

function collectContracts(moduleExports: Record<string, unknown>): Array<[string, ContractLike]> {
  const found: Array<[string, ContractLike]> = []
  for (const [name, value] of Object.entries(moduleExports)) {
    if (isContract(value)) {
      found.push([name, value])
      continue
    }
    if (
      typeof value === 'object' &&
      value !== null &&
      !isZodSchema(value) &&
      !Array.isArray(value)
    ) {
      for (const [inner, nested] of Object.entries(value as Record<string, unknown>)) {
        if (isContract(nested)) found.push([`${name}.${inner}`, nested])
      }
    }
  }
  return found.sort((a, b) => compareStrings(a[0], b[0]))
}

/** Barrels re-export their siblings; a defining module must win, so barrels sort last. */
function fileOrder(a: string, b: string): number {
  const aIndex = a.endsWith(`${sep}index.ts`) ? 1 : 0
  const bIndex = b.endsWith(`${sep}index.ts`) ? 1 : 0
  return aIndex - bIndex || compareStrings(a, b)
}

export async function exportContracts(repoRoot: string): Promise<ContractExport> {
  schemaErrors = 0
  const root = join(repoRoot, CONTRACTS_DIR)
  const sources = listSourceFiles(root).sort(fileOrder)
  const seen = new Set<ContractLike>()
  const files: ContractSchemaFile[] = []
  let contractCount = 0

  for (const source of sources) {
    const moduleExports = (await import(source)) as Record<string, unknown>
    const contracts: Record<string, Portable> = {}
    for (const [name, contract] of collectContracts(moduleExports)) {
      if (seen.has(contract)) continue
      seen.add(contract)
      contracts[name] = contractToJson(contract)
      contractCount += 1
    }
    if (Object.keys(contracts).length === 0) continue
    const relativePath = relative(root, source).split(sep).join('/')
    const stem = relativePath.replace(/\.ts$/, '').replace(/\//g, '.')
    files.push({
      file: `contracts/${stem}.schema.json`,
      source: `${CONTRACTS_DIR}/${relativePath}`,
      contracts,
    })
  }

  files.sort((a, b) => compareStrings(a.file, b.file))
  return { files, contractCount, schemaErrors }
}
