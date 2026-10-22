/// The web build's capture-phase `keydown` listener (global-behaviours.md
/// row 5): a chord a global command will handle has its browser default
/// (`Mod+L` focusing the address bar, `Mod+K` the search bar) prevented
/// before the browser acts, independent of how the engine replies.
library;

export 'shortcut_capture_stub.dart'
    if (dart.library.js_interop) 'shortcut_capture_web.dart';
