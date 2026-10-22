/**
 * Renders every icon component to a standalone SVG file.
 *
 * `renderToStaticMarkup` turns the React tree into markup; the script then
 * rewrites `useId`-generated ids into stable, file-local ones so the output is
 * identical across React versions, and records the features (gradients,
 * filters, masks, raster images) a vector renderer may not support.
 */

import { createElement } from 'react'
import * as emcnIcons from '@sim/emcn/icons'
import { compareStrings, escapeRegExp } from '@sim/utils/string'
import { renderToStaticMarkup } from 'react-dom/server'
import * as brandIcons from '@/components/icons'
import type { AnyFunction } from '@/scripts/flutter-port/portable'

export type IconSet = 'emcn' | 'brand'

export interface RenderedIcon {
  set: IconSet
  export: string
  name: string
  file: string
  features: string[]
  rasterImages: number
  bytes: number
}

export interface IconFailure {
  set: IconSet
  export: string
  reason: string
}

export interface IconRenderResult {
  icons: RenderedIcon[]
  failures: IconFailure[]
  /** Maps the component function to its `<set>/<name>` reference for `$icon` markers. */
  refs: Map<AnyFunction, string>
}

export function kebabCase(name: string): string {
  return name
    .replace(/([a-z0-9])([A-Z])/g, '$1-$2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1-$2')
    .toLowerCase()
}

const ID_ATTRIBUTE = /\sid="([^"]+)"/g

/** Replaces every `id` and its `url(#id)` / `href="#id"` references with `<name>-<n>`. */
function stabiliseIds(svg: string, name: string): string {
  const ids = [...svg.matchAll(ID_ATTRIBUTE)].map((match) => match[1])
  if (ids.length === 0) return svg
  let out = svg
  ids.forEach((id, index) => {
    const replacement = `${name}-${index}`
    const escaped = escapeRegExp(id)
    out = out
      .replace(new RegExp(`\\sid="${escaped}"`, 'g'), ` id="${replacement}"`)
      .replace(new RegExp(`url\\(#${escaped}\\)`, 'g'), `url(#${replacement})`)
      .replace(new RegExp(`url\\(&quot;#${escaped}&quot;\\)`, 'g'), `url(#${replacement})`)
      .replace(new RegExp(`url\\('#${escaped}'\\)`, 'g'), `url(#${replacement})`)
      .replace(new RegExp(`href="#${escaped}"`, 'g'), `href="#${replacement}"`)
  })
  return out
}

function ensureNamespaces(svg: string): string {
  let out = svg
  if (!/^<svg[^>]*\sxmlns="http:\/\/www\.w3\.org\/2000\/svg"/.test(out)) {
    out = out.replace(/^<svg/, '<svg xmlns="http://www.w3.org/2000/svg"')
  }
  if (out.includes('xlink:href') && !out.includes('xmlns:xlink=')) {
    out = out.replace(/^<svg/, '<svg xmlns:xlink="http://www.w3.org/1999/xlink"')
  }
  return out
}

function detectFeatures(svg: string): { features: string[]; rasterImages: number } {
  const features: string[] = []
  if (/<(linear|radial)Gradient/.test(svg)) features.push('gradient')
  if (svg.includes('<filter')) features.push('filter')
  if (svg.includes('<mask')) features.push('mask')
  if (svg.includes('<clipPath')) features.push('clipPath')
  if (svg.includes('<image')) features.push('image')
  if (svg.includes('<foreignObject')) features.push('foreignObject')
  if (svg.includes('<text')) features.push('text')
  if (svg.includes('<style')) features.push('style')
  if (svg.includes('currentColor')) features.push('currentColor')
  const rasterImages = (svg.match(/<image\b/g) ?? []).length
  return { features, rasterImages }
}

function renderOne(
  set: IconSet,
  exportName: string,
  component: AnyFunction,
  name: string
): { svg: string; icon: RenderedIcon } | IconFailure {
  let markup: string
  try {
    markup = renderToStaticMarkup(createElement(component as never, {}))
  } catch (error) {
    return {
      set,
      export: exportName,
      reason: error instanceof Error ? error.message : String(error),
    }
  }
  if (!markup.startsWith('<svg')) {
    return { set, export: exportName, reason: `rendered ${markup.slice(0, 40) || '(empty)'}` }
  }
  const svg = `${ensureNamespaces(stabiliseIds(markup, name))}\n`
  const { features, rasterImages } = detectFeatures(svg)
  return {
    svg,
    icon: {
      set,
      export: exportName,
      name,
      file: `icons/${set}/${name}.svg`,
      features,
      rasterImages,
      bytes: Buffer.byteLength(svg),
    },
  }
}

function componentEntries(moduleExports: Record<string, unknown>): Array<[string, AnyFunction]> {
  return Object.entries(moduleExports)
    .filter((entry): entry is [string, AnyFunction] => typeof entry[1] === 'function')
    .sort((a, b) => compareStrings(a[0], b[0]))
}

export function renderIcons(write: (file: string, svg: string) => void): IconRenderResult {
  const icons: RenderedIcon[] = []
  const failures: IconFailure[] = []
  const refs = new Map<AnyFunction, string>()
  const seenFiles = new Set<string>()
  const sets: Array<[IconSet, Record<string, unknown>]> = [
    ['emcn', emcnIcons],
    ['brand', brandIcons],
  ]
  for (const [set, moduleExports] of sets) {
    const entries = componentEntries(moduleExports)
    const kebabCounts = new Map<string, number>()
    for (const [exportName, component] of entries) {
      // Exports differing only in case (`SSHIcon`, `SshIcon`) share a kebab name on a
      // case-insensitive file system; the later export (sorted) gets a numeric suffix.
      const base = kebabCase(exportName)
      const ordinal = (kebabCounts.get(base) ?? 0) + 1
      kebabCounts.set(base, ordinal)
      const rendered = renderOne(
        set,
        exportName,
        component,
        ordinal === 1 ? base : `${base}-${ordinal}`
      )
      if (!('svg' in rendered)) {
        failures.push(rendered)
        continue
      }
      if (seenFiles.has(rendered.icon.file)) {
        failures.push({
          set,
          export: exportName,
          reason: `file name collides: ${rendered.icon.file}`,
        })
        continue
      }
      seenFiles.add(rendered.icon.file)
      write(rendered.icon.file, rendered.svg)
      icons.push(rendered.icon)
      refs.set(component, `${set}/${rendered.icon.name}`)
    }
  }
  return { icons, failures, refs }
}
