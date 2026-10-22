# Sim web app: design system and app shell (reference for the Flutter port)

Mapped from upstream commit 27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c (v0.9.30). Paths are relative to the repo root.
Tailwind v4; all tokens live in `apps/sim/app/_styles/globals.css` (`@theme inline`, `:root`, `.light`, `.dark`). No tailwind.config.

## 1. Tokens

### 1a. Colors (light = `:root, .light`; dark = `.dark`). Theme switching is class-based (`.dark` on `<html>`).

| Token | Light | Dark |
|---|---|---|
| --bg (main canvas) | #fefefe | #1b1b1b |
| --surface-1 (sidebar, panels) | #fbfbfb | #1e1e1e |
| --surface-2 (cards, blocks, modals) | #ffffff | #232323 |
| --surface-3 (popovers, headers) | #f7f7f7 | #242424 |
| --surface-4 (button base) | #f5f5f5 | #292929 |
| --surface-5 (inputs) | #f3f3f3 | #363636 |
| --surface-6 | #e5e5e5 | #454545 |
| --surface-7 | #d9d9d9 | #505050 |
| --surface-hover | #f2f2f2 | #262626 |
| --surface-active | #ececec | #2c2c2c |
| --workflow-edge | #e0e0e0 | #454545 |
| --text-primary | #1a1a1a | #e6e6e6 |
| --text-secondary | #525252 | #cccccc |
| --text-tertiary | #5c5c5c | #b3b3b3 |
| --text-muted | #7a7a7a | #6e6e6e |
| --text-subtle | #8c8c8c | #7d7d7d |
| --text-body | #434343 | #c1c1c1 |
| --text-icon | #5a5a5a | #969696 |
| --text-icon-muted | #5c5c5c | #949494 |
| --text-inverse | #ffffff | #1b1b1b |
| --text-muted-inverse | #a0a0a0 | #b3b3b3 |
| --text-error | #ef4444 | #ef4444 |
| --text-placeholder | #8d8d8d | #8d8d8d |
| --text-success | #22c55e | #22c55e |
| --border (all neutral lines) | #d8d8d8 | #444444 |
| --border-success | #e0e0e0 | #575757 |
| --brand-agent | #6f3dfa | #701ffc |
| --brand-secondary | #33b4ff | #33b4ff |
| --brand-accent / -hover | #33c482 / #2dac72 | same |
| --brand-blue (progress/done) | #3b6fe0 | #5b8def |
| --selection (interactive highlight) | #1a5cf6 | #4b83f7 |
| --selection-muted (::selection bg) | #1a5cf647 | #4b83f759 |
| --warning | #ea580c | #ff6600 |
| --surface-inverted / -hover | #1b1b1b / #363636 | #242424 / #363636 |
| --border-inverted | #363636 | #3d3d3d |
| --tooltip-bg | #1b1b1b | #fdfdfd |
| --code-bg / -foreground / -line-number | #f5f5f5 / #1a1a1a / #737373 | #1f1f1f / #eeeeee / #a8a8a8 |
| --error / -muted / -emphasis | #dc2626 / #fecaca / #b91c1c | #f87171 / #f6d2d2 / #b91c1c |
| --caution | #f59e0b | #f59e0b |
| --success | #22c55e | #22c55e |
| --brand-knowledge | #00b0b0 | #00b0b0 |
| --selection-dark | #264f78 | #264f78 |
| --selection-bg | #add6ff | #264f78 |
| --highlight-search-active / -search | #f6ad55 / #fcd34d | same |
| --highlight-match-bg / -text | #bae6fd / #0369a1 | rgba(51,180,255,.2) / #7dd3fc |
| --indicator-online / -active / -inactive / -seat-filled | #33c482 / #4ade80 / #b7b7b7 / #34b5ff | same |
| --scrollbar-thumb-color / -hover | #c0c0c0 / #a8a8a8 | #5a5a5a / #6a6a6a |
| --thinking-ink-current / -inner / -outer / -glow | #2c2c2c / #2c2c2c / #5f5f5f / rgba(255,255,255,.6) | #d6d6d6 / #a7a7a7 / #d6d6d6 / rgba(255,255,255,.9) |

Terminal status, light: error bg #fef2f2 border #f87171; info bg #f7f7f7 border #a3a3a3 text #525252; warning bg #fefce8 border #facc15 text #a16207.
Terminal status, dark: error bg #491515 border #883827; info bg #383838 border #686868 text #b7b7b7; warning bg #3d3520 border #5c4d1f text #d4a72c.

Badge colors, light (bg / text): success #bbf7d0/#15803d, error #fecaca/#dc2626, gray #e7e5e4/#57534e, blue #bfdbfe/#1d4ed8, blue-secondary #bae6fd/#0369a1, purple #e9d5ff/#7c3aed, orange #fed7aa/#c2410c, amber #fde68a/#a16207, teal #99f6e4/#0f766e, cyan #cffafe/#0891b2, pink #fbcfe8/#be185d.
Badge colors, dark (bg / text): success rgba(34,197,94,.2)/#86efac, error #551a1a/#fca5a5, gray #3a3a3a/#a8a8a8, blue rgba(59,130,246,.2)/#93c5fd, blue-secondary rgba(51,180,255,.2)/#7dd3fc, purple rgba(168,85,247,.2)/#d8b4fe, orange rgba(249,115,22,.2)/#fdba74, amber rgba(245,158,11,.2)/#fcd34d, teal rgba(20,184,166,.2)/#5eead4, cyan rgba(14,165,233,.2)/#7dd3fc, pink rgba(236,72,153,.2)/#f9a8d4.

Other: auth button bg/border #ffffff text #000 hover #e0e0e0. Stock palette pinned to Tailwind v3 hex (gray-50..950 = #fafafa #f5f5f5 #e5e5e5 #d4d4d4 #a3a3a3 #737373 #525252 #404040 #262626 #171717 #0a0a0a). No oklch anywhere. Browser theme-color light #ffffff dark #0c0c0c.

Color usage rules (`.claude/rules/sim-styling.md`): value text --text-body; muted/placeholder/labels --text-muted; icons --text-icon; neutral borders --border; field surfaces --surface-5 light / --surface-4 dark; active row --surface-active; hover row --surface-hover; errors --text-error. No focus rings on chip surfaces.

### 1b. Type scale
text-micro 10px · text-xs 11px (lh 1.5) · text-caption 12px · text-small 13px · text-sm 14px · text-base 15px · text-md 16px · text-lg 18px.
Weights only 400/500/600 (400 default, headings inherit). Field titles text-small; hints/errors text-caption. Menu rows 28px at text-small (sm variant 24px at text-caption). Chip pills 30px at text-sm.
Page heading: Season, 26px (28px at >=640), leading 1.15, tracking -0.01em (`packages/emcn/src/components/page-heading/page-heading.ts`).
Letter-spacing: body 0.28px; `.workspace-root` 0.02em (reset for code/kbd/.font-mono). 1rem = 16px.

### 1c. Radii
--radius 8px. radius-xs 2, sm 4, md 6, lg 8, xl 12, 2xl 16.
Chips/fields/menu rows 8px · menus/popovers/modals/search palette 12px · Button 5px (icon 4px) · toast 12px compact (<=46px tall) else 16px · scrollbar thumb 8px · identity tile 4px@16px, 8px@36px.

### 1d. Shadows
subtle 0 2px 4px 0 rgba(0,0,0,.08) · medium (menus) 0 4px 12px rgba(0,0,0,.1) · overlay 0 10px 30px rgba(0,0,0,.11) (dark .3) · kbd 0 4px 0 0 rgba(48,48,48,1) · kbd-sm 0 2px 0 0 · card 0 1px 3px rgba(0,0,0,.04) · ambient (chat input) 0 0 12px 0 rgba(0,0,0,.08) (dark .22).
Chip border-shadow ring: light `0 0 0 1px rgba(28,40,64,.08), 0 1px 3px 0 rgba(28,40,64,.1)`; dark `0 0 0 1px var(--border), 0 1px 3px 0 rgba(0,0,0,.3)`.

### 1e. Lines, spacing, z-index, breakpoints
Border width 1px (0.5px at 2dppx). Spacing: 4px scale. ChipModal rhythm: label-control gap 9px, field gutter px-2; body gap 16px, padding px-2 pt-4 pb-4.5; header px-4 pt-3; footer px-4 pt-2 pb-2 tinted. Legacy Modal footer px-4 py-3 bg surface-3@50%.
Settings sections: muted text-small label, then `mt-[9px] mb-3 h-px` divider; sections gap-7. Scroll fades 12px; OverflowText 18px mask.
Z-index: dropdown 100, toast 150, modal 200, popover 300, tooltip 400, takeover 500, shell-gate 600.
Breakpoints: sm 640, md 768 (mobile/desktop split), lg 1024, xl 1280, 2xl 1536. Chat column 704px. Below md on coarse pointers chips/menu rows get 44px touch target.

### 1f. Motion
caret-blink 1.25s · ring-pulse 1.5s · stream-fade-in 300ms ease-out · slide-in-bottom 400ms cubic-bezier(.16,1,.3,1) · collapsible 300ms cubic-bezier(.4,0,.2,1) · running-hatch-scroll 900ms linear (26px period) · popovers fade+zoom-95, slide 8px from trigger side · modal zoom-in-95 200ms · tooltip 150ms ease-out · sidebar chevrons 150ms · prefers-reduced-motion -> 0.01ms.

## 2. Fonts and assets
- Document font **Season Sans** variable 300–800: `apps/sim/app/_styles/fonts/season/SeasonSansUprightsVF.woff2` (also `public/brand/fonts/`). Fallback Arial metric-adjusted. `<body class="font-season">`.
- **Inter** (Google, variable 100–900) only for chat message content, composer, message sources, rich markdown editor.
- Mono: `var(--font-martian-mono, ui-monospace)`, SFMono, Menlo… (Martian Mono not loaded in product).
- `public/`: icon.svg; favicon/*; logo/wordmark.svg, wordmark-dark.svg, sim-landing.svg, b&w/*; brandbook/*; static/{discord,github,linkedin,slack,x}; tooltips/*.mp4. Wordmark also inline: `packages/emcn/src/components/sim-wordmark/`.

## 3. Component catalog
emcn: 57 component dirs in `packages/emcn/src/components/` (barrel `index.ts`), built on Radix + cva.
- Chip family: chip (Chip/ChipLink 30px, px-2, gap-1.5; variants primary, destructive, border-shadow, border, outline, filled; `active`), chip-input, chip-textarea, chip-copy-input, chip-dropdown, chip-select, chip-combobox (searchable, virtualized), chip-modal (ChipModal, ChipModalField types input/email/textarea/dropdown/copy/file/emails/custom; ChipConfirmModal; Tabs; sizes sm 440 / md 500 / lg 600 / xl 800 / full 1200; outer shell rounded-xl surface-4 (dark surface-5) p-[3px], inner rounded-lg on --bg), chip-switch (segmented), chip-button-group, chip-tag (20px), chip-date-picker, chip-time-picker, chip-emails-input.
- Fields: input, textarea, input-otp, secret-input, secret-reveal, tag-input, label, checkbox, switch, slider, combobox, time-picker, calendar.
- Overlays: modal (legacy; overlay bg-black/10 + 2px blur), dropdown-menu (MENU_STYLES: rounded-xl, --bg, --border, shadow-medium, p-1, rows 28px), popover, tooltip (cursor-following, no delay; rounded-lg --bg --border text-caption shadow-xs max 256px px-2 py-1.5), toast, lightbox, wizard, details-panel (right slide-in with resize handle).
- Display: avatar, badge, banner, info, info-card, progress-item, skeleton, status-page, page-heading, sim-wordmark, code (Prism editor), charts (bar, line, dashboard-metric, data-table, animated-number, legend, tooltip), table, collapsible-card, expandable, field-divider, overflow-text, scroll-fade.
- Actions: button (variants default, active, 3d, outline, primary, destructive, secondary, tertiary, ghost, subtle, ghost-secondary, quiet; sizes sm 11px, md 12px, icon 20px), bulk-action-button, composer-action-button, row-actions, upload-preview-button, tab-strip (draggable, framer-motion), mobile-touch-target.
- Helpers `src/lib`: cn.ts, keyboard.ts, preview-wheel-zoom.ts. Chip chrome tokens: `components/chip/chrome.ts`.
App-local `apps/sim/components/ui/`: activity-status, generated-password-input, progress, select, shimmer-text, thinking-loader.

## 4. Shell layout and navigation
Constants: `apps/sim/stores/constants.ts` (mirrored in globals.css and a pre-hydration script in `apps/sim/app/layout.tsx`). Chrome: `apps/sim/app/workspace/[workspaceId]/components/workspace-chrome/workspace-chrome.tsx`.

| Element | Default | Min | Max |
|---|---|---|---|
| Sidebar expanded | 224px | 224 | min(400, 30vw) |
| Sidebar collapsed rail | 48px | — | 0 on macOS desktop shell |
| Workflow right panel | 320px | 290 | 40vw |
| Workflow terminal (bottom) | 206px | 30 | 70vh |
| Editor connections | 172px | 30 | 300 |
| Output panel | 560px | 280 | — |
| Home chat resource panel | 50vw | 280 | 80%; chat column min 480 |
| Terminal block column | 240px | — | — |

(CSS default --sidebar-expanded-width says 256px but SIDEBAR_WIDTH.DEFAULT is 224px.) Resize handle 8px at the sidebar's right edge; clicking it when collapsed expands. Collapse state cookie `sidebar_collapsed`; width localStorage `sidebar-state`.
Viewport h-dvh bg --surface-1; sidebar `<aside>` --surface-1; content pane --bg with border-l --border. Below 768px: sidebar hidden, top bar with "Navigation" chip, sidebar opens full-screen. Collapsed-rail hover peek: 90ms open / 180ms close, floating card rounded-lg bordered left-2 z-modal. Electron title-bar lane 38px.
Sidebar: header px-2 pt-2 with WorkspaceHeader (switcher dropdown w-64) + Search and Collapse chips (30px). Section gap 16px; item gap 1px; rail chip 32px wide. Section titles text-caption muted 18px row. Nav rows are Chips 30px, 16px icons.

Navigation (`.../w/components/sidebar/sidebar.tsx` lines 757–856):
- Top: New chat (Home) -> /workspace/{id}/home (or "New workflow" when chat disabled); Dashboard -> /dashboards (flag); Changelog -> /changelog (flag); Integrations -> /integrations (also active on /skills).
- "Chats" section -> /workspace/{id}/chat/{chatId}.
- "Workspace" section: Tables (/tables, flyout), Files (/files, flyout), Knowledge bases (/knowledge), Tests (/tests, flag), Logs (/logs).
- "Workflows": folder/workflow tree -> /workspace/{id}/w/{workflowId}.
- Footer: account menu (Settings general, Teammates, Recently deleted, Billing (gated), Organization /o/{orgId}, Sign out); help menu (Docs, Join Slack, Contact support).
Settings sections (`apps/sim/components/settings/navigation.ts:96-127`, 31 `UnifiedSettingsSection`s): general, desktop*, browser*, terminal*, requests, access-control, audit-logs, forks, billing, teammates, organization, usage, secrets, connected-accounts, custom-tools, mcp, apikeys, workflow-mcp-servers, byok, sandboxes, chat-keys, inbox, recently-deleted, sso, security, data-retention, data-drains, whitelabeling, custom-blocks, admin, mothership, self-host (* = desktop-shell-only, `requiresDesktopSurface`). Gating flags per entry: `requiresHosted`, `requiresEnterprise`, `requiresMax`, `requiresSuperUser`, `requiresAdminRole`, `selfHostedOverride`, `organizationSection` (lines 146-174). `OrganizationSettingsSection` (lines 46-63, 17): knowledge-graphs, integrations, connected-accounts, search-mcp, search-slack, members, billing, usage, access-control, requests, audit-logs, sso, security, data-retention, data-drains, whitelabeling, recently-deleted. `AccountSettingsSection` (5): general, billing, api-keys, admin, mothership. `SelfHostSettingsSection` (3).
Theming (`apps/sim/app/_shell/providers/theme-provider.tsx`): next-themes class attribute, enableSystem, default 'system', storage key `sim-theme`. Forced light on login, signup, reset-password, sso, invite, verify, chat, resume, oauth, oauth-error, f, unsubscribe, cli, credential-groups.

## 5. Global UX behaviors
Shortcuts (`apps/sim/app/workspace/[workspaceId]/utils/commands.ts`, provider `providers/global-commands-provider.tsx`, Mod = Cmd/Ctrl): Mod+K open-search · Mod+B toggle-sidebar · Mod+L goto-logs · Mod+Shift+P add-workflow · Mod+Shift+A add-agent · Mod+Enter run-workflow · Mod+Shift+Enter accept-diff-changes · Mod+F search/replace · Mod+Alt+F focus toolbar search · Mod+Shift+F fit-to-view · Mod+D clear terminal. Each has `allowInEditable`.
Toasts (`packages/emcn/src/components/toast/toast.tsx`): bottom-right, 280px (min(100vw-2rem,280)), 16px inset, auto-dismiss 5s (actions persist), hover expands and pauses, up to 3 stacked (13px offset, 0.05 scale step, 8px gap expanded), easing [0.22,1,0.36,1] 0.4s. Variants default(Bell)/info/success/warning/error; card --bg with --border.
Command palette (cmdk, `.../sidebar/components/search-modal/search-modal.tsx`): fixed top 15%, width min(500px,100%-32px), rounded-xl surface-4/5 shell with inner --bg card. Groups: Sim, Blocks, Triggers, Tools, Tool operations, Pages, Workflows, Workspaces, Files, Tables, Knowledge Bases, Logs, Connected Integrations, Integrations, Chats. State in `apps/sim/stores/modals/search/` (other modal store: `modals/variables/`).
Context menus: emcn DropdownMenu at cursor (~31 files use onContextMenu); one separator before destructive actions.
Tooltips: Tooltip/FloatingTooltip follow cursor 16px offset, no delay; SidebarTooltip when collapsed.
Drag and drop: native HTML5 drag in ~23 files (sidebar tree, table grid columns, tab-strip, file viewer); drop target surface-active fill + 1px --text-subtle outline. Canvas is @xyflow/react 12.

## 6. Icons
- UI icons: `packages/emcn/src/icons/` — 191 inline-SVG React components (24x24 viewBox, stroke currentColor, strokeWidth ~1.55, round caps) + `animate/`. No lucide. Default 14px (16px in chips), color --text-icon.
- Brand/integration icons: `apps/sim/components/icons.tsx` (10,337 lines): 349 `export function` + 20 `export const` inline SVGs; 32 embed raster images. Also `components/icons/document-icons.tsx`, `nebius.tsx`.
- Blocks (~371 in `apps/sim/blocks/blocks/`) declare `icon`, `bgColor`, optional `iconColor`. `blocks/brand-icon.tsx` (BrandIcon), `blocks/block-tile.tsx` -> `BlockTileView` in `@sim/workflow-renderer`.
- Identity tiles: `apps/sim/components/identity-tile/identity-tile.tsx`.

## 7. i18n and animation
No i18n; English literals; `<html lang='en'>`.
framer-motion 12 used in product only for: emcn toast, emcn tab-strip, charts animated-number, knowledge-base/table bulk action bars (opacity 0->1, y 10->0, 0.2s), consent banner. Everything else is CSS (tw-animate-css, Tailwind transitions, keyframes in 1f).
