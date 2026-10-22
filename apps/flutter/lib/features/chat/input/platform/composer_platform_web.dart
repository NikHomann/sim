import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sim_app/features/chat/input/platform/composer_platform_types.dart';
import 'package:web/web.dart' as web;

/// Clipboard files, custom MIME and file drop are available on the web.
const bool composerRichClipboard = true;
const bool composerFileDropSupported = true;
const bool composerFilePickerSupported = true;

/// `matchMedia('(pointer: coarse)')`, the touch half of
/// `isTouchMobileViewport` (`hooks/use-is-mobile.ts`).
bool composerCoarsePointer() =>
    debugComposerCoarsePointer ??
    web.window.matchMedia('(pointer: coarse)').matches;

Future<List<ComposerPickedFile>> _readFiles(web.FileList? files) async {
  if (files == null) return const [];
  final out = <ComposerPickedFile>[];
  for (var i = 0; i < files.length; i++) {
    final file = files.item(i);
    if (file == null) continue;
    final buffer = await file.arrayBuffer().toDart;
    out.add(
      ComposerPickedFile(
        name: file.name,
        bytes: Uint8List.view(buffer.toDart),
        mimeType: file.type,
      ),
    );
  }
  return out;
}

/// Document-level `paste` / `copy` / `cut` listeners routed to the focused
/// composer: custom MIME, portable chip links, clipboard files.
void Function() installComposerClipboard(ComposerClipboardTarget target) {
  void onPaste(web.Event event) {
    if (!target.hasFocus || !event.isA<web.ClipboardEvent>()) return;
    final data = (event as web.ClipboardEvent).clipboardData;
    if (data == null) return;
    final text = data.getData('text/plain');
    final payload = data.getData(simSelectionMime);
    if (target.onPaste(
      text: text,
      selectionPayload: payload.isEmpty ? null : payload,
      files: const [],
    )) {
      event.preventDefault();
      return;
    }
    if (text.isNotEmpty) return;
    final files = data.files;
    if (files.length == 0) return;
    event.preventDefault();
    unawaited(() async {
      final picked = await _readFiles(files);
      if (picked.isEmpty) return;
      target.onPaste(text: '', selectionPayload: null, files: picked);
    }());
  }

  void Function(web.Event) copyHandler({required bool cut}) => (event) {
    if (!target.hasFocus || !event.isA<web.ClipboardEvent>()) return;
    final data = (event as web.ClipboardEvent).clipboardData;
    if (data == null) return;
    final result = target.onCopy(cut: cut);
    if (result == null) return;
    event.preventDefault();
    data.setData('text/plain', result.text);
    final payload = result.selectionPayload;
    if (payload != null) {
      try {
        data.setData(simSelectionMime, payload);
      } on Object {
        // Some browsers reject custom types mid-gesture.
      }
    }
  };

  final paste = onPaste.toJS;
  final copy = copyHandler(cut: false).toJS;
  final cut = copyHandler(cut: true).toJS;
  web.document
    ..addEventListener('paste', paste)
    ..addEventListener('copy', copy)
    ..addEventListener('cut', cut);
  return () {
    web.document
      ..removeEventListener('paste', paste)
      ..removeEventListener('copy', copy)
      ..removeEventListener('cut', cut);
  };
}

bool _carriesFiles(web.DragEvent event) {
  final types = event.dataTransfer?.types.toDart ?? const <JSString>[];
  return types.any((t) => t.toDart == 'Files');
}

/// Document-level OS file drag listeners hit-tested against the composer.
void Function() installComposerFileDrop(ComposerDropTarget target) {
  var over = false;

  void onDragOver(web.Event event) {
    if (!event.isA<web.DragEvent>()) return;
    final drag = event as web.DragEvent;
    if (!_carriesFiles(drag)) return;
    final inside = target.containsGlobal(
      drag.clientX.toDouble(),
      drag.clientY.toDouble(),
    );
    if (inside) {
      drag.preventDefault();
      drag.dataTransfer?.dropEffect = 'copy';
      if (!over) {
        over = true;
        target.onDragEnter();
      }
    } else if (over) {
      over = false;
      target.onDragLeave();
    }
  }

  void onDragLeave(web.Event event) {
    if (!event.isA<web.DragEvent>()) return;
    final drag = event as web.DragEvent;
    if (drag.relatedTarget == null && over) {
      over = false;
      target.onDragLeave();
    }
  }

  void onDrop(web.Event event) {
    if (!event.isA<web.DragEvent>() || !over) return;
    final drag = (event as web.DragEvent)..preventDefault();
    over = false;
    target.onDragLeave();
    final files = drag.dataTransfer?.files;
    unawaited(() async {
      final picked = await _readFiles(files);
      if (picked.isNotEmpty) target.onDrop(picked);
    }());
  }

  final dragOver = onDragOver.toJS;
  final dragLeave = onDragLeave.toJS;
  final drop = onDrop.toJS;
  web.document
    ..addEventListener('dragover', dragOver)
    ..addEventListener('dragleave', dragLeave)
    ..addEventListener('drop', drop);
  return () {
    web.document
      ..removeEventListener('dragover', dragOver)
      ..removeEventListener('dragleave', dragLeave)
      ..removeEventListener('drop', drop);
  };
}

/// The hidden `<input type=file multiple accept>`.
Future<List<ComposerPickedFile>> pickComposerFiles({required String accept}) {
  final completer = Completer<List<ComposerPickedFile>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = true;
  input
    ..onchange = (web.Event _) {
      unawaited(() async {
        completer.complete(await _readFiles(input.files));
      }());
    }.toJS
    ..oncancel = (web.Event _) {
      if (!completer.isCompleted) completer.complete(const []);
    }.toJS
    ..click();
  return completer.future;
}
