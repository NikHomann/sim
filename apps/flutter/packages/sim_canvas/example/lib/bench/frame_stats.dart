import 'dart:ui';

/// Summary of the `FrameTiming`s collected during one benchmark phase.
///
/// `frame` is build + raster (the work the engine did for the frame);
/// `span` is `FrameTiming.totalSpan` (vsync to raster finish, includes
/// waiting). A frame is jank when build + raster exceeds 16.6 ms.
///
/// The first frames of a phase pay one-off costs (raster-cache fill, glyph
/// atlas, texture upload); `firstFramesMs` lists them and `steady` summarises
/// the phase without its first [steadyStateSkip] frames, with the frame
/// rate derived from the vsync timestamps of the remaining frames.
class FrameStats {
  const FrameStats({
    required this.frames,
    required this.elapsedMs,
    required this.buildMs,
    required this.rasterMs,
    required this.frameMs,
    required this.spanMs,
    required this.jankFrames,
    required this.firstFramesMs,
    required this.steady,
  });

  factory FrameStats.from(List<FrameTiming> timings, Duration elapsed) {
    final build = timings
        .map((t) => t.buildDuration.inMicroseconds / 1000)
        .toList();
    final raster = timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000)
        .toList();
    final frame = [for (var i = 0; i < build.length; i++) build[i] + raster[i]];
    final span = timings.map((t) => t.totalSpan.inMicroseconds / 1000).toList();
    return FrameStats(
      frames: timings.length,
      elapsedMs: elapsed.inMicroseconds / 1000,
      buildMs: Summary.of(build),
      rasterMs: Summary.of(raster),
      frameMs: Summary.of(frame),
      spanMs: Summary.of(span),
      jankFrames: frame.where((ms) => ms > jankThresholdMs).length,
      firstFramesMs: frame.take(3).map(_round).toList(),
      steady: SteadyStats.from(timings.skip(steadyStateSkip).toList()),
    );
  }

  static const double jankThresholdMs = 16.6;
  static const int steadyStateSkip = 5;

  final int frames;
  final double elapsedMs;
  final Summary buildMs;
  final Summary rasterMs;
  final Summary frameMs;
  final Summary spanMs;
  final int jankFrames;
  final List<double> firstFramesMs;
  final SteadyStats steady;

  double get fps => elapsedMs == 0 ? 0 : frames / (elapsedMs / 1000);

  Map<String, Object?> toJson() => <String, Object?>{
    'frames': frames,
    'elapsed_ms': _round(elapsedMs),
    'fps': _round(fps),
    'build_ms': buildMs.toJson(),
    'raster_ms': rasterMs.toJson(),
    'frame_ms': frameMs.toJson(),
    'span_ms': spanMs.toJson(),
    'jank_frames': jankFrames,
    'jank_pct': frames == 0 ? 0 : _round(100 * jankFrames / frames),
    'first_frames_ms': firstFramesMs,
    'steady': steady.toJson(),
  };
}

/// Stats over the frames after the warm-up frames of a phase.
class SteadyStats {
  const SteadyStats({
    required this.frames,
    required this.fps,
    required this.frameMs,
    required this.rasterMs,
    required this.jankFrames,
  });

  factory SteadyStats.from(List<FrameTiming> timings) {
    if (timings.length < 2) {
      return const SteadyStats(
        frames: 0,
        fps: 0,
        frameMs: Summary(avg: 0, p95: 0, max: 0),
        rasterMs: Summary(avg: 0, p95: 0, max: 0),
        jankFrames: 0,
      );
    }
    final frame = timings
        .map(
          (t) =>
              (t.buildDuration.inMicroseconds +
                  t.rasterDuration.inMicroseconds) /
              1000,
        )
        .toList();
    final raster = timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000)
        .toList();
    final firstVsync = timings.first.timestampInMicroseconds(
      FramePhase.vsyncStart,
    );
    final lastVsync = timings.last.timestampInMicroseconds(
      FramePhase.vsyncStart,
    );
    final seconds = (lastVsync - firstVsync) / 1e6;
    return SteadyStats(
      frames: timings.length,
      fps: seconds <= 0 ? 0 : (timings.length - 1) / seconds,
      frameMs: Summary.of(frame),
      rasterMs: Summary.of(raster),
      jankFrames: frame.where((ms) => ms > FrameStats.jankThresholdMs).length,
    );
  }

  final int frames;
  final double fps;
  final Summary frameMs;
  final Summary rasterMs;
  final int jankFrames;

  Map<String, Object?> toJson() => <String, Object?>{
    'frames': frames,
    'fps': _round(fps),
    'frame_ms': frameMs.toJson(),
    'raster_ms': rasterMs.toJson(),
    'jank_frames': jankFrames,
  };
}

class Summary {
  const Summary({required this.avg, required this.p95, required this.max});

  factory Summary.of(List<double> values) {
    if (values.isEmpty) return const Summary(avg: 0, p95: 0, max: 0);
    final sorted = [...values]..sort();
    final avg = sorted.reduce((a, b) => a + b) / sorted.length;
    final p95 = sorted[((sorted.length - 1) * 0.95).round()];
    return Summary(avg: avg, p95: p95, max: sorted.last);
  }

  final double avg;
  final double p95;
  final double max;

  Map<String, Object?> toJson() => <String, Object?>{
    'avg': _round(avg),
    'p95': _round(p95),
    'max': _round(max),
  };
}

double _round(double value) => (value * 100).roundToDouble() / 100;
