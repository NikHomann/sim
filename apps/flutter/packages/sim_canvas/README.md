# sim_canvas

Graph editor engine for the Flutter port of the Sim workflow editor
(`docs/port/00-plan.md` §4.6). This is the Phase 0 spike skeleton: it decides
the rendering architecture by measurement (`docs/port/canvas-spike.md`).

## What is here

- `CanvasViewport` / `CanvasTransform`: pan, zoom 0.1–1.3 around the cursor,
  fit-to-view, `screen = canvas * zoom + offset`.
- `GraphCanvas`: the editor surface (pointer pan, wheel pan, ctrl/cmd + wheel
  zoom, trackpad pinch, node drag) composed of a node layer and an edge layer.
- Two interchangeable node-layer implementations behind `NodeLayerImplementation`:
  `StackNodeLayer` (`Stack` + `Transform`, content-sized with origin offset) and
  `RenderBoxNodeLayer` (custom `RenderBox` painting children under the viewport
  transform and hit-testing them without a bounds check).
- `EdgePainter` / `EdgeLayer`: smooth-step edges (port of `@xyflow/system`
  `getSmoothStepPath`, radius 8, offset 30/20) with a stroke hit test that
  samples `PathMetrics` at hit width 30 canvas units (`EdgeHitTester`).
- `GraphController`: per-node `ValueNotifier<Offset>` positions (absolute),
  container children follow their parent, cached edge geometry.
- `generateSyntheticWorkflow()`: 200 nodes / ~260 edges / 3 containers plus a
  hit-test fixture; `generateTinyWorkflow()` for the out-of-bounds check.

## Running the spike

```
cd example
flutter run -d windows --profile --dart-define=BENCH=true --dart-define=BENCH_OUT=C:\tmp\bench.jsonl
flutter run -d chrome  --profile --dart-define=BENCH=true --web-browser-flag=--window-size=1400,900
```

`BENCH=true` runs pan (5 s), zoom (2 s) and node-drag (1.5 s) phases for each
variant (`BENCH_IMPLS=stack,renderbox`, `BENCH_RASTER=both|never|duringGestures`),
runs the hit-test checks once per implementation, prints one `BENCH_RESULT {json}`
line per variant and `BENCH_DONE`, appends the lines to `BENCH_OUT` on Windows,
and exits. Without `BENCH` the example is an interactive playground with the
same controls in a toolbar.
