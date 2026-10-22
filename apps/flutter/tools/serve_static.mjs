#!/usr/bin/env node
// Serves a Flutter web build directory at "/" (single-page app: unknown paths
// fall back to index.html). Used behind tools/dev_proxy.mjs with
// FLUTTER_STRIP_PREFIX=1 for parity captures and e2e runs against a profile or
// release build, which load far faster and more reliably than the debug
// web-server (docs/port/04-test-plan.md §2).
//
//   node tools/serve_static.mjs build/web 8088
//   PROXY_PORT=3005 FLUTTER_PORT=8088 FLUTTER_STRIP_PREFIX=1 node tools/dev_proxy.mjs

import http from 'node:http'
import { createReadStream, statSync } from 'node:fs'
import { extname, join, normalize, resolve } from 'node:path'

const root = resolve(process.argv[2] ?? 'build/web')
const port = Number(process.argv[3] ?? 8088)

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.vec': 'application/octet-stream',
  '.bin': 'application/octet-stream',
}

function fileFor(urlPath) {
  const decoded = decodeURIComponent(urlPath.split('?')[0])
  const candidate = normalize(join(root, decoded))
  if (!candidate.startsWith(root)) return null
  try {
    const stat = statSync(candidate)
    if (stat.isFile()) return candidate
    if (stat.isDirectory()) {
      const index = join(candidate, 'index.html')
      if (statSync(index).isFile()) return index
    }
  } catch {
    // fall through to the SPA fallback
  }
  return null
}

http
  .createServer((req, res) => {
    const path = fileFor(req.url ?? '/') ?? join(root, 'index.html')
    res.writeHead(200, {
      'content-type': types[extname(path)] ?? 'application/octet-stream',
      'cache-control': 'no-cache',
    })
    createReadStream(path).pipe(res)
  })
  .listen(port, () => console.log(`serving ${root} on http://localhost:${port}`))
