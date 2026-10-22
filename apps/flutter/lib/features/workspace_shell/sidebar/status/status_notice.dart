import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_design/sim_design.dart';

/// `STATUS_PAGE_URL`.
const String statusPageUrl = 'https://status.sim.ai';

/// The status page poll interval (`refetchInterval: 60_000`).
const Duration statusPollInterval = Duration(seconds: 60);

/// Whether an indicator shows the notice (`major` / `critical` only).
bool statusIndicatorAlerts(String? indicator) =>
    indicator == 'major' || indicator == 'critical';

/// `StatusNotice` (`status-notice.tsx`): polls the status page every 60s
/// (hosted) and renders the "Sim is having issues" card for a major or
/// critical indicator; [preview] forces it (`NEXT_PUBLIC_STATUS_NOTICE_PREVIEW`).
class StatusNotice extends StatefulWidget {
  const StatusNotice({
    required this.services,
    super.key,
    this.preview = false,
  });

  final SidebarServices services;
  final bool preview;

  @override
  State<StatusNotice> createState() => _StatusNoticeState();
}

class _StatusNoticeState extends State<StatusNotice> {
  String? _indicator;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (!widget.preview && widget.services.fetchStatusIndicator != null) {
      unawaited(_fetch());
      _poll = Timer.periodic(statusPollInterval, (_) => unawaited(_fetch()));
    }
  }

  Future<void> _fetch() async {
    try {
      final indicator = await widget.services.fetchStatusIndicator!();
      if (mounted) setState(() => _indicator = indicator);
    } on Object {
      // retry: 0 — keep the last value until the next poll.
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicator = widget.preview ? 'critical' : _indicator;
    if (!statusIndicatorAlerts(indicator)) return const SizedBox.shrink();
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final palette = c.terminalStatusError;
    return Parity(
      'shell.sidebar.status',
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: palette.background,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(SimRadii.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: <Widget>[
              Row(
                spacing: 6,
                children: <Widget>[
                  SimIcon(
                    SimEmcnIcons.circleAlert,
                    size: 16,
                    color: c.textIcon,
                  ),
                  Flexible(
                    child: Text(
                      'Sim is having issues',
                      style: sim.text.sm.copyWith(
                        color: c.textBody,
                        height: 20 / 14,
                      ),
                    ),
                  ),
                ],
              ),
              SimChip(
                label: 'View status',
                variant: SimChipVariant.border,
                fullWidth: true,
                isLink: true,
                alignment: MainAxisAlignment.center,
                onPressed: () =>
                    widget.services.navigator.openExternal(statusPageUrl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
