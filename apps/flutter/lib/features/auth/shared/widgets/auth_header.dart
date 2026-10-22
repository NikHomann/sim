import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// Port of `auth-header.tsx`: centred title (32px / 1.2, `--text-primary`)
/// and description (15px / 1.5, `--text-muted`) on a 4px gap.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.title,
    required this.identifier,
    super.key,
    this.description,
  });

  final String title;
  final String? description;

  /// Parity id prefix: `<prefix>.header`, `<prefix>.title`,
  /// `<prefix>.description`.
  final String identifier;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Semantics(
      container: true,
      identifier: '$identifier.header',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: <Widget>[
          Semantics(
            container: true,
            identifier: '$identifier.title',
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: sim.text
                  .style(32, height: 1.2)
                  .copyWith(color: c.textPrimary),
            ),
          ),
          if (description != null)
            Semantics(
              container: true,
              identifier: '$identifier.description',
              child: Text(
                description!,
                textAlign: TextAlign.center,
                style: sim.text.base.copyWith(color: c.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
