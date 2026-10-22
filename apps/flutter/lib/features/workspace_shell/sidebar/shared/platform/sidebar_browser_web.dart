import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sim_app/features/workspace_shell/sidebar/shared/platform/picked_file.dart';
import 'package:web/web.dart' as web;

export 'package:sim_app/features/workspace_shell/sidebar/shared/platform/picked_file.dart';

/// The real browser.
class SidebarBrowser {
  const SidebarBrowser();

  String? get origin => web.window.location.origin;

  bool get isMac => web.window.navigator.platform.toUpperCase().contains('MAC');

  String get userAgent => web.window.navigator.userAgent;

  /// `window.location.assign(url)`.
  void assign(String url) => web.window.location.assign(url);

  /// `window.open(url, '_blank', 'noopener,noreferrer')`.
  void openNewTab(String url) =>
      web.window.open(url, '_blank', 'noopener,noreferrer');

  /// Opens a hidden `<input type=file accept multiple>` and resolves with the
  /// chosen files (empty when the dialog is cancelled).
  Future<List<PickedFile>> pickFiles({
    required String accept,
    bool multiple = false,
  }) {
    final completer = Completer<List<PickedFile>>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = accept
      ..multiple = multiple;
    input
      ..onchange = (web.Event _) {
        final files = input.files;
        if (files == null || files.length == 0) {
          completer.complete(const <PickedFile>[]);
          return;
        }
        unawaited(() async {
          final picked = <PickedFile>[];
          for (var i = 0; i < files.length; i++) {
            final file = files.item(i);
            if (file == null) continue;
            final buffer = await file.arrayBuffer().toDart;
            picked.add(
              PickedFile(
                name: file.name,
                bytes: Uint8List.view(buffer.toDart),
                mimeType: file.type,
              ),
            );
          }
          completer.complete(picked);
        }());
      }.toJS
      ..oncancel = (web.Event _) {
        if (!completer.isCompleted) completer.complete(const <PickedFile>[]);
      }.toJS
      ..click();
    return completer.future;
  }
}
