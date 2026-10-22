# Chat messages (Home / chat transcript rendering)
Upstream: `apps/sim/app/workspace/[workspaceId]/home/components/{message-content,mothership-chat,user-message-content,chat-message-attachments,context-mention-icon,chat-context-kind-registry,knowledge-search-results}/**`, `apps/sim/app/workspace/[workspaceId]/components/message-actions/**`, `apps/sim/components/ui/{activity-status,shimmer-text,thinking-loader}*`, `apps/sim/hooks/{use-smooth-text,use-auto-scroll}.ts`, commit `27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c`
Phase: 1.5

Paths are relative to `apps/sim/` unless prefixed `packages/`. `MC/` = `app/workspace/[workspaceId]/home/components/message-content/`, `AG/` = `MC/components/agent-group/`, `CC/` = `MC/components/chat-content/`, `MSC/` = `app/workspace/[workspaceId]/home/components/mothership-chat/`.

**Seeded first.** The "E2E conversation" seed (`apps/flutter/tools/seed/lib/src/fixtures.dart:710-760`) stores two `copilot_messages` with **no `contentBlocks`**: user `Summarise the seeded workspace for me.` and an assistant message whose `content` is a paragraph, a 3-row GFM table and a fenced `json` block. A block-less assistant message renders through the `fallbackContent` path as exactly one text segment (`MC/message-content.tsx:1019-1027`), so the first parity target is: user bubble → `ChatContent` (paragraph, `MarkdownTable`, highlighted code block) → settled actions row. §"Seeded rendering" gives the expected box stack; everything else in this spec is reachable only with a live stream (Phase 1.5 L5) or fixtures.

**Scope correction to the brief.** Reasoning is **never rendered**: `thinking`/`subagent_thinking` blocks are dropped by the parser (`MC/message-content.tsx:404-407`) and `<thinking>` tags inside text are skipped (`CC/chat-content.tsx:752-756`, `special-tags.tsx:1824-1825`). There is no expandable thinking panel. What the user sees while the model thinks is the turn-level **Thinking shimmer** (`chat.message.thinking`). Knowledge search results (`knowledge-search-results/**`) render in the resources panel (`search-resource-content.tsx`), not in the transcript; they share `SourceCard` with the sources popover and are mapped here only for `SourceCard`.

## Files
| File | Lines | Role |
|---|---|---|
| `MSC/mothership-chat.tsx` | 998 | Transcript: layout constants (149-177), `TaskNotificationRow` (194-211), `UserMessageRow` (213-235), `AssistantMessageRow` (256-355), virtualizer (688-706), scroll pinning (730-757, 822-853), root/scroll container/rows (865-962), footer composer (964-995) |
| `MSC/components/mothership-chat-skeleton/mothership-chat-skeleton.tsx` | 51 | Loading skeleton |
| `MSC/message-actions-visibility.ts` | 22 | `shouldShowAssistantMessageActions` |
| `MSC/copyable-markdown.ts` | 101 | `prepareContentForCopy` (chips → portable markdown links) |
| `MSC/use-chat-find.ts`, `chat-find-text.ts` | 309, 33 | Ctrl+F find-in-chat (highlight via CSS Highlight API) — out of first parity slice |
| `MSC/sizer-floor.ts` | 64 | Sizer min-height floor during send |
| `MC/message-content.tsx` | 1241 | Block → segment parser (`parseBlocksWithSpanTree` 293-523, `groupByActivity` 561-603, `parseBlocks` 605-626), `MessageContent` (976-1239): segment stack, tail slot (shimmer / actions / stopped) |
| `MC/utils.ts` | 245 | `TOOL_ICONS` (37-194), `getAgentIcon`/`getToolIcon` (196-202), `deriveMessagePhase` (204-217), `resolveToolDisplayState` (221-234), `isToolDone` (236-245) |
| `MC/resolve-citations.ts`, `message-sources.ts`, `sources-by-url.ts` | 57, 35, 16 | Citation resolution, footer source list |
| `CC/chat-content.tsx` | 826 | Markdown renderer: Streamdown config, `PROSE_CLASSES` (90-103), stream animation (118-141), `MarkdownTable` (284-307), `MARKDOWN_COMPONENTS` (309-509), reveal/drain lifecycle (561-698), inline/special grouping (718-823) |
| `CC/chat-sanitize.ts` | 129 | `sanitizeChatDisplayContent`: unwraps chips inside inline code, keeps fences literal, strips hidden internal refs |
| `CC/highlighted-lines.tsx` | 47 | Prism HTML split per line |
| `CC/external-link.tsx` | 39 | External link with favicon + hover preview |
| `CC/remark-plain-text.ts` | 39 | Fast path for one plain paragraph |
| `MC/components/source-link.ts` | 40 | `PROSE_LINK_CLASS` (26-27), desktop browser-panel diversion |
| `MC/components/source-chip/{source-chip,source-icon}.tsx` | 56, 77 | Inline citation chip |
| `MC/components/source-card/source-card.tsx` | 200 | Source row (dense in popover, full in search results) |
| `MC/components/source-preview.tsx`, `source-history-context.tsx` | 154, 89 | Hover preview card, navigation |
| `MC/components/message-sources/message-sources.tsx` | 93 | "N sources" button + popover in the actions row |
| `MC/components/options/options.tsx` | 27 | `options` block → round border chips |
| `MC/components/special-tags/special-tags.tsx` | 3519 | Tag parser (`parseSpecialTags` 1573) and renderers: `SpecialTags` switch (1812-1859), `OptionsDisplay` "Suggested follow-ups" (1866-1926), `WorkspaceResourceDisplay` (1963-2053), credential family (2169-3437), `MothershipErrorDisplay` (3439-3443), `UsageUpgradeDisplay` (3445-3519) |
| `MC/components/special-tags/pending-tag-indicator.tsx` | 17 | Turn shimmer (ThinkingLoader + label) |
| `MC/components/question/question.tsx` | 476 | `<question>` card (single/multi select, stepper, free text, recap) |
| `MC/components/interaction-card.tsx` | 135 | Card chrome shared by question and credential cards |
| `MC/components/resource-mention.tsx` | 28 | Inline resource chip (ChipTag mono) |
| `MC/components/watch-activity/watch-activity.tsx` | 59 | `task` (watch) row |
| `AG/agent-group.tsx`, `agent-group-view.tsx` | 23, 364 | Agent/subagent lane |
| `AG/main-agent-activity.tsx`, `tool-activity-group.tsx`, `tool-call-item.tsx` | 66, 286, 185 | Main-lane runs, grouped tool header, tool row |
| `AG/activity-stream.tsx`, `activity-disclosure.tsx`, `activity-viewport.tsx` | 81, 72, 102 | Paced header, chevron disclosure, 110 px auto-following viewport |
| `AG/tool-permission-card.tsx` | 231 | Allow / Don't ask again / Skip |
| `AG/inline-markdown.tsx` | 56 | Narration-row inline markdown |
| `AG/lane-activity.ts`, `agent-group-content.ts`, `tool-call-title.ts`, `tool-interactions.ts`, `search-activity-*.ts(x)`, `browser-agent-icon.tsx` | 245, 74, 106, 24, 14+87, 140 | Liveness, titles, search result previews, browser icon |
| `app/workspace/[workspaceId]/home/components/user-message-content/{user-message-content.tsx,utils.ts}` | 88, 104 | User bubble text + mention ranges |
| `.../home/components/chat-message-attachments/chat-message-attachments.tsx` | 72 | Attachment pills/thumbnails above the bubble |
| `.../home/components/context-mention-icon/context-mention-icon.tsx`, `chat-context-kind-registry/chat-context-kind-registry.tsx` | 18, 144 | Mention icon per context kind |
| `app/workspace/[workspaceId]/components/message-actions/message-actions.tsx` | 272 | Copy / Like / Dislike / Fork + feedback modal |
| `components/ui/activity-status.tsx` | 61 | Activity row (icon slot + OverflowText label + shimmer) |
| `components/ui/shimmer-text.tsx` + `.module.css` | 29 + 57 | Sweep shimmer |
| `components/ui/thinking-loader.tsx` + `.module.css` | 544 + 607 | Gooey SVG loader + phrase crossfade |
| `hooks/use-smooth-text.ts` | 278 | Paced word reveal |
| `hooks/use-auto-scroll.ts` | 263 | Sticky bottom-follow |
| `lib/core/utils/smooth-bottom-chase.ts` | — | Eased chase used by auto-scroll |
| `lib/mothership/tools/display.ts` | — | Tool titles; `getToolStatusDisplayTitle` (1796-1820) |
| emcn | — | `CopyCodeButton` (`components/code/copy-code-button.tsx`), Prism `languages`/`highlight` (`components/code/prism.ts`: markup, css, clike, javascript, python, json, bash, toml; chat adds typescript), token theme `components/code/code.css`, `Button` (ghost), `Chip`, `ChipTag`, `ChipModal*`, `Checkbox`, `Lightbox`, `Tooltip`, `Popover`, `DropdownMenu`, `Expandable` (Radix Collapsible, `animate-collapsible-*` 300 ms), `OverflowText`, `Skeleton`, `useScrollEdges` + `scrollFadeClass`/`scrollFadeXClass` (`components/scroll-fade/scroll-fade.module.css`), `useCopyToClipboard` (default reset 2000 ms), icons `Duplicate`, `Check`, `ThumbsUp`, `ThumbsDown`, `Split`, `BookOpen`, `CircleStop`, `ChevronDown`, `ArrowRight`, `ShieldCheck` |
| npm | — | `streamdown` 2.5.0 (`package.json:259`), `remark-gfm` 4.0.1, `prismjs` ^1.30, `@tailwindcss/typography` 0.5.20 (`prose` classes), `@tanstack/react-virtual` |

## Layout

### Fonts in this surface
The whole chat root carries `inter.className` (`MSC/mothership-chat.tsx:875`), and `ChatContent`, `UserMessageContent`, `MessageSources`' popover and `SourceCard` re-apply it. **All transcript text is Inter (variable)**; the composer is out of scope. Code (`font-mono`) = `var(--font-martian-mono, ui-monospace), SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace` (`globals.css:77-79`); Martian Mono is not loaded and Chromium on Windows does not resolve `ui-monospace`, so React renders **Consolas** on Windows and **Liberation Mono/DejaVu Sans Mono** in a Linux container (see Ambiguities). Letter-spacing: `.workspace-root` sets 0.02em (`globals.css:559-561`) but every chat text element resets it — prose and user text `tracking-[0]` (`CC/chat-content.tsx:92`, `user-message-content.tsx:12`), code `letter-spacing: normal` (`globals.css:572-576`). Activity rows, chips and actions are **not** reset and keep 0.02em.

### Transcript container (`mothership-view` layout, `MSC/mothership-chat.tsx:149-162`)
- Root `chat.root` (865-877): `relative flex h-full min-h-0 min-w-0 flex-col`, Inter. Below md it gets `mt-[var(--resource-header-controls-height)]`.
- Scroll container `chat.transcript` (895-900): `mt-[var(--workspace-content-title-bar-inset)]` (0 on web), `min-h-0 flex-1 overflow-y-auto overflow-x-hidden px-3 md:px-6 pt-4 pb-2 [overflow-anchor:none] [scrollbar-gutter:stable_both-edges]` → 24 px side padding at ≥768 (12 px below), 16 px top, 8 px bottom, scrollbar gutter reserved on **both** sides; plus `scrollFadeClass` with `overflowFadeSizeClass` (`--overflow-fade-size:16px`) → a 16 px mask band at the top/bottom edge only while content is hidden beyond it.
- Sizer `chat.transcript.column` (905-908): `relative mx-auto w-full max-w-chat` = max 704 px (`--container-chat: 44rem`, `globals.css:217`), height = virtualizer total size; rows are `absolute left-0 w-full` with `top = virtualItem.start` (913-927). Overscan 6 rows; estimates user 64 / assistant 280 (123-126). The last user row and the last row are always mounted (675-686).
- Footer (964-995): `shrink-0 px-3 md:px-[24px] pb-[max(12px,safe-area)] md:pb-[16px]`, inner `mx-auto max-w-chat` → composer column aligned with messages (composer spec is separate).
- `copilot-view` variant (163-176): px-3 pt-2 pb-4, no max width, row gap 16, user row pt-2, bubble px-3. Not used by Home; the editor copilot tab (Phase 3) reuses it.

### Rows
| Parity id | Classes (file:line) | Measured |
|---|---|---|
| `chat.message.user` | `flex flex-col items-end gap-[6px] pt-3` + `pb-6` (`MSC/mothership-chat.tsx:154,153,223`) | 12 px top, 24 px bottom; children right-aligned, 6 px between attachments and bubble |
| `chat.message.user.attachments` | `flex flex-wrap gap-[6px] justify-end max-w-[85%] md:max-w-[70%]` (`chat-message-attachments.tsx:24-29`; width 155) | Image/video thumbs 56×56 r8 (`:43,63`), video placeholder `--surface-5` with 18 px icon; file pill = `ChipTag mono` (20 px tall, r6, px-4, gap 3, `--surface-5`/dark `--surface-4`, 14/20 text) max 140 px with `OverflowText` (`:8-10`) |
| `chat.message.user.bubble` | `max-w-[85%] md:max-w-[70%] overflow-hidden rounded-[16px] bg-[var(--surface-5)] px-3.5 py-2` (157-158) | ≤ 70 % of the column (492.8 px at 704), radius 16, padding 14 × 8, fill `--surface-5` |
| `chat.message.user.text` | `<p>` `whitespace-pre-wrap [overflow-wrap:anywhere] text-base text-[var(--text-primary)] leading-[23px] tracking-[0] antialiased` (`user-message-content.tsx:11-12,54`) | Inter 15/23, weight 400, `--text-primary`; content `trim()`med; newlines preserved; one line → bubble 39 px tall |
| `chat.message.user.mention` | `ResourceMention` = `ChipTag mono` + `max-w-full align-middle` (`resource-mention.tsx:11`), icon 12 px `--text-icon` (`user-message-content.tsx:27-38`) | 20 px inline pill inside the text line |
| `chat.message.taskNotification` | `flex w-full justify-center` › `max-w-[85%] rounded-full border border-[var(--border)] bg-[var(--bg)] px-3 py-1 text-[12px] text-[var(--text-secondary)]`, prefix `font-medium text-primary mr-1.5` "Background task" (`MSC/mothership-chat.tsx:203-208`) | Only for `msg.origin === 'task'` user rows |
| `chat.message.assistant` | `group/msg` + `pb-6` (+`pb-4` more when it ends in a question/credential card) (`MSC/mothership-chat.tsx:159,324`) | 24 px bottom |
| `chat.message.assistant.segments` | `[&>:empty]:hidden [&>:has(~:not(:empty))]:mb-4` (`MC/message-content.tsx:1121-1127`) | 16 px between visible segments; 8 px (`mb-2`) between consecutive activity segments; 16 px after an agent group that ends in an interaction card |
| `chat.message.tail` | `mt-[10px] flex h-[36px] items-center` (`TAIL_REGION_CLASSES`, `MC/message-content.tsx:67`) | Fixed 46 px tail holding **either** the shimmer (streaming/revealing, last message) **or** the actions row (settled). Same extent so the swap never moves layout (1205-1236) |
| `chat.message.stopped` | `mt-[10px] flex items-center gap-[8px]` › `CircleStop size-[16px] text-[var(--text-icon)]` + `text-[14px] text-[var(--text-body)]` "Stopped by user" (1226-1233) | Then actions row in `mt-[10px]` (not the 36 px box) |

### Assistant content (`ChatContent`, `CC/chat-content.tsx`)
Root `chat.message.assistant.content`: `div.space-y-4` + Inter (782). Children are groups: consecutive text/inline chips merge into one **inline** markdown group (`div[data-chat-find-content]` with `PROSE_CLASSES` + `[&>:first-child]:mt-0 [&>:last-child]:mb-0`, 786-790, parity id `chat.markdown`); block special tags (`options`, `credential`, `question`, `usage_upgrade`, `mothership-error`) become sibling blocks (805-816) separated by 16 px (`space-y-4`).

Markdown pipeline: `Streamdown` with `defaultRemarkPlugins` (GFM: tables, strikethrough, task lists, autolink literals, footnotes) + `remarkPlainText`, `defaultRehypePlugins` (raw-HTML sanitize + link/image hardening) prefixed by `privateImageUrls` (rewrites inline chat file images to the authenticated image route) (85-88, 579-584). **No** math/KaTeX, **no** Mermaid, **no** Shiki: those are separate opt-in plugins in streamdown 2 and are not passed (verify, see Ambiguities). Highlighting is Prism via emcn.

`PROSE_CLASSES` (90-103) on Tailwind Typography `prose prose-base dark:prose-invert max-w-none antialiased break-words tracking-[0]`:

| Element | Parity id | Font / line-height | Colour | Spacing | Source |
|---|---|---|---|---|---|
| Paragraph | `chat.markdown.p` | Inter 15 / 25, 400 | `--text-primary` | prose-base margin 1.25em = 18.75 px top/bottom; first child mt 0, last mb 0 | `:95`, `:789` |
| Heading h1–h4 | `chat.markdown.h1`…`h4` | weight 600, tracking 0; sizes from prose-base on a 16 px root: h1 2.25em = 36 px (lh 1.111 = 40), h2 1.5em = 24 (lh 1.333 = 32), h3 1.25em = 20 (lh 1.6 = 32), h4 1em = 16 (lh 1.5 = 24) | `--text-primary` | mt 24, mb 12; first heading mt 0 | `:93-94` |
| Bold | `chat.markdown.strong` | 600 | `--text-primary` | — | `:99` |
| Italic | — | italic | `--text-primary` | — | `:484-486` |
| Strikethrough | — | line-through | `--text-tertiary` | — | `:487-489` |
| Link (plain/relative/footnote) | `chat.markdown.link` | inherits | `--brand-blue` (#3b6fe0 / #5b8def), no underline; focus-visible 2 px `--text-primary` outline | opens `_blank` | `:403-413`, `source-link.ts:26-27` |
| External http(s) link | `chat.markdown.link.external` | inherits | `--brand-blue`; leading favicon (`SourceIcon`, `mr-1 inline-flex align-middle`); hover shows `SourcePreview` card | `_blank`; desktop shell diverts plain clicks to the browser panel | `:392-395`, `external-link.tsx:19-38` |
| mailto | — | inherits | `--brand-blue` | same tab | `:396-401` |
| Inline code | `chat.markdown.inlineCode` | mono, prose-base `code` 0.875em of 15 = 13.125 px (verify), 400, not italic, no backticks | `--text-primary` on `--surface-5` (dark `--surface-4`) | `rounded` (4 px) `px-1 py-[1px]`, `whitespace-normal` | `:452-463`, `chrome.ts:2` |
| Unordered list | `chat.markdown.ul` | — | marker `--text-primary` | `my-4 list-disc pl-5` (16 / 20 px) | `:428` |
| Ordered list | `chat.markdown.ol` | — | marker `--text-primary` | `my-4 list-decimal pl-5` | `:431` |
| List item | `chat.markdown.li` | 15 / 25 | `--text-primary` | `my-1`; nested lists `my-1`; a lone `<p>` child renders inline | `:96-98`, `:446-450` |
| Task list | `chat.markdown.taskList` | — | — | `ul` `my-4 list-none space-y-2 ps-0`; `li` `list-none ps-6`; disabled emcn `Checkbox size=sm` at `-ms-6 mr-2 inline-flex align-middle` | `:416-426`, `:434-444`, `:471-481` |
| Blockquote | `chat.markdown.blockquote` | italic | `--text-primary` | `my-4 border-l-2 border-[var(--border)] pl-4`, inner p `my-2`, first/last 0 | `:464-469` |
| Horizontal rule | `chat.markdown.hr` | — | `--border` | `my-6` | `:101` |
| Image | `chat.markdown.image` | — | border `--border` | button `my-4 block max-w-full cursor-zoom-in rounded-lg`; img `max-h-[360px] max-w-full rounded-lg border object-contain`, lazy; click → emcn `Lightbox`; empty/unauthorised inline file src → not rendered | `:490-508`, `:539-559` |
| Table | `chat.table` | see below | | | `:284-333` |
| Fenced code | `chat.code` | see below | | | `:334-368` |
| Inline citation | `chat.source.chip` | 12 px (`text-caption`) | `--text-body` on `--surface-5`/dark `--surface-4`, hover `--surface-hover` | `inline-flex h-[20px] max-w-[160px] rounded-full px-1.5 gap-1 align-middle`; favicon/brand mark + `OverflowText` title | `:181-190`, `source-chip.tsx:30-55` |
| Inline workspace resource | `chat.workspaceResource.chip` | 14 / 20 | `--text-primary` on `--surface-5`/dark `--surface-4` | `ChipTag mono` 20 px, icon 12 px; clickable → opens resource in the panel | `:192-209`, `special-tags.tsx:1987-2053` |

**Table** (`MarkdownTable`, 284-307; cells 311-333):
- Wrapper `chat.table`: `not-prose my-4 w-full overflow-x-auto` + `scrollFadeXClass` + `[--overflow-fade-size:16px]`; while horizontally overflowing it gets `role=region aria-label="Scrollable table" tabIndex=0` and a 16 px left/right mask fade at the side(s) hiding content (`scroll-fade.module.css` `.rootX`).
- `<table class="min-w-full border-collapse [&_tbody_tr:last-child_td]:border-b-0">` → at least the column width; columns size to content; no outer border, no zebra, no header fill.
- `th` (`chat.table.th`): `whitespace-nowrap border-b border-[var(--border)] px-3 py-2 text-left font-semibold text-[var(--text-primary)] text-sm leading-6`, `textAlign` from the GFM alignment row → Inter 14/24, 600, 12 × 8 padding, 1 px bottom rule → 41 px header row.
- `td` (`chat.table.td`): same without `font-semibold`, 400 → 41 px rows, **last body row has no rule** → 40 px.
- `[&_strong]:font-semibold`. No copy/download controls (Streamdown's default table chrome is replaced).

**Code block** (`code` component, 334-368), parity ids `chat.code`, `chat.code.header`, `chat.code.lang`, `chat.code.copy`, `chat.code.body`:
- Container: `not-prose my-6 overflow-hidden rounded-lg border border-[var(--border)]` → 24 px vertical margin, 8 px radius, 1 px border.
- Header (`data-chat-find-ignore`): `flex items-center justify-between border-b border-[var(--border)] bg-[var(--surface-4)] px-4 py-2` (light #f5f5f5, dark #292929). Left: language label `text-xs text-[var(--text-tertiary)]` (Inter 11/16.5, the fence info word, `code` when absent). Right: `CopyCodeButton` = emcn `Button variant=ghost` (base `inline-flex items-center justify-center transition-colors rounded-[5px]`, `button.tsx:28,46`) overridden to `flex items-center gap-1 rounded px-1.5 py-0.5 text-xs -mr-2 text-[var(--text-tertiary)] hover:bg-[var(--surface-5)] hover:text-[var(--text-secondary)]` (`copy-code-button.tsx:20`, `CC/chat-content.tsx:356-359`), icon `Duplicate` 14 px → `Check` 14 px for 2000 ms after copy. Button 26 × 18, header height 18 + 16 + 1 = **35 px** (border-box incl. rule).
- Body: `code-editor-theme bg-[var(--surface-5)] dark:bg-[var(--code-bg)]` (light #f3f3f3, dark #1f1f1f) › `pre.m-0 overflow-x-auto whitespace-pre p-4 font-mono text-[var(--text-primary)] text-small leading-[21px]` → 16 px padding, mono 13/21, horizontal scroll (no wrap). Highlighted with Prism (`highlight()` 259-278: aliases js/ts/tsx/jsx/sh/shell/html/xml/yml/py, unknown language → JavaScript grammar, LRU 512) and split per line (`highlighted-lines.tsx:9-47`). The trailing newline is trimmed (`codeString.trimEnd()`, 347); copy copies the untrimmed text.
- Empty code (no text) → plain `pre.not-prose my-6 rounded-lg bg-[var(--surface-5)] dark:bg-[var(--code-bg)] p-4 font-mono text-small leading-[21px]` without header (339-345).
- Token colours (`packages/emcn/src/components/code/code.css`, light / dark): comment, prolog, doctype, cdata #16a34a / #6ec97d · punctuation, operator, entity, url, symbol #383838 / #d4d4d4 · property, attr-name, variable #0891b2 / #4fc3f7 · tag, boolean, number, constant #16a34a / #a5d6a7 · string, char, builtin, inserted #b45309 / #f39c6b · atrule, attr-value, keyword #2f55ff / #2fa1ff · function, class-name #ca8a04 / #fbbf24 · regex, important #e11d48 / #f87171 · deleted #dc2626 / (dark rule further down in the file) · default text `--text-primary`. Token backgrounds transparent (`code.css:155-157`).

### Seeded rendering (expected boxes, light, ≥768 px, column 704 px wide)
| Parity id | Expected |
|---|---|
| `chat.message.user` (row 0, top 0) | height 12 + 39 + 24 = **75**; bubble right-aligned, width = text width + 28 (single line "Summarise the seeded workspace for me." Inter 15) |
| `chat.message.assistant` (row 1, top 75) | content then tail then 24 px |
| `chat.markdown.p` | "Flutter E2E workspace", 25 px tall, y = 0 in the content |
| `chat.table` | y = 25 + 18.75 = 43.75 (paragraph bottom margin wins over the wrapper's 16); 2 columns "Resource"/"Count", rows Workflows/3, Tables/1 (50 rows), Knowledge bases/1 (2 documents); height 41 + 41 + 41 + 40 = **163**; width = column width (min-w-full) |
| `chat.code` | y = 43.75 + 163 + 24 = 230.75; header label `json`; body one line `{"workspace":"Flutter E2E workspace","seeded":true}`; height 1 + 35 + 53 + 1 = **90** |
| content height | 320.75 |
| `chat.message.tail` | y = 330.75, 36 tall; holds `chat.message.actions` with **4** buttons (copy, like, dislike, fork: `chatId`, `userQuery` and a persisted message id are all present) |
| row height | 320.75 + 46 + 24 = **390.75** |
| Prism tokens in the body | `{` `}` `,` punctuation #383838, `"workspace"`/`"seeded"` property #0891b2, `:` operator #383838, `"Flutter E2E workspace"` string #b45309, `true` boolean #16a34a (dark: #d4d4d4, #4fc3f7, #d4d4d4, #f39c6b, #a5d6a7) |
The seeded chat stores a `table` resource, so opening it may also open the resources panel (50 vw default, chat column min 480): parity captures must state the panel state, and the 704 px column only holds when the panel is closed or the viewport is wide enough.

### Actions row (`chat.message.actions`, `message-actions.tsx:167-233`; wrapper `MC/message-content.tsx:1105-1117`)
`flex items-center gap-0.5` (2 px). Buttons `flex size-[44px] md:size-[26px] items-center justify-center rounded-[6px] text-[var(--text-icon)] transition-colors hover:bg-[var(--surface-hover)]`, icons 14 px (`:30-32`). Order: Copy (`Duplicate` → `Check` for 1500 ms, tooltip "Copy message"/"Copied message"), Like (`ThumbsUp`, "Good response"), Dislike (`ThumbsDown`, "Bad response"), Fork (`Split` rotated 90°, "Fork in new chat"; `opacity-50 cursor-not-allowed` while pending), then `chat.message.sources` when the reply cited sources: `h-[26px] rounded-[6px] px-1.5 gap-1 text-caption text-[var(--text-icon)]` with `BookOpen` 14 px + count, open state `--surface-active` (`message-sources.tsx:22`). Tooltips `side=top`. Gating: copy when the orchestrator text is non-empty; like/dislike when `chatId && userQuery`; fork when owner + chatId + a non-live message id (`:159-165`). Row shows only at `phase === 'settled'` with content and no trailing active question/credential card (`message-actions-visibility.ts:15-22`).

### Turn shimmer (`chat.message.thinking`, `MC/message-content.tsx:1205-1219`, `pending-tag-indicator.tsx:11-16`)
In the tail slot of the **last** message while `phase !== 'settled'` and not stopped: `div[aria-hidden=!showShimmer]` › `transition-opacity duration-200 ease-out` 0 ↔ 1 › `animate-stream-fade-in py-2` › `ThinkingLoader size=20 startVariant='corners' label labelRatio=0.7`. Loader row: `inline-flex items-center gap-[8px] whitespace-nowrap` (gap = 0.4 × size, `thinking-loader.module.css:68-79`), 20 × 20 SVG, label Inter 14 px (0.7 × 20) 400 with the shimmer sweep. Label = `deriveThinkingLabel(blocks)` (930-942): "Returning" after `subagent_end`, "Dispatching" after a dispatch tool call, else "Thinking". Visible when (1097-1103): no segments yet, or a special tag is mid-stream, or (pending agent lanes with no text tail, or 1500 ms with no visible stream change — `STREAM_IDLE_DELAY_MS`, 59) and no text is painting and no lane owns the wait.

### Activity (agent groups and tool calls)
- Segment wrapper `div[data-agent-group][data-chat-activity]` (+`animate-stream-fade-in` while streaming) (`MC/message-content.tsx:1163-1183`).
- Lane `chat.agent.group`: `flex min-w-0 flex-col gap-2` (`AG/agent-group-view.tsx:313`). Main lane (`mothership`) shows only its tool runs (`AG/main-agent-activity.tsx:62-65`); a subagent lane shows a disclosure header.
- Activity row `chat.activity.status` (`components/ui/activity-status.tsx:6-44`): `span[role=status].flex.min-w-0.items-center.gap-2`; icon slot `flex size-[14px] shrink-0 items-center justify-center text-[var(--text-icon)]`; label `OverflowText` `text-[var(--text-tertiary)] text-base leading-5` (Inter 15/20, `--text-tertiary` #5c5c5c / #b3b3b3) → `--text-body` on header hover (`group-hover/agent`). Active → label painted by `ShimmerText` with `--shimmer-rest: --text-tertiary`.
- Text column `ActivityTextColumn` (`:54-61`): 14 px empty icon slot + 8 px gap, so nested content aligns with labels (22 px indent per level).
- Disclosure header `chat.activity.header` (`AG/activity-disclosure.tsx:32-58`): `flex w-full min-w-0 items-center gap-2 text-left`, `role=button tabIndex=0 aria-expanded` when collapsible; chevron `chat.activity.chevron` `ChevronDown size-[14px] text-[var(--text-icon)] transition-[transform,opacity] duration-150`, collapsed = `-rotate-90 opacity-0`, shown on header hover/focus. Body: emcn `Expandable` (height animation 300 ms cubic-bezier(.4,0,.2,1)) › `pt-2` › viewport.
- Viewport `chat.activity.viewport` (`AG/activity-viewport.tsx:89-97`): `pr-2 scrollbar-hide max-h-[110px] overflow-y-auto` + 16 px scroll-edge fade; unbounded (no max height) when it holds a pending interaction or search results.
- Tool row `chat.tool.call` (`AG/tool-call-item.tsx:81-184`): `ActivityStatus` with the block brand icon (`BrandIcon`, for `read` of a block / integration gateway) or `TOOL_ICONS[name]` (default `Wrench`; agent default `Blimp`), label from `useToolCallTitle`. Rows never shimmer; only the lane's live header does.
- Grouped run header (`AG/tool-activity-group.tsx:211-286`): one `ActivityStream` per consecutive run of main-lane tools; label in progress = active title (+ " · N stopped/skipped"), completed = model `completedTitle` when all succeeded, else summary ("Navigated, read pages, clicked elements · 1 stopped", max 3 actions, 26-93); collapsible when >1 call or search details; auto-expanded while live with search details.
- Subagent header (`AG/agent-group-view.tsx:287-300`): error → agent label; in progress → active tool label or "Thinking"; done → completed label or agent label. Icon: live with no status tool → `ThinkingLoader size=14 startVariant=corners` (203); browser lane → `BrowserAgentIcon`; else agent icon.
- Narration `chat.agent.narration` (`AG/agent-group-view.tsx:356-364`): `span.text-[var(--text-tertiary)].text-base.leading-5` with `renderInlineMarkdown` (bold 600, italic, bold-italic, `` `code` `` → `font-mono text-caption`, links → label only; `AG/inline-markdown.tsx:4-56`); live tail paced by `useSmoothText`.
- Lane error `chat.agent.error` (`:331-335`): `text-[var(--text-tertiary)] text-caption` in the text column.
- Permission `chat.tool.permission` (`AG/tool-permission-card.tsx:156-230`): row `flex items-center gap-2`, `ShieldCheck` 14 px, title `text-[var(--text-body)] text-sm truncate` (tooltip with tool name + args JSON ≤600 chars), chips `Allow` (primary), `Don't ask again ▾` (border, menu "For this chat" / "For every chat"), `Skip` (bare), `gap-1`; with >1 outstanding, the first card adds "N tools need permission" (`text-xs --text-tertiary`) + `Allow all` / `Skip all`. Disabled while submitting; 404 → "{title} — this request is no longer active" (`text-sm --text-tertiary`).
- Watch row `chat.watch` (`watch-activity.tsx:50-57`): `ActivityStatus` active while pending; labels "Waiting for workflow run: {name}", "Completed …", "Failed …", "Stopped watching …", "Watch expired for …", timers "Waiting until 9:47 AM" etc. (11-39).

### Other segments
- `options` block `chat.options` (`options.tsx:13-21`): `flex flex-wrap gap-2` of `Chip variant=border shape=round max-w-full` (30 px, `rounded-full`, raised ring `0 0 0 1px rgba(28,40,64,.08), 0 1px 3px rgba(28,40,64,.1)`, hover `--surface-hover`); click → submits the option id as a new user message (only on the last message).
- `<options>` tag `chat.followups` (`special-tags.tsx:1866-1926`): label "Suggested follow-ups" (`text-sm --text-body`), rows `flex items-center gap-2 border-[var(--border)] px-2 py-2` with `border-t` between, number in a 16 px slot (`text-sm --text-icon`), title `text-sm --text-body`, `ArrowRight` 16 px; hover `--surface-5`; on older messages the rows are disabled and the label becomes a collapse toggle with a chevron (150 ms rotate).
- Question `chat.question` (`question.tsx`, chrome `interaction-card.tsx:27-45`): card `rounded-2xl border border-[var(--border-1)] bg-[var(--white)] dark:bg-[var(--surface-4)] px-2.5 py-2` (16 px radius); title row `px-2 py-2` prompt `text-sm --text-primary`; actions: `‹ N of M ›` stepper (`text-sm --text-muted tabular-nums`, 14 px ghost chevrons) and dismiss `X` 14 px; option rows `chat.question.option` = `INTERACTION_CARD_ROW_CLASSES` (`flex items-center gap-2 border-[var(--border)] px-2 py-2`), `border-t` between, selected/hover `--surface-5`, single-select trailing `ArrowRight` 16, multi-select leading sm checkbox; free text row `chat.question.freeText` placeholder "Something else" (`text-sm`, transparent input), trailing arrow armed when text present; multi-select `Continue`/`Submit` action row. Answered → recap card (`InteractionCardRecap`: prompt `text-sm --text-primary`, answers `mt-1.5 gap-1 text-sm --text-muted`) and the paired user bubble is hidden.
- Error `chat.error` (`special-tags.tsx:3439-3443`): `p.text-[var(--text-secondary)].text-small.italic.leading-[20px]` (13/20 italic).
- Credential, usage-upgrade, organisation-secret, search-integration-connection cards: share `InteractionCard`; rows 16 px brand icon + `text-sm --text-body` + `ArrowRight`/`Check`. Mapped by reference only (Phase 1.5 implements the chrome; flows that need OAuth are Phase 4).

### Skeleton (`chat.skeleton`, `mothership-chat-skeleton.tsx:22-50`)
While `isLoading && !hasMessages`: `mx-auto max-w-chat space-y-6`; user row (same row classes) with `Skeleton h-[40px] w-[55%] rounded-[16px]`; 4 lines `h-[14px] w-[90/75/82/40%] rounded-[4px]` `space-y-3`; user row `h-[32px] w-[40%]`; 3 lines `85/70/60 %`. Skeleton fill `--surface-active` (#ececec / #2c2c2c) with `animate-pulse` (off under reduced motion) (`packages/emcn/src/components/skeleton/skeleton.tsx:11`).

## Tokens
| Element | Tokens |
|---|---|
| Transcript background | inherits content pane `--bg` (#fefefe / #1b1b1b) |
| User bubble | fill `--surface-5` (#f3f3f3 / #363636); text `--text-primary` (#1a1a1a / #e6e6e6) |
| Prose text, headings, list markers, table text | `--text-primary` |
| Links | `--brand-blue` (#3b6fe0 / #5b8def) |
| Strikethrough, code label, activity labels | `--text-tertiary` (#5c5c5c / #b3b3b3) |
| Inline code, citation chip, mention chip fill | `--surface-5` light / `--surface-4` dark (#f5f5f5 → dark #292929) |
| Table rules, code border/rule, hr, blockquote bar, image border | `--border` (#d8d8d8 / #444444) |
| Code header | `--surface-4` (#f5f5f5 / #292929) |
| Code body | light `--surface-5` #f3f3f3, dark `--code-bg` #1f1f1f |
| Action icons, chevrons, activity icons | `--text-icon` (#5a5a5a / #969696) |
| Action hover | `--surface-hover` (#f2f2f2 / #262626) |
| Copy-code hover | `--surface-5`, text `--text-secondary` |
| Shimmer | gradient `--text-body` 40 % → `--color-gray-400` #a3a3a3 50 % (dark `--color-gray-50` #fafafa) → `--text-body` 60 %, 200 % wide (`shimmer-text.module.css:11-31`) |
| Thinking loader ink | `--thinking-ink-inner/outer/glow` (light #2c2c2c→#5f5f5f, glow white .6; dark #a7a7a7→#d6d6d6, glow white .9) |
| Stopped row | icon `--text-icon`, text `--text-body` |
| Interaction card | border `--border-1` (= `--border`), fill `--white` / dark `--surface-4`, hover/selected `--surface-5` |
| Skeleton | `--surface-active` |

### Colour anchors (non-text zones; light / dark)
`chat.message.user.bubble @ (5, h/2)` → `--surface-5` #f3f3f3 / #363636 · `chat.code.header @ (4,4)` → `--surface-4` #f5f5f5 / #292929 · `chat.code.body @ (4,4)` → #f3f3f3 / #1f1f1f · `chat.code @ (0, 20)` → `--border` #d8d8d8 / #444444 (1 px left edge) · `chat.code.header @ (w/2, 34)` → `--border` (header rule) · `chat.table.th @ (2, 40)` → `--border` (row rule) · `chat.table.td(last row) @ (2, 39)` → `--bg` #fefefe / #1b1b1b (no rule) · `chat.transcript @ (4, 4)` → `--bg` · `chat.message.actions.copy @ (2,2)` at rest → `--bg`, hovered → `--surface-hover` #f2f2f2 / #262626 · `chat.skeleton` line `@ (2,7)` → `--surface-active` #ececec / #2c2c2c (capture with reduced motion so the pulse is off). Note: in light mode header #f5f5f5 vs body #f3f3f3 is ΔE ≈ 0.8, under the ΔE 2 gate, so only the dark capture distinguishes them; the box geometry row covers light.

## States
| State | Behaviour | Source |
|---|---|---|
| Loading (no messages yet) | skeleton; composer hidden while `isLoading` | `MSC/mothership-chat.tsx:901-903,980` |
| Message phases | `streaming` (network open) → `revealing` (stream closed, paced text still draining) → `settled` | `MC/utils.ts:204-217`, `MC/message-content.tsx:1062-1079` |
| Streaming text | last text segment only (`shouldSmoothTextSegment`, 907-917) is paced by `useSmoothText` and faded per word | `CC/chat-content.tsx:589-698` |
| Restored history | rendered static (no pacing, no fade); content > 60 chars at stream start shows immediately (`RESUME_SKIP_THRESHOLD`) | `use-smooth-text.ts:80,128-168` |
| Complete (settled) | shimmer slot replaced by actions row in the same render, same 46 px | `MC/message-content.tsx:1205-1236` |
| Stopped | "Stopped by user" row (+ actions) replaces the slot; user Stop snaps every paced reveal to full text (`snapAllSmoothText`) | `:1226-1233`, `use-smooth-text.ts:10-26` |
| Error | `<mothership-error>` tag in the text renders italic 13/20 `--text-secondary`; lane errors render under the lane in `text-caption` | `special-tags.tsx:3439-3443`, `AG/agent-group-view.tsx:331-335`, `hooks/stream/handle-error-event.ts:12-17` |
| Empty assistant (no renderable content, not streaming) | row renders nothing | `MSC/mothership-chat.tsx:289-291` |
| Pending special tag | tag bytes render nothing until closed; shimmer bridges | `CC/chat-content.tsx:694-698`, `MC/message-content.tsx:1097-1103` |
| Tool executing | row in its run; run header live (shimmer) when it holds the lane's live call; header label paced to ≥1000 ms per change while collapsed | `AG/tool-activity-group.tsx:230-264`, `AG/activity-stream.tsx:10-58` |
| Tool success / error / rejected / cancelled / skipped / interrupted | static row; title tense from `getToolStatusDisplayTitle`: success → completed verb, error/rejected → neutral action title, cancelled/aborted/interrupted → "Stopped …", skipped → "Skipped …"; a failed search followed by a retry is hidden | `lib/mothership/tools/display.ts:1796-1820`, `AG/tool-activity-group.tsx:39-50` |
| Tool awaiting approval | permission card replaces the row; the lane is force-expanded and its viewport unbounded | `AG/tool-call-item.tsx:138-147`, `AG/agent-group-view.tsx:151-154` |
| Agent group collapsed / expanded | collapsed by default (`defaultExpanded=false`); click or Enter/Space toggles; a pending interaction or nested browser takeover forces expanded; non-collapsible when it holds a single plain successful tool | `AG/agent-group-view.tsx:147-154,301-310` |
| Thinking | not rendered (see scope correction); shimmer label "Thinking" | `MC/message-content.tsx:404-407,930-942` |
| Question active / answered / dismissed | card; recap; hidden (actions row returns) | `question.tsx:136-156`, `MSC/mothership-chat.tsx:293-322` |
| Option chips | interactive only on the last message (`onOptionSelect` undefined otherwise) | `MSC/mothership-chat.tsx:953` |
| Reduced motion | shimmer → opacity pulse 2.2 s in `--shimmer-rest`; loader pins the `thinking` shape; global 0.01 ms animations | `shimmer-text.module.css:42-57`, `thinking-loader.tsx` (reduced-motion branch) |

## Interactions
- **Copy message** (`message-actions.tsx:78-84`): copies `getOrchestratorMessageText` (text segments joined, agent-lane text excluded) passed through `prepareContentForCopy` (workspace resource chips → portable markdown links; `copyable-markdown.ts`); icon → Check 1500 ms.
- **Copy code** (`copy-code-button.tsx:12-24`): copies the raw fence text; Check 2000 ms.
- **Like / Dislike**: opens `ChipModal` "Give feedback" with a resizable textarea (6 rows, min 140 px), placeholders "Tell us what was helpful..." / "Tell us what went wrong...", footer Cancel + Submit, Dislike adds "Copy ID" (copies `requestId`, "Copied" for 1500 ms). Submit with empty text just closes (`:108-125`).
- **Fork**: `POST /api/mothership/chats/{chatId}/fork {upToMessageId}` → navigate to `/workspace/{id}/chat/{newId}`; warning toast when files failed to copy; 409/413 show the server message, else "Failed to fork chat" (`:135-157`).
- **Links**: `_blank`, `noopener noreferrer`; external link hover → `SourcePreview` card; desktop shell plain click → browser panel (`source-link.ts:35-40`).
- **Citation chip**: same navigation as external links; hover preview.
- **Sources button**: popover `w-[420px]` above (`side=top align=start sideOffset=4`), list `max-h-[320px] py-1` with scroll fade, dense `SourceCard` rows (30 px chip geometry, 16 px icon slot, title `text-sm --text-body`, meta `text-caption --text-tertiary max-w-40%`, `⋯` menu Copy link); footer "View all sources" chip opens the sources resource (`message-sources.tsx:36-91`).
- **Workspace resource chip**: opens the resource in the resources panel (`onWorkspaceResourceSelect`).
- **Image**: click → Lightbox.
- **Agent group header**: click / Enter / Space toggles (`handleKeyboardActivation`); chevron appears on hover/focus.
- **Option / follow-up / question answer**: submit a user message (`stableOnOptionSelect` → `onSubmit(id)`; question → `"Prompt — Answer"` lines, `question.tsx:31-33`). Question keyboard: Enter submits free text, Escape blurs.
- **Permission**: Allow / For this chat / For every chat / Skip → `POST /api/copilot/tool-permission`.
- **Text selection copy** trims trailing whitespace from the plain-text flavour (`MSC/mothership-chat.tsx:799-813`).
- **Scrolling** (`use-auto-scroll.ts`): while streaming (or the last row still revealing), the view sticks to the bottom via an eased chase triggered by the sizer's ResizeObserver; detaches on wheel up, touch drag down, scrollbar drag up, or ArrowUp/PageUp/Home/Shift+Space; re-attaches within 5 px of the bottom on a downward move (stick tolerance 30 px); after the stream ends it idle-follows 800 ms. On chat open/switch and on the user's own send the view jumps to the last row (`MSC/mothership-chat.tsx:822-853`). The streaming last row never triggers virtualizer scroll compensation (730-731).
- **Ctrl+F** opens find-in-chat (`use-chat-find.ts`) — mapped separately.

## Animations
| Animation | Timing | Source |
|---|---|---|
| Word fade-in of streamed text | Streamdown `animated={animation:'fadeIn', duration:220, stagger:0, sep:'word'}`; disabled after 6000 revealed chars; animated tree dropped 300 ms after the reveal settles | `CC/chat-content.tsx:118-141,623-682` |
| Paced reveal (`useSmoothText`) | rAF loop; rate = backlog / 400 ms clamped 45–2400 chars/s; publishes ≤ 60 Hz; releases at word/punctuation boundaries (`[\s.,!?;:)\]]`), 24-char lookahead for long tokens; after stream end drains the rest within 400 ms | `use-smooth-text.ts:41-71,200-264` |
| Segment fade-in (agent group, options, takeover, shimmer) | `stream-fade-in` 300 ms ease-out, opacity 0→1 | `globals.css:222,295-302` |
| Shimmer slot swap | opacity 200 ms ease-out | `MC/message-content.tsx:1211-1218` |
| Shimmer sweep | background-position 100 % → −100 %, 2.2 s linear infinite | `shimmer-text.module.css:11-40` |
| Loader phrase change | incoming: mask wipe + fade 460 ms ease; outgoing: fade 300 ms; exiting label removed after 420 ms | `thinking-loader.module.css:101-135`, `thinking-loader.tsx` |
| Loader shape morph | stage opacity 500 ms ease-in-out; deterministic 16-step cycle 1.1–2.6 s per shape, starts on `corners`, phase-locked to wall clock (12 s period) | `thinking-loader.tsx:7-90`, `.module.css:140-147` |
| Disclosure | chevron rotate/opacity 150 ms; body height 300 ms cubic-bezier(.4,0,.2,1) | `AG/activity-disclosure.tsx:49-56`, emcn `expandable.tsx:52-53` |
| Activity viewport follow | rAF, step = max(1, gap × 0.18) | `AG/activity-viewport.tsx:58-86` |
| Header label pacing | ≥ 1000 ms between label changes while live and collapsed | `AG/activity-stream.tsx:10,43-58` |
| Copy feedback | icon swap 1500 ms (message) / 2000 ms (code) | as above |
| Skeleton | `animate-pulse` (2 s Tailwind default) | emcn skeleton |
Under `SIM_E2E` all durations are zero (plan §4.2); the paced reveal must also be bypassable (render full text) so parity captures of a just-streamed message equal the restored one.

## Network and realtime
Rendering itself issues no requests except: favicons for external links/citations (`SourceIcon`), inline chat images (`inlineChatImageUrl(chatId, requestId, ref)`), `useMothershipTaskStatus` for pending watch rows, resource name lookups for workspace resource chips (`useWorkflows`, `useTablesList`, `useWorkspaceFiles`, `useKnowledgeBasesQuery` — already cached by the shell), and the action mutations: `POST /api/copilot/feedback {chatId, userQuery, agentResponse, isPositiveFeedback, feedback}` (`lib/api/contracts/copilot.ts:364-365`), `POST /api/mothership/chats/[chatId]/fork {upToMessageId}` (`lib/api/contracts/mothership-chats.ts:352-356`), `POST /api/copilot/tool-permission {decisions:[{toolCallId, decision}]}` (`copilot.ts:449-450`; `always_allow` then invalidates general settings). Transcript loading and the stream are in the chat-engine spec.

## Flutter renderer decision (markdown)
`gpt_markdown` (plan §4.7 default) is **not sufficient** for this surface. Where it falls short:
1. Per-element component overrides with exact chrome: the table (no outer border, nowrap cells, 41/40 px rows, last-row rule removed, horizontal scroll with conditional 16 px edge fade, `min-w-full`), the code block (header with language label + copy button, separate header/body fills, border, 8 px radius) and inline code fill are fixed widgets/styles in gpt_markdown with only partial builder hooks.
2. Prism-equivalent highlighting with the `code.css` token palette and JSON/TS/bash/python grammars.
3. Sentinel links (`#sim-source-ref-N`, `#sim-workspace-ref-N`) that must become inline `WidgetSpan` chips inside the paragraph's line box.
4. Streaming: partial-markdown repair (unterminated fences, emphasis, tables) so a half-received message renders like Streamdown's `remend`, plus per-word fade spans and the paced reveal.
5. Prose metrics: Tailwind Typography prose-base margins (em-based, collapsing between siblings), heading scale, list indents, blockquote, task-list checkboxes.
6. GFM details: footnotes, autolink literals, raw-HTML sanitisation semantics.
It does provide LaTeX, which this surface does not need.

Recommendation: parse with `package:markdown` (GFM extension set: tables, fenced code, strikethrough, task lists, autolinks, footnotes; HTML blocks dropped/escaped) into an AST, and render with a custom `sim_chat` widget renderer (block widgets + `Text.rich` for inlines, margin-collapsing column layout). Highlighting: `re_highlight` (already in the stack for code fields) with a theme mapping highlight.js scopes to the Prism token colours above (json: `attr`→property, `string`, `literal`→boolean/null, `punctuation`, `number`; js/ts: `keyword`, `title.function`, `title.class`, `comment`, `regexp`, `variable`), or a small Prism-port tokenizer for json/js/ts/bash/python if exact token boundaries are required by goldens. A streaming "repair" pass (close open fence/emphasis/table row before parsing) is a small pure-Dart function with L1 tests ported from Streamdown's remend behaviour. gpt_markdown can stay for the TipTap-rendered notes/files surfaces.

## Ambiguities (to resolve by measurement on the first parity capture)
1. **Streamdown wrapper structure**: whether Streamdown 2.5 wraps blocks in its own div (with its own `space-y-4`/first-last margin reset). If it does, the paragraph→table gap may be 16 px or 18.75 px rather than the computed 18.75; the spec's numbers assume prose margins collapse normally. `node_modules` is not present in this checkout, so this was not verified.
2. **Streamdown default plugins**: assumed `defaultRemarkPlugins` = GFM (+ CJK/remend handling) and `defaultRehypePlugins` = raw/sanitize/harden with no KaTeX/Mermaid/Shiki in 2.5. Verify by rendering `$x^2$` and a ```mermaid fence in the React app (expected: literal text and a plain Prism-fallback code block).
3. **Tailwind Typography prose-base values** (p margin 1.25em, heading sizes, inline-code 0.875em) come from the plugin's defaults (0.5.20), not readable locally; the heading/inline-code rows are "verify".
4. **Monospace face** differs by OS (Consolas on Windows, Liberation/DejaVu in Linux Chromium). Flutter bundles fonts only; pick one (e.g. bundle a metric-compatible mono) and record a known gap for mono glyph widths, or run React captures with a pinned mono font.
5. **Scrollbar gutter**: `scrollbar-gutter: stable both-edges` reserves classic scrollbar width (≈15 px) on both sides in Windows Chromium; with overlay scrollbars it is 0. The column's x position depends on it.
6. **Resources panel** auto-open for the seeded chat (it has a `table` resource) changes the column width; captures must pin the panel state.
7. **ThinkingLoader**: a goo SVG filter (feGaussianBlur + feColorMatrix alpha threshold + inner glow) over 9 animated shapes; Flutter needs a `CustomPainter` with `ImageFilter.blur` + a colour-matrix threshold layer. Pixel parity is not realistic; parity = 20 × 20 box, label metrics, phrase timing. Propose a known-gap row for the shape rendering.
8. Live-stream states (tools, permission, agent groups, shimmer) cannot be produced from the current seed; they need either a recorded mothership stream fixture replayed by a fake server (L3) or contentBlocks fixtures inserted by the seed (would require the seed to gain those rows).

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | MSC/mothership-chat.tsx:151-152,895-900 | `chat.transcript` px 24 (≥768) / 12, pt 16, pb 8, both-edge scrollbar gutter, overflow-x hidden | | |
| 2 | layout | MSC/mothership-chat.tsx:153,905-908; globals.css:217 | `chat.transcript.column` centred, max width 704 | | |
| 3 | token | MSC/mothership-chat.tsx:897; scroll-fade.module.css | 16 px top/bottom fade only while content is hidden past that edge | | |
| 4 | layout | MSC/mothership-chat.tsx:154-155,223 | `chat.message.user` pt 12, pb 24, right-aligned, 6 px gap to attachments | | |
| 5 | layout | MSC/mothership-chat.tsx:157-158 | bubble max 70 % (85 % < 768), radius 16, padding 14 × 8, `--surface-5` | | |
| 6 | token | user-message-content.tsx:11-12 | user text Inter 15/23 400 `--text-primary`, tracking 0, pre-wrap, overflow-wrap anywhere, trimmed | | |
| 7 | layout | seed fixtures.dart:712; MSC/mothership-chat.tsx:154 | seeded user row height 75, bubble 39 tall single line | | |
| 8 | layout | user-message-content.tsx:27-38; resource-mention.tsx:10-27 | mentions render as 20 px mono chips with 12 px icon inside the text | | |
| 9 | layout | chat-message-attachments.tsx:23-70 | attachments: 56 px r8 thumbs, file pills 20 px max 140, gap 6, right aligned above bubble | | |
| 10 | layout | MSC/mothership-chat.tsx:194-211 | task-notification pill centred, 12 px, `--border`, rounded-full | | |
| 11 | layout | MSC/mothership-chat.tsx:159,324 | `chat.message.assistant` pb 24 (+16 when ending in an interaction card) | | |
| 12 | state | MC/message-content.tsx:1019-1027 | block-less message renders `content` as a single text segment (seeded path) | | |
| 13 | layout | MC/message-content.tsx:1121-1127 | 16 px between segments, 8 px between consecutive activity segments, empty segments hidden | | |
| 14 | layout | CC/chat-content.tsx:782,805-816 | special-tag blocks are siblings of the markdown group, 16 px apart | | |
| 15 | token | CC/chat-content.tsx:90-96 | `chat.markdown.p` Inter 15/25 400 `--text-primary`, tracking 0 | | |
| 16 | layout | CC/chat-content.tsx:95,789 | paragraph margins 18.75, first child mt 0, last child mb 0 | | |
| 17 | token | CC/chat-content.tsx:93-94 | headings 600, `--text-primary`, mt 24 mb 12, first heading mt 0, h1 36/40 h2 24/32 h3 20/32 h4 16/24 (verify) | | |
| 18 | token | CC/chat-content.tsx:99,484-489 | bold 600; italic; strikethrough `--text-tertiary` | | |
| 19 | token | CC/chat-content.tsx:403-413; source-link.ts:26-27 | links `--brand-blue`, no underline, `_blank` | | |
| 20 | layout | external-link.tsx:19-38 | external links show a leading favicon (mr 4, middle aligned) | | |
| 21 | interaction | external-link.tsx:24-35; source-preview.tsx | hover on external link shows the preview card; click opens new tab | | |
| 22 | token | CC/chat-content.tsx:452-463; chrome.ts:2 | inline code mono, `--surface-5`/dark `--surface-4`, radius 4, px 4 py 1, no backticks | | |
| 23 | layout | CC/chat-content.tsx:415-451 | ul/ol `my-4 pl-5`, li `my-1` 15/25, markers `--text-primary`, nested `my-1` | | |
| 24 | layout | CC/chat-content.tsx:416-444,471-481 | task list: no bullets, 24 px indent, disabled sm checkbox | | |
| 25 | layout | CC/chat-content.tsx:464-469 | blockquote 2 px `--border` left bar, pl 16, italic, my 16 | | |
| 26 | token | CC/chat-content.tsx:101 | hr `--border`, my 24 | | |
| 27 | layout | CC/chat-content.tsx:490-508 | image max-h 360, rounded 8, 1 px border, my 16; click → lightbox | | |
| 28 | layout | CC/chat-content.tsx:290-301 | `chat.table` wrapper my 16, full width, horizontal scroll | | |
| 29 | state | CC/chat-content.tsx:285-300; scroll-fade.module.css (.rootX) | overflowing table: 16 px left/right fade only at hidden sides; region role + focusable | | |
| 30 | layout | CC/chat-content.tsx:302 | table `min-w-full`, border-collapse, no outer border/fill | | |
| 31 | token | CC/chat-content.tsx:314-322 | `chat.table.th` 14/24 600 `--text-primary`, px 12 py 8, nowrap, left, 1 px `--border` bottom → 41 px | | |
| 32 | token | CC/chat-content.tsx:324-332 | `chat.table.td` 14/24 400, same padding and rule | | |
| 33 | layout | CC/chat-content.tsx:302 | last body row has no bottom rule (40 px) | | |
| 34 | layout | seed fixtures.dart:716; CC/chat-content.tsx:284-333 | seeded table: 2 columns, 3 body rows, height 163, y = 43.75 in content | | |
| 35 | layout | CC/chat-content.tsx:350 | `chat.code` my 24, radius 8, 1 px `--border`, clipped | | |
| 36 | layout | CC/chat-content.tsx:351-354 | `chat.code.header` px 16 py 8, `--surface-4`, bottom rule, 35 px | | |
| 37 | token | CC/chat-content.tsx:355 | language label Inter 11/16.5 `--text-tertiary`; "code" when no info string | | |
| 38 | layout | copy-code-button.tsx:16-23; CC/chat-content.tsx:356-359; button.tsx:28,46 | copy button 26 × 18, radius 4, −8 px right margin, 14 px icon, `--text-tertiary` | | |
| 39 | interaction | copy-code-button.tsx:13-22 | copy-code copies raw text, icon → Check for 2000 ms; hover `--surface-5` + `--text-secondary` | | |
| 40 | layout | CC/chat-content.tsx:361-364 | `chat.code.body` p 16, mono 13/21, no wrap, horizontal scroll, `--surface-5` / dark `--code-bg` | | |
| 41 | token | packages/emcn/src/components/code/code.css | token colours per table (property #0891b2, string #b45309, boolean #16a34a, punctuation #383838; dark #4fc3f7, #f39c6b, #a5d6a7, #d4d4d4) | | |
| 42 | state | CC/chat-content.tsx:259-262,72-83 | aliases js/ts/tsx/jsx/sh/shell/html/xml/yml/py; unknown language → JS grammar | | |
| 43 | state | CC/chat-content.tsx:339-345 | empty fence renders plain pre without header | | |
| 44 | layout | seed fixtures.dart:716; CC/chat-content.tsx:334-368 | seeded code block: label `json`, one line, height 90, y = 230.75 | | |
| 45 | layout | MC/message-content.tsx:67,1234-1236 | tail region mt 10, height 36, actions vertically centred | | |
| 46 | layout | message-actions.tsx:30-32,169 | action buttons 26 × 26 (44 below md), r6, 14 px icons `--text-icon`, gap 2 | | |
| 47 | state | message-actions.tsx:159-165; MSC/message-actions-visibility.ts:15-22 | seeded message shows copy, like, dislike, fork; actions only when settled and not ending in an active question/credential | | |
| 48 | interaction | message-actions.tsx:78-84,170-185 | copy message: orchestrator text via `prepareContentForCopy`, Check 1500 ms, tooltip text swaps | | |
| 49 | interaction | message-actions.tsx:100-125,235-269 | like/dislike open the feedback modal; empty submit closes; dislike shows "Copy ID" | | |
| 50 | network | message-actions.tsx:116-122; contracts/copilot.ts:364-365 | `POST /api/copilot/feedback` body shape | | |
| 51 | network | message-actions.tsx:135-157; contracts/mothership-chats.ts:352-356 | fork `POST /api/mothership/chats/{id}/fork` then navigate; 409/413 message toast | | |
| 52 | layout | message-sources.tsx:22,56-90 | sources button 26 px, BookOpen + count; popover 420 wide, list max 320 with fades, "View all sources" | | |
| 53 | layout | source-chip.tsx:46 | citation chip 20 px, max 160, rounded-full, 12 px text, `--surface-5`/`--surface-4`, hover `--surface-hover` | | |
| 54 | layout | MC/message-content.tsx:1205-1219; pending-tag-indicator.tsx:11-16 | shimmer slot: last message only, py 8, 20 px loader + 8 px gap + 14 px label | | |
| 55 | state | MC/message-content.tsx:930-942,1097-1103 | label Thinking/Dispatching/Returning; shown with no segments, pending tag, or 1500 ms idle; hidden while text paints | | |
| 56 | token | shimmer-text.module.css:11-51 | shimmer gradient body→gray-400 (dark gray-50)→body, 200 % width, 2.2 s linear; reduced motion → pulse to .55 | | |
| 57 | state | MC/message-content.tsx:1226-1233 | stopped: CircleStop 16 + "Stopped by user" 14 px `--text-body`, then actions in mt 10 | | |
| 58 | state | use-smooth-text.ts:41-71,128-168,200-264 | paced reveal: 400 ms horizon, 45–2400 cps, word boundaries, 60 Hz, history not animated | | |
| 59 | state | CC/chat-content.tsx:118-141,623-682 | word fade 220 ms; off after 6000 chars; static tree after 300 ms drain without visual change | | |
| 60 | state | use-smooth-text.ts:10-26 | user Stop snaps all paced text to full | | |
| 61 | layout | components/ui/activity-status.tsx:6-44 | activity row: 14 px icon slot `--text-icon`, gap 8, label Inter 15/20 `--text-tertiary`, hover `--text-body` | | |
| 62 | layout | components/ui/activity-status.tsx:54-61 | nested content indented by icon slot + gap (22 px) | | |
| 63 | interaction | AG/activity-disclosure.tsx:32-68 | header click/Enter/Space toggles; chevron 14 px rotated −90° and hidden when collapsed, visible on hover/focus, 150 ms | | |
| 64 | layout | AG/activity-viewport.tsx:89-97 | expanded body pt 8, viewport max 110 px with scroll fades, unbounded for interactions/search results | | |
| 65 | state | AG/tool-call-item.tsx:109-184; MC/utils.ts:196-202 | tool row icon: block brand icon, else `TOOL_ICONS`, else Wrench; agent default Blimp | | |
| 66 | state | lib/mothership/tools/display.ts:1796-1820 | tool title tense per status (completed, neutral on error, "Stopped …", "Skipped …", "Waiting for approval: …") | | |
| 67 | state | AG/tool-activity-group.tsx:26-93,193-200 | run summary: model completed title when all succeeded, else up to 3 actions + " · N stopped/skipped" | | |
| 68 | state | AG/activity-stream.tsx:10-58 | live header label changes at most once per 1000 ms while collapsed | | |
| 69 | state | AG/agent-group-view.tsx:147-154,301-310 | groups collapsed by default; forced open by pending interaction; non-collapsible single plain success | | |
| 70 | state | AG/agent-group-view.tsx:200-208,287-300 | subagent header: live → 14 px ThinkingLoader or "Thinking"; done → completed label; error → agent label + caption error line | | |
| 71 | token | AG/agent-group-view.tsx:356-364; AG/inline-markdown.tsx:4-56 | narration 15/20 `--text-tertiary`, inline bold/italic/code(mono 12)/links-as-text | | |
| 72 | layout | AG/tool-permission-card.tsx:156-230 | permission row: ShieldCheck, title text-sm `--text-body`, Allow (primary), Don't ask again ▾, Skip; bulk row for >1 | | |
| 73 | network | AG/tool-permission-card.tsx:106-135 | `POST /api/copilot/tool-permission` decisions; 404 → expired text; other error → toast + re-enable | | |
| 74 | layout | options.tsx:13-21; chip.tsx:66-81 | options chips: border variant, round, 30 px, wrap gap 8 | | |
| 75 | layout | special-tags.tsx:1866-1926 | "Suggested follow-ups" numbered rows, px 8 py 8, rules between, ArrowRight 16, hover `--surface-5` | | |
| 76 | layout | interaction-card.tsx:27-45; question.tsx:258-436 | question card radius 16, `--white`/dark `--surface-4`, 1 px border, rows px 8 py 8, stepper, dismiss, "Something else" | | |
| 77 | interaction | question.tsx:164-243,409-424 | single-select row answers; multi-select toggles + Continue/Submit; Enter submits text; Escape blurs; answer message format "Prompt — Answer" | | |
| 78 | state | question.tsx:136-156; interaction-card.tsx:52-67 | answered → recap (prompt + muted answers) | | |
| 79 | token | special-tags.tsx:3439-3443 | mothership error italic 13/20 `--text-secondary` | | |
| 80 | layout | watch-activity.tsx:11-57 | watch row labels per status/kind; shimmer while pending | | |
| 81 | layout | mothership-chat-skeleton.tsx:22-50; skeleton.tsx:11 | skeleton geometry and `--surface-active` fill, pulse off under reduced motion | | |
| 82 | interaction | use-auto-scroll.ts:5-33,121-188 | sticky follow while streaming; detach on upward gesture; reattach within 5 px moving down; 800 ms settle follow | | |
| 83 | interaction | MSC/mothership-chat.tsx:822-853 | open/switch chat and own send jump to the last row | | |
| 84 | interaction | MSC/mothership-chat.tsx:799-813 | copying a selection trims trailing whitespace | | |
| 85 | state | MC/message-content.tsx:404-407; CC/chat-content.tsx:752-756 | thinking blocks and `<thinking>` tags never render | | |
| 86 | token | globals.css:222,295-302 | segment fade-in 300 ms ease-out (zero under SIM_E2E) | | |
</content>
</invoke>
