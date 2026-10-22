import 'package:sim_app/app/app.dart';
import 'package:sim_app/app/config.dart';
import 'package:sim_app/bootstrap.dart';

/// Web entry point: served under /app/ on the same origin as the Sim backend.
Future<void> main() {
  return bootstrap(
    SimApp.new,
    config: const AppConfig(
      surface: AppSurface.web,
      backendOrigin: null,
      e2e: AppConfig.e2eFromEnvironment,
    ),
  );
}
