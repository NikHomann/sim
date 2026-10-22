import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// `EmptyState` (`components/empty-state/empty-state.tsx`): centred title,
/// a muted 240px description and an optional action row.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    required this.title,
    required this.description,
    super.key,
    this.actions = const <Widget>[],
    this.parityId,
  });

  final String title;
  final String description;
  final List<Widget> actions;
  final String? parityId;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    Widget body = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: SimTextStyles.weight(
                sim.text.small.copyWith(color: c.textPrimary),
                SimTextStyles.medium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: sim.text.small.copyWith(
                    color: c.textMuted,
                    height: 20 / 13,
                  ),
                ),
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
    if (parityId != null) {
      body = Semantics(identifier: parityId, container: true, child: body);
    }
    return ColoredBox(color: c.bg, child: body);
  }
}

/// `ErrorShell` (`app/workspace/[workspaceId]/components/error/error.tsx`):
/// the 52px framed mark, a page heading, a 340px muted paragraph and the
/// action row.
class HomeErrorShell extends StatelessWidget {
  const HomeErrorShell({
    required this.title,
    required this.description,
    required this.actions,
    super.key,
    this.icon = SimEmcnIcons.triangleAlert,
    this.parityId,
  });

  final String title;
  final String description;
  final List<Widget> actions;
  final SimIconData icon;
  final String? parityId;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final viewport = MediaQuery.sizeOf(context).width;
    Widget body = ColoredBox(
      color: c.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 20,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: sim.isDark ? c.surface5 : c.surface4,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                    boxShadow: SimShadows.xs,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: c.border),
                    ),
                    child: Center(
                      child: SimIcon(icon, size: 22, color: c.textIcon),
                    ),
                  ),
                ),
                Column(
                  spacing: 8,
                  children: <Widget>[
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: sim.text
                          .pageHeading(viewportWidth: viewport)
                          .copyWith(color: c.textPrimary),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Text(
                        description,
                        textAlign: TextAlign.center,
                        style: sim.text
                            .style(14, height: 1.55)
                            .copyWith(color: c.textTertiary),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (parityId != null) {
      body = Semantics(identifier: parityId, container: true, child: body);
    }
    return body;
  }
}
