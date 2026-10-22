import 'package:flutter/foundation.dart';
import 'package:sim_app/app/app.dart';
import 'package:sim_app/app/config.dart';
import 'package:sim_app/bootstrap.dart';

/// Development entry point: web behind tools/dev_proxy.mjs
/// (`flutter run -d chrome --web-port 8087 --web-launch-url http://localhost:3001/app/`)
/// or Windows against the local docker stack.
Future<void> main() {
  return bootstrap(
    SimApp.new,
    config: AppConfig(
      surface: kIsWeb ? AppSurface.web : AppSurface.desktop,
      backendOrigin: kIsWeb ? null : Uri.parse('http://localhost:3000'),
      e2e: AppConfig.e2eFromEnvironment,
    ),
  );
}
