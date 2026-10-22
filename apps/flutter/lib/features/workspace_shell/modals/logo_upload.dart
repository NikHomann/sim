import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';

/// `MAX_LOGO_SIZE` (`lib/uploads/client/logo-file.ts`).
const int maxLogoBytes = 5 * 1024 * 1024;

/// `LOGO_IMAGE_TYPES`; joined with `,` it is the picker's `accept`.
const List<String> logoImageTypes = <String>[
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/gif',
  'image/svg+xml',
  'image/webp',
];

/// `validateLogoFile`: size first, then type.
String? validateLogoFile({
  required String name,
  required int size,
  required String contentType,
}) {
  if (size > maxLogoBytes) {
    return 'File "$name" is too large. Maximum size is 5MB.';
  }
  if (!logoImageTypes.contains(contentType)) {
    return 'File "$name" is not a supported image format. Please use PNG, '
        'JPEG, GIF, SVG, or WebP.';
  }
  return null;
}

/// `useWorkspaceLogoUpload` (`use-workspace-logo-upload.ts`): validate, run
/// the signed upload session with purpose `workspace_logo`, then
/// `PATCH /api/workspaces/[id] {logoUrl: result.path}`. Errors go to
/// [onError] (logged upstream, no UI). The switcher owns the file picker
/// (`accept` = [logoImageTypes] joined with `,`) and the optimistic preview,
/// reverted when [upload] returns null.
class WorkspaceLogoUploader {
  WorkspaceLogoUploader({
    required UploadSessionClient uploads,
    required WorkspacesCubit workspaces,
    this.onError,
  }) : _uploads = uploads,
       _workspaces = workspaces;

  /// The uploader over the app's [SimHttpClient] and [WorkspacesCubit].
  factory WorkspaceLogoUploader.fromLocator({
    void Function(String message)? onError,
  }) => WorkspaceLogoUploader(
    uploads: UploadSessionClient(locator<SimHttpClient>()),
    workspaces: locator<WorkspacesCubit>(),
    onError: onError,
  );

  final UploadSessionClient _uploads;
  final WorkspacesCubit _workspaces;
  final void Function(String message)? onError;

  void _fail(String message) {
    developer.log(message, name: 'sim_app.logo-upload');
    onError?.call(message);
  }

  /// Returns the stored logo path, or null when rejected or failed.
  Future<String?> upload({
    required String workspaceId,
    required String name,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final invalid = validateLogoFile(
      name: name,
      size: bytes.length,
      contentType: contentType,
    );
    if (invalid != null) {
      _fail(invalid);
      return null;
    }
    final String path;
    try {
      final completed = await _uploads.upload(
        body: <String, Object?>{
          'purpose': 'workspace_logo',
          'workspaceId': workspaceId,
          'name': name,
          'contentType': contentType,
          'size': bytes.length,
        },
        source: BytesUploadSource(name: name, bytes: bytes),
      );
      final purpose = completed['purpose'];
      final result = completed['result'];
      final resultPath = result is Map ? result['path'] : null;
      if (purpose != 'workspace_logo' || resultPath is! String) {
        _fail('Completed workspace_logo upload returned no result');
        return null;
      }
      path = resultPath;
    } on Object catch (error) {
      _fail('Failed to upload logo: $error');
      return null;
    }
    final updated = await _workspaces.update(workspaceId, logoUrl: path);
    if (!updated) {
      _fail('Failed to save workspace logo');
      return null;
    }
    return path;
  }
}
