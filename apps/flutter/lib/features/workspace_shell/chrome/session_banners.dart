import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/chrome/session_actions.dart';
import 'package:sim_design/sim_design.dart';

/// `SessionExpired` (`session-expired.tsx:29-85`, `shell.session-expired`):
/// once a live session settles to `null` without an error, covers the
/// viewport and runs the stale-session recovery once — sign out, wipe, then
/// `/login`. A failed sign-out turns the copy red and offers "Try again". A
/// network error is never an expiry.
///
/// The cover is a modal layer of the app's [SimOverlayHost] at
/// [SimZ.takeover] (`z-[var(--z-takeover)]`, 500), so it paints above the
/// toast stack and any open modal; this widget only arms it (and renders it
/// in place when no overlay host is above).
class SessionExpiredTakeover extends StatefulWidget {
  const SessionExpiredTakeover({
    required this.session,
    required this.actions,
    super.key,
    this.onRecovered,
  });

  final SessionCubit session;
  final SessionActions actions;

  /// Navigation after a successful recovery; defaults to `go('/login')`.
  final void Function(BuildContext context)? onRecovered;

  @override
  State<SessionExpiredTakeover> createState() => _SessionExpiredTakeoverState();
}

class _SessionExpiredTakeoverState extends State<SessionExpiredTakeover> {
  bool _started = false;
  bool _failed = false;
  bool _wasImpersonation = false;
  SimOverlayEntry? _entry;

  void _attemptRecovery() {
    _update(() => _failed = false);
    unawaited(
      widget.actions.recoverFromStaleSession().then((recovered) {
        if (!mounted) return;
        if (!recovered) {
          _update(() => _failed = true);
          return;
        }
        final navigate = widget.onRecovered;
        if (navigate != null) {
          navigate(context);
        } else {
          GoRouter.of(context).go('/login');
        }
      }),
    );
  }

  /// Applies [change] to the inline copy and the overlay layer alike.
  void _update(VoidCallback change) {
    setState(change);
    _entry?.markNeedsBuild();
  }

  void _onState(SessionState state) {
    if (state.isImpersonated && !_wasImpersonation) {
      _update(() => _wasImpersonation = true);
    }
    _syncLayer(state);
    if (state.isExpired && !_started) {
      _started = true;
      _attemptRecovery();
    }
  }

  void _syncLayer(SessionState state) {
    if (!state.isExpired) {
      _removeLayer();
      return;
    }
    if (_entry != null) return;
    final overlay = SimOverlay.maybeOf(context);
    if (overlay == null) return;
    final entry = SimOverlayEntry(
      z: SimZ.takeover,
      modal: true,
      dismissOnOutsideTap: false,
      dismissOnEscape: false,
      builder: _cover,
    );
    _entry = entry;
    overlay.insert(entry);
    // The layer replaces the in-place cover.
    setState(() {});
  }

  void _removeLayer() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
  }

  @override
  void initState() {
    super.initState();
    _wasImpersonation = widget.session.state.isImpersonated;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onState(widget.session.state);
    });
  }

  @override
  void dispose() {
    final entry = _entry;
    _entry = null;
    // Disposal runs while the tree is locked; the host rebuilds on removal.
    if (entry != null) scheduleMicrotask(entry.remove);
    super.dispose();
  }

  Widget _cover(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final subject = _wasImpersonation
        ? 'The impersonation session expired'
        : 'Your session expired';
    return Semantics(
      identifier: 'shell.session-expired',
      container: true,
      liveRegion: true,
      child: ColoredBox(
        color: c.bg,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: <Widget>[
                Text(
                  _failed
                      ? '$subject, but signing out failed.'
                      : '$subject. Signing you out…',
                  textAlign: TextAlign.center,
                  style: sim.text.sm.copyWith(
                    color: _failed ? c.textError : c.textSecondary,
                  ),
                ),
                if (_failed)
                  Semantics(
                    identifier: 'shell.session-expired.retry',
                    container: true,
                    child: SimChip(
                      label: 'Try again',
                      variant: SimChipVariant.primary,
                      onPressed: _attemptRecovery,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionCubit, SessionState>(
      bloc: widget.session,
      listener: (context, state) => _onState(state),
      builder: (context, state) {
        if (!state.isExpired || _entry != null) return const SizedBox.shrink();
        // Before the layer is inserted (the first frame), or without a host.
        return _cover(context);
      },
    );
  }
}

/// `ImpersonationBanner` (`impersonation-banner.tsx:100-135`,
/// `shell.banner.impersonation`): the destructive `Banner` above the chrome
/// while `session.impersonatedBy` is set. "Stop impersonating" runs the
/// admin mutation, clears user data (keeping recent impersonations) and
/// goes to `/home`; on error the button re-enables.
class ImpersonationBanner extends StatefulWidget {
  const ImpersonationBanner({
    required this.session,
    required this.actions,
    super.key,
    this.onStopped,
  });

  final SessionCubit session;
  final SessionActions actions;
  final void Function(BuildContext context)? onStopped;

  @override
  State<ImpersonationBanner> createState() => _ImpersonationBannerState();
}

class _ImpersonationBannerState extends State<ImpersonationBanner> {
  bool _pending = false;

  static const Color _red50 = Color(0xFFFEF2F2);
  static const Color _red950 = Color(0xFF450A0A);
  static const Color _red700 = Color(0xFFB91C1C);
  static const Color _red300 = Color(0xFFFCA5A5);

  Future<void> _stop() async {
    setState(() => _pending = true);
    try {
      await widget.actions.stopImpersonating();
    } on Object {
      if (mounted) setState(() => _pending = false);
      return;
    }
    if (!mounted) return;
    final navigate = widget.onStopped;
    if (navigate != null) {
      navigate(context);
    } else {
      GoRouter.of(context).go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      bloc: widget.session,
      builder: (context, state) {
        if (state.isPending || !state.isImpersonated) {
          return const SizedBox.shrink();
        }
        final sim = SimTheme.of(context);
        final c = sim.colors;
        final user = state.user;
        final label = (user?.name?.isNotEmpty ?? false)
            ? user!.name!
            : 'this user';
        final email = user?.email;
        final text =
            'Impersonating $label${email != null ? ' ($email)' : ''}. '
            'Changes will apply to this account until you switch back.';
        final fill = sim.isDark
            ? Color.alphaBlend(_red950.withValues(alpha: 0.3), c.surface1)
            : _red50;
        return Semantics(
          identifier: 'shell.banner.impersonation',
          container: true,
          child: ColoredBox(
            color: fill,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Row(
                    spacing: 12,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          text,
                          style: sim.text
                              .style(13)
                              .copyWith(color: sim.isDark ? _red300 : _red700),
                        ),
                      ),
                      Semantics(
                        identifier: 'shell.banner.impersonation.action',
                        container: true,
                        child: SimButton(
                          variant: SimButtonVariant.destructive,
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          enabled: !_pending,
                          onPressed: _stop,
                          child: Text(
                            _pending ? 'Returning...' : 'Stop impersonating',
                            style: sim.text.style(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
