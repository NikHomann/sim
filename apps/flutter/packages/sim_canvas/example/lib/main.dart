import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sim_canvas/sim_canvas.dart';
import 'package:sim_canvas_example/bench/bench_runner.dart';
import 'package:sim_canvas_example/bench/platform_stub.dart'
    if (dart.library.io) 'package:sim_canvas_example/bench/platform_io.dart';

/// `--dart-define=BENCH=true` runs the benchmark on start-up and exits.
const bool kBench = bool.fromEnvironment('BENCH');

/// File that receives one JSON line per variant (io platforms only).
const String kBenchOut = String.fromEnvironment('BENCH_OUT');

/// Comma-separated subset of `stack,renderbox`.
const String kBenchImpls = String.fromEnvironment(
  'BENCH_IMPLS',
  defaultValue: 'stack,renderbox',
);

/// `both`, `never` or `duringGestures`.
const String kBenchRaster = String.fromEnvironment(
  'BENCH_RASTER',
  defaultValue: 'both',
);

void main() {
  runApp(const CanvasSpikeApp());
}

class CanvasSpikeApp extends StatelessWidget {
  const CanvasSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sim_canvas spike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6366F1),
        useMaterial3: true,
      ),
      home: const CanvasSpikePage(),
    );
  }
}

class CanvasSpikePage extends StatefulWidget {
  const CanvasSpikePage({super.key});

  @override
  State<CanvasSpikePage> createState() => _CanvasSpikePageState();
}

class _CanvasSpikePageState extends State<CanvasSpikePage>
    implements BenchHost {
  static const List<NodeLayerImplementation> _implementations =
      <NodeLayerImplementation>[
        StackNodeLayer(),
        RenderBoxNodeLayer(),
      ];

  @override
  final CanvasViewport viewport = CanvasViewport();

  @override
  late GraphController controller = GraphController(
    generateSyntheticWorkflow(),
  );

  @override
  final GlobalKey<GraphCanvasState> canvasKey = GlobalKey<GraphCanvasState>();

  @override
  final List<HitRecord> hits = <HitRecord>[];

  NodeLayerImplementation _implementation = const RenderBoxNodeLayer();
  RasterPolicy _rasterPolicy = RasterPolicy.duringGestures;
  String _status = kBench
      ? 'benchmark starting…'
      : 'drag to pan, wheel to scroll, ctrl+wheel to zoom';
  bool _busy = false;
  HitRecord? _lastHit;

  @override
  void initState() {
    super.initState();
    if (kBench) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_runBenchmark(exitWhenDone: true)),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    viewport.dispose();
    super.dispose();
  }

  @override
  void clearHits() => hits.clear();

  @override
  Future<void> configure({
    required NodeLayerImplementation implementation,
    required RasterPolicy rasterPolicy,
    CanvasGraph? graph,
  }) async {
    setState(() {
      _implementation = implementation;
      _rasterPolicy = rasterPolicy;
      if (graph != null) {
        final previous = controller;
        controller = GraphController(graph);
        previous.dispose();
      }
    });
    await WidgetsBinding.instance.endOfFrame;
    canvasKey.currentState?.fitToView();
    await WidgetsBinding.instance.endOfFrame;
  }

  List<BenchVariant> _variants() {
    final impls = kBenchImpls.split(',').map((s) => s.trim()).toSet();
    final rasters = switch (kBenchRaster) {
      'never' => const <RasterPolicy>[RasterPolicy.never],
      'duringGestures' => const <RasterPolicy>[RasterPolicy.duringGestures],
      _ => RasterPolicy.values,
    };
    return <BenchVariant>[
      for (final impl in _implementations)
        if (impls.contains(impl.name))
          for (final raster in rasters) BenchVariant(impl, raster),
    ];
  }

  Future<void> _runBenchmark({required bool exitWhenDone}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'benchmark running…';
    });
    final refreshRate = View.of(context).display.refreshRate;
    final runner = BenchRunner(
      host: this,
      variants: _variants(),
      outPath: kBenchOut.isEmpty ? null : kBenchOut,
    );
    final results = await runner.runAll(refreshRate: refreshRate);
    if (!mounted) return;
    final summary = results
        .map((r) {
          final phases = r['phases']! as Map<String, Object?>;
          final pan = phases['pan']! as Map<String, Object?>;
          final frame = pan['frame_ms']! as Map<String, Object?>;
          return '${r['impl']}/${r['raster']}: pan ${pan['fps']} fps, frame avg ${frame['avg']} ms, p95 ${frame['p95']} ms, jank ${pan['jank_frames']}';
        })
        .join('\n');
    setState(() {
      _busy = false;
      _status = summary;
    });
    if (exitWhenDone) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exitApp(0);
    }
  }

  Future<void> _runHitChecks() async {
    if (_busy) return;
    setState(() => _busy = true);
    final runner = BenchRunner(host: this, variants: const <BenchVariant>[]);
    final lines = <String>[];
    for (final impl in _implementations) {
      final results = await runner.runHitChecks(impl);
      for (final r in results) {
        lines.add(
          '${r['pass']! as bool ? 'PASS' : 'FAIL'} ${r['impl']}: ${r['name']} → ${r['actual']}',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = lines.join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          if (!kBench) _toolbar(),
          Expanded(
            child: GraphCanvas(
              key: canvasKey,
              controller: controller,
              viewport: viewport,
              implementation: _implementation,
              rasterPolicy: _rasterPolicy,
              onHit: (hit) {
                hits.add(hit);
                if (!kBench && !_busy) setState(() => _lastHit = hit);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropdownButton<String>(
              value: _implementation.name,
              items: <DropdownMenuItem<String>>[
                for (final impl in _implementations)
                  DropdownMenuItem<String>(
                    value: impl.name,
                    child: Text(impl.name),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (name) => setState(() {
                      _implementation = _implementations.firstWhere(
                        (i) => i.name == name,
                      );
                    }),
            ),
            const SizedBox(width: 12),
            const Text('raster during gestures'),
            Switch(
              value: _rasterPolicy == RasterPolicy.duringGestures,
              onChanged: _busy
                  ? null
                  : (on) => setState(() {
                      _rasterPolicy = on
                          ? RasterPolicy.duringGestures
                          : RasterPolicy.never;
                    }),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => canvasKey.currentState?.fitToView(),
              child: const Text('Fit'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => unawaited(_runBenchmark(exitWhenDone: false)),
              child: const Text('Run benchmark'),
            ),
            TextButton(
              onPressed: _busy ? null : () => unawaited(_runHitChecks()),
              child: const Text('Hit checks'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_lastHit == null ? '' : 'last hit: $_lastHit\n'}$_status',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ListenableBuilder(
              listenable: viewport,
              builder: (context, _) => Text(
                'zoom ${viewport.zoom.toStringAsFixed(2)}  ${SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle ? '' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
