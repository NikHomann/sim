import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/shared/backend_image.dart';
import 'package:sim_design/sim_design.dart';

/// `getWorkspaceInitial` (`lib/workspaces/initials.ts`): the first letter of
/// the name with the word "workspace" removed, upper-cased; falls back to
/// the name's first character, then "W".
String workspaceInitial(String? name) {
  final source = name ?? '';
  final stripped = source
      .replaceAll(RegExp('workspace', caseSensitive: false), '')
      .trim();
  if (stripped.isNotEmpty) return stripped[0].toUpperCase();
  if (source.isNotEmpty) return source[0].toUpperCase();
  return 'W';
}

/// `IdentityTile` (`components/identity-tile/identity-tile.tsx`), `sm`: the
/// 16px workspace mark — the uploaded logo (`object-cover`) or the initial
/// on `--surface-6`, letter `--text-icon` (dark `--text-secondary`) at
/// `text-micro`, `rounded-sm`.
class IdentityTile extends StatelessWidget {
  const IdentityTile({
    required this.name,
    super.key,
    this.logoUrl,
    this.size = 16,
  });

  final String? name;
  final String? logoUrl;
  final double size;

  static const double _radius = SimRadii.identityTile16;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final letter = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface6,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Text(
        workspaceInitial(name),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: sim.text
            .style(SimTextStyles.sizeMicro, height: 1)
            .copyWith(color: sim.isDark ? c.textSecondary : c.textIcon),
      ),
    );
    final url = logoUrl;
    if (url == null || url.isEmpty) return ExcludeSemantics(child: letter);
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: BackendImage(
        url: url,
        size: size,
        semanticLabel: name,
        fallback: letter,
      ),
    );
  }
}
