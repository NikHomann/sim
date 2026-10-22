#!/usr/bin/env node
// L6 parity capture (docs/port/04-test-plan.md §1, §4).
//
// For every screen in screens.json, theme and viewport it opens the React app (reactOrigin)
// and the Flutter app (flutterOrigin + flutterBase, same origin as the Next app through
// tools/dev_proxy.mjs) in Playwright Chromium with deviceScaleFactor 1, reducedMotion
// 'reduce', a fixed timezone/locale and the seeded session cookie, waits for a stable frame
// and records:
//   - full-viewport PNG screenshots of both apps,
//   - React boxes (getBoundingClientRect + selected computed styles + text) per parity id,
//   - Flutter boxes from the semantics DOM (flt-semantics[flt-semantics-identifier]) after
//     enabling semantics through the flt-semantics-placeholder,
//   - React text rects (mask for the SSIM measure), the final route, HTTP errors.
// compare.mjs turns these into the gate measures.
//
// Usage: node capture.mjs [--config screens.json] [--seed seed.json] [--out out/<phase>]
//                         [--screens a,b] [--viewports 1440x900] [--themes light] [--concurrency 2]
// Env: SIM_SEED_PATH (seed report written by tools/seed), PARITY_OUT.

import { chromium } from 'playwright'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))

function parseArgs(argv) {
  const args = {}
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (!a.startsWith('--')) continue
    const key = a.slice(2)
    const next = argv[i + 1]
    if (next === undefined || next.startsWith('--')) args[key] = true
    else {
      args[key] = next
      i++
    }
  }
  return args
}

const args = parseArgs(process.argv.slice(2))
const configPath = resolve(args.config ?? join(here, 'screens.json'))
const config = JSON.parse(readFileSync(configPath, 'utf8'))
const seedPath = args.seed ?? process.env.SIM_SEED_PATH
if (!seedPath) {
  console.error('capture: pass --seed <seed.json> or set SIM_SEED_PATH (the report written by tools/seed)')
  process.exit(2)
}
const seed = JSON.parse(readFileSync(seedPath, 'utf8'))
const outDir = resolve(args.out ?? process.env.PARITY_OUT ?? join(here, 'out', config.phase))
const onlyScreens = args.screens ? new Set(String(args.screens).split(',')) : null
const onlyViewports = args.viewports ? new Set(String(args.viewports).split(',')) : null
const onlyThemes = args.themes ? new Set(String(args.themes).split(',')) : null
const concurrency = Number(args.concurrency ?? 2)

const STYLE_PROPS = [
  'color',
  'backgroundColor',
  'borderTopColor',
  'borderTopWidth',
  'borderTopLeftRadius',
  'fontSize',
  'fontWeight',
  'lineHeight',
  'paddingTop',
  'paddingRight',
  'paddingBottom',
  'paddingLeft',
  'opacity',
]

function substitute(template) {
  return template.replaceAll('{workspaceId}', seed.workspaceId)
}

/** Merges the screen's included groups (ids, anchors, children) under its own entries. */
function resolveScreen(screen) {
  const ids = {}
  const children = {}
  const anchors = []
  for (const groupName of screen.include ?? []) {
    const group = config.groups[groupName]
    if (!group) throw new Error(`screen ${screen.name}: unknown group ${groupName}`)
    Object.assign(ids, group.ids ?? {})
    Object.assign(children, group.children ?? {})
    anchors.push(...(group.anchors ?? []))
  }
  Object.assign(ids, screen.ids ?? {})
  Object.assign(children, screen.children ?? {})
  anchors.push(...(screen.anchors ?? []))
  return { ...screen, ids, children, anchors }
}

function originPort(origin) {
  return new URL(origin).origin
}

async function newContext(browser, screen, theme, [width, height]) {
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: 1,
    reducedMotion: 'reduce',
    colorScheme: theme,
    timezoneId: config.timezoneId ?? 'UTC',
    locale: config.locale ?? 'en-US',
  })
  const cookies = []
  // Cookies are host-scoped (ports are ignored), so one cookie on localhost serves :3000 and :3001.
  const cookieUrl = originPort(config.reactOrigin)
  if (screen.auth) {
    cookies.push({ name: seed.session.cookieName, value: seed.session.cookieValue, url: cookieUrl })
  }
  for (const [name, value] of Object.entries(screen.cookies ?? {})) {
    cookies.push({ name, value, url: cookieUrl })
  }
  if (cookies.length) await context.addCookies(cookies)
  const storage = { theme, sessionStorage: screen.sessionStorage ?? {} }
  await context.addInitScript((s) => {
    try {
      localStorage.setItem('sim-theme', s.theme)
    } catch {}
    try {
      for (const [k, v] of Object.entries(s.sessionStorage)) sessionStorage.setItem(k, v)
    } catch {}
  }, storage)
  return context
}

async function waitStable(page, { tries = 8, intervalMs = 400 } = {}) {
  let previous = await page.screenshot({ caret: 'hide', animations: 'disabled' })
  for (let i = 0; i < tries; i++) {
    await page.waitForTimeout(intervalMs)
    const current = await page.screenshot({ caret: 'hide', animations: 'disabled' })
    if (current.equals(previous)) return { stable: true, attempts: i + 1, png: current }
    previous = current
  }
  return { stable: false, attempts: tries, png: previous }
}

// ---------------- React side ----------------

async function reactBox(page, selector, childSelector) {
  const locator = page.locator(selector).first()
  if ((await locator.count()) === 0) return null
  return locator.evaluate(
    (el, { props, childSelector }) => {
      const r = el.getBoundingClientRect()
      const cs = getComputedStyle(el)
      const styles = {}
      for (const p of props) styles[p] = cs[p]
      const text = (el.innerText ?? el.textContent ?? '').replace(/\s+/g, ' ').trim()
      return {
        rect: { x: r.x, y: r.y, width: r.width, height: r.height },
        styles,
        text,
        tag: el.tagName.toLowerCase(),
        childSelector,
      }
    },
    { props: STYLE_PROPS, childSelector },
  )
}

async function reactTextRects(page) {
  return page.evaluate(() => {
    const rects = []
    const push = (r) => {
      if (r.width > 0 && r.height > 0) rects.push({ x: r.x, y: r.y, width: r.width, height: r.height })
    }
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT)
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (!node.textContent.trim()) continue
      const parent = node.parentElement
      if (!parent) continue
      const cs = getComputedStyle(parent)
      if (cs.visibility === 'hidden' || cs.opacity === '0') continue
      const range = document.createRange()
      range.selectNodeContents(node)
      for (const r of range.getClientRects()) push(r)
    }
    for (const el of document.querySelectorAll('input, textarea')) {
      if (el.value || el.placeholder) push(el.getBoundingClientRect())
    }
    for (const el of document.querySelectorAll('svg')) push(el.getBoundingClientRect())
    return rects
  })
}

async function captureReact(page, screen) {
  const ids = {}
  for (const [id, spec] of Object.entries(screen.ids)) {
    if (!spec.react) continue
    ids[id] = await reactBox(page, spec.react)
  }
  const children = {}
  for (const [id, spec] of Object.entries(screen.children)) {
    children[id] = await page.locator(spec.react).count()
  }
  return { ids, children, textRects: await reactTextRects(page) }
}

// ---------------- Flutter side ----------------

async function enableFlutterSemantics(page) {
  // The engine renders a hidden "Enable accessibility" placeholder until assistive tech
  // asks for semantics; a click on it builds the flt-semantics tree.
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 90_000 })
  const before = await page.evaluate(() => document.querySelectorAll('flt-semantics').length)
  if (before === 0) {
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click())
  }
  await page.waitForFunction(() => document.querySelectorAll('flt-semantics').length > 0, null, { timeout: 15_000 })
  return { enabledBy: before === 0 ? 'placeholder-click' : 'app' }
}

async function flutterNodes(page) {
  // Semantics nodes are <flt-semantics> or role-specific elements (<a>, <input>, ...) whose
  // id starts with flt-semantic-node-. Labels live in aria-label or in a scaled <span>.
  return page.evaluate(() => {
    // A label may repeat itself across lines (label + tooltip/hint); keep each line once.
    const norm = (s) =>
      [...new Set((s ?? '').split('\n').map((l) => l.replace(/\s+/g, ' ').trim()).filter(Boolean))].join(' ')
    const ownLabel = (el) => {
      const aria = el.getAttribute('aria-label')
      if (aria) return norm(aria)
      const own = [...el.childNodes]
        .filter((c) => c.nodeType === 3 || c.tagName === 'SPAN')
        .map((c) => c.textContent)
        .join('\n')
      return norm(own)
    }
    return [...document.querySelectorAll('[id^="flt-semantic-node-"]')].map((el) => {
      const r = el.getBoundingClientRect()
      const parts = []
      for (const node of [el, ...el.querySelectorAll('[id^="flt-semantic-node-"]')]) {
        const label = ownLabel(node)
        if (label && !parts.includes(label)) parts.push(label)
      }
      return {
        id: el.getAttribute('flt-semantics-identifier'),
        role: el.getAttribute('role') ?? (el.tagName === 'A' ? 'link' : null),
        tag: el.tagName.toLowerCase(),
        label: ownLabel(el) || parts[0] || '',
        text: parts.join(' '),
        rect: { x: r.x, y: r.y, width: r.width, height: r.height },
      }
    })
  })
}

function flutterLookup(nodes, id, fallback) {
  const byId = nodes.find((n) => n.id === id)
  if (byId) return { rect: byId.rect, text: byId.text, via: 'identifier' }
  if (!fallback) return null
  const matches = nodes.filter(
    (n) =>
      (fallback.role === undefined ||
        n.role === fallback.role ||
        (fallback.role === 'button' && n.role === 'link')) &&
      (fallback.label === undefined ||
        n.label === fallback.label ||
        n.text === fallback.label ||
        n.label.split(' ').slice(0, fallback.label.split(' ').length).join(' ') === fallback.label),
  )
  const hit = matches[fallback.nth ?? 0]
  return hit ? { rect: hit.rect, text: hit.text, via: 'fallback' } : null
}

async function captureFlutter(page, screen) {
  const nodes = await flutterNodes(page)
  const ids = {}
  for (const [id, spec] of Object.entries(screen.ids)) ids[id] = flutterLookup(nodes, id, spec.flutterFallback)
  const children = {}
  for (const [id, spec] of Object.entries(screen.children)) {
    const re = new RegExp(spec.flutter)
    children[id] = new Set(nodes.filter((n) => n.id && re.test(n.id)).map((n) => n.id)).size
  }
  const identifiers = [...new Set(nodes.map((n) => n.id).filter(Boolean))]
  return { ids, children, identifiers, nodeCount: nodes.length }
}

// ---------------- driving ----------------

async function boxCenter(page, side, screen, id) {
  if (side === 'react') {
    const box = await page.locator(screen.ids[id].react).first().boundingBox()
    if (!box) throw new Error(`react: no box for ${id}`)
    return [box.x + box.width / 2, box.y + box.height / 2]
  }
  const nodes = await flutterNodes(page)
  const hit = flutterLookup(nodes, id, screen.ids[id]?.flutterFallback)
  if (!hit) throw new Error(`flutter: no semantics node for ${id}`)
  return [hit.rect.x + hit.rect.width / 2, hit.rect.y + hit.rect.height / 2]
}

async function waitForSide(page, side, target) {
  if (side === 'react') await page.locator(target).first().waitFor({ state: 'visible', timeout: 30_000 })
  else await page.waitForSelector(`[flt-semantics-identifier="${target}"]`, { state: 'attached', timeout: 30_000 })
}

async function runActions(page, side, screen) {
  for (const action of screen.actions ?? []) {
    if (action.key) await page.keyboard.press(action.key)
    else if (action.click) {
      const [x, y] = await boxCenter(page, side, screen, action.click)
      await page.mouse.click(x, y)
    } else if (action.waitFor) await waitForSide(page, side, action.waitFor[side])
    else if (action.type) await page.keyboard.type(action.type)
    // Flutter re-builds its semantics tree on the next frame after an interaction.
    if (side === 'flutter') await page.waitForTimeout(150)
  }
}

async function captureSide(browser, screen, theme, viewport, side, dir) {
  const context = await newContext(browser, screen, theme, viewport)
  const page = await context.newPage()
  const httpErrors = []
  let requestCount = 0
  page.on('request', () => requestCount++)
  page.on('response', (res) => {
    if (res.status() >= 400) {
      const u = new URL(res.url())
      httpErrors.push({ method: res.request().method(), path: u.pathname, status: res.status() })
    }
  })
  const consoleErrors = []
  page.on('pageerror', (e) => consoleErrors.push(String(e).slice(0, 300)))
  const url =
    side === 'react'
      ? config.reactOrigin + substitute(screen.react)
      : config.flutterOrigin + config.flutterBase + substitute(screen.flutter)
  const startedAt = Date.now()
  const result = { side, url, theme, viewport }
  try {
    await page.goto(url, { waitUntil: 'load', timeout: 90_000 })
    if (side === 'flutter') Object.assign(result, await enableFlutterSemantics(page))
    if (screen.settleMs) await page.waitForTimeout(screen.settleMs)
    await waitForSide(page, side, screen.ready[side])
    await page.evaluate(() => document.fonts?.ready)
    // Park the pointer on an inert spot so no hover state leaks into the frame.
    await page.mouse.move(viewport[0] - 4, viewport[1] - 4)
    await runActions(page, side, screen)
    await page.waitForTimeout(screen.actionSettleMs ?? 600)
    const stable = await waitStable(page)
    result.stable = stable.stable
    result.stableAttempts = stable.attempts
    const pngName = `${theme}-${viewport[0]}x${viewport[1]}-${side}.png`
    writeFileSync(join(dir, pngName), stable.png)
    result.screenshot = pngName
    result.finalPath = new URL(page.url()).pathname
    Object.assign(result, side === 'react' ? await captureReact(page, screen) : await captureFlutter(page, screen))
    result.status = 'ok'
  } catch (error) {
    result.status = 'error'
    result.error = String(error?.message ?? error).split('\n')[0]
    try {
      const pngName = `${theme}-${viewport[0]}x${viewport[1]}-${side}.png`
      writeFileSync(join(dir, pngName), await page.screenshot())
      result.screenshot = pngName
      result.finalPath = new URL(page.url()).pathname
    } catch {}
  }
  result.durationMs = Date.now() - startedAt
  result.httpErrors = httpErrors
  result.requestCount = requestCount
  result.pageErrors = consoleErrors
  await context.close()
  return result
}

async function pool(items, limit, fn) {
  const results = new Array(items.length)
  let next = 0
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const i = next++
      results[i] = await fn(items[i], i)
    }
  })
  await Promise.all(workers)
  return results
}

async function main() {
  const startedAt = new Date().toISOString()
  const browser = await chromium.launch()
  const jobs = []
  for (const raw of config.screens) {
    if (onlyScreens && !onlyScreens.has(raw.name)) continue
    const screen = resolveScreen(raw)
    for (const theme of screen.themes ?? ['light']) {
      if (onlyThemes && !onlyThemes.has(theme)) continue
      for (const viewport of screen.viewports ?? config.viewports) {
        if (onlyViewports && !onlyViewports.has(`${viewport[0]}x${viewport[1]}`)) continue
        jobs.push({ screen, theme, viewport })
      }
    }
  }
  console.log(`capture: ${jobs.length} variants -> ${outDir}`)
  await pool(jobs, concurrency, async ({ screen, theme, viewport }) => {
    const dir = join(outDir, screen.name)
    mkdirSync(dir, { recursive: true })
    const react = await captureSide(browser, screen, theme, viewport, 'react', dir)
    const flutter = await captureSide(browser, screen, theme, viewport, 'flutter', dir)
    const record = { screen: screen.name, theme, viewport, capturedAt: new Date().toISOString(), react, flutter }
    writeFileSync(join(dir, `${theme}-${viewport[0]}x${viewport[1]}.json`), JSON.stringify(record, null, 2))
    const flag = (r) => (r.status === 'ok' ? (r.stable ? 'ok' : 'unstable') : `ERROR ${r.error}`)
    console.log(`  ${screen.name} ${theme} ${viewport.join('x')}: react ${flag(react)}, flutter ${flag(flutter)}`)
  })
  await browser.close()
  writeFileSync(
    join(outDir, 'capture-run.json'),
    JSON.stringify({ startedAt, completedAt: new Date().toISOString(), config: configPath, seed: seedPath, variants: jobs.length }, null, 2),
  )
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
