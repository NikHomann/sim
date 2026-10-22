#!/usr/bin/env node
// Same-origin dev proxy for the Flutter port.
//
// Listens on PROXY_PORT (default 3001) and routes:
//   /app/*        -> the Flutter dev server (FLUTTER_PORT, default 8087), prefix kept (see FLUTTER_STRIP_PREFIX)
//   /socket.io/*  -> the realtime server (REALTIME_URL, default http://localhost:3002), incl. WebSocket upgrades
//   everything else -> the Next app (APP_URL, default http://localhost:3000)
//
// It also logs every request as one JSON line when PROXY_LOG is set to a file path,
// which the behavioral-parity tooling uses to diff React vs Flutter network calls.
//
// Uses only Node built-ins so it needs no npm install.

import http from 'node:http'
import net from 'node:net'
import { appendFileSync } from 'node:fs'
import { URL } from 'node:url'

const PROXY_PORT = Number(process.env.PROXY_PORT ?? 3001)
const APP_URL = new URL(process.env.APP_URL ?? 'http://localhost:3000')
const REALTIME_URL = new URL(process.env.REALTIME_URL ?? 'http://localhost:3002')
const FLUTTER_URL = new URL(process.env.FLUTTER_URL ?? `http://localhost:${process.env.FLUTTER_PORT ?? 8087}`)
const FLUTTER_PREFIX = process.env.FLUTTER_PREFIX ?? '/app'
// `flutter run` honours the <base href="/app/"> in web/index.html and serves the dev build
// under /app/ itself, so the prefix is forwarded unchanged by default. Set
// FLUTTER_STRIP_PREFIX=1 when the upstream serves the bundle at its root instead.
const FLUTTER_STRIP_PREFIX = process.env.FLUTTER_STRIP_PREFIX === '1'
const PROXY_LOG = process.env.PROXY_LOG

function pickTarget(pathname) {
  if (pathname === FLUTTER_PREFIX || pathname.startsWith(`${FLUTTER_PREFIX}/`)) return { target: FLUTTER_URL, kind: 'flutter' }
  if (pathname.startsWith('/socket.io')) return { target: REALTIME_URL, kind: 'realtime' }
  return { target: APP_URL, kind: 'app' }
}

function logLine(entry) {
  if (!PROXY_LOG) return
  try {
    appendFileSync(PROXY_LOG, `${JSON.stringify(entry)}\n`)
  } catch {
    // logging must never break the proxy
  }
}

function rewritePathForFlutter(pathname) {
  if (!FLUTTER_STRIP_PREFIX) return pathname
  const stripped = pathname.slice(FLUTTER_PREFIX.length)
  return stripped === '' ? '/' : stripped
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`)
  const { target, kind } = pickTarget(url.pathname)
  const forwardPath = kind === 'flutter' ? rewritePathForFlutter(url.pathname) + url.search : url.pathname + url.search
  const startedAt = Date.now()

  const headers = { ...req.headers, host: target.host }
  // Next/Better Auth read the public origin from these when behind a proxy.
  headers['x-forwarded-host'] = req.headers.host ?? `localhost:${PROXY_PORT}`
  headers['x-forwarded-proto'] = 'http'

  const upstream = http.request(
    { hostname: target.hostname, port: target.port, path: forwardPath, method: req.method, headers },
    (upstreamRes) => {
      const resHeaders = { ...upstreamRes.headers }
      // Flutter's dev server sends absolute paths in some responses; the app uses base-href so no rewrite needed.
      res.writeHead(upstreamRes.statusCode ?? 502, resHeaders)
      upstreamRes.pipe(res)
      upstreamRes.on('end', () => {
        logLine({
          ts: new Date(startedAt).toISOString(),
          kind,
          method: req.method,
          path: url.pathname,
          query: url.search,
          status: upstreamRes.statusCode,
          durationMs: Date.now() - startedAt,
          contentType: upstreamRes.headers['content-type'] ?? null,
          clientInfo: req.headers['x-sim-client-info'] ?? null,
        })
      })
    },
  )
  upstream.on('error', (err) => {
    res.writeHead(502, { 'content-type': 'text/plain' })
    res.end(`dev_proxy: upstream ${kind} (${target.origin}) unreachable: ${err.message}`)
  })
  req.pipe(upstream)
})

// WebSocket upgrades: socket.io (realtime) and the Flutter dev server's hot-restart channel.
server.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`)
  const { target, kind } = pickTarget(url.pathname)
  const forwardPath = kind === 'flutter' ? rewritePathForFlutter(url.pathname) + url.search : url.pathname + url.search
  const upstreamSocket = net.connect(Number(target.port), target.hostname, () => {
    const lines = [`${req.method} ${forwardPath} HTTP/1.1`]
    for (const [key, value] of Object.entries(req.headers)) {
      if (key === 'host') continue
      lines.push(`${key}: ${Array.isArray(value) ? value.join(', ') : value}`)
    }
    lines.push(`host: ${target.host}`)
    upstreamSocket.write(`${lines.join('\r\n')}\r\n\r\n`)
    if (head.length) upstreamSocket.write(head)
    upstreamSocket.pipe(socket)
    socket.pipe(upstreamSocket)
  })
  upstreamSocket.on('error', () => socket.destroy())
  socket.on('error', () => upstreamSocket.destroy())
})

server.listen(PROXY_PORT, () => {
  console.log(`dev_proxy listening on http://localhost:${PROXY_PORT}`)
  console.log(`  ${FLUTTER_PREFIX}/*  -> ${FLUTTER_URL.origin}`)
  console.log(`  /socket.io/* -> ${REALTIME_URL.origin}`)
  console.log(`  /*          -> ${APP_URL.origin}`)
  if (PROXY_LOG) console.log(`  request log -> ${PROXY_LOG}`)
})
