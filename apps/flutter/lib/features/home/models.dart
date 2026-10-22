import 'dart:convert';

import 'package:flutter/foundation.dart';

/// `MothershipResourceType` (`lib/mothership/resources/types.ts:4-21`).
enum HomeResourceType {
  search,
  sources,
  table,
  file,
  dashboard,
  test,
  workflow,
  knowledgebase,
  folder,
  filefolder,
  task,
  log,
  integration,
  generic,
  browser,
  terminal
  ;

  /// The wire name (`'knowledgebase'`, `'filefolder'`, ...).
  String get wire => name;

  static HomeResourceType? fromWire(String? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }

  /// `RESOURCE_POLICY[type].persisted` (`types.ts:189-205`).
  bool get persisted => this != generic && this != browser && this != terminal;
}

/// `/^[0-9a-f]{8}-...-[0-9a-f]{12}$/i` (`types.ts:154`).
final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// One resource tab of a chat (`MothershipResource`, `types.ts:25-46`),
/// reduced to the fields the Home surface reads. The chat engine owns the
/// list; Home only renders, selects and edits it through the session slot.
@immutable
class HomeResource {
  const HomeResource({
    required this.type,
    required this.id,
    required this.title,
    this.workspaceId,
    this.executionId,
    this.sourcesMessageId,
    this.sourcesRequestId,
  });

  final HomeResourceType type;
  final String id;
  final String title;

  /// Non-file workspace scope (the add menu stamps the current workspace).
  final String? workspaceId;

  /// The run a log row records (`type == log` only).
  final String? executionId;

  /// `resource.sources` (`type == sources` only): the assistant message
  /// whose cited sources the panel lists.
  final String? sourcesMessageId;
  final String? sourcesRequestId;

  /// `isEphemeralResource` (`types.ts:224-232`).
  bool get isEphemeral => id == 'streaming-file' || !type.persisted;

  /// `getChatResourceKey` without an owner (`types.ts:122-136`).
  String get key => workspaceId != null
      ? jsonEncode(<String>[workspaceId!, type.wire, id])
      : '${type.wire}:$id';

  /// `getChatResourceSelectionId` (`types.ts:151-160`): UUID resources keep
  /// their own id (existing deep links), workspace aliases carry their key.
  String get selectionId =>
      workspaceId != null && !_uuid.hasMatch(id) && !isEphemeral ? key : id;

  HomeResource copyWith({String? title, String? workspaceId}) => HomeResource(
    type: type,
    id: id,
    title: title ?? this.title,
    workspaceId: workspaceId ?? this.workspaceId,
    executionId: executionId,
    sourcesMessageId: sourcesMessageId,
    sourcesRequestId: sourcesRequestId,
  );

  /// The drag payload of one tab (`SIM_RESOURCE_DRAG_TYPE`,
  /// `resource-tabs.tsx:553-561`).
  Map<String, Object?> toDragJson() => <String, Object?>{
    'type': type.wire,
    'id': id,
    'title': title,
    'workspaceId': ?workspaceId,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeResource &&
      other.type == type &&
      other.id == id &&
      other.title == title &&
      other.workspaceId == workspaceId &&
      other.executionId == executionId &&
      other.sourcesMessageId == sourcesMessageId &&
      other.sourcesRequestId == sourcesRequestId;

  @override
  int get hashCode => Object.hash(
    type,
    id,
    title,
    workspaceId,
    executionId,
    sourcesMessageId,
    sourcesRequestId,
  );

  @override
  String toString() => 'HomeResource(${type.wire}:$id "$title")';
}

/// What a resource tab drag carries out of the strip
/// (`application/x-sim-resource` for one tab, `application/x-sim-resources`
/// JSON for a multi-selection, `resource-tabs.tsx:518-562`). The composer
/// accepts it with a `DragTarget<HomeResourceDragData>`.
@immutable
class HomeResourceDragData {
  const HomeResourceDragData(this.resources);

  final List<HomeResource> resources;

  /// Whether the drag carries a multi-selection (`SIM_RESOURCES_DRAG_TYPE`).
  bool get isMulti => resources.length > 1;

  /// The MIME type React sets on the drag.
  String get mimeType =>
      isMulti ? 'application/x-sim-resources' : 'application/x-sim-resource';

  /// The JSON React puts under [mimeType].
  String encode() => isMulti
      ? jsonEncode(<Object?>[for (final r in resources) r.toDragJson()])
      : jsonEncode(resources.single.toDragJson());
}

/// A composer context (chip) as far as Home reads it
/// (`resolveResourceFromContext`, `home.tsx:258-283`): its kind, the id of
/// the resource it addresses, its chip label and, for selections, the
/// whole resource's name.
@immutable
class HomeChatContext {
  const HomeChatContext({
    required this.kind,
    required this.label,
    this.resourceId,
    this.resourceName,
  });

  /// `workflow`, `current_workflow`, `knowledge`, `table`,
  /// `table_selection`, `file`, `file_selection`, `dashboard`, or another
  /// kind Home ignores.
  final String kind;
  final String label;

  /// `workflowId` / `knowledgeId` / `tableId` / `fileId` / `dashboardId`.
  final String? resourceId;

  /// `fileName` / `tableName` of a selection context.
  final String? resourceName;

  /// The resource tab the chip opens, or null (`home.tsx:258-283`).
  ({HomeResourceType type, String id})? get resource {
    final id = resourceId;
    final type = switch (kind) {
      'workflow' || 'current_workflow' => HomeResourceType.workflow,
      'knowledge' => HomeResourceType.knowledgebase,
      'table' || 'table_selection' => HomeResourceType.table,
      'file' || 'file_selection' => HomeResourceType.file,
      'dashboard' => HomeResourceType.dashboard,
      _ => null,
    };
    if (type == null || id == null) return null;
    return (type: type, id: id);
  }

  /// `resourceTitleForContext` (`home.tsx:290-294`).
  String get resourceTitle => switch (kind) {
    'file_selection' || 'table_selection' => resourceName ?? label,
    _ => label,
  };
}

/// One attachment of an outgoing or queued message.
@immutable
class HomeAttachment {
  const HomeAttachment({required this.filename, this.id});

  final String filename;
  final String? id;
}

/// A message the composer hands to Home (`handleSubmit(text, files,
/// contexts)`, `home.tsx:211`).
@immutable
class HomeOutgoingMessage {
  const HomeOutgoingMessage({
    required this.text,
    this.attachments = const <HomeAttachment>[],
    this.contexts = const <HomeChatContext>[],
    this.payload,
  });

  final String text;
  final List<HomeAttachment> attachments;
  final List<HomeChatContext> contexts;

  /// The composer slot's own submission (uploaded file records, full
  /// context maps, effort), handed to the session slot unchanged; Home
  /// never reads it.
  final Object? payload;
}

/// A queued follow-up (`QueuedMessage`, `home/types.ts:39-48`) as the tray
/// renders it.
@immutable
class HomeQueuedMessage {
  const HomeQueuedMessage({
    required this.id,
    required this.content,
    this.attachments = const <HomeAttachment>[],
    this.contexts = const <HomeChatContext>[],
    this.admissionUnknown = false,
    this.payload,
  });

  final String id;
  final String content;
  final List<HomeAttachment> attachments;
  final List<HomeChatContext> contexts;

  /// The session slot's own queued record, handed to the composer slot
  /// unchanged when the message is loaded for editing.
  final Object? payload;

  /// The server may already have this message (editing could send twice).
  final bool admissionUnknown;
}

/// What a resource chip in an assistant message knows about its target
/// (`WorkspaceResourceRef`): a type, a best-effort id or path, a title.
@immutable
class HomeResourceRef {
  const HomeResourceRef({
    required this.type,
    required this.title,
    this.id,
    this.path,
  });

  final HomeResourceType type;
  final String title;
  final String? id;
  final String? path;
}

/// Agent/plan request mode of a new chat (`selectedMode`, `home.tsx:84`).
enum HomeRequestMode { agent, plan }
