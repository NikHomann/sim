# Chat input (Mothership composer)
Upstream: `app/workspace/[workspaceId]/home/components/user-input/**`, `home/components/chat-context-kind-registry/**`, `home/components/context-mention-icon/**`, and the hooks it pulls from `w/[workflowId]/components/panel/components/copilot/components/user-input/{hooks,utils}`, `hooks/use-{voice-input,speech-to-text,chat-input-focus,auto-size-textarea,animated-placeholder}.ts`, `stores/{mothership-drafts,mothership-effort}`, commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c
Phase: 1.5

Paths are relative to `apps/sim/` unless stated; `ui/` means `app/workspace/[workspaceId]/home/components/user-input/`, `cp/` means `app/workspace/[workspaceId]/w/[workflowId]/components/panel/components/copilot/components/user-input/`. The composer appears in two variants: the **hero** variant on the empty Home (`isInitialView=true`, has the mode selector, ambient shadow, min editor height 56) and the **conversation** variant in the chat footer (`isInitialView=false`). Where it sits and what happens after submit is in `home-page.md`; the send/queue engine itself is the chat-engine spec.

## Files

| File | Lines | Role |
|---|---|---|
| `ui/user-input.tsx` | 693 | Composer: container, drafts, attachments, voice, drag/drop, submit/Enter policy, toolbar |
| `ui/components/prompt-editor/prompt-editor.tsx` | 250 | Transparent textarea + mirror overlay that paints chips; mounts `+` and `/` menus |
| `ui/components/prompt-editor/use-prompt-editor.ts` | 1411 | Editor state machine: value, contexts, triggers, chip atomicity, paste/copy/cut, inserts |
| `ui/components/constants.ts` | 151 | Text/overlay/scroller classes, `PlusMenuHandle`, `RESOURCE_TO_CONTEXT` |
| `ui/components/growing-textarea.tsx` | 38 | `<textarea rows=1>` + autosize |
| `ui/components/input-toolbar.tsx` | 85 | Toolbar order and wrapping |
| `ui/components/plus-menu-dropdown/plus-menu-dropdown.tsx` | 546 | `+` browse menu and `@` mention menu |
| `ui/components/plus-menu-dropdown/resource-mention-items.ts` | 139 | Mention candidate building |
| `ui/components/skills-menu-dropdown/skills-menu-dropdown.tsx` | 250 | `/` skills + MCP menu |
| `ui/components/attached-files-list/attached-files-list.tsx` | 186 | Attachment cards/thumbnails |
| `ui/components/drop-overlay/drop-overlay.tsx` | 48 | Drop overlay |
| `ui/components/mic-button/mic-button.tsx` | 120 | Mic toggle + waveform |
| `ui/components/microphone-permission-help/microphone-permission-help.tsx` | 41 | Blocked-mic help modal |
| `ui/components/send-button/send-button.tsx` | 41 | Send / stop |
| `ui/components/model-selector.tsx` | 113 | Reasoning effort chip (+ model, fast mode behind flag) |
| `ui/components/model-setting-trigger.tsx` | 50 | Chip trigger for effort/model |
| `ui/components/fast-mode-toggle.tsx` | 44 | Fast mode chip |
| `ui/components/conversation-mode-selector.tsx` | 59 | Build/Plan(/Search) dropdown |
| `ui/hooks/use-conversation-mode-shortcut.ts` | 66 | Shift+Tab cycles modes |
| `ui/utils/conversation-modes.ts` | 11 | Mode list |
| `ui/hooks/use-skill-auto-mention.ts` | 253 | `/name` → skill chip |
| `ui/components/animated-placeholder-effect/animated-placeholder-effect.tsx` | 25 | Placeholder writer |
| `ui/components/chip-clipboard-codec.ts` | 314 | Portable chip links on copy/paste |
| `ui/chip-selection.ts` | 69 | Selection snapping around chips |
| `ui/mothership-context-event.ts` | 42 | `mothership-add-context` window event |
| `home/components/chat-context-kind-registry/chat-context-kind-registry.tsx` | 144 | 23 context kinds → label + icon |
| `home/components/context-mention-icon/context-mention-icon.tsx` | 18 | Chip icon |
| `cp/hooks/use-file-attachments.ts` | 429 | Attachment upload pipeline |
| `cp/hooks/{use-mention-menu,use-mention-tokens,use-context-management,use-integration-auto-mention}.ts` | — | Trigger detection, token ranges, context list, `@Integration` canonicalisation |
| `cp/utils.ts` | — | `SKILL_CHIP_TRIGGER=' '`, `extractContextTokens`, `computeMentionHighlightRanges` |
| `hooks/use-voice-input.ts` / `hooks/use-speech-to-text.ts` | 160 / 448 | Voice: transcript merge, token, mic, websocket |
| `hooks/use-chat-input-focus.ts` | 24 | Autofocus rule |
| `hooks/use-auto-size-textarea.ts` | ~75 | Autosize |
| `hooks/use-animated-placeholder.ts` | 88 | Typewriter placeholder |
| `stores/mothership-drafts/store.ts` | ~95 | Drafts (persisted) |
| `stores/mothership-effort/store.ts` | ~105 | Effort/model prefs |
| `lib/mothership/model-options.ts` | ~80 | Effort/model options and resolution |

emcn: `Chip` (shape `round`), `ChipDropdown` (ghost, round), `ComposerActionButton`, `Button`, `Tooltip` (+ `Tooltip.Shortcut`), `DropdownMenu*` (`Content`, `Trigger`, `Item`, `ItemLabel`, `Label`, `SearchInput`, `RadioGroup`, `Sub*`), `dropdownMenuRowClass`, `ChipModal`/`ChipModalHeader`/`ChipModalBody`, `Lightbox`, `Loader`, `OverflowText`, `IdentityTile`, `scrollFade*`, `useScrollEdges`, `toast`. Icons: `Plus`, `Paperclip`, `Slash`, `ArrowUp`, `StopFilled`, `Mic`, `X`, `Brain`, `Sparkles`, `Zap`, `ChevronDown`, `Check`, file-type icons; `AgentSkillsIcon`, `McpIcon` (`components/icons.tsx`).

## Is it a rich editor?
No. It is a native `<textarea>` whose text is transparent (`text-transparent`, caret `--text-primary`) under an `aria-hidden` mirror `<div>` with identical box/typography that re-paints the value: plain spans for text and, for every context token, the token text with its **first character made invisible and an icon centred over that slot** (`prompt-editor.tsx:108–175, 186–218`). A "chip" is therefore just text (`@Label ` / ` Label `) plus an icon; there is no pill background, no border, no inline widget, and wrapping is identical to plain text. All chip semantics (atomic delete, caret hop, selection snapping, no typing inside) are implemented on the plain string in `use-prompt-editor.ts`. Above 256 KiB of text (`PASTE_RENDER_THRESHOLDS.ENHANCED_TEXT_CHARACTERS`) with no skill chip, the overlay is dropped, the text becomes visible and the textarea scrolls itself (max 240px) (`prompt-editor.tsx:83–85, 187–196`).

## Layout

Coordinates assume the hero at 1440×900 (see `home-page.md`): composer box x ≈480.5..1184.5, y ≈338..442. "≈" values are derived and must be confirmed by capture.

### Root (`chat-input.root`, `user-input.tsx:570–590`)
`relative z-10 mx-auto w-full max-w-chat (704px) cursor-text rounded-2xl (16px) border border-[var(--border-1)] (= --border) bg-[var(--white)] dark:bg-[var(--surface-4)] px-2.5 (10px) py-2 (8px)`, Inter font (`inter.className`); hero adds `shadow-ambient` (`0 0 12px 0 rgba(0,0,0,.08)`, dark `.22`). Children in order: placeholder effect (no box), `AttachedFilesList`, `PromptEditor`, `InputToolbar`, hidden `<input type=file multiple accept=MOTHERSHIP_ACCEPT_ATTRIBUTE>`, `DropOverlay` (while dragging files), `MicrophonePermissionHelp`.
Hero single-line height: 1 + 8 + 56 (editor min) + 30 (toolbar) + 8 + 1 = 104px. Conversation variant: editor min is the 32px single line → 80px.

### Editor (`chat-input.editor`, `prompt-editor.tsx:177–219`, `constants.ts:58–102`)
- Scroller: `relative overflow-y-auto overflow-x-hidden cursor-text`, scrollbar hidden; `max-h-[200px]`; hero `min-h-[56px]`.
- Sizer `relative` → overlay `chat-input.overlay` (`pointer-events-none absolute inset-0 whitespace-pre-wrap`) + textarea `chat-input.textarea`.
- Shared field box: `m-0 box-border min-h-[24px] w-full px-1 py-1 (4px) [overflow-wrap:anywhere] border-0 bg-transparent`.
- Typography `PROMPT_TEXT_CLASSES`: `font-body` = system UI stack (`ui-sans-serif, -apple-system, system-ui, Segoe UI, Helvetica, …`, `globals.css:74–76`, **not Inter**), `text-md` 16px, `md:pointer-fine:text-sm` → **14px on desktop with a fine pointer**, `leading-[24px]`, `tracking-[-0.015em]`; colour `--text-primary`, caret `--text-primary`, placeholder `--text-muted`; no focus ring.
- Textarea: `block h-auto resize-none overflow-hidden rows=1`, grown by script to its `scrollHeight` (the scroller clips/scrolls). Single line = 32px.
- Chip glyph (`chat-input.chip`): the trigger character is `invisible`; icon `absolute inset-0 m-auto size-[12px] translate-y-[1.25px] --text-icon` centred in the glyph advance; label follows as normal text in `--text-primary`. Trigger per kind: `skill`/`mcp` → EM SPACE ` ` (wide slot for the icon; restored to `/` on submit/copy), `slash_command` → `/`, everything else → `@` (`cp/utils.ts:29–41`). `current_workflow` never renders a token.
- Text start x ≈ 480.5 + 1 + 10 + 4 = 495.5; first line top ≈ 338 + 1 + 8 + 4 = 351.

### Toolbar (`chat-input.toolbar`, `input-toolbar.tsx:37–83`)
`@container/input-toolbar flex flex-wrap items-center justify-between gap-y-1`.
- Leading `chat-input.toolbar.leading`: `flex min-h-[30px] shrink-0 items-center gap-1` (gap 0 when the toolbar is ≤280px). Order: Add resources, Attach file, Skills, mode selector (hero, only when ≥2 modes).
- Trailing: `ml-auto flex min-h-[30px] items-center gap-1`: [effort chip (+ fast + model when flagged), mic] then send.
- Round icon chips (`chat-input.add`, `chat-input.attach`, `chat-input.skills`): `Chip shape=round` → `inline-flex h-[30px] items-center gap-1.5 px-2 rounded-full`, icon 16px `--text-icon` → 32×30; hover `--surface-hover`; tooltip side top: "Add resources" / "Attach file" / "Skills". At 1440: x ≈491.5–523.5, 527.5–559.5, 563.5–595.5.
- Mode selector `chat-input.mode`: `ChipDropdown variant=ghost shape=round` (label "Build"/"Plan" in `--text-icon` with chevron), `align=start`, no selected check, wrapped in `inline-flex shrink-0`; tooltip "Select mode" + shortcut `⇧ Tab` (hidden while open).
- Effort chip `chat-input.effort` (`ModelSettingTrigger`): `Chip shape=round` with `OverflowText` value label (`text-sm --text-icon`), e.g. "High"; below 320px toolbar width the label collapses to a 14px `Brain` icon; tooltip (prefers above) "Reasoning effort: High"; `aria-label='Reasoning effort'`, `aria-description=<value>`. Menu: `side=top align=start`, radio rows (`role=menuitemradio`, `aria-checked`).
- Model chip `chat-input.model` (flag `mothership-model-selector` only): same trigger with chevron, `Sparkles` icon in narrow mode; menu `side=top align=end`, rows with a 16px `Check` on the current model. Fast toggle `chat-input.fast` (flag on and model ≠ Opus 5.5): round chip with `Zap` 14px filled when on, `aria-pressed`, tooltip "Faster responses at a higher price".
- Mic `chat-input.mic`: `Button` 28×28 `rounded-full p-0`, ghost (idle: `--text-icon`, hover `--surface-hover`) / `active` variant while listening; `Mic` 16px stroke 1.25 ↔ 18px 5-bar waveform (bars at x 3,6,9,12,15 of an 18-unit box, stroke 1.5, height 1..14 around y 9, easing 0.24/frame, √level); cross-fade 300ms `cubic-bezier(.2,0,0,1)` with scale .25 and 4px blur; press scale .96. Tooltip/label "Voice input" / "Stop listening".
- Send `chat-input.send` (`ComposerActionButton`): ghost button `size-auto rounded-full p-0` wrapping a 28px circle: enabled `#383838` (dark `#E0E0E0`), hover `#575757` (dark `#CFCFCF`); disabled `#808080` both themes, and the disabled button carries emcn `Button`'s `disabled:opacity-70` (seen: #a5a5a5 light, #666666 dark); `ArrowUp` 16px white (dark black). Streaming: same 28px circle (active colour) with `StopFilled` 14px, label "Stop generation". At 1440: x ≈1145.5..1173.5, centre y ≈418.

### Attachments (`chat-input.attachments`, `attached-files-list.tsx`)
- List (only when ≥1): `mb-1.5 (6px)` → `flex flex-wrap items-center gap-1.5`.
- Media (image/video) `chat-input.attachment`: 48×48 card; other files: `h-[48px] max-w-[min(220px,100%)]` card `flex items-center gap-2 py-[7px] pr-5 pl-2`.
- Card chrome: `rounded-lg border --border bg --surface-5`, hover `--surface-active` (dark `--surface-6`). File card: 32px tile `rounded-md bg --surface-7` (dark `--surface-3`) with 16px doc icon `--text-icon`; name `text-small --text-body leading-tight truncate`; extension `text-caption uppercase --text-icon`. Media: centred 18px icon under an `object-cover` image/video (`muted playsInline preload=metadata`); a failed image keeps the icon.
- Uploading: overlay `bg --surface-5/70` (dark `--surface-4/70`) with a 14px spinning `Loader`; remove hidden.
- Remove `chat-input.attachment.remove`: hit 16×16 at `top-[2px] right-[2px]`, visual 16px circle `border --border bg --surface-2` with `X` 10px `--text-body`; `aria-label="Remove {name}"`.
- Click: image with preview → `Lightbox` (aria "Preview {name}"); else opens `file.path` (uploaded) or the blob preview in a new tab.

### Drop overlay (`chat-input.drop-overlay`, `drop-overlay.tsx`)
`pointer-events-none absolute inset-[6px] z-10 flex items-center justify-center rounded-[14px] border-[1.5px] border-dashed border-[var(--border-1)] bg-[var(--white)] dark:bg-[var(--surface-4)]`; "Drop files" `text-small --text-secondary`; row of nine 14px icons (pdf, docx, xlsx, csv, txt, md, json, audio, video) `--text-icon` gap 8.

### Menus
- `+` / mention menu `chat-input.plus-menu` (`plus-menu-dropdown.tsx:409–543`): anchored to a 0×0 fixed trigger at a viewport point (caret top-left of the `@` for mentions; the `+` chip's top-left for browse), `side=top align=start sideOffset=8 collisionPadding=8`, width `360px` (max `min(360px, 100vw−16px)`), `MENU_STYLES` surface (`rounded-xl border --border bg --bg shadow-medium p-1`). Browse mode: `DropdownMenuSearchInput` "Search resources" (28px field) then one submenu per family (same families as `home-page.md` add-menu, but composer excludes only `test`; `integration` appears only in mention mode; `task` (past chats) and folder entries are included; submenus also 360px). Mention mode: no search box, focus stays in the textarea, `max-h-[min(280px, available)]`, flat list grouped by family with `DropdownMenuLabel` headings (28px `text-caption --text-muted`), ≤5 rows per family when the query is empty; rows are `dropdownMenuRowClass` (28px `text-small` rounded-lg px-2 gap-1.5) buttons with the registry renderer and an optional right-aligned workspace name (`text-xs --text-muted`, max 35%); cursor row `--surface-hover`; empty → "No results" 28px `text-caption --text-muted`.
- Skills menu `chat-input.skills-menu` (`skills-menu-dropdown.tsx:180–245`): same anchoring (caret), `side=top align=start sideOffset=8`, `max-w-[min(300px,100vw−32px)]`; rows (skills then MCP servers) with `AgentSkillsIcon`/`McpIcon` (managed connectors use their own icon), name, optional workspace name; empty "No skills or MCP servers". Never takes focus.
- Mic help `chat-input.mic-help`: `ChipModal size=sm` (440px) title "Allow microphone access"; body: "Once microphone access is blocked, your browser requires you to change it from the site controls." (`text-sm --text-secondary`), ordered list (`text-sm --text-body`, gap 8): "Open the site controls beside the address bar." / "Set Microphone access for this site to Allow." / "Reload the page if prompted, then try voice input again."; footnote "In Safari, open Safari Settings, then Websites, then Microphone." (`--text-tertiary`).

### Parity ids
`chat-input.root` · `chat-input.editor` · `chat-input.textarea` · `chat-input.overlay` · `chat-input.chip` (first) · `chat-input.toolbar` · `chat-input.toolbar.leading` · `chat-input.add` · `chat-input.attach` · `chat-input.skills` · `chat-input.mode` · `chat-input.effort` · `chat-input.model` · `chat-input.fast` · `chat-input.mic` · `chat-input.send` · `chat-input.attachments` · `chat-input.attachment` (first) · `chat-input.attachment.remove` · `chat-input.drop-overlay` · `chat-input.plus-menu` · `chat-input.plus-menu.search` · `chat-input.plus-menu.row` (first) · `chat-input.skills-menu` · `chat-input.skills-menu.row` (first) · `chat-input.mic-help`.

### Colour anchors (hero, 1440×900, dpr 1)
| # | Point | Light | Dark | Source |
|---|---|---|---|---|
| C1 | (1100, 365) composer fill, right of the placeholder | `--white` #ffffff | `--surface-4` #292929 | `user-input.tsx:582` |
| C2 | (1159, 418) send button centre, empty composer | #808080 at 70% over the composer fill → #a6a6a6 (captured #a5a5a5) | over #292929 → #666666 | `composer-action-button.tsx` + emcn `Button` `disabled:opacity-70` |
| C3 | (1152, 418) send button 7px left of centre (off the arrow) after typing "a" | #383838 | #e0e0e0 | same |
| C4 | (497, 418) Add-resources chip while hovered, off the glyph | `--surface-hover` #f2f2f2 | #262626 | `chip.tsx:87–90` |
| C5 | (832, 360) drop overlay centre-top while dragging a file over | `--white` #ffffff | #292929 | `drop-overlay.tsx:31` |
| C6 | file attachment card 3px inside its left edge, mid-height | `--surface-5` #f3f3f3 | #363636 | `attached-files-list.tsx:22` |
| C7 | file tile centre-left (tile x+3) | `--surface-7` #d9d9d9 | `--surface-3` #242424 | `attached-files-list.tsx:95` |

## Tokens
| Element | Tokens |
|---|---|
| Container | `--white`/dark `--surface-4`, border `--border-1` (= `--border`), radius 16, `shadow-ambient` (hero) |
| Text / caret / placeholder | `--text-primary` / `--text-primary` / `--text-muted`; system font 14px (16px coarse), lh 24, tracking −0.015em |
| Chip icon | 12px `--text-icon` |
| Toolbar chips | icon 16px `--text-icon`, hover `--surface-hover`, radius full, 30px tall |
| Effort/model label | `text-sm --text-icon` |
| Send/stop | `#383838`/`#E0E0E0` active, `#575757`/`#CFCFCF` hover, `#808080` disabled; glyph white/black |
| Mic | idle `--text-icon` + hover `--surface-hover`; listening = emcn Button `active` variant |
| Attachments | `--surface-5`, `--border`, hover `--surface-active`/dark `--surface-6`, tile `--surface-7`/dark `--surface-3`, name `--text-body`, ext `--text-icon`, remove `--surface-2` + `--border` |
| Drop overlay | `--white`/dark `--surface-4`, dashed 1.5px `--border-1`, label `--text-secondary` |
| Menus | `MENU_STYLES` (`--bg`, `--border`, shadow-medium), cursor `--surface-hover`, headings/empty `--text-muted` |

## States
| State | Behaviour | Source |
|---|---|---|
| Empty | send disabled grey; hero placeholder animates, conversation placeholder "Send message to Sim" | `user-input.tsx:296`, `animated-placeholder-effect.tsx:15–22` |
| Hero placeholder animation | prefix "Ask Sim to " + suffixes "respond to my emails...", "find and track leads...", "DM me Linear updates on Slack...", "track GitHub commits..."; type 60ms/char, hold 2000ms, delete 35ms/char, gap 400ms, loop (static prefix when disabled) | `use-animated-placeholder.ts:3–87` |
| Has text or ≥1 uploaded file, nothing uploading, not sending | send enabled (dark) | `user-input.tsx:296` |
| Any file uploading | send disabled; Enter ignored | 296, 535 |
| Sending/streaming | send shows Stop; Enter with text still submits (the engine queues it); Enter on empty sends the queued head (conversation) | 534–546, `send-button.tsx:20–29` |
| Speech supported | mic shown only if `AudioContext`, `WebSocket`, `getUserMedia` exist **and** `GET /api/settings/voice` → `sttAvailable:true` | `use-speech-to-text.ts:100–109` |
| Listening | waveform, `aria-pressed`, max session 3 min then auto-stop | `use-speech-to-text.ts:340–345`, `lib/speech/config.ts` |
| Mic blocked (web) | toast error "Microphone access is blocked. Allow it for this site and try again." with action "Show steps" → help modal | `use-voice-input.ts:105–112` |
| No mic / other failure | "No microphone found. Connect one and try again." / "Could not start voice input. Try again." | 115–119 |
| Speech token 402 | toast (server message or "You are out of credits.") with "Upgrade" → billing settings, unless member-scoped limit | `user-input.tsx:317–331` |
| Mode selector | hero only; options Build (`agent`) + Plan (`plan`, flag `mothership-plan-mode`); hidden when only Build; Search (`assistant`) exists only in organization chat | `conversation-mode-selector.tsx:21–24`, `conversation-modes.ts` |
| Effort default | Build `high`, Plan `medium`; options Low/Medium/High/Extra High; with model selector flag also Max; stored `none` → low; without flag Build `max` → `xhigh` | `lib/mothership/model-options.ts:19–58` |
| Effort value source | existing chat: per-chat pick (optimistic) ?? history `effort`; new chat: in-memory `newChatEffort` (not persisted) | `model-selector.tsx:38–56` |
| Model selector flag | adds Model menu (GPT-6 Astra, GPT-6.1 Sol, Opus 5.5; default Build `gpt-6-astra`, Plan `claude-opus-5-5`) and Fast toggle (not for Opus 5.5); persisted in localStorage `mothership-effort` / `mothership-plan-effort` (`modelSelection` only) | `model-selector.tsx:62–93`, `stores/mothership-effort/store.ts:89–90` |
| Dragging files over | drop overlay; drag counter tolerates child enter/leave | `use-file-attachments.ts:288–305` |
| Dragging Sim resources over (`application/x-sim-resource[s]`) | no overlay, `dropEffect=copy`; drop inserts chips | `user-input.tsx:402–450` |
| Draft restored | text (re-chipified once skills load), chips, uploaded files restored; caret at end; focus unless mobile; text typed before hydration wins | 171–216 |
| Plain-text mode (>256 KiB, no skill chip) | overlay off, visible textarea text, max 240px internal scroll | `prompt-editor.tsx:83–85,196` |
| Mention lists still loading | Enter/Tab inside an `@` query is swallowed (no submit) | `use-prompt-editor.ts:921–932` |
| Read-only editor (not used by the composer) | no menus, caret hidden | `prompt-editor.tsx:198–221` |

## Interactions

### Keyboard (textarea `onKeyDown`, `use-prompt-editor.ts:908–1054`, plus the root `onKeyDown`)
- `@` menu open (and not composing): ↓/↑ move (wrap), Enter or Tab (no Shift) select → if lists are hydrating the key is swallowed; if nothing matches the key falls through (Enter submits, Tab default).
- `/` menu open: ↓/↑ move (wrap), Enter/Tab select; nothing matching → falls through.
- ArrowUp (no modifiers) on an **empty** value → recall the last queued message for editing when the host provides it and there are no attachments (conversation only).
- Enter (no Shift, not composing, not a touch-mobile viewport) → submit policy: ignored while uploading; empty → send queued head if streaming; else submit. **Shift+Enter** inserts a newline (native). On touch-mobile Enter always inserts a newline.
- Backspace/Delete with a collapsed caret touching a chip (and not Cmd) deletes the whole token; Cmd+Backspace stays native.
- ←/→ (no modifiers, collapsed, not composing) hop over a chip to its edge.
- Any printable key with the caret inside a chip is blocked and the caret moves to the chip end (Cmd/Ctrl combos pass).
- Shift+Tab (root handler, textarea focused, no menu open, not composing, ≥2 modes) cycles Build → Plan → …, preserving selection; key-repeat ignored (`use-conversation-mode-shortcut.ts`).
- Escape / outside click closes a menu (Radix); closing marks the current `@`/`/` token as dismissed so it does not reopen until the caret leaves it.
- IME: every handler checks `isComposing`; multi-char commits go through the bulk auto-mention path.

### Triggers and chips
- `@` opens the mention menu when it starts a token (position 0 or after whitespace), isn't part of a completed chip, and the query has no newline; `/` opens the skills menu under the same token rule and closes on any of ``\s . , ; : ! ? ( ) { } [ ] " ' ` \ < >`` (`cp/hooks/use-mention-menu.ts:58–160`, `use-prompt-editor.ts:723–805`).
- Selecting inserts `@{label} ` (or ` {label} ` for skills/MCP) replacing the typed query, adding a leading space if the previous char is not whitespace, caret after the trailing space; registers the context and calls `onContextAdd` (Home opens the matching resource tab — see `home-page.md`). Duplicate labels get ` (1)`, ` (2)` suffixes (`insertContext`, 396–446).
- Auto-mention: typing a boundary after `@slack` canonicalises to `@Slack` chip (only with an explicit `@`, never bare words); typing a boundary after `/skill-name` chips the skill; pasted/programmatic text runs the bulk version in one undo step (839–906). `populatePrompt` (suggested actions) first rewrites bare integration names to `@Name`.
- Resource→context map (`constants.ts:114–147`): browser→`browser_tab`, terminal→`terminal_tab`, workflow, knowledgebase→`knowledge`, table (+viewId), dashboard, file, folder, filefolder, task→`past_chat`, log→`logs` (executionId), integration, generic→`docs`; `search`, `sources`, `test` produce no chip.
- Context kinds (23, `chat-context-kind-registry.tsx`): browser_tab (Globe), terminal_tab (TerminalWindow), workflow / current_workflow / workflow_block (Workflow), blocks (none), knowledge (Database), table / table_selection (Table), dashboard (Dashboard), file / file_selection (document icon by extension of the file name), folder / filefolder / project (Folder), workspace (Workspaces), past_chat (Task), logs (Library), docs (none), slash_command (none), integration (block brand icon), skill (AgentSkillsIcon), mcp (McpIcon or managed connector icon).
- Context pruning: a context whose token no longer exists in the text is dropped; on removal the host's `onContextRemove` fires (hero closes the tab when no other chip references it) (`user-input.tsx:263–294`). Submit sends only contexts present in the text (`getActiveContexts`).

### Pointer
- Click anywhere in the container (not on a button/dialog/menu) focuses the textarea; clicks in editor padding focus too.
- `+` chip → browse menu at the chip; Paperclip → native file picker; Slash chip → inserts `/` (with a leading space if needed) at the caret and opens the skills menu.
- Selection gestures (drag, double-click, Shift+arrows, select-all) snap range edges to chip boundaries; caret placed inside a chip snaps to the nearest edge (`chip-selection.ts`, `use-prompt-editor.ts:1101–1140`).

### Paste / copy / cut (`use-prompt-editor.ts:1142–1340`)
1. Clipboard carries a Sim selection context (`text/x-sim-selection`, from file/table viewers) not already attached → insert `@{label} ` chip.
2. Plain text over 1,000,000 characters or 4,000,000 bytes (result or pasted) → blocked, `toast.warning('Paste is too large for a message', {description:'Messages support up to 1,000,000 characters. Attach the content as a file to send more without slowing the editor.'})`. The same limits are mirrored on the textarea as `data-paste-max-*` for the global capture-phase guard.
3. Portable chip links `[label](sim:kind/id)` → rewritten to chip tokens and registered (without opening resource tabs).
4. Clipboard files (no text handled above) → attached via the upload pipeline.
5. Copy/cut of a range containing chips writes portable links (or the single-selection MIME for one selection chip); skill sentinels become `/`.

### Attachments (`cp/hooks/use-file-attachments.ts`)
- Admission before upload (`assertMultiFileUploadAdmission`): ≤20 files including those already attached ("Select up to 20 files at a time."), each ≤ 5 GiB (`MAX_WORKSPACE_FILE_SIZE`; "\"{name}\" is too large. Each file must be 5 GiB or smaller."), total ≤ 25 GiB; failure → `toast.error("Couldn't add files", {description})`.
- Accept list: document (pdf csv doc docx txt md xlsx xls pptx html htm json jsonl yaml yml), code/text extensions, audio (mp3 m4a wav webm ogg flac aac opus), video (mp4 mov avi mkv webm), images (png jpg jpeg gif webp svg …) and zip (`lib/uploads/utils/validation.ts:17–211`). The server rejects zero-byte files (`size ≥ 1`).
- Each file gets a placeholder card immediately (blob preview for browser-renderable image/video; HEIC/HEIF wait for the server derivative), uploads with 3 files in parallel; success fills `key`/`path` and a preview URL `/api/files/serve/{key}?context=mothership[&preview=1 for images]`; failure removes the card and toasts `Couldn't upload "{name}"` with the error; removing an uploading card aborts it.
- Drop and paste use the same pipeline; after a drop the textarea is refocused.

### Focus (`hooks/use-chat-input-focus.ts`)
On mount, in the next frame: focus the textarea unless the viewport is mobile, the window lacks focus, or another input/textarea/select/contenteditable already has focus. After a send finishes, focus returns to the textarea if the composer owned focus and the window is focused (`user-input.tsx:463–473`). Menus restore focus (and a pending caret) to the textarea on close.

### Autosize
Textarea height = `scrollHeight` on every value change (scroller height locked during measurement so the transcript does not jump); re-measured when the textarea width changes; the scroller caps at 200px and scrolls with a hidden scrollbar. `clear()` resets height.

### Drafts (`stores/mothership-drafts/store.ts`, `user-input.tsx:168–261, 484–500`)
- Key per surface: `${workspaceId}:${chatId ?? 'new'}` (the prop chatId: a chat created in place keeps writing under `…:new` until the route remounts).
- Payload `{text, fileAttachments?:[{id,key,filename,media_type,size,path?}], contexts?}`; empty payload deletes the key. Saved 200ms after the last change (skip the first render), flushed on unmount, cleared on submit (with text, chips, files, voice transcript).
- localStorage `mothership-drafts:v1`, zustand-persist `{"state":{"drafts":{…}},"version":1}`; v0 workflow-copilot keys dropped on migrate. Corrupt entry → cleared.

### Voice (`use-voice-input.ts`, `use-speech-to-text.ts`)
Toggle on: remember current text as prefix → token → `getUserMedia({audio:{echoCancellation, noiseSuppression, autoGainControl, channelCount:1, sampleRate:16000}})` → WebSocket → 16 kHz `AudioContext` + `ScriptProcessor(4096)`; every 250ms send buffered PCM16 as base64. Partial and committed transcripts are merged into the editor text with a word diff so manual edits made while dictating win conflicts; the editor's `setValue` re-chipifies. Toggle off / unmount / 3 min stop the stream. Submit resets the transcript.

## Network
| When | Request | Notes |
|---|---|---|
| Mount (browser supports capture) | `GET /api/settings/voice` → `{sttAvailable:boolean}` | stale ∞ |
| Mount | `GET /api/skills?workspaceId=` ; `GET /api/mcp/servers?workspaceId=` + `GET /api/mcp/managed-connections?workspaceId=` | skills/MCP menu (enabled servers of this workspace) |
| First focus (warm) or `+` open | inventory lists as in `home-page.md` §Network (workflows, folders incl. table/KB folder types, tables, files, file folders, knowledge bases, chats, logs first page limit 50, dashboard if flagged); tests not fetched (composer excludes `test`) | `plus-menu-dropdown.tsx:154–160` |
| Attach | `POST /api/files/uploads {purpose:'mothership_attachment', workspaceId, name, contentType, size}` → `{data:{session, uploadToken, transfer}}`; `PUT transfer.url` (or multipart: `POST /api/files/uploads/{id}/parts {partNumbers}` + PUTs); `POST /api/files/uploads/{id}/complete` (header `upload-token`) → `result{path,key,…}`; remove while uploading → `DELETE /api/files/uploads/{id}` | `lib/uploads/client/session-upload.ts:106–153` |
| Thumbnail | `GET /api/files/serve/{key}?context=mothership&preview=1` | images; videos without `preview` |
| Mic start | `POST /api/speech/token {workspaceId}` → `{token}`; 402 → usage toast | |
| Mic stream | `wss://api.elevenlabs.io/v1/speech-to-text/realtime?token=…&model_id=scribe_v2_realtime&audio_format=pcm_16000&commit_strategy=vad&vad_silence_threshold_secs=1.0`; send `{message_type:'input_audio_chunk', audio_base_64, sample_rate:16000, commit:false, previous_text?}`; receive `partial_transcript`, `committed_transcript[_with_timestamps]`, `error`/`auth_error`/`quota_exceeded` (logged) | external origin |
| Effort change, existing chat | `PUT /api/mothership/chats/{chatId}/effort {effort}`; optimistic; failure rolls back that pick and toasts "Couldn't change reasoning effort" | `hooks/queries/mothership-chats.ts:798–840` |
| Submit | handed to the chat engine (`POST /api/mothership/chat …`) with `{text (skill sentinels → '/'), fileAttachments?, contexts?}` | chat-engine spec |

## Flutter-hard parts
1. **Prompt editor with inline chips.** Needs: a `TextField`/`EditableText` whose `TextEditingController.buildTextSpan` renders each context token as normal text but replaces the token's first character with a `WidgetSpan` that is exactly that glyph's advance wide (measure `@`/EM SPACE with a `TextPainter` in the field's style) and paints the 12px icon centred, offset +1.25px; one `WidgetSpan` must map to exactly one code unit so caret/selection offsets stay text offsets. Wrapping must match plain text, so no padding or background. Around it: token ranges recomputed from `(value, contexts)` (longest-label-first regex), and the editing rules — atomic Backspace/Delete, ←/→ hop, printable keys blocked inside a token, selection snapping on every selection change (listen to `controller.selection` changes and correct in a post-frame callback), IME guard via `value.composing.isValid`. Caret rect for menu anchoring via `RenderEditable.getLocalRectForCaret` → global. Font: the system UI stack (Segoe UI on Windows; on web register the same CSS stack), 14px/24px, tracking −0.015em.
2. **Non-focus-stealing menus anchored at the caret.** `@` and `/` menus must open above the caret while focus and typing remain in the field; arrow/Enter/Tab/Escape routed from the field's key handler to the menu (use `OverlayPortal` + `CompositedTransformFollower`, no `FocusScope` in the overlay). The `+` browse menu does take focus (search box) and has nested submenus with folder trees.
3. **Clipboard formats.** Custom MIME `text/x-sim-selection` and HTML flavours are not available through `Clipboard`; web needs a JS `paste`/`copy` listener (`package:web`), Windows needs a native clipboard plugin. Pasting files from the clipboard into a text field has the same requirement. Record unported parts in `known-gaps.md`.
4. **File drag and drop** onto the composer (OS files) on web (`dragenter/over/drop` via JS interop or `desktop_drop`), plus in-app drags carrying `application/x-sim-resource[s]` from resource tabs and sidebar chats.
5. **Voice (web only).** `getUserMedia`, `AudioContext` + `ScriptProcessorNode` (or AudioWorklet), PCM16/base64 encoding, external WebSocket — all through `dart:js_interop`; waveform from per-band RMS levels. Windows: not offered (gap, mic button hidden because `isSupported` is false).
6. **Autosize with a locked scroller** (avoid transcript jump) and the 200px cap with hidden scrollbar; plain-text fallback above 256 KiB.
7. **Paste admission limits** before the text reaches the field (`TextInputFormatter` cannot see the paste as one event; handle via the web paste listener / `Actions` override of `PasteTextIntent`).

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | `user-input.tsx:581–585` | container max 704, radius 16, 1px border, px 10 py 8 | | |
| 2 | token | `user-input.tsx:582` | fill `--white` light / `--surface-4` dark | | |
| 3 | token | `user-input.tsx:584`, `globals.css:468,995` | hero `shadow-ambient` 0 0 12px rgba(0,0,0,.08) / .22; none in conversation | | |
| 4 | layout | `user-input.tsx:605–608` | editor max 200px; hero min 56px | | |
| 5 | layout | `constants.ts:68–72` | field padding 4px, min line 24px | | |
| 6 | token | `constants.ts:59–60`, `globals.css:74–76` | system font stack, 14px fine pointer / 16px coarse, lh 24, tracking −0.015em | | |
| 7 | token | `constants.ts:79–85` | text and caret `--text-primary`, placeholder `--text-muted` | | |
| 8 | state | `animated-placeholder-effect.tsx:15–22` | hero animated placeholder; conversation "Send message to Sim" | | |
| 9 | state | `use-animated-placeholder.ts:3–25` | four suffixes, 60 / 2000 / 35 / 400 ms timings, loop | | |
| 10 | layout | `prompt-editor.tsx:147–163` | chip icon 12px centred in the trigger glyph slot, +1.25px, `--text-icon` | | |
| 11 | state | `cp/utils.ts:29–41` | trigger: skill/mcp EM SPACE, slash_command `/`, others `@`; current_workflow untokenised | | |
| 12 | state | `chat-context-kind-registry.tsx` | 23 kinds with the listed icons | | |
| 13 | state | `prompt-editor.tsx:83–85,196` | >256 KiB without skill chip → visible text, no overlay, 240px | | |
| 14 | layout | `input-toolbar.tsx:37–83` | toolbar wraps; leading/trailing min 30px, gap 4 (0 under 280px) | | |
| 15 | layout | `user-input.tsx:615–650` | order: Add resources, Attach file, Skills, mode | | |
| 16 | layout | `chip.tsx:66–81`, `chrome.ts:58,68` | round icon chips 32×30, 16px `--text-icon` icon | | |
| 17 | token | `chrome.ts:83` | round chip hover `--surface-hover` | | |
| 18 | interaction | `user-input.tsx:617–646` | tooltips (top) "Add resources", "Attach file", "Skills" | | |
| 19 | state | `conversation-mode-selector.tsx:21–24` | mode selector only in the hero and only with ≥2 modes | | |
| 20 | keyboard | `use-conversation-mode-shortcut.ts:24–63` | Shift+Tab cycles modes in the focused textarea, keeps selection, ignores repeat | | |
| 21 | interaction | `conversation-mode-selector.tsx:52–56` | tooltip "Select mode ⇧ Tab", hidden while open | | |
| 22 | state | `model-options.ts:19–58` | effort default High (Plan Medium); options Low…Extra High (+Max with flag) | | |
| 23 | layout | `model-setting-trigger.tsx:136–155` | effort chip shows value label `text-sm --text-icon`; ≤320px shows Brain icon | | |
| 24 | interaction | `model-selector.tsx:94–110` | effort menu side top, radio items | | |
| 25 | network | `mothership-chats.ts:798–840` | existing chat effort → `PUT …/effort`, optimistic, rollback + toast | | |
| 26 | state | `model-selector.tsx:46,55` | new chat effort kept in memory until send | | |
| 27 | state | `model-selector.tsx:62–93` | Model menu and Fast toggle only with `mothership-model-selector`; no Fast for Opus 5.5 | | |
| 28 | layout | `mic-button.tsx:88–114` | mic 28px round; Mic 16px ↔ 18px waveform cross-fade 300ms | | |
| 29 | state | `use-speech-to-text.ts:100–109` | mic hidden unless browser APIs exist and `sttAvailable` | | |
| 30 | state | `use-voice-input.ts:89–120` | three mic error toasts; blocked → "Show steps" opens help modal | | |
| 31 | layout | `microphone-permission-help.tsx` | help ChipModal sm with the listed copy | | |
| 32 | network | `use-speech-to-text.ts:220–265` | `POST /api/speech/token` then ElevenLabs WSS with the listed params | | |
| 33 | interaction | `use-speech-to-text.ts:140–170,338–345` | 250ms PCM16 chunks; 3 min cap | | |
| 34 | interaction | `use-voice-input.ts:47–73,129–134` | transcript merges around manual edits | | |
| 35 | state | `user-input.tsx:317–331` | 402 → toast with "Upgrade" (not for member limits) | | |
| 36 | layout | `composer-action-button.tsx` | send 28px circle | | |
| 37 | token | `composer-action-button.tsx` | enabled #383838/#E0E0E0, hover #575757/#CFCFCF, disabled #808080 | | |
| 38 | state | `send-button.tsx:20–40` | idle ArrowUp 16 "Send message"; streaming StopFilled 14 "Stop generation" | | |
| 39 | state | `user-input.tsx:296` | send enabled only with text or uploaded file, not sending, nothing uploading | | |
| 40 | keyboard | `use-prompt-editor.ts:963–973` | Enter submits (not Shift, not composing, not touch-mobile); Shift+Enter newline | | |
| 41 | keyboard | `user-input.tsx:534–546` | Enter while uploading ignored; empty Enter while streaming sends queued head | | |
| 42 | keyboard | `use-prompt-editor.ts:956–961`, `user-input.tsx:552–558` | ArrowUp on empty recalls queued tail (no attachments) | | |
| 43 | keyboard | `use-prompt-editor.ts:984–998` | Backspace/Delete removes a whole chip; Cmd+Backspace native | | |
| 44 | keyboard | `use-prompt-editor.ts:1002–1032` | ←/→ hop over chips | | |
| 45 | keyboard | `use-prompt-editor.ts:1035–1050` | typing inside a chip blocked, caret to chip end | | |
| 46 | interaction | `use-prompt-editor.ts:1101–1140`, `chip-selection.ts` | selection edges snap to chip boundaries | | |
| 47 | keyboard | `use-prompt-editor.ts:910–953` | menu open: ↑/↓ wrap, Enter/Tab select, hydrating swallows, no-match falls through | | |
| 48 | interaction | `cp/hooks/use-mention-menu.ts:58–90` | `@` opens only at token start, not inside completed chips, no newline in query | | |
| 49 | interaction | `use-prompt-editor.ts:765–805` | `/` opens at token start, closes on boundary punctuation | | |
| 50 | interaction | `use-prompt-editor.ts:708–716,723–760` | dismissed trigger does not reopen until the caret leaves it | | |
| 51 | interaction | `use-prompt-editor.ts:470–517` | selection inserts `@label ` with auto leading space, caret after | | |
| 52 | interaction | `use-prompt-editor.ts:396–446` | external context inserts dedupe labels with ` (n)` | | |
| 53 | interaction | `use-prompt-editor.ts:839–906` | `@slack`+boundary → `@Slack` chip; `/skill`+boundary → skill chip; bulk on paste | | |
| 54 | interaction | `user-input.tsx:377–385` | `populatePrompt` mentionifies bare integration names, focuses at end | | |
| 55 | layout | `plus-menu-dropdown.tsx:427–438` | `+`/mention menu above, align start, offset 8, 360px; mention max 280px | | |
| 56 | state | `plus-menu-dropdown.tsx:80,215–252` | browse hides integrations; mention shows ≤5 per family with headings | | |
| 57 | state | `available-resources.ts:38` | composer excludes tests | | |
| 58 | interaction | `plus-menu-dropdown.tsx:399–404` | mention menu never takes focus | | |
| 59 | layout | `skills-menu-dropdown.tsx:180–245` | skills menu ≤300px; skills then MCP; empty "No skills or MCP servers" | | |
| 60 | interaction | `use-prompt-editor.ts:807–833` | Slash chip inserts `/` (leading space if needed) and opens the menu | | |
| 61 | interaction | `user-input.tsx:560–563` | `+` chip opens browse menu at the chip | | |
| 62 | interaction | `use-prompt-editor.ts:1142–1196` | paste over 1,000,000 chars / 4 MB blocked with the warning toast | | |
| 63 | interaction | `use-prompt-editor.ts:1198–1250` | `[label](sim:kind/id)` pastes back as chips without opening tabs | | |
| 64 | interaction | `use-prompt-editor.ts:1252–1272` | clipboard files are attached | | |
| 65 | interaction | `use-prompt-editor.ts:1292–1340` | copy/cut write portable links; sentinel → `/` | | |
| 66 | interaction | `user-input.tsx:502–527` | submit sends plain value, uploaded files, active contexts; composer and draft cleared | | |
| 67 | layout | `attached-files-list.tsx:118–126,166–175` | attachments above editor: 48px media / 48px-tall ≤220px file cards, gap 6, mb 6 | | |
| 68 | token | `attached-files-list.tsx:21–22,95–106` | card `--surface-5`/`--border`, hover `--surface-active`; tile `--surface-7`/dark `--surface-3` | | |
| 69 | state | `attached-files-list.tsx:110–114,145` | uploading veil with 14px loader; remove hidden | | |
| 70 | layout | `attached-files-list.tsx:135–151` | 16px remove badge at top-right 2px | | |
| 71 | interaction | `attached-files-list.tsx:63,128–133`, `use-file-attachments.ts:281–287` | image opens lightbox; others open in a new tab | | |
| 72 | state | `use-file-attachments.ts:148–167`, `admission.ts:6–98` | ≤20 files, ≤5 GiB each, ≤25 GiB total; "Couldn't add files" toast | | |
| 73 | network | `use-file-attachments.ts:182–243`, `session-upload.ts:106–153` | upload session `mothership_attachment`, 3 parallel, complete, abort on remove | | |
| 74 | state | `use-file-attachments.ts:224–238` | failed upload removes the card and toasts `Couldn't upload "{name}"` | | |
| 75 | layout | `drop-overlay.tsx:31–43` | overlay inset 6, radius 14, dashed 1.5px, "Drop files" + nine icons | | |
| 76 | interaction | `user-input.tsx:402–450` | resource drags insert chips; file drops upload and refocus | | |
| 77 | interaction | `use-chat-input-focus.ts:9–23` | autofocus rule (not mobile, window focused, nothing else editable focused) | | |
| 78 | interaction | `user-input.tsx:463–482` | focus returns after a send; container click focuses textarea except on buttons/menus/dialogs | | |
| 79 | interaction | `use-auto-size-textarea.ts:26–74` | grows to content up to 200px, re-measures on width change, no transcript jump | | |
| 80 | state | `user-input.tsx:168–261`, `mothership-drafts/store.ts:63–93` | draft per `${ws}:${chatId\|new}`, 200ms debounce, flush on unmount, `mothership-drafts:v1` v1 | | |
| 81 | state | `user-input.tsx:171–216` | draft restore: chips, files, text, caret at end, focus (desktop) | | |
| 82 | network | `use-speech-to-text.ts:108`, `contracts/common.ts:91–96` | `GET /api/settings/voice` once | | |
| 83 | network | `use-prompt-editor.ts:182–192` | skills and MCP lists for the workspace | | |
| 84 | network | `plus-menu-dropdown.tsx:154–160`, `prompt-editor.tsx:82,227` | inventory lists start on first focus, not page load | | |
| 85 | interaction | `user-input.tsx:263–294` | removing the last token of a context reports `onContextRemove` | | |
