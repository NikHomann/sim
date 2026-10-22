import 'package:sim_app/app/app.dart';
import 'package:sim_app/app/config.dart';
import 'package:sim_app/bootstrap.dart';

/// Windows entry point. The backend origin comes from
/// `--dart-define=SIM_ORIGIN=https://...` (default: the local docker stack).
Future<void> main() {
  const origin = String.fromEnvironment(
    'SIM_ORIGIN',
    defaultValue: 'http://localhost:3000',
  );
  return bootstrap(
    SimApp.new,
    config: AppConfig(
      surface: AppSurface.desktop,
      backendOrigin: Uri.parse(origin),
      e2e: AppConfig.e2eFromEnvironment,
    ),
  );
}
