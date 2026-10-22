# Screen specs

One file per screen or shared surface, written by a mapper agent before the screen is built (plan §7), named after the React route folder (`workspace-sidebar.md`, `auth-login.md`, `editor-panel-editor.md`). Template:

```markdown
# <Screen name>
Upstream: <route folder(s)>, commit <UPSTREAM_COMMIT>
Phase: <n>

## Files
<React files with line counts; hooks; stores; emcn components used>

## Layout
<measurements: widths, heights, paddings, gaps, breakpoints, resizable bounds, z-order; parity ids assigned to the elements that will be compared (`data-parity` in the capture script ↔ `Semantics(identifier:)`)>

## Tokens
<every token used, by element>

## States
<loading, empty, error, permission-denied, feature-flag-gated, hosted-only, dirty/unsaved, offline/reconnecting>

## Interactions
<pointer, keyboard (shortcuts, editable-target rule), drag and drop, context menus, focus order>

## Network and realtime
<every request in order with method, path, query keys, body shape; socket events emitted and consumed; invalidations after mutations>

## Parity checklist
| # | Aspect | React source | Expected | Flutter evidence | Status |
|---|---|---|---|---|---|
| 1 | layout | file:line | ... | | |
```

Aspects: layout | token | state | interaction | network | keyboard. Status: pass | gap (→ known-gaps.md) | verified-by-review. The verifier fills the last two columns; the React source wins over the spec on disagreement.
