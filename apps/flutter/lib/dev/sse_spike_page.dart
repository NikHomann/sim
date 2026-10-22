import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';

/// Phase 0 spike (b): proves SSE over POST on web through the fetch adapter
/// against `/api/workflows/[id]/execute` (docs/port/spikes.md). Dev-only.
class SseSpikePage extends StatefulWidget {
  const SseSpikePage({required this.workflowId, super.key});

  final String workflowId;

  @override
  State<SseSpikePage> createState() => _SseSpikePageState();
}

class _SseSpikePageState extends State<SseSpikePage> {
  final List<String> _lines = <String>[];
  String _session = 'checking session…';
  String? _executionId;
  bool _running = false;
  ExecutionStream? _stream;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSession());
  }

  Future<void> _loadSession() async {
    try {
      final session = await locator<AuthRepository>().getSession();
      setState(
        () => _session = session == null
            ? 'no session (sign in at /login first)'
            : 'signed in as ${session.user.email}',
      );
    } on Object catch (error) {
      setState(() => _session = 'session error: $error');
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _lines.clear();
      _executionId = null;
    });
    final started = DateTime.now();
    try {
      final client = ExecutionStreamClient(locator<SimHttpClient>());
      final stream = await client.execute(workflowId: widget.workflowId);
      _stream = stream;
      setState(() => _executionId = stream.executionId);
      await for (final event in stream.events) {
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        setState(() => _lines.add('+${elapsed}ms ${event.type}'));
      }
      setState(() => _lines.add('stream ended normally'));
    } on Object catch (error) {
      setState(() => _lines.add('ERROR $error'));
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SSE spike · workflow ${widget.workflowId}'),
            Text(_session),
            Text('executionId: ${_executionId ?? '-'}'),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _running ? null : _run,
                  child: const Text('Run (stream: true)'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _running ? () => _stream?.cancel() : null,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final line in _lines)
                    Text(
                      line,
                      key: ValueKey(line),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
