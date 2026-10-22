#!/usr/bin/env node
// L6 parity comparison (docs/port/04-test-plan.md §4, report schema §5).
//
// Reads the captures written by capture.mjs and computes per screen/theme/viewport:
//   1. layout   rect delta per parity id (React getBoundingClientRect vs Flutter semantics
//               rect), gate max |dx|,|dy|,|dw|,|dh| <= gates.rectPx; an id the Flutter
//               semantics tree does not expose fails as 'id-missing' (a fallback match still
//               reports its delta); text equality for ids flagged "text"; child counts.
//   2. colours  ΔE76 between the Flutter and React pixel at each anchor, gate <= gates.deltaE;
//               the spec token is reported next to it (informational).
//   3. ssim     SSIM over the configured regions with text/icon pixels masked (React text
//               rects dilated by 2 px, copied into both images), gate >= gates.ssim.
//   4. route    the final path of both apps (Flutter path without its base) must match.
// Writes docs/port/parity/<phase>/<screen>.json, images, index.html and summary.json
// (or PARITY_REPORT_PATH), and exits 1 when any gate fails.
//
// Usage: node compare.mjs [--config screens.json] [--in out/<phase>] [--report-dir docs/port/parity/<phase>]
//                         [--seed seed.json] [--no-images]

import pixelmatch from 'pixelmatch'
import { PNG } from 'pngjs'
import ssimPkg from 'ssim.js'
import { execSync } from 'node:child_process'
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const { ssim } = ssimPkg
const here = dirname(fileURLToPath(import.meta.url))
const flutterRoot = resolve(here, '..', '..')

function parseArgs(argv) {
  const args = {}
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (!a.startsWith('--')) continue
    const next = argv[i + 1]
    if (next === undefined || next.startsWith('--')) args[a.slice(2)] = true
    else {
      args[a.slice(2)] = next
      i++
    }
  }
  return args
}

const args = parseArgs(process.argv.slice(2))
const configPath = resolve(args.config ?? join(here, 'screens.json'))
const config = JSON.parse(readFileSync(configPath, 'utf8'))
const inDir = resolve(args.in ?? process.env.PARITY_OUT ?? join(here, 'out', config.phase))
const reportDir = resolve(args['report-dir'] ?? join(flutterRoot, 'docs', 'port', 'parity', config.phase))
const summaryPath = resolve(process.env.PARITY_REPORT_PATH ?? join(reportDir, 'summary.json'))
const seedPath = args.seed ?? process.env.SIM_SEED_PATH
const seed = seedPath && existsSync(seedPath) ? JSON.parse(readFileSync(seedPath, 'utf8')) : null
const copyImages = !args['no-images']
const gates = { rectPx: 1, deltaE: 2, ssim: 0.98, ...(config.gates ?? {}) }

// ---------------- colour ----------------

function hexToRgb(hex) {
  const h = hex.replace('#', '')
  return [0, 2, 4].map((i) => Number.parseInt(h.slice(i, i + 2), 16))
}
const rgbToHex = (rgb) => `#${rgb.map((v) => v.toString(16).padStart(2, '0')).join('')}`

function rgbToLab([r, g, b]) {
  const lin = (c) => {
    const v = c / 255
    return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
  }
  const [R, G, B] = [lin(r), lin(g), lin(b)]
  const X = (R * 0.4124564 + G * 0.3575761 + B * 0.1804375) / 0.95047
  const Y = R * 0.2126729 + G * 0.7151522 + B * 0.072175
  const Z = (R * 0.0193339 + G * 0.119192 + B * 0.9503041) / 1.08883
  const f = (t) => (t > 216 / 24389 ? Math.cbrt(t) : (24389 / 27 * t + 16) / 116)
  const [fx, fy, fz] = [f(X), f(Y), f(Z)]
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)]
}

function deltaE76(a, b) {
  const [l1, a1, b1] = rgbToLab(a)
  const [l2, a2, b2] = rgbToLab(b)
  return Math.hypot(l1 - l2, a1 - a2, b1 - b2)
}

function pixel(png, x, y) {
  const xi = Math.round(x)
  const yi = Math.round(y)
  if (xi < 0 || yi < 0 || xi >= png.width || yi >= png.height) return null
  const i = (yi * png.width + xi) * 4
  return [png.data[i], png.data[i + 1], png.data[i + 2]]
}

// ---------------- helpers ----------------

function resolveScreen(screen) {
  const ids = {}
  const children = {}
  const anchors = []
  for (const groupName of screen.include ?? []) {
    const group = config.groups[groupName]
    Object.assign(ids, group.ids ?? {})
    Object.assign(children, group.children ?? {})
    anchors.push(...(group.anchors ?? []))
  }
  Object.assign(ids, screen.ids ?? {})
  Object.assign(children, screen.children ?? {})
  anchors.push(...(screen.anchors ?? []))
  return { ...screen, ids, children, anchors }
}

const round = (n, d = 2) => Math.round(n * 10 ** d) / 10 ** d
const fmtRect = (r) => (r ? `${round(r.x, 1)},${round(r.y, 1)} ${round(r.width, 1)}×${round(r.height, 1)}` : '—')
const normText = (s) => (s ?? '').replace(/[​ ]/g, ' ').replace(/\s+/g, ' ').trim()

function readPng(path) {
  return PNG.sync.read(readFileSync(path))
}

function crop(png, rect) {
  const x0 = Math.max(0, Math.floor(rect.x))
  const y0 = Math.max(0, Math.floor(rect.y))
  const x1 = Math.min(png.width, Math.ceil(rect.x + rect.width))
  const y1 = Math.min(png.height, Math.ceil(rect.y + rect.height))
  const width = Math.max(0, x1 - x0)
  const height = Math.max(0, y1 - y0)
  const data = new Uint8ClampedArray(width * height * 4)
  for (let y = 0; y < height; y++) {
    const src = ((y0 + y) * png.width + x0) * 4
    data.set(png.data.subarray(src, src + width * 4), y * width * 4)
  }
  return { data, width, height, x0, y0 }
}

function buildMask(width, height, rects, pad = 2) {
  const mask = new Uint8Array(width * height)
  for (const r of rects) {
    const x0 = Math.max(0, Math.floor(r.x - pad))
    const y0 = Math.max(0, Math.floor(r.y - pad))
    const x1 = Math.min(width, Math.ceil(r.x + r.width + pad))
    const y1 = Math.min(height, Math.ceil(r.y + r.height + pad))
    for (let y = y0; y < y1; y++) mask.fill(1, y * width + x0, y * width + x1)
  }
  return mask
}

// ---------------- measures ----------------

function layoutMeasure(screen, react, flutter) {
  const rows = []
  for (const [id, spec] of Object.entries(screen.ids)) {
    const r = react.ids?.[id] ?? null
    const f = flutter.ids?.[id] ?? null
    const row = { id, react: r?.rect ?? null, flutter: f?.rect ?? null, via: f?.via ?? null }
    if (!r) {
      row.status = 'react-missing'
      row.note = `React selector matched nothing: ${spec.react}`
    } else if (!f) {
      row.status = 'id-missing'
      row.note = 'no Flutter semantics node with this identifier'
    } else {
      const d = {
        dx: f.rect.x - r.rect.x,
        dy: f.rect.y - r.rect.y,
        dw: f.rect.width - r.rect.width,
        dh: f.rect.height - r.rect.height,
      }
      row.delta = Object.fromEntries(Object.entries(d).map(([k, v]) => [k, round(v)]))
      row.maxDelta = round(Math.max(...Object.values(d).map(Math.abs)))
      if (f.via === 'fallback') {
        row.status = 'id-missing'
        row.note = `identifier not exposed; measured via fallback ${JSON.stringify(spec.flutterFallback)}`
      } else row.status = row.maxDelta <= gates.rectPx ? 'pass' : 'fail'
    }
    if (spec.text && r && f) {
      row.text = { react: normText(r.text), flutter: normText(f.text) }
      // React innerText can carry glyph-like text Flutter exposes elsewhere (an identity
      // tile's initial), so containment either way counts as equal.
      row.text.pass =
        row.text.react === row.text.flutter ||
        (row.text.flutter !== '' && (row.text.react.includes(row.text.flutter) || row.text.flutter.includes(row.text.react)))
      if (!row.text.pass && row.status === 'pass') row.status = 'fail'
    }
    if (r?.styles) row.reactStyles = r.styles
    rows.push(row)
  }
  const childRows = Object.entries(screen.children).map(([id]) => {
    const rc = react.children?.[id]
    const fc = flutter.children?.[id]
    return { id, react: rc, flutter: fc, pass: rc === fc }
  })
  const gated = rows.filter((r) => r.status !== 'react-missing')
  const failures = gated.filter((r) => r.status !== 'pass')
  const deltas = rows.filter((r) => r.maxDelta !== undefined).map((r) => r.maxDelta)
  return {
    pass: failures.length === 0 && childRows.every((c) => c.pass),
    maxDelta: deltas.length ? Math.max(...deltas) : null,
    compared: gated.length,
    passed: gated.length - failures.length,
    idMissing: rows.filter((r) => r.status === 'id-missing').map((r) => r.id),
    reactMissing: rows.filter((r) => r.status === 'react-missing').map((r) => r.id),
    failures: failures.map((r) => r.id),
    rows,
    children: childRows,
  }
}

function anchorPoint(anchor, box) {
  if (anchor.point) return { x: anchor.point[0], y: anchor.point[1] }
  if (!box) return null
  return { x: box.x + anchor.at[0], y: box.y + anchor.at[1] }
}

function colourMeasure(screen, theme, react, flutter, reactPng, flutterPng) {
  const rows = []
  for (const anchor of screen.anchors) {
    const rBox = anchor.parity ? react.ids?.[anchor.parity]?.rect : null
    const fBoxRaw = anchor.parity ? flutter.ids?.[anchor.parity] : null
    const fBox = fBoxRaw?.rect ?? rBox
    const rp = anchorPoint(anchor, rBox)
    const fp = anchorPoint(anchor, fBox)
    const row = { id: anchor.id, parity: anchor.parity ?? null, at: anchor.at ?? anchor.point }
    if (!rp || !fp) {
      row.status = 'skipped'
      row.note = 'anchor element not found'
      rows.push(row)
      continue
    }
    if (anchor.parity && !fBoxRaw) row.note = 'Flutter box missing; sampled at the React position'
    const rc = pixel(reactPng, rp.x, rp.y)
    const fc = pixel(flutterPng, fp.x, fp.y)
    row.reactPoint = [round(rp.x, 1), round(rp.y, 1)]
    row.flutterPoint = [round(fp.x, 1), round(fp.y, 1)]
    row.react = rc ? rgbToHex(rc) : null
    row.flutter = fc ? rgbToHex(fc) : null
    row.deltaE = rc && fc ? round(deltaE76(rc, fc)) : null
    const expected = anchor.expect?.[theme]
    if (expected) {
      row.expected = expected
      row.reactVsSpec = rc ? round(deltaE76(rc, hexToRgb(expected))) : null
      row.flutterVsSpec = fc ? round(deltaE76(fc, hexToRgb(expected))) : null
    }
    if (!rc || !fc) {
      row.status = 'skipped'
      row.note = 'anchor outside the viewport'
    } else row.status = row.deltaE <= gates.deltaE ? 'pass' : 'fail'
    rows.push(row)
  }
  const measured = rows.filter((r) => r.deltaE !== null && r.deltaE !== undefined)
  return {
    pass: rows.every((r) => r.status !== 'fail'),
    maxDeltaE: measured.length ? Math.max(...measured.map((r) => r.deltaE)) : null,
    rows,
  }
}

function ssimMeasure(screen, react, reactPng, flutterPng) {
  const regions = []
  const mask = buildMask(reactPng.width, reactPng.height, react.textRects ?? [])
  for (const regionName of screen.ssim ?? ['viewport']) {
    const rect =
      regionName === 'viewport'
        ? { x: 0, y: 0, width: reactPng.width, height: reactPng.height }
        : react.ids?.[regionName]?.rect
    if (!rect) {
      regions.push({ region: regionName, value: null, note: 'region box not found in React' })
      continue
    }
    const a = crop(reactPng, rect)
    const b = crop(flutterPng, rect)
    if (a.width < 11 || a.height < 11) {
      regions.push({ region: regionName, value: null, note: 'region smaller than the SSIM window' })
      continue
    }
    let masked = 0
    for (let y = 0; y < a.height; y++) {
      for (let x = 0; x < a.width; x++) {
        if (!mask[(a.y0 + y) * reactPng.width + a.x0 + x]) continue
        const i = (y * a.width + x) * 4
        b.data[i] = a.data[i]
        b.data[i + 1] = a.data[i + 1]
        b.data[i + 2] = a.data[i + 2]
        b.data[i + 3] = a.data[i + 3]
        masked++
      }
    }
    const { mssim } = ssim(a, b, { ssim: 'weber' })
    regions.push({
      region: regionName,
      rect: { x: a.x0, y: a.y0, width: a.width, height: a.height },
      maskedFraction: round(masked / (a.width * a.height), 3),
      value: round(mssim, 4),
    })
  }
  const values = regions.map((r) => r.value).filter((v) => v !== null)
  const value = values.length ? Math.min(...values) : null
  return { value, pass: value !== null && value >= gates.ssim, regions }
}

function diffImage(reactPng, flutterPng, outPath) {
  const { width, height } = reactPng
  if (flutterPng.width !== width || flutterPng.height !== height) return null
  const diff = new PNG({ width, height })
  const count = pixelmatch(reactPng.data, flutterPng.data, diff.data, width, height, { threshold: 0.1 })
  if (outPath) writeFileSync(outPath, PNG.sync.write(diff))
  return round(count / (width * height), 4)
}

// ---------------- report ----------------

const esc = (s) =>
  String(s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')

const badge = (pass) => `<span class="badge ${pass ? 'ok' : 'bad'}">${pass ? 'pass' : 'fail'}</span>`

function variantHtml(v) {
  const failingLayout = v.layout.rows.filter((r) => r.status !== 'pass')
  const failingColours = v.colors.rows.filter((r) => r.status !== 'pass')
  const layoutRows = failingLayout
    .map(
      (r) => `<tr><td><code>${esc(r.id)}</code></td><td>${esc(r.status)}</td><td>${fmtRect(r.react)}</td><td>${fmtRect(
        r.flutter,
      )}</td><td>${r.delta ? esc(`dx ${r.delta.dx} dy ${r.delta.dy} dw ${r.delta.dw} dh ${r.delta.dh}`) : ''}</td><td>${esc(
        [r.note, r.text && !r.text.pass ? `text "${r.text.react}" vs "${r.text.flutter}"` : ''].filter(Boolean).join('; '),
      )}</td></tr>`,
    )
    .join('')
  const colourRows = failingColours
    .map(
      (r) =>
        `<tr><td>${esc(r.id)}</td><td>${esc(r.status)}</td><td>${swatch(r.react)}</td><td>${swatch(r.flutter)}</td><td>${
          r.deltaE ?? ''
        }</td><td>${r.expected ? `${swatch(r.expected)} (R ΔE ${r.reactVsSpec}, F ΔE ${r.flutterVsSpec})` : ''}</td><td>${esc(
          r.note ?? '',
        )}</td></tr>`,
    )
    .join('')
  const childRows = v.layout.children
    .filter((c) => !c.pass)
    .map((c) => `<tr><td><code>${esc(c.id)}</code></td><td>${c.react}</td><td>${c.flutter}</td></tr>`)
    .join('')
  const ssimRows = v.ssim.regions
    .map((r) => `<li><code>${esc(r.region)}</code>: ${r.value ?? esc(r.note)}${r.maskedFraction !== undefined ? ` (masked ${r.maskedFraction})` : ''}</li>`)
    .join('')
  const img = (name) => (name ? `<a href="${esc(name)}"><img loading="lazy" src="${esc(name)}" alt=""></a>` : '<div class="noimg">no image</div>')
  return `<section class="variant" id="${esc(`${v.screen}-${v.theme}-${v.viewport}`)}">
<h3>${esc(v.screen)} · ${esc(v.theme)} · ${esc(v.viewport)} ${badge(v.pass)}</h3>
<p>layout ${badge(v.layout.pass)} ${v.layout.passed}/${v.layout.compared} ids within ${gates.rectPx}px, max Δ ${v.layout.maxDelta ?? '—'} px · colours ${badge(
    v.colors.pass,
  )} max ΔE ${v.colors.maxDeltaE ?? '—'} · SSIM ${badge(v.ssim.pass)} ${v.ssim.value ?? '—'} · route ${badge(v.route.pass)} · pixel diff ${
    v.pixelDiffRatio ?? '—'
  }${v.errors.length ? ` · <strong>capture errors:</strong> ${esc(v.errors.join('; '))}` : ''}</p>
<div class="imgs"><figure>${img(v.images.react)}<figcaption>React</figcaption></figure><figure>${img(
    v.images.flutter,
  )}<figcaption>Flutter</figcaption></figure><figure>${img(v.images.diff)}<figcaption>pixelmatch diff</figcaption></figure></div>
${layoutRows ? `<h4>Layout rows not passing</h4><table><tr><th>id</th><th>status</th><th>React</th><th>Flutter</th><th>delta</th><th>note</th></tr>${layoutRows}</table>` : ''}
${childRows ? `<h4>Child counts</h4><table><tr><th>id</th><th>React</th><th>Flutter</th></tr>${childRows}</table>` : ''}
${colourRows ? `<h4>Colour anchors not passing</h4><table><tr><th>anchor</th><th>status</th><th>React</th><th>Flutter</th><th>ΔE</th><th>spec</th><th>note</th></tr>${colourRows}</table>` : ''}
<h4>SSIM regions</h4><ul>${ssimRows}</ul>
${v.route.pass ? '' : `<p>route: React <code>${esc(v.route.react)}</code> vs Flutter <code>${esc(v.route.flutter)}</code></p>`}
</section>`
}

function swatch(hex) {
  return hex ? `<span class="sw" style="background:${esc(hex)}"></span>${esc(hex)}` : '—'
}

function indexHtml(variants, summary) {
  const rows = variants
    .map(
      (v) =>
        `<tr><td><a href="#${esc(`${v.screen}-${v.theme}-${v.viewport}`)}">${esc(v.screen)}</a></td><td>${esc(v.theme)}</td><td>${esc(
          v.viewport,
        )}</td><td>${badge(v.layout.pass)} ${v.layout.passed}/${v.layout.compared} (max ${v.layout.maxDelta ?? '—'})</td><td>${badge(
          v.colors.pass,
        )} ${v.colors.maxDeltaE ?? '—'}</td><td>${badge(v.ssim.pass)} ${v.ssim.value ?? '—'}</td><td>${badge(v.route.pass)}</td></tr>`,
    )
    .join('')
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Parity ${esc(config.phase)}</title>
<style>
:root{color-scheme:light dark;--bg:#fff;--fg:#1a1a1a;--muted:#666;--line:#ddd;--ok:#1f7a45;--bad:#b42318}
@media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#eee;--muted:#aaa;--line:#333;--ok:#4ade80;--bad:#f87171}}
body{margin:0;padding:16px 24px;background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,sans-serif}
table{border-collapse:collapse;margin:8px 0;font-size:12.5px}td,th{border:1px solid var(--line);padding:3px 6px;text-align:left;vertical-align:top}
.badge{display:inline-block;padding:0 6px;border-radius:4px;font-size:12px;font-weight:600}.ok{color:var(--ok)}.bad{color:var(--bad)}
.imgs{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px}.imgs img{width:100%;border:1px solid var(--line)}figure{margin:0}figcaption{color:var(--muted);font-size:12px}
.sw{display:inline-block;width:12px;height:12px;border:1px solid var(--line);vertical-align:middle;margin-right:4px}
section.variant{border-top:1px solid var(--line);margin-top:24px}code{font-size:12px}
@media (max-width:700px){.imgs{grid-template-columns:1fr}body{padding:12px 16px}}
</style></head><body>
<h1>Parity report · ${esc(config.phase)}</h1>
<p>Status <strong>${esc(summary.status)}</strong> · ${esc(summary.completedAt)} · upstream ${esc(summary.upstreamCommit ?? '?')} · ${esc(
    summary.flutterVersion ?? '',
  )} · gates: rect ≤ ${gates.rectPx}px, ΔE76 ≤ ${gates.deltaE}, SSIM ≥ ${gates.ssim}</p>
<table><tr><th>screen</th><th>theme</th><th>viewport</th><th>layout (ids pass, max Δpx)</th><th>colours (max ΔE)</th><th>SSIM</th><th>route</th></tr>${rows}</table>
${variants.map(variantHtml).join('\n')}
</body></html>`
}

function upstreamCommit() {
  try {
    return JSON.parse(readFileSync(join(flutterRoot, 'generated', 'manifest.json'), 'utf8')).upstreamCommit
  } catch {
    return null
  }
}

function flutterVersion() {
  if (process.env.FLUTTER_VERSION) return process.env.FLUTTER_VERSION
  try {
    const out = execSync('flutter --version --machine', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 60_000 })
    return JSON.parse(out.slice(out.indexOf('{'))).frameworkVersion
  } catch {
    return null
  }
}

function main() {
  const startedAt = new Date().toISOString()
  mkdirSync(reportDir, { recursive: true })
  const variants = []
  let requestCount = 0
  const httpErrors = []
  for (const raw of config.screens) {
    const screen = resolveScreen(raw)
    const dir = join(inDir, screen.name)
    if (!existsSync(dir)) continue
    const files = readdirSync(dir).filter((f) => f.endsWith('.json'))
    const screenVariants = []
    for (const file of files) {
      const cap = JSON.parse(readFileSync(join(dir, file), 'utf8'))
      const { react, flutter, theme } = cap
      const viewport = cap.viewport.join('x')
      const errors = [react, flutter].filter((s) => s.status !== 'ok').map((s) => `${s.side}: ${s.error}`)
      requestCount += (react.requestCount ?? 0) + (flutter.requestCount ?? 0)
      for (const side of [react, flutter]) for (const e of side.httpErrors ?? []) httpErrors.push({ ...e, app: side.side, screen: screen.name })
      const outScreenDir = join(reportDir, screen.name)
      mkdirSync(outScreenDir, { recursive: true })
      const images = {}
      let reactPng = null
      let flutterPng = null
      for (const side of [react, flutter]) {
        if (!side.screenshot) continue
        const src = join(dir, side.screenshot)
        if (copyImages) copyFileSync(src, join(outScreenDir, side.screenshot))
        images[side.side] = relative(reportDir, join(outScreenDir, side.screenshot)).replaceAll('\\', '/')
        if (side.side === 'react') reactPng = readPng(src)
        else flutterPng = readPng(src)
      }
      let pixelDiffRatio = null
      if (reactPng && flutterPng) {
        const diffName = `${theme}-${viewport}-diff.png`
        pixelDiffRatio = diffImage(reactPng, flutterPng, copyImages ? join(outScreenDir, diffName) : null)
        if (copyImages) images.diff = relative(reportDir, join(outScreenDir, diffName)).replaceAll('\\', '/')
      }
      const ok = errors.length === 0 && reactPng && flutterPng
      const layout = ok ? layoutMeasure(screen, react, flutter) : { pass: false, maxDelta: null, compared: 0, passed: 0, failures: [], rows: [], children: [], idMissing: [], reactMissing: [] }
      const colors = ok ? colourMeasure(screen, theme, react, flutter, reactPng, flutterPng) : { pass: false, maxDeltaE: null, rows: [] }
      const ssimResult = ok ? ssimMeasure(screen, react, reactPng, flutterPng) : { value: null, pass: false, regions: [] }
      const flutterPath = (flutter.finalPath ?? '').replace(new RegExp(`^${config.flutterBase}`), '') || '/'
      const route = { react: react.finalPath, flutter: flutterPath, pass: react.finalPath === flutterPath }
      const variant = {
        screen: screen.name,
        theme,
        viewport,
        pass: Boolean(ok) && layout.pass && colors.pass && ssimResult.pass && route.pass,
        errors,
        stable: { react: react.stable, flutter: flutter.stable },
        semantics: flutter.enabledBy ?? null,
        layout,
        colors,
        ssim: ssimResult,
        route,
        pixelDiffRatio,
        images,
        flutterIdentifiers: flutter.identifiers ?? [],
      }
      screenVariants.push(variant)
      variants.push(variant)
    }
    writeFileSync(
      join(reportDir, `${screen.name}.json`),
      JSON.stringify({ screen: screen.name, react: raw.react, flutter: raw.flutter, gates, variants: screenVariants }, null, 2),
    )
  }
  const completedAt = new Date().toISOString()
  const summary = {
    suite: 'parity',
    startedAt,
    completedAt,
    status: variants.length && variants.every((v) => v.pass) ? 'passed' : 'failed',
    transport: 'web',
    baseUrl: config.flutterOrigin,
    upstreamCommit: upstreamCommit(),
    flutterVersion: flutterVersion(),
    seed: seed
      ? { userId: seed.user?.id, workspaceId: seed.workspaceId, workflowIds: Object.values(seed.workflowIds ?? {}) }
      : null,
    requestCount,
    checks: variants.map((v) => ({
      name: `${v.screen} ${v.theme} ${v.viewport}`,
      status: v.pass ? 'passed' : 'failed',
      durationMs: 0,
      ...(v.errors.length ? { error: v.errors.join('; ') } : {}),
      screenshot: v.images.flutter,
      artifacts: [v.images.react, v.images.diff, `${v.screen}.json`].filter(Boolean),
    })),
    httpErrors,
    parity: variants.map((v) => ({
      screen: v.screen,
      theme: v.theme,
      viewport: v.viewport,
      layout: { pass: v.layout.pass, maxDelta: v.layout.maxDelta, failures: v.layout.failures },
      colors: { pass: v.colors.pass, maxDeltaE: v.colors.maxDeltaE },
      ssim: { value: v.ssim.value, pass: v.ssim.pass },
      networkDiff: { missing: [], extra: [] },
    })),
  }
  mkdirSync(dirname(summaryPath), { recursive: true })
  writeFileSync(summaryPath, JSON.stringify(summary, null, 2))
  writeFileSync(join(reportDir, 'index.html'), indexHtml(variants, summary))
  for (const v of variants) {
    console.log(
      `${v.pass ? 'PASS' : 'FAIL'} ${v.screen} ${v.theme} ${v.viewport}: layout ${v.layout.passed}/${v.layout.compared} (max ${v.layout.maxDelta}px, ${v.layout.idMissing.length} id-missing), colours max ΔE ${v.colors.maxDeltaE}, ssim ${v.ssim.value}, route ${v.route.pass ? 'ok' : 'differs'}`,
    )
  }
  console.log(`report: ${join(reportDir, 'index.html')}\nsummary: ${summaryPath}`)
  process.exit(summary.status === 'passed' ? 0 : 1)
}

main()
