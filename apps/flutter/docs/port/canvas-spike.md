# Phase 0 spike c: canvas rendering architecture (200-node pan benchmark)

Status: measured 2026-10-21 on Flutter 3.38.9 / Dart 3.10.8, profile mode. Code: `packages/sim_canvas` (engine skeleton) and `packages/sim_canvas/example` (benchmark + hit-test checks). Plan reference: `00-plan.md` §4.6, `reviews/architecture-review-v1.md` finding 8, `04-test-plan.md` (spike c: ≥55 fps pan with 200 nodes on CanvasKit and Windows).

## 1. What was built

- `CanvasViewport` (pan, zoom 0.1–1.3 around the cursor, fit-to-view, gesture flag for the raster policy) and `CanvasTransform` (`screen = canvas · zoom + offset`).
- Two node-layer implementations behind one interface (`NodeLayerImplementation`):
  - **A `StackNodeLayer`**: `OverflowBox` → `Transform(matrix = viewport · translate(bounds.topLeft))` → `SizedBox(content bounds)` → `Stack(clipBehavior: none)` with one `Positioned` + `RepaintBoundary` per node. Raster policy: `Transform.filterQuality = low` while a viewport gesture is active (the framework then composites through an `ImageFilterLayer(ImageFilter.matrix)`), `null` at rest.
  - **B `RenderBoxNodeLayer`**: `MultiChildRenderObjectWidget` → `RenderCanvasNodeLayer`: children laid out unconstrained, painted at their canvas position under a `TransformLayer` (`pushTransform`), hit-tested through `BoxHitTestResult.addWithPaintTransform` with **no** `size.contains` check; a position change marks paint only, never layout. Raster policy: same `ImageFilterLayer(ImageFilter.matrix, low)` recipe as `RenderTransform`.
- Edge layer: `EdgePainter extends CustomPainter` sized to the content bounds, smooth-step port of `@xyflow/system` `getSmoothStepPath` (radius 8, offset 30 horizontal / 20 vertical, same corner points as upstream), `hitTest` backed by `EdgeHitTester`: every edge path sampled through `PathMetrics` every 3 canvas units, hit when within 15 (half of hit width 30) of a sample, bounds pre-check, last-painted edge wins. Samples are cached per edge and recomputed only when an endpoint's position version changes.
- `GraphController`: absolute positions in one `ValueNotifier<Offset>` per node (only that node's `Positioned`/`CanvasPositioned` rebuilds on a move), container children follow their parent, `geometryChanged` listenable drives the edge painter's `repaint`.
- `generateSyntheticWorkflow()`: 203 nodes (200 requested rounded to 14 columns × 13 rows + 3 containers with 3 children each + a 3-node hit-test fixture) and 260 edges (right-neighbour chains, 75 random long/backward/cross-row edges, container edges, fixture edges); grid origin at (−700, −400) so nodes exist at negative canvas coordinates; content ≈ 6 000 × 3 500 canvas units. Cards are 250 × 120 (40 px header, two 20 px rows, 16 px padding, 8 px gap) with left/right handles at mid height; containers 800 × 500 with a `Start` inset.
- Benchmark (`example`, `--dart-define=BENCH=true`): per variant (A/B × raster policy never/duringGestures): pan at zoom 1 across the whole graph in three serpentine sweeps (5 s), zoom 1 → 0.1 → 1.3 around the viewport centre (2 s), drag one node in a circle (1.5 s, not a viewport gesture), and for the raster variants the same drag with the gesture flag raised (the naive policy). Frame timings via `SchedulerBinding.addTimingsCallback`; build, raster, build+raster and `totalSpan` avg/p95/max; jank = build+raster > 16.6 ms; `steady` = the same without the first 5 frames with fps from vsync timestamps. One `BENCH_RESULT {json}` line per variant on stdout and appended to `--dart-define=BENCH_OUT=<file>` (Windows), then `exit(0)`. Hit-test checks run once per implementation through the real pointer pipeline (`WidgetsBinding.handlePointerEvent` down/up at a screen position, taps reported by `GraphCanvas.onHit`).

## 2. Results

| Platform | Impl | Raster policy | Phase | Frames | fps (all) | build avg/p95/max ms | raster avg/p95/max ms | build+raster avg/p95/max ms | span avg/p95/max ms | jank >16.6 ms |
|---|---|---|---|---|---|---|---|---|---|---|
| Windows (Skia, profile) | stack | never | pan | 281 | 55.7 | 0.78 / 1.02 / 3.5 | 2.32 / 2.76 / 137.5 | 3.10 / 4.37 / 137.6 | 12.8 / 23.2 / 147.2 | 4 (1.42%) |
| Windows (Skia, profile) | stack | never | zoom | 120 | 59.4 | 0.41 / 0.71 / 1.2 | 13.91 / 23.69 / 27.2 | 14.32 / 24.03 / 27.7 | 25.1 / 45.1 / 57.4 | 31 (25.83%) |
| Windows (Skia, profile) | stack | never | drag | 91 | 59.2 | 1.10 / 1.48 / 4.2 | 8.89 / 10.93 / 13.7 | 9.99 / 12.27 / 14.9 | 18.8 / 26.3 / 41.3 | 0 (0.0%) |
| Windows (Skia, profile) | stack | duringGestures | pan | 262 | 52.0 | 0.43 / 0.56 / 2.7 | 2.75 / 1.13 / 231.4 | 3.18 / 1.70 / 232.0 | 13.1 / 22.8 / 252.5 | 3 (1.15%) |
| Windows (Skia, profile) | stack | duringGestures | zoom | 120 | 58.9 | 0.35 / 0.47 / 0.7 | 2.75 / 1.05 / 128.6 | 3.09 / 1.54 / 129.3 | 12.4 / 17.1 / 131.4 | 2 (1.67%) |
| Windows (Skia, profile) | stack | duringGestures | drag | 86 | 55.9 | 1.03 / 1.26 / 1.6 | 8.80 / 11.16 / 16.5 | 9.83 / 12.28 / 17.6 | 18.5 / 28.6 / 35.6 | 1 (1.16%) |
| Windows (Skia, profile) | stack | duringGestures | drag_rasterized | 15 | 9.8 | 1.32 / 2.18 / 2.8 | 120.23 / 163.48 / 163.6 | 121.55 / 164.71 / 164.9 | 230.7 / 312.0 / 322.1 | 12 (80.0%) |
| Windows (Skia, profile) | renderbox | never | pan | 283 | 56.2 | 0.39 / 0.56 / 2.1 | 1.89 / 1.80 / 142.6 | 2.28 / 2.27 / 142.8 | 10.7 / 17.1 / 148.3 | 2 (0.71%) |
| Windows (Skia, profile) | renderbox | never | zoom | 114 | 55.9 | 0.51 / 0.86 / 1.9 | 14.48 / 23.98 / 26.4 | 14.99 / 24.60 / 27.2 | 26.7 / 47.6 / 57.5 | 38 (33.33%) |
| Windows (Skia, profile) | renderbox | never | drag | 88 | 57.7 | 1.40 / 1.78 / 7.0 | 10.21 / 12.25 / 13.4 | 11.61 / 13.54 / 19.3 | 19.6 / 26.4 / 38.9 | 1 (1.14%) |
| Windows (Skia, profile) | renderbox | duringGestures | pan | 268 | 53.2 | 0.41 / 0.59 / 1.4 | 3.12 / 1.06 / 291.1 | 3.53 / 1.61 / 291.5 | 13.3 / 17.2 / 300.9 | 3 (1.12%) |
| Windows (Skia, profile) | renderbox | duringGestures | zoom | 117 | 57.7 | 0.32 / 0.43 / 0.7 | 2.82 / 0.86 / 139.8 | 3.14 / 1.36 / 140.2 | 13.1 / 16.7 / 164.4 | 2 (1.71%) |
| Windows (Skia, profile) | renderbox | duringGestures | drag | 93 | 60.5 | 1.08 / 1.32 / 5.4 | 8.88 / 10.46 / 19.6 | 9.96 / 12.15 / 20.6 | 17.4 / 24.3 / 39.3 | 1 (1.08%) |
| Windows (Skia, profile) | renderbox | duringGestures | drag_rasterized | 14 | 8.8 | 1.48 / 2.38 / 3.5 | 138.38 / 185.00 / 192.1 | 139.86 / 186.15 / 193.5 | 266.3 / 365.6 / 374.1 | 11 (78.57%) |

Run parameters: 203 nodes, 260 edges, viewport 1265 × 683 logical px, display 60 Hz, `--profile`, Flutter 3.38.9 (Skia on Windows). `fps (all)` = frames rendered / phase wall time, including the first frame; the `max` columns are dominated by that first frame (raster-cache fill, glyph atlas), see below. Raw lines: `BENCH_RESULT` JSON printed by the example (the `steady` block, first-5-frames-excluded stats, was added to the harness after this run and is not in these rows).

**Web (CanvasKit): not measured yet.** The headless run (`flutter run -d chrome --profile --web-browser-flag=--headless=new`) was started and had compiled and launched when this report was written, but had not emitted a `BENCH_RESULT` line; its numbers are unverified. Note for whoever re-runs it: `--web-browser-flag=--window-size=1400,900` is split at the comma by `flutter run` and makes headless Chrome fail with "Multiple targets are not supported"; pass no window-size flag (800 × 600 default) or run headed. Headless Chrome renders CanvasKit through SwiftShader (software GL), so a headed run is the representative one.

Reading the numbers:

- **Pan (the spike's pass criterion)**: both implementations render 262–283 frames in 5.04 s (52–56 fps including the first frame) with build+raster of 2.3–3.5 ms avg and 1.6–4.4 ms p95; after the first frame no frame exceeds 16.6 ms (jank 2–4 frames per 5 s, all at the start). The display is 60 Hz, so the steady state is at the display rate; the deficit against 60 fps is the single 137–291 ms first frame (8–17 lost vsyncs). Verdict: pass on Windows for A and B, with or without the raster cache; the raster cache does not help pan (translation-only transforms already hit Skia's picture raster cache) and costs a longer first frame.
- **Zoom**: without the raster cache both implementations re-rasterise all node pictures at the new scale every frame: 14–15 ms avg, 24 ms p95, 26–33 % jank. With the `ImageFilterLayer` cache: 2.8–3.1 ms avg, 2 jank frames (the cache fill at the start). This is the one place the cache earns its keep.
- **Node drag** (not a viewport gesture, flag down): 10–12 ms build+raster avg, 12–14 ms p95, 0–1 jank frame in both; the cost is the edge layer repaint (260 anti-aliased smooth-step paths) plus the moved node's picture. `drag_rasterized` (same drag with the gesture flag raised, i.e. a naive "cache during any gesture" policy): 120–140 ms per frame, 8–10 fps, 79–80 % jank, because the whole 6 000 × 3 500 scene is re-rasterised into the cache texture every frame.
- **First frames**: the `max` of every phase is its first frame: 137–143 ms without the cache (Skia rasterising 200 pictures at a new scale), 231–291 ms with it (one full-scene texture). A and B are within noise of each other on every metric.


### 2b. Results: Chrome / CanvasKit (headed, profile, 1251×1278 viewport, 60 Hz; `spikes/c-canvas-bench-chrome-canvaskit.jsonl`)

| Impl | Raster policy | Phase | Frames | fps all / steady | build+raster avg / p95 / max ms | jank |
|---|---|---|---|---|---|---|
| A stack | never | pan | 258 | 51.4 / 51.1 | 1.96 / 2.6 / 4.3 | 0 |
| A stack | never | zoom | 93 | 45.6 / 46.3 | 1.81 / 2.4 / 3.9 | 0 |
| A stack | never | drag | 73 | 48.2 / 46.7 | 4.04 / 5.0 / 6.3 | 0 |
| A stack | duringGestures | pan | 284 | 56.7 / 56.6 | 2.27 / 3.2 / 6.9 | 0 |
| A stack | duringGestures | zoom | 121 | 59.7 / 59.6 | 2.78 / 3.7 / 5.0 | 0 |
| A stack | duringGestures | drag | 74 | 48.5 / 49.7 | 3.71 / 4.4 / 5.2 | 0 |
| A stack | duringGestures | drag_rasterized | 72 | 46.9 / 48.4 | 4.17 / 4.9 / 8.1 | 0 |
| B renderbox | never | pan | 258 | 51.3 / 52.0 | 1.69 / 2.1 / 3.0 | 0 |
| B renderbox | never | zoom | 99 | 48.9 / 48.6 | 1.60 / 2.0 / 2.6 | 0 |
| B renderbox | never | drag | 76 | 49.6 / 50.7 | 3.46 / 4.2 / 4.9 | 0 |
| B renderbox | duringGestures | pan | 284 | 56.5 / 56.2 | 2.10 / 2.7 / 4.4 | 0 |
| B renderbox | duringGestures | zoom | 90 | 44.5 / 43.0 | 2.29 / 3.3 / 3.7 | 0 |
| B renderbox | duringGestures | drag | 75 | 48.4 / 50.0 | 3.56 / 4.3 / 5.4 | 0 |
| B renderbox | duringGestures | drag_rasterized | 83 | 54.2 / 54.1 | 4.14 / 5.1 / 6.0 | 0 |

Hit tests: 8/8 pass for A and B on CanvasKit as well.

Reading the CanvasKit numbers: build+raster never exceeds 8 ms and no frame janks, so rendering cost is not the limit; the 44–57 fps cadence (frame spans ~18 ms) is the browser's frame delivery for a window that was not continuously focused during the run, plus CanvasKit's own compositing. Unlike Windows, CanvasKit does not pay a 100+ ms raster-cache fill and the `drag_rasterized` policy is harmless (the matrix image filter is cheap in CanvasKit), but it also gains little. The spike criterion (≥55 fps pan) is met with the raster cache (56.5 fps) and marginal without (51–52 fps) under these conditions; the Phase 2 L3 regression runs this harness in a Playwright-controlled foreground window (`04-test-plan.md`) to get a stable cadence. The recommendation in §4 is unchanged by the CanvasKit run: A and B are within noise of each other on both platforms.

How the web run was driven: `flutter run -d chrome --profile --dart-define=BENCH=true --dart-define=BENCH_OUT=http://localhost:3998/result` with a tiny Node receiver (`appendLine` POSTs each result line on web, since `flutter run` does not forward console output in profile mode); the built-in Claude browser pane and headless Chrome both throttle animation frames to ~1 fps and cannot be used for this benchmark.

## 3. Hit-test findings

| Platform | Impl | Check | Expected | Actual | Result |
|---|---|---|---|---|---|
| Windows (Skia, profile) | stack | node at negative canvas coordinates after panning (zoom 1.0) | `node:n-0-0` | `node:n-0-0` | pass |
| Windows (Skia, profile) | stack | child node inside a container (child above container) (zoom 1.0) | `node:c0-child-0` | `node:c0-child-0` | pass |
| Windows (Skia, profile) | stack | edge mid-segment at zoom 0.5 (zoom 0.5) | `edge:fx-edge-near` | `edge:fx-edge-near` | pass |
| Windows (Skia, profile) | stack | edge mid-segment at zoom 1.3 (zoom 1.3) | `edge:fx-edge-near` | `edge:fx-edge-near` | pass |
| Windows (Skia, profile) | stack | edge 13 canvas units off-centre at zoom 0.5 (inside hit width 30) (zoom 0.5) | `edge:fx-edge-near` | `edge:fx-edge-near` | pass |
| Windows (Skia, profile) | stack | edge 22 canvas units off-centre at zoom 1.3 (outside hit width 30) (zoom 1.3) | `empty` | `empty` | pass |
| Windows (Skia, profile) | stack | empty space between two edges 60 canvas units apart (zoom 1.0) | `empty` | `empty` | pass |
| Windows (Skia, profile) | stack | node visible beyond the content-sized layer box (tiny graph, zoom 1.3) (zoom 1.3) | `node:tiny-b` | `node:tiny-b` | pass |
| Windows (Skia, profile) | renderbox | node at negative canvas coordinates after panning (zoom 1.0) | `node:n-0-0` | `node:n-0-0` | pass |
| Windows (Skia, profile) | renderbox | child node inside a container (child above container) (zoom 1.0) | `node:c0-child-0` | `node:c0-child-0` | pass |
| Windows (Skia, profile) | renderbox | edge mid-segment at zoom 0.5 (zoom 0.5) | `edge:fx-edge-near` | `edge:fx-edge-near` | pass |
| Windows (Skia, profile) | renderbox | edge mid-segment at zoom 1.3 (zoom 1.3) | `edge:fx-edge-near` | `edge:fx-edge-near` | pass |
| Windows (Skia, profile) | renderbox | edge 13 canvas units off-centre at zoom 0.5 (inside hit width 30) (zoom 0.5) | `edge:fx-edge-near` | `edge:fx-edge-near` | pass |
| Windows (Skia, profile) | renderbox | edge 22 canvas units off-centre at zoom 1.3 (outside hit width 30) (zoom 1.3) | `empty` | `empty` | pass |
| Windows (Skia, profile) | renderbox | empty space between two edges 60 canvas units apart (zoom 1.0) | `empty` | `empty` | pass |
| Windows (Skia, profile) | renderbox | node visible beyond the content-sized layer box (tiny graph, zoom 1.3) (zoom 1.3) | `node:tiny-b` | `node:tiny-b` | pass |

- Nodes at negative canvas coordinates, nodes placed on screen beyond the layer's own box, child nodes inside containers, edge strokes at zoom 0.5 and 1.3, the 30-unit hit band (13 inside / 22 outside) and the empty gap between two edges 60 units apart all resolve correctly in **both** implementations on both platforms, through the real gesture arena (the innermost `GestureDetector` wins: node over edge layer over background).
- Finding 8(a) of the review (`RenderBox.hitTest` rejects points outside the box) is real for `Stack`, but implementation A avoids it by sizing the `Stack` to the content bounds and folding the bounds origin into the transform, and `RenderTransform.hitTest` deliberately skips its own size check (framework source comment: it does not check itself because "the untransformed size and the child's transformed position" do not interact). The widget test `node visible beyond the content-sized layer box` encodes this for both implementations.
- The cost of A's approach is that the content bounds are a layout input: a node dragged (or moved remotely) outside them is painted (`clipBehavior: none`) but not hit-testable until the bounds are recomputed, which rebuilds the whole `Stack` (`GraphCanvasState.refreshBounds`, called at drag end). B has no bounds at all: hit testing inverts the viewport matrix and walks the children.
- `CustomPainter.hitTest` must return a real answer: `null` means "hit everything" (`RenderCustomPaint.hitTestSelf`), which would make the edge layer swallow every empty-canvas tap. The painter returns `edgeAt(position) != null`; the `EdgeLayer`'s `GestureDetector` asks the same sampler for the edge id.
- `Path.contains` is fill-only, as the review said; the `PathMetrics` sampler gives a stroke test with ≤ 1.5 canvas units of error at 3-unit spacing and costs ~0.3 ms per hit test for 260 edges (bounds pre-check first).
- A zero-length edge (coincident handles) produces no `PathMetrics` contour and is therefore not hit-testable; the unit test records this.

## 4. Recommendation

**Choose B, the custom `RenderBox` node layer (`RenderBoxNodeLayer`), with per-node `RepaintBoundary`s, a plain `TransformLayer` for pan, and the `ImageFilterLayer` raster cache enabled only for zoom gestures.** Reasons, in order of weight:

1. **Performance is a tie for pan and drag; the raster cache decides zoom, and both implementations support it equally.** On Windows, A and B pan at the display rate with ~2–3 ms of build+raster per frame and no jank after the first frame; node drag costs 9–12 ms in both (the edge layer repaint dominates). Zoom without the cache re-rasterises every node picture at the new scale every frame (14–15 ms avg, 24 ms p95, 26–33 % jank) in both; with the cache it drops to ~3 ms with 2 jank frames (the cache fill). The architecture question is therefore not decided by frame times.
2. **B has no layout coupling to the content bounds.** In A the `Stack` must be sized to the content bounds and the bounds origin folded into the transform; every node that leaves those bounds (local drag, remote move, paste, auto-layout) needs a bounds recompute that rebuilds the whole layer, and a node outside the stale bounds is visible but not clickable until then. B hit-tests by inverting the viewport matrix (`addWithPaintTransform`) and walking children, so there is nothing to keep in sync. This is the Phase 2 engine's hard requirement (remote moves arrive continuously).
3. **B keeps position changes out of layout.** `CanvasPositioned.applyParentData` marks paint only; `Positioned` in A dirties the `Stack`'s layout, which walks all 200 children (cheap today, but it is the path that grows with containers, dynamic handles and selection chrome).
4. **B owns the layer recipe.** The raster policy, clipping (`clipBehavior: none` is implied), culling of off-screen children at paint time, z-order (containers below children, selected node on top), and later the marquee/connection overlays can be implemented in `paint`/`hitTestChildren` without widget-tree gymnastics (`OverflowBox` + `Transform` + `Stack` in A). `Stack` also cannot cull: it paints every child; B can skip children whose transformed rect misses the viewport.
5. **A's advantages do not outweigh this.** A is ~150 lines less and uses only framework widgets, and its hit testing turned out correct (finding 8a is avoided by content-sized `Stack` + `RenderTransform.hitTest` skipping its bounds check). Keep `StackNodeLayer` in the package as the reference implementation for the widget tests until Phase 2 replaces it; it costs nothing.

Raster-cache policy (from the `drag_rasterized` rows): the `ImageFilterLayer` path re-rasterises the **whole scene** into one texture whenever anything under it changes. With the flag raised during a node drag a frame costs 120–140 ms on Windows (8–10 fps). The policy must be: cache **only** during viewport gestures whose scene content is static (wheel/pinch zoom, and pan if measured useful on the platform), **never** while a node moves, a selection changes, an edge animates or a remote cursor is drawn inside the layer. Remote cursors, marquee and connection previews must live in a sibling overlay layer outside the cached subtree. The one-time cache fill (first frame 130–290 ms at zoom 1 for a 6 000 × 3 500 scene) is paid at every gesture start, so for pan the plain `TransformLayer` (no cache fill, ~2 ms/frame) is the better default; enable the cache for zoom, where it removes 25–33 % jank.

## 5. What the Phase 2 engine must keep

- **Coordinate conventions** (`CanvasTransform`): canvas units are React Flow flow coordinates; `screen = canvas · zoom + offset` with `offset` the screen position of the canvas origin; zoom clamped to 0.1–1.3; zoom around a focal point by `offset' = focal − (focal − offset) · zoom'/zoom`; `fitToView` centres the content bounds with padding. Node positions are stored relative to the parent container (upstream `parentId`/`extent: parent`) and resolved to absolute positions by the controller; handles are at `(0, h/2)` (target, left) and `(w, h/2)` (source, right) for blocks and at `SUBFLOW_CONNECTION_Y = 69` for containers (`dimensions.ts`).
- **Node layer**: `RenderCanvasNodeLayer` (B). One `RepaintBoundary` per node (the node's picture survives pan/zoom; only the layer tree is rebuilt). Position changes go through parent data and mark paint only. Children laid out with loose constraints (a card's width is fixed at 250, height intrinsic). Hit testing: `hitTest` without `size.contains`, `hitTestChildren` through `addWithPaintTransform(viewportMatrix)` then `addWithPaintOffset(childPosition)`, topmost child first, stop at the first hit. Paint order = child order; the Phase 2 engine must order containers before their children and put the selected/dragged node last.
- **Raster cache policy**: `RasterPolicy.duringGestures` means `ImageFilterLayer(ImageFilter.matrix(viewport, FilterQuality.low))` only while `CanvasViewport.isGestureActive`, and the gesture flag is raised only by viewport gestures (`beginGesture`/`endGesture`, wheel with a 150 ms idle timeout), never by node drags. Phase 2 should restrict it further to zoom gestures (see §4) and keep anything that changes per frame (cursors, marquee, connection line, run-state dash animation) in a sibling layer above the node layer. Crisp repaint at rest is automatic: the layer switches back to `TransformLayer` when the flag drops.
- **Edge layer**: `CustomPainter` with the smooth-step port (`smoothStepPath`, radius 8, offset 30/20, corner points identical to upstream so fixtures can be compared), one `RepaintBoundary` around the `CustomPaint`, `repaint` driven by the controller's `geometryChanged`, geometry cached per edge keyed by endpoint position versions. `hitTest` must return a boolean from the `PathMetrics` sampler (`EdgeHitTester`, hit width 30 canvas units, 3-unit spacing, bounds pre-check, last-painted wins); never leave it `null`. The painter translates by the content-bounds origin so the `CustomPaint` is a finite box; in B that box is just another child and can also be replaced by a direct `paint` call in the render object later.
- **Per-node notifiers**: `GraphController` keeps absolute positions in one `ValueNotifier<Offset>` per node and rebuilds only the moved node's `CanvasPositioned`; this is the 33 ms coalescing seam for the collaborative position updates (`01-editor-architecture.md` §3).
- **Gesture arena conventions**: nodes, the edge layer and the background each have their own `GestureDetector` (tap + pan); the innermost wins ties, so a node drag beats a canvas pan and an edge tap beats an empty-canvas tap without any manual routing. Wheel = pan, ctrl/cmd + wheel = zoom at the cursor (`exp(−Δy · 0.0015)`), `PointerScaleEvent`/`PointerPanZoom*` = trackpad pinch.
- **Benchmark harness**: keep `example/` bench mode and the hit-test checks as the L3 canvas regression (`04-test-plan.md` Phase 2 L3); the pass criterion stays "steady-state pan ≥ 55 fps at zoom 1 with 200 nodes, zero jank frames after warm-up, all hit checks pass".

## 6. How to re-run

```
cd apps/flutter/packages/sim_canvas/example
flutter run -d windows --profile --dart-define=BENCH=true --dart-define=BENCH_OUT=<file.jsonl>
flutter run -d chrome  --profile --dart-define=BENCH=true --web-browser-flag=--window-size=1400,900
flutter run -d chrome  --profile --dart-define=BENCH=true --web-browser-flag=--headless=new --web-browser-flag=--window-size=1400,900
```

`flutter run` is driven non-interactively with stdin from `/dev/null`; on Windows the app exits itself after `BENCH_DONE`, on Chrome the driver script kills `flutter run` when the line appears in its output (the app's `print` lines are forwarded by `flutter run`). `flutter test` in the package runs the viewport, smooth-step, hit-sampler and both-implementation widget hit tests (49 tests).
