import 'dart:async';
import 'dart:js_interop';

import 'package:sim_app/features/chat/engine/platform/browser_signals.dart';
import 'package:web/web.dart' as web;

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String get timeZone;
}

/// `Intl.DateTimeFormat().resolvedOptions().timeZone`.
String deviceTimeZone() {
  try {
    return _DateTimeFormat().resolvedOptions().timeZone;
  } on Object {
    return 'UTC';
  }
}

bool deviceIsOnline() => web.window.navigator.onLine;

/// `visibilitychange` (visible only), `pageshow` and `online`.
Stream<BrowserReturnReason> browserReturnSignals() {
  late StreamController<BrowserReturnReason> controller;
  final subscriptions = <StreamSubscription<web.Event>>[];
  controller = StreamController<BrowserReturnReason>.broadcast(
    onListen: () {
      subscriptions
        ..add(
          const web.EventStreamProvider<web.Event>(
            'visibilitychange',
          ).forTarget(web.document).listen((_) {
            if (web.document.visibilityState == 'visible') {
              controller.add(BrowserReturnReason.visible);
            }
          }),
        )
        ..add(
          web.EventStreamProviders.pageShowEvent
              .forTarget(web.window)
              .listen((_) => controller.add(BrowserReturnReason.pageshow)),
        )
        ..add(
          web.EventStreamProviders.onlineEvent
              .forTarget(web.window)
              .listen((_) => controller.add(BrowserReturnReason.online)),
        );
    },
    onCancel: () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
      subscriptions.clear();
    },
  );
  return controller.stream;
}

Stream<void> onlineSignals() =>
    web.EventStreamProviders.onlineEvent.forTarget(web.window).map((_) {});
