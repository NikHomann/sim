// Scripted scenarios for the mock copilot agent service.
//
// Each scenario is `async (io, turn) => void | { resume }`. A scenario that hands a
// sim-executed tool to Sim emits the call frame, calls `io.pause([...ids])` and returns
// `{ resume: async (io, results, turn) => ... }`; the mock ends the leg there and runs
// `resume` when Sim POSTs /api/tools/resume with the tool results.
//
// `io` helpers (see server.mjs `createIo`): say, think, emit, sleep, goTool, simTool,
// pause, span, complete, error. Every helper throws when the turn was stopped, so a
// script never has to check for aborts itself.

export const PLAIN_ANSWER = [
  '## Mock answer',
  '',
  'This reply comes from the **mock agent service**. It is deterministic, so a test can assert on it. It exercises the markdown renderer:',
  '',
  '| Scenario | What it tests | Frames |',
  '| --- | --- | --- |',
  '| `plain` | Markdown, a table and a code block | `text` |',
  '| `thinking` | A reasoning block before the answer | `text` (thinking) |',
  '| `tool` | A server tool round trip | `tool`, `run` |',
  '',
  '```dart',
  'void main() {',
  "  final greeting = 'Hello from the mock';",
  '  for (var i = 0; i < 3; i++) {',
  "    print('\$greeting #\$i');",
  '  }',
  '}',
  '```',
  '',
  '- Inline `code` and *emphasis*',
  '- A [link](https://www.sim.ai)',
  '',
  'Send `#scenario:list` to see every scenario.',
].join('\n')

function longAnswer() {
  const parts = ['# A long answer', '', 'This answer is long on purpose, so a test can press Stop while it streams.', '']
  for (let i = 1; i <= 60; i++) {
    parts.push(
      `${i}. Paragraph ${i} of 60. The mock keeps writing steady, predictable text so the stop button, the partial message and the persisted transcript can be checked against a known prefix.`
    )
  }
  parts.push('', 'End of the long answer.')
  return parts.join('\n')
}

function json(value, max = 800) {
  const text = JSON.stringify(value, null, 2) ?? 'undefined'
  return text.length > max ? `${text.slice(0, max)}\n…` : text
}

function describeResults(results) {
  if (!Array.isArray(results) || results.length === 0) return 'Sim sent no tool results.'
  return results
    .map((r) => {
      const status = r.success ? 'succeeded' : 'failed'
      return `- \`${r.name || 'tool'}\` (\`${r.callId}\`) ${status}. Result data:\n\n\`\`\`json\n${json(r.data)}\n\`\`\``
    })
    .join('\n\n')
}

function isSkipped(result) {
  return Boolean(result?.data && typeof result.data === 'object' && result.data.skipped === true)
}

export const SCENARIOS = {
  plain: {
    description: 'Markdown answer with a table and a code block, streamed in small chunks (default).',
    async run(io) {
      await io.say(PLAIN_ANSWER)
      io.complete()
    },
  },

  thinking: {
    description: 'Reasoning on the thinking channel, then the answer.',
    async run(io) {
      await io.think(
        'The user wants a short explanation. I will first list the facts, then check the arithmetic: 6 × 7 = 42. That matches. Now I will write the answer.'
      )
      await io.sleep(300)
      await io.say('After thinking it over: **6 × 7 = 42**.\n\nThe thinking block above should render collapsed above this text.')
      io.complete()
    },
  },

  tool: {
    description:
      'Sim-executed server tool round trip: `list_workspaces` call, checkpoint pause, Sim runs it and POSTs /api/tools/resume, then the answer quotes the result.',
    async run(io) {
      await io.say('Let me look up your workspaces.')
      const id = io.simTool('list_workspaces', {})
      io.pause([id])
      return {
        async resume(io2, results) {
          await io2.say(`\n\nThe tool returned:\n\n${describeResults(results)}`)
          io2.complete()
        },
      }
    },
  },

  'tool-go': {
    description: 'Worker-executed tool (`web_search`, executor go): call, streamed arguments, success result. No Sim execution.',
    async run(io) {
      await io.say('Searching the web for you.')
      await io.goTool({
        name: 'web_search',
        args: { query: 'sim studio mock agent' },
        output: {
          results: [
            { title: 'Sim', url: 'https://www.sim.ai', snippet: 'Build AI agent workflows.' },
            { title: 'Docs', url: 'https://docs.sim.ai', snippet: 'Documentation.' },
          ],
        },
      })
      await io.say('\n\nI found **2** results: [Sim](https://www.sim.ai) and [Docs](https://docs.sim.ai).')
      io.complete()
    },
  },

  'tool-error': {
    description: 'Worker-executed tool (`web_fetch`) that fails with an error result; the answer continues.',
    async run(io) {
      await io.say('Fetching the page.')
      await io.goTool({
        name: 'web_fetch',
        args: { url: 'https://example.invalid/missing' },
        success: false,
        error: 'HTTP 404 from https://example.invalid/missing (mock)',
        output: { error: 'HTTP 404 from https://example.invalid/missing (mock)' },
      })
      await io.say('\n\nThe page could not be fetched (404). I will continue without it.')
      io.complete()
    },
  },

  'tool-error-sim': {
    description:
      'Sim-executed tool with invalid arguments (`list_workspaces` with limit 0): Sim rejects it and resumes with success:false.',
    async run(io) {
      await io.say('Calling a server tool with arguments it will reject.')
      const id = io.simTool('list_workspaces', { limit: 0 })
      io.pause([id])
      return {
        async resume(io2, results) {
          await io2.say(`\n\nSim reported:\n\n${describeResults(results)}`)
          io2.complete()
        },
      }
    },
  },

  permission: {
    description:
      'Permission-gated tool: `list_workspaces` call frame with status awaiting_approval. Needs COPILOT_TOOL_PERMISSIONS_ENABLED=true on the Sim server, otherwise Sim runs it without asking.',
    async run(io) {
      await io.say('I need your permission to list your workspaces.')
      const id = io.simTool('list_workspaces', {}, { status: 'awaiting_approval' })
      io.pause([id])
      return {
        async resume(io2, results) {
          const skipped = results.some(isSkipped)
          await io2.say(
            skipped
              ? '\n\nYou skipped the tool, so nothing was run.'
              : `\n\nThanks, the tool ran:\n\n${describeResults(results)}`
          )
          io2.complete()
        },
      }
    },
  },

  subagent: {
    description:
      'Agent group: a `search` subagent span with its own thinking, text and two nested worker tools (one fails), then the parent tool result and a summary.',
    async run(io) {
      await io.say('I will hand this to a search agent.')
      const parentId = io.newId('search')
      const args = { task: 'Find the Sim docs page about copilot' }
      io.emit('tool', {
        phase: 'call',
        toolCallId: parentId,
        toolName: 'search',
        executor: 'go',
        mode: 'async',
        status: 'executing',
        arguments: args,
      })
      const scope = { lane: 'subagent', agentId: 'search', parentToolCallId: parentId, spanId: io.newId('span') }
      await io.sleep(150)
      await io.span(scope, async () => {
        await io.think('Two sources look promising. I will search, then fetch the best hit.', { scope })
        await io.say('Searching the docs.', { scope })
        await io.goTool({
          name: 'web_search',
          args: { query: 'sim copilot docs' },
          output: { results: [{ title: 'Copilot', url: 'https://docs.sim.ai/copilot' }] },
          scope,
        })
        await io.goTool({
          name: 'web_fetch',
          args: { url: 'https://docs.sim.ai/copilot/old' },
          success: false,
          error: 'HTTP 410 Gone (mock)',
          output: { error: 'HTTP 410 Gone (mock)' },
          scope,
        })
        await io.goTool({
          name: 'web_fetch',
          args: { url: 'https://docs.sim.ai/copilot' },
          output: { title: 'Copilot', content: 'Copilot is the in-app agent.' },
          scope,
        })
        await io.say('Found it: the Copilot page at docs.sim.ai/copilot.', { scope })
      }, { name: 'Search agent' })
      io.emit('tool', {
        phase: 'result',
        toolCallId: parentId,
        toolName: 'search',
        executor: 'go',
        mode: 'async',
        success: true,
        output: { summary: 'Copilot docs: https://docs.sim.ai/copilot' },
      })
      await io.say('\n\nThe search agent found the page: [Copilot docs](https://docs.sim.ai/copilot).')
      io.complete()
    },
  },

  error: {
    description: 'Agent-side error: some text, then an `error` frame (provider overloaded) and the stream ends.',
    async run(io) {
      await io.say('Starting the answer, but the provider will fail')
      await io.sleep(300)
      io.error({
        message: 'The model provider is overloaded (mock). Please try again.',
        error: 'provider_overloaded',
        displayMessage: 'The model provider is overloaded (mock). Please try again.',
        code: 'provider_overloaded',
        provider: 'mock',
      })
    },
  },

  long: {
    description: 'Long answer (60 numbered paragraphs, about 64 s at MOCK_SPEED=real, 6.4 s at fast) for stop-mid-stream tests.',
    async run(io) {
      await io.say(longAnswer(), { delayMs: 70 })
      io.complete()
    },
  },

  title: {
    description: 'Short answer; the title endpoint answers after 4 s (real) so the title arrives late. Title: "Mock title scenario".',
    title: { text: 'Mock title scenario', delayMs: 4000 },
    async run(io) {
      await io.say('A short answer. Watch the chat title change from "New chat" a moment later.')
      io.complete()
    },
  },

  'title-fail': {
    description: 'Short answer; /api/generate-chat-title answers 500, so the chat stays untitled.',
    title: { fail: true },
    async run(io) {
      await io.say('A short answer. The title request fails, so the chat keeps its placeholder title.')
      io.complete()
    },
  },

  drop: {
    description:
      'First attempt streams some text and closes without a terminal frame; Sim re-attaches with the same messageId and the mock re-sends the whole response (offsets let Sim drop the duplicate prefix).',
    async run(io, turn) {
      if (turn.attempt === 1) {
        await io.say('This text arrives, then the connection drops')
        io.drop()
        return
      }
      await io.say('This text arrives, then the connection drops… and the re-attach completes the answer.')
      io.complete()
    },
  },

  'http-500': {
    description: 'Every attempt answers HTTP 500 JSON. Sim retries up to 3 times within 30 s, then shows "The agent service is temporarily unavailable".',
    http: () => ({ status: 500, body: { error: 'Internal error (mock)' } }),
  },

  flaky: {
    description: 'First attempt answers HTTP 503 JSON, the retry streams the plain answer.',
    http: (turn) => (turn.attempt === 1 ? { status: 503, body: { error: 'Temporarily unavailable (mock)' } } : null),
    async run(io) {
      await io.say('This answer arrived on the retry after a 503.')
      io.complete()
    },
  },

  'http-400': {
    description: 'HTTP 400 with a user-facing reason. Not retried; the reason is shown.',
    http: () => ({ status: 400, body: { error: 'The mock agent rejected this request.' } }),
  },

  'http-402': {
    description: 'HTTP 402: Sim shows its usage-limit card (synthetic usage_upgrade text) and completes.',
    http: () => ({ status: 402, body: { error: 'Usage limit reached (mock)' } }),
  },

  list: {
    description: 'Lists every scenario.',
    async run(io) {
      const rows = Object.entries(SCENARIOS)
        .map(([name, s]) => `| \`#scenario:${name}\` | ${s.description.replace(/\|/g, '\\|')} |`)
        .join('\n')
      await io.say(`Available mock scenarios:\n\n| Message | Behaviour |\n| --- | --- |\n${rows}`, { delayMs: 10 })
      io.complete()
    },
  },
}

/** `#scenario:<name>` anywhere at the start of the message, plus an optional `speed=<fast|real|instant>`. */
export function parseDirectives(message) {
  const text = typeof message === 'string' ? message : ''
  const match = /^\s*#scenario:([A-Za-z0-9_-]+)/.exec(text)
  const speedMatch = /\bspeed=(fast|real|instant)\b/.exec(text)
  const requested = match ? match[1].toLowerCase() : null
  const scenario = requested && SCENARIOS[requested] ? requested : requested ? 'unknown' : 'plain'
  return { scenario, requested, speed: speedMatch ? speedMatch[1] : null }
}

export const UNKNOWN_SCENARIO = {
  description: 'Fallback for an unrecognised #scenario name.',
  async run(io, turn) {
    await io.say(
      `Unknown mock scenario \`${turn.requestedScenario}\`. Known: ${Object.keys(SCENARIOS)
        .map((n) => `\`${n}\``)
        .join(', ')}.`,
      { delayMs: 10 }
    )
    io.complete()
  },
}

export function titleFor(message) {
  const { scenario, requested } = parseDirectives(message)
  const def = SCENARIOS[scenario]
  if (def?.title?.text) return def.title.text
  if (requested) return `Mock: ${requested}`
  const words = String(message ?? '')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .slice(0, 6)
    .join(' ')
  return words ? `Mock: ${words}`.slice(0, 60) : 'Mock chat'
}
