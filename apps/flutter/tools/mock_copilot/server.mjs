#!/usr/bin/env node
// Mock of the Sim "copilot agent service" (the Go mothership worker behind SIM_AGENT_API_URL).
//
// Implements the endpoints the Sim server calls (see
// apps/flutter/docs/port/specs/agent-service-protocol.md) and plays scripted scenarios
// chosen by the user message (`#scenario:<name>`, see README.md). Node built-ins only.
//
// Env:
//   PORT            listen port (default 4010)
//   HOST            listen address (default 0.0.0.0, so Docker can reach it via host.docker.internal)
//   MOCK_SPEED      fast | real | instant (default real). Per message: `speed=<value>`.
//   MOCK_API_KEY    when set, requests must carry this x-api-key (401 otherwise)
//   MOCK_LOG_BODY   1 = log full request bodies (default: a summary)
//   MOCK_POLL_HOLD_MS  how long /api/sim-transport/poll holds before answering (default 20000)

import http from 'node:http'
import { randomUUID } from 'node:crypto'
import { parseDirectives, SCENARIOS, titleFor, UNKNOWN_SCENARIO } from './scenarios.mjs'

const SPEED_FACTOR = { real: 1, fast: 0.1, instant: 0 }
const PORT = Number(process.env.PORT ?? 4010)
const HOST = process.env.HOST ?? '0.0.0.0'
const DEFAULT_SPEED = normalizeSpeed(process.env.MOCK_SPEED) ?? 'real'
const API_KEY = process.env.MOCK_API_KEY || null
const LOG_BODY = process.env.MOCK_LOG_BODY === '1'
const POLL_HOLD_MS = Number(process.env.MOCK_POLL_HOLD_MS ?? 20_000)
const KEEPALIVE_MS = 10_000
const MAX_TURNS = 500

const SSE_HEADERS = {
  'Content-Type': 'text/event-stream',
  'Cache-Control': 'no-cache',
  Connection: 'keep-alive',
  'X-Accel-Buffering': 'no',
}

/** Turns by streamId (= the user messageId Sim sends). Kept for resume, replay and re-attach. */
const turns = new Map()

function normalizeSpeed(value) {
  return value && Object.hasOwn(SPEED_FACTOR, value) ? value : null
}

function log(entry) {
  process.stdout.write(`${JSON.stringify({ ts: new Date().toISOString(), ...entry })}\n`)
}

class TurnStopped extends Error {
  constructor(reason) {
    super(`turn stopped: ${reason}`)
    this.reason = reason
  }
}

function summarizeBody(path, body) {
  if (LOG_BODY || !body || typeof body !== 'object') return body
  const pick = {}
  for (const key of [
    'message',
    'messageId',
    'streamId',
    'chatId',
    'workspaceId',
    'organizationId',
    'workflowId',
    'userId',
    'mode',
    'model',
    'effort',
    'protocolVersion',
    'receivedTextChars',
    'channelId',
    'steeringId',
    'content',
    'taskId',
  ]) {
    if (body[key] !== undefined) pick[key] = body[key]
  }
  if (Array.isArray(body.results)) {
    pick.results = body.results.map((r) => ({ callId: r.callId, name: r.name, success: r.success }))
  }
  if (Array.isArray(body.context)) pick.contextTypes = body.context.map((c) => c?.type)
  if (body.simConnection) pick.simConnection = { mode: body.simConnection.mode }
  if (Array.isArray(body.clientCapabilities)) pick.clientCapabilities = body.clientCapabilities
  pick.keys = Object.keys(body)
  return pick
}

async function readBody(req) {
  let raw = ''
  for await (const chunk of req) raw += chunk
  if (!raw) return { raw, body: null }
  try {
    return { raw, body: JSON.parse(raw) }
  } catch {
    return { raw, body: null }
  }
}

function sendJson(res, status, body) {
  const text = JSON.stringify(body)
  res.writeHead(status, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(text) })
  res.end(text)
}

function rememberTurn(turn) {
  turns.set(turn.streamId, turn)
  if (turns.size > MAX_TURNS) turns.delete(turns.keys().next().value)
}

function newTurn(body, route) {
  const message = typeof body?.message === 'string' ? body.message : ''
  const directives = parseDirectives(message)
  return {
    streamId: typeof body?.messageId === 'string' && body.messageId ? body.messageId : randomUUID(),
    chatId: typeof body?.chatId === 'string' ? body.chatId : undefined,
    requestId: randomUUID(),
    route,
    message,
    scenario: directives.scenario,
    requestedScenario: directives.requested,
    speed: directives.speed ?? DEFAULT_SPEED,
    attempt: 0,
    seq: 0,
    textChars: 0,
    idCounter: 0,
    frames: [],
    subscribers: new Set(),
    state: 'idle', // idle | streaming | parked | done | stopped
    resume: null,
    stopRequested: false,
    res: null,
  }
}

function scenarioDef(turn) {
  return turn.scenario === 'unknown' ? UNKNOWN_SCENARIO : SCENARIOS[turn.scenario]
}

/** Writes one stream-v1 envelope as an SSE `data:` frame. */
function writeFrame(turn, type, payload, scope) {
  turn.seq += 1
  const envelope = {
    v: 1,
    type,
    seq: turn.seq,
    ts: new Date().toISOString(),
    stream: {
      streamId: turn.streamId,
      ...(turn.chatId ? { chatId: turn.chatId } : {}),
      cursor: String(turn.seq),
    },
    trace: { requestId: turn.requestId },
    ...(scope ? { scope } : {}),
    payload,
  }
  turn.frames.push(envelope)
  const line = `data: ${JSON.stringify(envelope)}\n\n`
  if (turn.res && !turn.res.writableEnded) turn.res.write(line)
  for (const sub of turn.subscribers) if (!sub.writableEnded) sub.write(line)
  return envelope
}

function splitChunks(text, wordsPerChunk) {
  const tokens = text.match(/\s*\S+\s*|\s+/g) ?? []
  const chunks = []
  for (let i = 0; i < tokens.length; i += wordsPerChunk) {
    chunks.push(tokens.slice(i, i + wordsPerChunk).join(''))
  }
  return chunks
}

/** The scripting surface a scenario sees. Every helper throws TurnStopped once the turn is stopped. */
function createIo(turn) {
  const factor = SPEED_FACTOR[turn.speed] ?? 1
  const assertLive = () => {
    if (turn.stopRequested) throw new TurnStopped('explicit-abort')
    if (!turn.res || turn.res.destroyed || turn.res.writableEnded) throw new TurnStopped('client-closed')
  }
  const sleep = async (ms) => {
    assertLive()
    const scaled = Math.round(ms * factor)
    if (scaled > 0) await new Promise((resolve) => setTimeout(resolve, scaled))
    assertLive()
  }
  const emit = (type, payload, scope) => {
    assertLive()
    return writeFrame(turn, type, payload, scope)
  }
  const streamText = async (text, channel, { scope, delayMs = 45, wordsPerChunk = 2 } = {}) => {
    for (const chunk of splitChunks(text, wordsPerChunk)) {
      const mainAssistant = channel === 'assistant' && !scope
      const payload = { channel, text: chunk }
      if (mainAssistant) payload.textOffset = turn.textChars
      emit('text', payload, scope)
      if (mainAssistant) turn.textChars += chunk.length
      await sleep(delayMs)
    }
  }
  const newId = (prefix) => {
    turn.idCounter += 1
    return `mock-${prefix}-${turn.streamId.slice(0, 8)}-${turn.idCounter}`
  }
  return {
    newId,
    emit,
    sleep,
    say: (text, opts) => streamText(text, 'assistant', opts),
    think: (text, opts) => streamText(text, 'thinking', { delayMs: 35, ...opts }),

    /** A worker-executed tool: generating call, streamed args, final call, result. Sim only displays it. */
    async goTool({ name, args = {}, output, success = true, error, scope, runMs = 600 }) {
      const toolCallId = newId(name)
      const base = { toolCallId, toolName: name, executor: 'go', mode: 'sync' }
      emit('tool', { ...base, phase: 'call', status: 'generating', partial: true }, scope)
      const argText = JSON.stringify(args)
      const half = Math.ceil(argText.length / 2)
      for (const delta of [argText.slice(0, half), argText.slice(half)]) {
        await sleep(60)
        emit('tool', { ...base, phase: 'args_delta', argumentsDelta: delta }, scope)
      }
      emit('tool', { ...base, phase: 'call', status: 'executing', arguments: args }, scope)
      await sleep(runMs)
      emit(
        'tool',
        {
          ...base,
          phase: 'result',
          success,
          status: success ? 'success' : 'error',
          ...(output !== undefined ? { output } : {}),
          ...(error ? { error } : {}),
        },
        scope
      )
      await sleep(100)
      return toolCallId
    },

    /** A sim-executed tool: only the call frame. Follow with `pause([id])`; Sim runs it and resumes. */
    simTool(name, args = {}, extra = {}) {
      const toolCallId = newId(name)
      emit('tool', {
        phase: 'call',
        toolCallId,
        toolName: name,
        executor: 'sim',
        mode: 'async',
        arguments: args,
        ...extra,
      })
      return toolCallId
    },

    pause(pendingToolCallIds) {
      emit('run', {
        kind: 'checkpoint_pause',
        checkpointId: randomUUID(),
        executionId: randomUUID(),
        runId: randomUUID(),
        pendingToolCallIds,
      })
      turn.state = 'parked'
    },

    async span(scope, body, { name } = {}) {
      emit(
        'span',
        {
          kind: 'subagent',
          event: 'start',
          agent: scope.agentId,
          data: { tool_call_id: scope.parentToolCallId, ...(name ? { name } : {}) },
        },
        scope
      )
      await sleep(100)
      await body()
      emit('span', { kind: 'subagent', event: 'end', agent: scope.agentId, data: {} }, scope)
      await sleep(100)
    },

    complete() {
      emit('complete', {
        status: 'complete',
        textLength: turn.textChars,
        usage: { input_tokens: 1200, output_tokens: Math.max(1, Math.round(turn.textChars / 4)) },
      })
      turn.state = 'done'
    },

    error(payload) {
      emit('error', payload)
      turn.state = 'done'
    },

    /** Ends the body without a terminal frame (simulates a dropped connection). */
    drop() {
      turn.state = 'dropped'
    },
  }
}

/** Runs one leg (initial or resume) on `res`. */
async function runLeg(turn, res, legFn, label) {
  turn.res = res
  turn.state = 'streaming'
  res.writeHead(200, SSE_HEADERS)
  res.flushHeaders?.()
  const keepalive = setInterval(() => {
    if (!res.writableEnded) res.write(': keepalive\n\n')
  }, KEEPALIVE_MS)
  const startedFrames = turn.frames.length
  let outcome = 'ended'
  try {
    const result = await legFn(createIo(turn))
    if (turn.state === 'parked') {
      turn.resume = result?.resume ?? null
      outcome = 'parked'
    } else if (turn.state === 'dropped') {
      outcome = 'dropped'
    } else if (turn.state === 'done') {
      outcome = turn.frames.at(-1)?.type === 'error' ? 'error' : 'complete'
    } else {
      outcome = 'no-terminal'
    }
  } catch (error) {
    if (error instanceof TurnStopped) {
      turn.state = 'stopped'
      outcome = `stopped:${error.reason}`
    } else {
      outcome = `crashed:${error?.message ?? error}`
      turn.state = 'done'
      if (!res.writableEnded) writeFrame(turn, 'error', { message: `Mock scenario crashed: ${error?.message}` })
    }
  } finally {
    clearInterval(keepalive)
    if (!res.writableEnded) res.end()
    if (turn.state !== 'parked') {
      for (const sub of turn.subscribers) if (!sub.writableEnded) sub.end()
      turn.subscribers.clear()
    }
    log({
      event: 'leg_end',
      leg: label,
      streamId: turn.streamId,
      scenario: turn.scenario,
      outcome,
      frames: turn.frames.length - startedFrames,
      textChars: turn.textChars,
    })
  }
}

async function handleTurn(req, res, body, route) {
  const messageId = typeof body?.messageId === 'string' ? body.messageId : null
  let turn = messageId ? turns.get(messageId) : undefined
  if (!turn) {
    turn = newTurn(body, route)
    rememberTurn(turn)
  } else {
    // Same messageId again: Sim re-attaches (retry after 5xx / dropped body / recovery).
    // Re-send the response from the start; text offsets let Sim drop what it already has.
    turn.seq = 0
    turn.textChars = 0
    turn.idCounter = 0
    turn.frames = []
    turn.stopRequested = false
  }
  turn.attempt += 1
  const def = scenarioDef(turn)
  log({ event: 'turn', streamId: turn.streamId, scenario: turn.scenario, attempt: turn.attempt, speed: turn.speed })

  const httpFailure = def.http?.(turn)
  if (httpFailure) {
    sendJson(res, httpFailure.status, httpFailure.body)
    return httpFailure.status
  }
  const run = def.run
  await runLeg(turn, res, async (io) => {
    io.emit('session', { kind: 'start', data: { responseId: turn.requestId } })
    return run(io, turn)
  }, `initial#${turn.attempt}`)
  return 200
}

async function handleResume(req, res, body) {
  const streamId = typeof body?.streamId === 'string' ? body.streamId : null
  let turn = streamId ? turns.get(streamId) : undefined
  if (!turn) {
    const parked = [...turns.values()].filter((t) => t.state === 'parked')
    if (parked.length === 1) turn = parked[0]
  }
  if (!turn || !turn.resume) {
    sendJson(res, 404, { error: 'Run not found' })
    return 404
  }
  if (typeof body?.receivedTextChars === 'number') turn.textChars = body.receivedTextChars
  const results = Array.isArray(body?.results) ? body.results : []
  const resume = turn.resume
  turn.resume = null
  turn.stopRequested = false
  await runLeg(turn, res, (io) => resume(io, results, turn), 'resume')
  return 200
}

async function handleTitle(res, body) {
  const message = typeof body?.message === 'string' ? body.message : ''
  const { scenario, speed } = parseDirectives(message)
  const def = SCENARIOS[scenario]
  const factor = SPEED_FACTOR[speed ?? DEFAULT_SPEED] ?? 1
  const delay = Math.round((def?.title?.delayMs ?? 800) * factor)
  if (delay > 0) await new Promise((resolve) => setTimeout(resolve, delay))
  if (def?.title?.fail) {
    sendJson(res, 500, { error: 'Title generation failed (mock)' })
    return 500
  }
  sendJson(res, 200, { title: titleFor(message) })
  return 200
}

function handleExplicitAbort(res, body) {
  const turn = typeof body?.messageId === 'string' ? turns.get(body.messageId) : undefined
  if (turn) {
    turn.stopRequested = true
    if (turn.state === 'parked') {
      turn.state = 'stopped'
      turn.resume = null
    }
  }
  sendJson(res, 200, { settled: true })
  return 200
}

function handleReplay(req, res, body) {
  const turn = typeof body?.streamId === 'string' ? turns.get(body.streamId) : undefined
  if (!turn || turn.frames.length === 0) {
    sendJson(res, 404, { error: 'Run not found' })
    return 404
  }
  res.writeHead(200, SSE_HEADERS)
  for (const frame of turn.frames) res.write(`data: ${JSON.stringify(frame)}\n\n`)
  if (turn.state === 'streaming') {
    turn.subscribers.add(res)
    req.on('close', () => turn.subscribers.delete(res))
    return 200
  }
  if (turn.state === 'parked') {
    res.write(
      `data: ${JSON.stringify({
        v: 1,
        type: 'run',
        seq: turn.seq + 1,
        ts: new Date().toISOString(),
        stream: { streamId: turn.streamId, ...(turn.chatId ? { chatId: turn.chatId } : {}) },
        payload: { kind: 'replay_end', reason: 'parked', textLength: turn.textChars },
      })}\n\n`
    )
  }
  res.end()
  return 200
}

function handlePoll(req, res) {
  let done = false
  const timer = setTimeout(() => {
    done = true
    if (!res.writableEnded) sendJson(res, 200, { requests: [] })
  }, POLL_HOLD_MS)
  req.on('close', () => {
    if (!done) clearTimeout(timer)
  })
  return 200
}

const server = http.createServer(async (req, res) => {
  const started = Date.now()
  const url = new URL(req.url ?? '/', 'http://mock')
  const path = url.pathname
  const { body } = await readBody(req)
  const apiKey = req.headers['x-api-key']
  const quiet = path === '/api/sim-transport/poll'
  if (!quiet) {
    log({
      event: 'request',
      method: req.method,
      path,
      apiKey: apiKey ? (API_KEY ? (apiKey === API_KEY ? 'match' : 'mismatch') : 'present') : 'absent',
      simRequestId: req.headers['x-sim-request-id'],
      clientVersion: req.headers['x-client-version'],
      sourceEnv: req.headers['x-sim-source-env'],
      body: summarizeBody(path, body),
    })
  }
  let status = 200
  try {
    if (API_KEY && apiKey !== API_KEY && req.method === 'POST') {
      status = 401
      sendJson(res, 401, { error: 'Invalid API key' })
    } else if (req.method === 'GET' && (path === '/healthz' || path === '/health' || path === '/')) {
      sendJson(res, 200, { ok: true, service: 'mock-copilot', scenarios: Object.keys(SCENARIOS) })
    } else if (req.method !== 'POST') {
      status = 405
      sendJson(res, 405, { error: 'Method not allowed' })
    } else if (path === '/api/mothership' || path === '/api/copilot' || path === '/api/mothership/execute') {
      status = await handleTurn(req, res, body, path)
    } else if (path === '/api/tools/resume') {
      status = await handleResume(req, res, body)
    } else if (path === '/api/generate-chat-title') {
      status = await handleTitle(res, body)
    } else if (path === '/api/streams/explicit-abort') {
      status = handleExplicitAbort(res, body)
    } else if (path === '/api/streams/steer') {
      sendJson(res, 200, { queued: true })
    } else if (path === '/api/streams/replay') {
      status = handleReplay(req, res, body)
    } else if (path === '/api/sim-transport/poll') {
      status = handlePoll(req, res)
    } else if (path === '/api/sim-transport/reply') {
      sendJson(res, 200, {})
    } else if (path === '/api/validate-key/get-api-keys') {
      sendJson(res, 200, [])
    } else if (path === '/api/validate-key/generate') {
      sendJson(res, 200, { id: randomUUID(), apiKey: `mock-${randomUUID()}` })
    } else if (path.startsWith('/api/validate-key/')) {
      sendJson(res, 200, { success: true })
    } else if (path === '/api/tasks/status') {
      status = 404
      sendJson(res, 404, { error: 'Task not found' })
    } else {
      status = 404
      sendJson(res, 404, { error: `Not implemented by the mock: ${path}` })
    }
  } catch (error) {
    status = 500
    if (!res.headersSent) sendJson(res, 500, { error: String(error?.message ?? error) })
    else if (!res.writableEnded) res.end()
  }
  if (!quiet) log({ event: 'response', method: req.method, path, status, ms: Date.now() - started })
})

server.listen(PORT, HOST, () => {
  log({ event: 'listening', host: HOST, port: PORT, speed: DEFAULT_SPEED, apiKeyRequired: Boolean(API_KEY) })
})
