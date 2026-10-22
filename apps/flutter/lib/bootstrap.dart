import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/config.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/app/platform/key_value_shared_state.dart';
import 'package:sim_app/features/chat/integration/chat_integration.dart';

/// Logs every bloc transition and error in debug builds, mirroring the
/// BlocObserver pattern of the sibling OttoFrontend app.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      developer.log('${bloc.runtimeType} $change', name: 'bloc');
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    developer.log(
      '${bloc.runtimeType} $error',
      name: 'bloc',
      error: error,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }
}

/// Shared startup for every entry point: URL strategy, error handling,
/// bloc observer, service locator, then the root widget.
Future<void> bootstrap(
  FutureOr<Widget> Function() builder, {
  required AppConfig config,
}) async {
  // Path URLs under the fixed <base href="/app/"> (web only; no-op elsewhere).
  usePathUrlStrategy();

  FlutterError.onError = (details) {
    // Debug builds also print the error the framework's way: on web,
    // developer.log alone never reaches the browser console, which hid a
    // build-time stack overflow during the Phase 1 live run.
    if (kDebugMode) FlutterError.presentError(details);
    developer.log(
      details.exceptionAsString(),
      name: 'flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  Bloc.observer = const AppBlocObserver();

  await configureLocator(config);
  // Off the web the theme and sidebar state are read synchronously from
  // the key-value store: load them before anything reads them.
  final shared = locator<SharedWebState>();
  if (shared is KeyValueSharedWebState) await shared.load();
  // The chat stores read their key-value cache synchronously too.
  await loadChatStorage(locator);

  runApp(await builder());
}
