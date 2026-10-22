/// Which surface the binary runs as. Mirrors the React app's
/// `x-sim-client-id` tab identity and the desktop/web split.
enum AppSurface { web, desktop }

/// Build-time configuration selected by the entry point.
///
/// On web the backend origin is always the page origin (same-origin serving,
/// plan section 3), so [backendOrigin] is null there. On Windows it is the
/// configured Sim origin.
class AppConfig {
  const AppConfig({
    required this.surface,
    required this.backendOrigin,
    required this.e2e,
  });

  final AppSurface surface;
  final Uri? backendOrigin;

  /// `--dart-define=SIM_E2E=true`: deterministic clock, ids, zero motion.
  final bool e2e;

  static const bool e2eFromEnvironment = bool.fromEnvironment('SIM_E2E');
}
