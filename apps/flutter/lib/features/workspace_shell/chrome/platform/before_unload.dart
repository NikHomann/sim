/// The `beforeunload` prompt of `useSettingsBrowserNavigation`
/// (`use-settings-browser-navigation.ts:205-217`): web only.
library;

export 'before_unload_stub.dart'
    if (dart.library.js_interop) 'before_unload_web.dart';
