#!/usr/bin/env bun

/**
 * Exports everything the Flutter port generates its registry, assets and
 * conformance fixtures from (apps/flutter/docs/port/00-plan.md §4.5).
 *
 * Runs inside the extraction container (apps/flutter/tools/extract) because
 * it imports the block, tool and trigger registries, React icon components and
 * the serializer; the host has no bun.
 *
 * Usage:
 *   bun --no-env-file run apps/sim/scripts/export-flutter-port.ts --out <dir>
 *
 * `FLUTTER_PORT_OUT` is the fallback for `--out`; `UPSTREAM_COMMIT` overrides
 * the `git rev-parse HEAD` lookup (the container has no `.git`).
 *
 * Output ordering is deterministic: registry maps and file lists are sorted by
 * key; the fields inside a block, tool or trigger keep their source order
 * because `outputs`, `subBlocks` and `options` order is meaningful to the UI.
 */

import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createLogger } from '@sim/logger'
import { getErrorMessage } from '@sim/utils/errors'
import { compareStrings } from '@sim/utils/string'
import { exportContracts } from '@/scripts/flutter-port/contracts'
import { buildFixtures, buildMergeCases } from '@/scripts/flutter-port/fixtures'
import { renderIcons } from '@/scripts/flutter-port/icons'
import { OutputDir } from '@/scripts/flutter-port/output'
import type { Portable } from '@/scripts/flutter-port/portable'
import {
  type ClosureClass,
  exportRegistries,
  readSubBlockTypes,
  subBlockTypeUsage,
} from '@/scripts/flutter-port/registries'
import { parseTokens } from '@/scripts/flutter-port/tokens'

const SCRIPT_VERSION = '1.0.0'
const GLOBALS_CSS = 'apps/sim/app/_styles/globals.css'
const FONT_FILES = ['apps/sim/app/_styles/fonts/season/SeasonSansUprightsVF.woff2']
const OWNED_PATHS = [
  'blocks.json',
  'tools.json',
  'triggers.json',
  'subblock-types.json',
  'tool-selector-tables.json',
  'closures.json',
  'tokens.json',
  'manifest.json',
  'icons/emcn',
  'icons/brand',
  'icons/report.json',
  'fonts',
  'fixtures',
  'contracts',
]

const logger = createLogger('ExportFlutterPort')

function readArg(name: string): string | undefined {
  const index = process.argv.indexOf(name)
  return index >= 0 ? process.argv[index + 1] : undefined
}

function resolveRepoRoot(): string {
  const fromScript = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '..')
  if (existsSync(join(fromScript, 'apps/sim/package.json'))) return fromScript
  return process.cwd()
}

function resolveCommit(repoRoot: string): string {
  const fromEnv = process.env.UPSTREAM_COMMIT?.trim()
  if (fromEnv) return fromEnv
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], { cwd: repoRoot, encoding: 'utf8' }).trim()
  } catch (error) {
    logger.warn('git rev-parse HEAD failed; recording unknown commit', {
      error: getErrorMessage(error),
    })
    return 'unknown'
  }
}

function countBy<T extends string>(items: T[]): Record<string, number> {
  const counts: Record<string, number> = {}
  for (const item of items) counts[item] = (counts[item] ?? 0) + 1
  return Object.fromEntries(Object.entries(counts).sort((a, b) => compareStrings(a[0], b[0])))
}

async function main(): Promise<void> {
  const outArg = readArg('--out') ?? process.env.FLUTTER_PORT_OUT
  if (!outArg) {
    throw new Error('Missing output directory: pass --out <dir> or set FLUTTER_PORT_OUT')
  }
  const repoRoot = resolveRepoRoot()
  const out = new OutputDir(resolve(outArg))
  const commit = resolveCommit(repoRoot)
  logger.info('Exporting Flutter port data', { repoRoot, out: out.root, commit })
  for (const owned of OWNED_PATHS) out.clear(owned)

  const iconResult = renderIcons((file, svg) => out.writeText(file, svg))
  const iconsBySet = countBy(iconResult.icons.map((icon) => icon.set))
  const filterOrMask = iconResult.icons
    .filter((icon) => icon.features.includes('filter') || icon.features.includes('mask'))
    .map((icon) => icon.file)
  out.writeJson('icons/report.json', {
    counts: iconsBySet,
    filterOrMask,
    rasterImages: iconResult.icons.filter((icon) => icon.rasterImages > 0).map((icon) => icon.file),
    failures: iconResult.failures,
    icons: Object.fromEntries(
      iconResult.icons.map((icon) => [
        `${icon.set}/${icon.name}`,
        {
          export: icon.export,
          file: icon.file,
          features: icon.features,
          rasterImages: icon.rasterImages,
          bytes: icon.bytes,
        },
      ])
    ),
  })
  logger.info('Icons rendered', { ...iconsBySet, failures: iconResult.failures.length })

  const registries = exportRegistries(iconResult.refs)
  out.writeJson('blocks.json', registries.blocks)
  out.writeJson('tools.json', registries.tools)
  out.writeJson('triggers.json', registries.triggers)
  out.writeJson('tool-selector-tables.json', registries.selectorTables as unknown as Portable)
  out.writeJson('closures.json', registries.closures as unknown as Portable)
  const closureClasses = countBy(registries.closures.map((closure) => closure.class))
  const pureTables = registries.selectorTables.filter((table) => table.pure).length
  logger.info('Registries exported', {
    blocks: Object.keys(registries.blocks).length,
    tools: Object.keys(registries.tools).length,
    triggers: Object.keys(registries.triggers).length,
    selectorTables: registries.selectorTables.length,
    pureTables,
  })

  const subBlockTypes = readSubBlockTypes(repoRoot)
  out.writeJson('subblock-types.json', {
    source: 'packages/workflow-types/src/blocks.ts',
    types: subBlockTypes,
    usage: subBlockTypeUsage(subBlockTypes) as unknown as Portable,
  })

  const tokens = parseTokens(readFileSync(join(repoRoot, GLOBALS_CSS), 'utf8'), GLOBALS_CSS)
  out.writeJson('tokens.json', tokens as unknown as Portable)

  const fonts: string[] = []
  for (const font of FONT_FILES) {
    const source = join(repoRoot, font)
    if (!existsSync(source)) {
      logger.warn('Font file missing', { font })
      continue
    }
    const name = font.slice(font.lastIndexOf('/') + 1)
    out.writeBytes(`fonts/${name}`, readFileSync(source))
    fonts.push(`fonts/${name}`)
  }

  const fixtures = await buildFixtures()
  for (const fixture of fixtures) {
    out.writeJson(`fixtures/${fixture.name}.json`, fixture as unknown as Portable)
  }
  out.writeJson('fixtures/merge-subblock-state.json', buildMergeCases() as unknown as Portable)

  const contracts = await exportContracts(repoRoot)
  for (const file of contracts.files) {
    out.writeJson(file.file, { source: file.source, contracts: file.contracts })
  }
  logger.info('Contracts exported', {
    files: contracts.files.length,
    contracts: contracts.contractCount,
    schemaErrors: contracts.schemaErrors,
  })

  out.writeJson('manifest.json', {
    scriptVersion: SCRIPT_VERSION,
    upstreamCommit: commit,
    runtime: { bun: process.versions.bun ?? 'unknown' },
    counts: {
      blocks: Object.keys(registries.blocks).length,
      tools: Object.keys(registries.tools).length,
      triggers: Object.keys(registries.triggers).length,
      subBlockTypes: subBlockTypes.length,
      icons: iconsBySet,
      iconFailures: iconResult.failures.length,
      closures: closureClasses as Record<ClosureClass, number>,
      closuresByStatus: countBy(registries.closures.map((closure) => closure.portStatus)),
      closureTotal: registries.closures.length,
      toolFunctionFields: registries.toolFunctionFields,
      selectorTables: {
        total: registries.selectorTables.length,
        pure: pureTables,
        impure: registries.selectorTables.length - pureTables,
      },
      tokens: {
        root: Object.keys(tokens.root).length,
        light: Object.keys(tokens.light).length,
        dark: Object.keys(tokens.dark).length,
        themeInline: Object.keys(tokens.theme.inline).length,
        themeStatic: Object.keys(tokens.theme.static).length,
      },
      fonts: fonts.length,
      fixtures: fixtures.length,
      contractFiles: contracts.files.length,
      contracts: contracts.contractCount,
      contractSchemaErrors: contracts.schemaErrors,
    },
    files: {
      fonts,
      fixtures: [
        ...fixtures.map((f) => `fixtures/${f.name}.json`),
        'fixtures/merge-subblock-state.json',
      ],
      contracts: contracts.files.map((f) => f.file),
    },
  })
  logger.info('Export complete', { out: out.root })
}

main().catch((error: unknown) => {
  logger.error('Export failed', { error: getErrorMessage(error) })
  process.exitCode = 1
})
