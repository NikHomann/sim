/// The deployment facts upstream reads through `getDeploymentShape()` and
/// `getEnv()` (`apps/sim/lib/core/config/*`) when deciding sub-block
/// visibility. The app provides one from `/api/public-env` and the workspace
/// host context.
class SubBlockEnvironment {
  const SubBlockEnvironment({
    this.hosted = false,
    Map<String, String> publicEnv = const {},
  }) : _publicEnv = publicEnv;

  /// The self-hosted default: nothing hosted, no `NEXT_PUBLIC_*` set.
  static const SubBlockEnvironment selfHosted = SubBlockEnvironment();

  final bool hosted;
  final Map<String, String> _publicEnv;

  /// Port of `isTruthy(getEnv(name))`: `'true'` / `'1'` (case-insensitive).
  bool isEnvTruthy(String name) {
    final value = _publicEnv[name];
    if (value == null) return false;
    final lower = value.trim().toLowerCase();
    return lower == 'true' || lower == '1';
  }

  /// Port of `anyEnvSet(spec)`: a comma-separated list means "any of these".
  bool anyEnvSet(String spec) =>
      spec.split(',').any((name) => isEnvTruthy(name.trim()));
}
