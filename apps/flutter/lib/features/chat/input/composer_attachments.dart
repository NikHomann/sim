import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/input/model/composer_models.dart';
import 'package:sim_app/features/chat/input/platform/composer_platform_types.dart';

/// `MULTI_FILE_UPLOAD_MAX_FILES`.
const int composerMaxFiles = 20;

/// `MAX_WORKSPACE_FILE_SIZE` (5 GiB) and the aggregate bound (5 files' worth).
const int composerMaxFileBytes = 5 * 1024 * 1024 * 1024;
const int composerMaxTotalBytes = 5 * composerMaxFileBytes;

/// `WHOLE_FILE_PARALLEL_UPLOADS`.
const int composerParallelUploads = 3;

/// `formatBinaryBytes`.
String formatBinaryBytes(int bytes) {
  const gib = 1024 * 1024 * 1024;
  const mib = 1024 * 1024;
  if (bytes % gib == 0) return '${bytes ~/ gib} GiB';
  if (bytes % mib == 0) return '${bytes ~/ mib} MiB';
  return '$bytes bytes';
}

/// A refused selection (`MultiFileUploadAdmissionError`).
class AttachmentAdmissionError implements Exception {
  const AttachmentAdmissionError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `assertMultiFileUploadAdmission` with the composer's limits.
void assertAttachmentAdmission(
  List<({String name, int size})> files, {
  List<({String name, int size})> existing = const [],
  int maxFiles = composerMaxFiles,
  int maxFileBytes = composerMaxFileBytes,
  int maxTotalBytes = composerMaxTotalBytes,
}) {
  if (existing.length + files.length > maxFiles) {
    throw AttachmentAdmissionError('Select up to $maxFiles files at a time.');
  }
  var total = 0;
  for (final file in [...existing, ...files]) {
    if (file.size > maxFileBytes) {
      final label = file.name.isEmpty ? 'A selected file' : '"${file.name}"';
      throw AttachmentAdmissionError(
        '$label is too large. Each file must be '
        '${formatBinaryBytes(maxFileBytes)} or smaller.',
      );
    }
    total += file.size;
  }
  if (total > maxTotalBytes) {
    throw AttachmentAdmissionError(
      'Select files totaling ${formatBinaryBytes(maxTotalBytes)} or less.',
    );
  }
}

const Map<String, String> _mimeByExtension = {
  'pdf': 'application/pdf',
  'csv': 'text/csv',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'xls': 'application/vnd.ms-excel',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'html': 'text/html',
  'htm': 'text/html',
  'json': 'application/json',
  'jsonl': 'application/x-ndjson',
  'yaml': 'application/x-yaml',
  'yml': 'application/x-yaml',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'flac': 'audio/flac',
  'aac': 'audio/aac',
  'opus': 'audio/opus',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'avi': 'video/x-msvideo',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
  'zip': 'application/zip',
};

/// The file's extension, lower-case, without the dot ('' when none).
String fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
}

/// `resolveFileType`: the browser type unless it is generic, else by
/// extension.
String resolveFileType(String name, String browserType) {
  final type = browserType.trim();
  if (type.isNotEmpty && type != 'application/octet-stream') return type;
  return _mimeByExtension[fileExtension(name)] ?? 'application/octet-stream';
}

/// `MOTHERSHIP_ACCEPT_ATTRIBUTE` (documents, code/text, audio, video,
/// images, zip) as an `accept` list of extensions.
const String composerAcceptAttribute =
    '.pdf,.csv,.doc,.docx,.txt,.md,.xlsx,.xls,.pptx,.html,.htm,.json,.jsonl,'
    '.yaml,.yml,.mdx,.xml,.css,.scss,.less,.js,.jsx,.ts,.tsx,.py,.rb,.go,.rs,'
    '.java,.kt,.swift,.c,.cpp,.h,.hpp,.cs,.php,.sh,.bash,.zsh,.fish,.sql,'
    '.graphql,.gql,.toml,.ini,.conf,.cfg,.env,.log,.diff,.patch,.mmd,.chart,'
    '.mp3,.m4a,.wav,.webm,.ogg,.flac,.aac,.opus,.mp4,.mov,.avi,.mkv,.png,'
    '.jpg,.jpeg,.gif,.webp,.svg,.bmp,.tif,.tiff,.heic,.heif,.avif,.ico,.zip,'
    'application/zip';

/// One attachment card (`AttachedFile`).
@immutable
class ComposerAttachment {
  const ComposerAttachment({
    required this.id,
    required this.name,
    required this.size,
    required this.type,
    this.path = '',
    this.key,
    this.uploading = false,
    this.previewUrl,
    this.previewBytes,
  });

  final String id;
  final String name;
  final int size;
  final String type;
  final String path;
  final String? key;
  final bool uploading;

  /// Served thumbnail URL (uploaded image/video).
  final String? previewUrl;

  /// Local bytes shown before the upload lands (browser-renderable images).
  final Uint8List? previewBytes;

  bool get isImage => type.startsWith('image/');
  bool get isVideo => type.startsWith('video/');
  bool get isMedia => isImage || isVideo;

  ComposerAttachment copyWith({
    String? path,
    String? key,
    bool? uploading,
    String? previewUrl,
  }) => ComposerAttachment(
    id: id,
    name: name,
    size: size,
    type: type,
    path: path ?? this.path,
    key: key ?? this.key,
    uploading: uploading ?? this.uploading,
    previewUrl: previewUrl ?? this.previewUrl,
    previewBytes: previewBytes,
  );

  ComposerFileAttachment? toApi() {
    final k = key;
    if (uploading || k == null || k.isEmpty) return null;
    return ComposerFileAttachment(
      id: id,
      key: k,
      filename: name,
      mediaType: type,
      size: size,
      path: path.isEmpty ? null : path,
    );
  }
}

/// Cancellation of one upload (removing its card).
class ComposerUploadCancel {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  /// Runs [listener] on cancel (at once when already cancelled).
  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

/// Uploads one attachment (`uploadInternalFileSession`, purpose
/// `mothership_attachment`) and returns its storage `key` and `path`.
// ignore: one_member_abstracts, a seam the tests fake
abstract interface class ComposerUploader {
  Future<({String key, String path})> upload(
    ComposerPickedFile file, {
    required String contentType,
    required ComposerUploadCancel cancel,
  });
}

/// [ComposerUploader] over the signed upload-session protocol.
class HttpComposerUploader implements ComposerUploader {
  HttpComposerUploader(this._client, {required this.workspaceId});

  final UploadSessionClient _client;
  final String workspaceId;

  @override
  Future<({String key, String path})> upload(
    ComposerPickedFile file, {
    required String contentType,
    required ComposerUploadCancel cancel,
  }) async {
    final completed = await _client.upload(
      body: {
        'purpose': 'mothership_attachment',
        'workspaceId': workspaceId,
        'name': file.name,
        'contentType': contentType,
        'size': file.size,
      },
      source: BytesUploadSource(name: file.name, bytes: file.bytes),
      onSession: (session) => cancel.onCancel(session.cancelToken.cancel),
    );
    final result = completed['result'];
    if (result is! Map) {
      throw StateError(
        'Completed mothership_attachment upload returned no result',
      );
    }
    final key = result['key'];
    final path = result['path'];
    if (key is! String) throw StateError('Upload result has no key');
    return (key: key, path: path is String ? path : '');
  }
}

/// Runs [worker] over [items] with at most [limit] in flight.
Future<void> _runWithConcurrency<T>(
  List<T> items,
  int limit,
  Future<void> Function(T item, int index) worker,
) async {
  var next = 0;
  Future<void> runner() async {
    while (next < items.length) {
      final index = next++;
      await worker(items[index], index);
    }
  }

  await Future.wait([
    for (var i = 0; i < math.min(limit, items.length); i++) runner(),
  ]);
}

/// The attachment pipeline (`use-file-attachments.ts`): admission, a
/// placeholder card per file at once, three uploads in parallel, failure
/// removes the card and reports, removing an uploading card aborts it.
class ComposerAttachmentsController extends ChangeNotifier {
  ComposerAttachmentsController({
    required this.uploader,
    required this.onError,
    String Function()? idGenerator,
  }) : _nextId = idGenerator ?? _defaultId;

  static int _counter = 0;
  static String _defaultId() =>
      'att-${DateTime.now().microsecondsSinceEpoch}-${++_counter}';

  ComposerUploader? uploader;

  /// `toast.error(message, {description})`.
  final void Function(String message, String? description) onError;
  final String Function() _nextId;
  final Map<String, ComposerUploadCancel> _tokens = {};
  List<ComposerAttachment> _items = const [];
  bool _disposed = false;

  List<ComposerAttachment> get attachments => _items;
  bool get hasUploading => _items.any((a) => a.uploading);
  bool get hasUploaded => _items.any((a) => !a.uploading && a.key != null);

  List<ComposerFileAttachment> get uploaded => [
    for (final a in _items) ?a.toApi(),
  ];

  void _set(List<ComposerAttachment> next) {
    if (_disposed) return;
    _items = List.unmodifiable(next);
    notifyListeners();
  }

  /// `processFiles`.
  Future<void> addFiles(List<ComposerPickedFile> files) async {
    if (files.isEmpty) return;
    final upload = uploader;
    if (upload == null) {
      developer.log('No uploader for attachments', name: 'sim_app.composer');
      return;
    }
    try {
      assertAttachmentAdmission(
        [for (final f in files) (name: f.name, size: f.size)],
        existing: [for (final a in _items) (name: a.name, size: a.size)],
      );
    } on AttachmentAdmissionError catch (error) {
      onError("Couldn't add files", error.message);
      return;
    }
    final placeholders = [
      for (final file in files)
        () {
          final type = resolveFileType(file.name, file.mimeType);
          final local =
              type.startsWith('image/') && !type.startsWith('image/hei');
          return ComposerAttachment(
            id: _nextId(),
            name: file.name,
            size: file.size,
            type: type,
            uploading: true,
            previewBytes: local ? file.bytes : null,
          );
        }(),
    ];
    for (final p in placeholders) {
      _tokens[p.id] = ComposerUploadCancel();
    }
    _set([..._items, ...placeholders]);
    await _runWithConcurrency(files, composerParallelUploads, (file, i) async {
      final placeholder = placeholders[i];
      final token = _tokens[placeholder.id];
      if (token == null || token.isCancelled) return;
      try {
        final result = await upload.upload(
          file,
          contentType: file.mimeType.isEmpty ? placeholder.type : file.mimeType,
          cancel: token,
        );
        _set([
          for (final a in _items)
            if (a.id == placeholder.id)
              a.copyWith(
                path: result.path,
                key: result.key,
                uploading: false,
                previewUrl: mothershipAttachmentPreviewUrl(result.key, a.type),
              )
            else
              a,
        ]);
      } on Object catch (error) {
        if (!token.isCancelled) {
          onError(
            'Couldn\'t upload "${file.name}"',
            error is ApiClientError ? error.message : '$error',
          );
        }
        _set([
          for (final a in _items)
            if (a.id != placeholder.id) a,
        ]);
      } finally {
        _tokens.remove(placeholder.id);
      }
    });
  }

  /// Removes a card, aborting its upload.
  void remove(String id) {
    _tokens.remove(id)?.cancel();
    _set([
      for (final a in _items)
        if (a.id != id) a,
    ]);
  }

  /// Restores uploaded attachments (draft / queued message), replacing the
  /// current cards (in-flight uploads are aborted).
  void restore(List<ComposerFileAttachment> files) {
    for (final token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    _set([
      for (final f in files)
        ComposerAttachment(
          id: f.id,
          name: f.filename,
          size: f.size,
          type: f.mediaType,
          path: f.path ?? '',
          key: f.key,
          previewUrl: mothershipAttachmentPreviewUrl(f.key, f.mediaType),
        ),
    ]);
  }

  /// Drops every card (after submit), aborting uploads.
  void clear() {
    for (final token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    _set(const []);
  }

  @override
  void dispose() {
    for (final token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    _disposed = true;
    super.dispose();
  }
}
