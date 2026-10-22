import 'package:flutter/foundation.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';

/// Which composer: the hero on the empty Home (`isInitialView`: mode
/// selector, ambient shadow, 56px editor minimum, animated placeholder) or
/// the conversation footer.
enum ComposerVariant { hero, conversation }

/// `ChatRequestMode` values the workspace composer offers.
enum ComposerMode {
  agent('agent', 'Build'),
  plan('plan', 'Plan')
  ;

  const ComposerMode(this.wire, this.label);

  final String wire;
  final String label;
}

/// `getConversationModes(false, planEnabled)`: Build, plus Plan when the
/// `mothership-plan-mode` flag is on. (Search exists only in organization
/// chat.)
List<ComposerMode> conversationModes({required bool planEnabled}) => [
  ComposerMode.agent,
  if (planEnabled) ComposerMode.plan,
];

/// `MothershipEffort` (`lib/mothership/model-options.ts`).
enum ComposerEffort {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  xhigh('xhigh', 'Extra High'),
  max('max', 'Max')
  ;

  const ComposerEffort(this.wire, this.label);

  final String wire;
  final String label;

  /// Parses a stored value; the retired `none` reads as [low].
  static ComposerEffort? fromWire(String? wire) {
    if (wire == 'none') return low;
    for (final effort in values) {
      if (effort.wire == wire) return effort;
    }
    return null;
  }
}

/// `MOTHERSHIP_SIMPLE_EFFORT_OPTIONS`.
const List<ComposerEffort> simpleEffortOptions = [
  ComposerEffort.low,
  ComposerEffort.medium,
  ComposerEffort.high,
  ComposerEffort.xhigh,
];

/// `MOTHERSHIP_MODEL_OPTIONS`.
enum ComposerModel {
  gpt6Astra('gpt-6-astra', 'GPT-6 Astra'),
  gpt6Sol('gpt-6-sol', 'GPT-6.1 Sol'),
  opus55('claude-opus-5-5', 'Opus 5.5')
  ;

  const ComposerModel(this.wire, this.label);

  final String wire;
  final String label;

  static ComposerModel? fromWire(String? wire) {
    if (wire == 'claude-opus-5') return opus55;
    for (final model in values) {
      if (model.wire == wire) return model;
    }
    return null;
  }
}

/// `ModelSelection`.
@immutable
class ComposerModelSelection {
  const ComposerModelSelection({required this.model, this.fastMode = false});

  final ComposerModel model;
  final bool fastMode;

  /// `normalizeModelSelection`: Opus 5.5 has no Fast mode.
  ComposerModelSelection normalized() => ComposerModelSelection(
    model: model,
    fastMode: model != ComposerModel.opus55 && fastMode,
  );

  Map<String, Object?> toJson() => {'model': model.wire, 'fastMode': fastMode};

  @override
  bool operator ==(Object other) =>
      other is ComposerModelSelection &&
      other.model == model &&
      other.fastMode == fastMode;

  @override
  int get hashCode => Object.hash(model, fastMode);
}

/// `resolveMothershipModelSettings`: the effective effort and model.
({ComposerEffort effort, ComposerModelSelection? modelSelection})
resolveModelSettings({
  required bool advanced,
  ComposerEffort? effort,
  ComposerModelSelection? modelSelection,
  bool plan = false,
}) {
  var resolved = effort ?? (plan ? ComposerEffort.medium : ComposerEffort.high);
  if (!advanced) {
    if (!plan && resolved == ComposerEffort.max) {
      resolved = ComposerEffort.xhigh;
    }
    return (
      effort: resolved,
      modelSelection: plan
          ? const ComposerModelSelection(model: ComposerModel.opus55)
          : null,
    );
  }
  return (
    effort: resolved,
    modelSelection:
        (modelSelection ??
                ComposerModelSelection(
                  model: plan ? ComposerModel.opus55 : ComposerModel.gpt6Astra,
                ))
            .normalized(),
  );
}

/// `FileAttachmentForApi`: an uploaded attachment as the engine sends it.
@immutable
class ComposerFileAttachment {
  const ComposerFileAttachment({
    required this.id,
    required this.key,
    required this.filename,
    required this.mediaType,
    required this.size,
    this.path,
  });

  static ComposerFileAttachment? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final key = json['key'];
    final filename = json['filename'];
    final mediaType = json['media_type'];
    final size = json['size'];
    if (id is! String ||
        key is! String ||
        filename is! String ||
        mediaType is! String ||
        size is! num) {
      return null;
    }
    final path = json['path'];
    return ComposerFileAttachment(
      id: id,
      key: key,
      filename: filename,
      mediaType: mediaType,
      size: size.toInt(),
      path: path is String && path.isNotEmpty ? path : null,
    );
  }

  final String id;
  final String key;
  final String filename;
  final String mediaType;
  final int size;
  final String? path;

  Map<String, Object?> toJson() => {
    'id': id,
    'key': key,
    'filename': filename,
    'media_type': mediaType,
    'size': size,
    'path': ?path,
  };

  @override
  bool operator ==(Object other) =>
      other is ComposerFileAttachment &&
      other.id == id &&
      other.key == key &&
      other.filename == filename &&
      other.mediaType == mediaType &&
      other.size == size &&
      other.path == path;

  @override
  int get hashCode => Object.hash(id, key, filename, mediaType, size, path);
}

/// What the composer hands to the chat engine on submit
/// (`onSubmit(text, fileAttachments, contexts)` plus the toolbar state).
@immutable
class ComposerSubmission {
  const ComposerSubmission({
    required this.text,
    required this.contexts,
    required this.fileAttachments,
    required this.effort,
    required this.mode,
    this.modelSelection,
  });

  /// Plain text: skill sentinels restored to `/`, untrimmed (the host trims).
  final String text;

  /// Contexts whose token is still in the text (`getActiveContexts`).
  final List<ChatContext> contexts;

  /// Uploaded attachments only (uploading ones are never sent).
  final List<ComposerFileAttachment> fileAttachments;
  final ComposerEffort effort;
  final ComposerMode mode;

  /// Only with the `mothership-model-selector` flag (or Plan's Opus default).
  final ComposerModelSelection? modelSelection;
}

/// A queued message loaded back for editing (`loadQueuedMessage`).
@immutable
class ComposerQueuedMessage {
  const ComposerQueuedMessage({
    required this.content,
    this.contexts = const [],
    this.fileAttachments = const [],
  });

  final String content;
  final List<ChatContext> contexts;
  final List<ComposerFileAttachment> fileAttachments;
}

/// `getMothershipAttachmentUrl` / `...PreviewUrl` paths.
String mothershipAttachmentUrl(String key) =>
    '/api/files/serve/${Uri.encodeComponent(key)}?context=mothership';

/// The thumbnail URL of an image/video attachment; `null` for documents.
String? mothershipAttachmentPreviewUrl(String key, String mediaType) {
  final isImage = mediaType.startsWith('image/');
  if (!isImage && !mediaType.startsWith('video/')) return null;
  return '${mothershipAttachmentUrl(key)}${isImage ? '&preview=1' : ''}';
}
