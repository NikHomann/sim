/**
 * Extracts CSS custom properties from `globals.css` into theme buckets.
 *
 * A tiny brace-walking scanner is enough: the file is authored, not minified,
 * and only `--*` declarations matter. Each declaration is attributed to the
 * chain of rule preludes it sits in, so `:root, .light` inside `@layer base`
 * lands in both the `root` and `light` buckets, `.dark` in `dark`, and the
 * `@theme inline` / `@theme static` blocks in `theme`.
 */

import { compareStrings } from '@sim/utils/string'

export type TokenMap = Record<string, string>

export interface Tokens {
  source: string
  root: TokenMap
  light: TokenMap
  dark: TokenMap
  theme: { inline: TokenMap; static: TokenMap }
  /** Custom properties declared under any other selector chain (media queries, attribute selectors). */
  scoped: Record<string, TokenMap>
  keyframes: string[]
  fontFamilies: TokenMap
}

interface Declaration {
  chain: string[]
  name: string
  value: string
}

function stripComments(css: string): string {
  return css.replace(/\/\*[\s\S]*?\*\//g, '')
}

function normaliseValue(value: string): string {
  return value.replace(/\s+/g, ' ').trim()
}

/** Walks the stylesheet, returning every custom-property declaration with its rule chain. */
function scan(css: string): { declarations: Declaration[]; keyframes: string[] } {
  const declarations: Declaration[] = []
  const keyframes: string[] = []
  const chain: string[] = []
  let token = ''
  let depthParens = 0
  let quote: string | null = null

  const flushDeclaration = () => {
    const text = token.trim()
    token = ''
    if (!text.startsWith('--')) return
    const colon = text.indexOf(':')
    if (colon < 0) return
    declarations.push({
      chain: [...chain],
      name: text.slice(0, colon).trim(),
      value: normaliseValue(text.slice(colon + 1)),
    })
  }

  for (const char of css) {
    if (quote) {
      token += char
      if (char === quote) quote = null
      continue
    }
    if (char === '"' || char === "'") {
      quote = char
      token += char
      continue
    }
    if (char === '(') depthParens += 1
    if (char === ')') depthParens = Math.max(0, depthParens - 1)
    if (depthParens > 0) {
      token += char
      continue
    }
    if (char === '{') {
      const prelude = normaliseValue(token)
      token = ''
      chain.push(prelude)
      const keyframe = /^@keyframes\s+(\S+)$/.exec(prelude)
      if (keyframe) keyframes.push(keyframe[1])
      continue
    }
    if (char === ';') {
      flushDeclaration()
      continue
    }
    if (char === '}') {
      flushDeclaration()
      chain.pop()
      continue
    }
    token += char
  }
  return { declarations, keyframes }
}

function selectorsOf(prelude: string): string[] {
  return prelude.split(',').map((part) => part.trim())
}

function sortedTokens(map: TokenMap): TokenMap {
  return Object.fromEntries(Object.entries(map).sort((a, b) => compareStrings(a[0], b[0])))
}

export function parseTokens(css: string, source: string): Tokens {
  const { declarations, keyframes } = scan(stripComments(css))
  const root: TokenMap = {}
  const light: TokenMap = {}
  const dark: TokenMap = {}
  const theme = { inline: {} as TokenMap, static: {} as TokenMap }
  const scoped: Record<string, TokenMap> = {}
  const fontFamilies: TokenMap = {}

  for (const declaration of declarations) {
    const { chain, name, value } = declaration
    const rule = chain[chain.length - 1] ?? ''
    const ancestors = chain.slice(0, -1)
    const conditional = ancestors.some(
      (part) => part.startsWith('@media') || part.startsWith('@supports')
    )
    const selectors = selectorsOf(rule)

    if (rule === '@theme inline') {
      theme.inline[name] = value
      continue
    }
    if (rule === '@theme static') {
      theme.static[name] = value
      continue
    }
    if (rule === '@font-face') {
      if (name === '--font-family') fontFamilies[name] = value
      continue
    }
    const plain =
      !conditional && selectors.every((s) => s === ':root' || s === '.light' || s === '.dark')
    if (plain) {
      if (selectors.includes(':root')) root[name] = value
      if (selectors.includes('.light')) light[name] = value
      if (selectors.includes('.dark')) dark[name] = value
      continue
    }
    const key = chain.join(' > ')
    scoped[key] ??= {}
    scoped[key][name] = value
  }

  for (const [name, value] of Object.entries(theme.inline)) {
    if (name.startsWith('--font-')) fontFamilies[name] = value
  }

  return {
    source,
    root: sortedTokens(root),
    light: sortedTokens(light),
    dark: sortedTokens(dark),
    theme: { inline: sortedTokens(theme.inline), static: sortedTokens(theme.static) },
    scoped: Object.fromEntries(
      Object.entries(scoped)
        .sort((a, b) => compareStrings(a[0], b[0]))
        .map(([key, map]) => [key, sortedTokens(map)])
    ),
    keyframes: [...new Set(keyframes)].sort(compareStrings),
    fontFamilies: sortedTokens(fontFamilies),
  }
}
