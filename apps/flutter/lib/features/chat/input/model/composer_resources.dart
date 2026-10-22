import 'package:flutter/foundation.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';

/// `MothershipResourceType`: the resource families of the `+` / `@` menus.
enum ComposerResourceType {
  integration('Integrations'),
  task('Chats'),
  dashboard('Dashboards'),
  test('Tests'),
  table('Tables'),
  file('Files'),
  filefolder('File Folders'),
  knowledgebase('Knowledge Bases'),
  workflow('Workflows'),
  log('Logs'),
  folder('Folders'),
  browser('Browser'),
  terminal('Terminal'),
  generic('Docs')
  ;

  const ComposerResourceType(this.label);

  /// The registry label used as the menu heading / submenu name.
  final String label;
}

/// `RESOURCE_MENU_ORDER` (the declaration order above).
const List<ComposerResourceType> resourceMenuOrder =
    ComposerResourceType.values;

/// `MENTION_PREVIEW_DEFAULT_LIMIT`: rows per family in an empty `@` list.
const int mentionPreviewDefaultLimit = 5;

/// One mentionable / attachable resource (`AvailableItem`).
@immutable
class ComposerResource {
  const ComposerResource({
    required this.type,
    required this.id,
    required this.name,
    this.workspaceId,
    this.workspaceName,
    this.mentionFamily,
    this.viewId,
    this.executionId,
    this.secondary,
  });

  final ComposerResourceType type;
  final String id;
  final String name;
  final String? workspaceId;
  final String? workspaceName;

  /// Extra searchable family text ("Table folders", "Browser").
  final String? mentionFamily;
  final String? viewId;
  final String? executionId;

  /// Right-aligned secondary text (a log row's time).
  final String? secondary;

  /// `resourceMentionMatches`.
  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        (workspaceName?.toLowerCase().contains(q) ?? false) ||
        (mentionFamily?.toLowerCase().contains(q) ?? false);
  }

  /// `mapResourceToContext` (`constants.ts:114-147`); `null` for families
  /// without a chat context (`test`).
  ChatContext? toContext() => switch (type) {
    ComposerResourceType.browser => ChatContext(
      kind: ChatContextKind.browserTab,
      label: name,
      fields: {'tabId': id},
    ),
    ComposerResourceType.terminal => ChatContext(
      kind: ChatContextKind.terminalTab,
      label: name,
      fields: {'terminalId': id},
    ),
    ComposerResourceType.workflow => ChatContext.workflow(id, name),
    ComposerResourceType.knowledgebase => ChatContext(
      kind: ChatContextKind.knowledge,
      label: name,
      fields: {'knowledgeId': id},
    ),
    ComposerResourceType.table => ChatContext(
      kind: ChatContextKind.table,
      label: name,
      fields: {'tableId': id, 'viewId': ?viewId},
    ),
    ComposerResourceType.dashboard => ChatContext(
      kind: ChatContextKind.dashboard,
      label: name,
      fields: {'dashboardId': id},
    ),
    ComposerResourceType.test => null,
    ComposerResourceType.file => ChatContext(
      kind: ChatContextKind.file,
      label: name,
      fields: {'fileId': id},
    ),
    ComposerResourceType.folder => ChatContext(
      kind: ChatContextKind.folder,
      label: name,
      fields: {'folderId': id},
    ),
    ComposerResourceType.filefolder => ChatContext(
      kind: ChatContextKind.filefolder,
      label: name,
      fields: {'fileFolderId': id},
    ),
    ComposerResourceType.task => ChatContext(
      kind: ChatContextKind.pastChat,
      label: name,
      fields: {'chatId': id},
    ),
    ComposerResourceType.log => ChatContext(
      kind: ChatContextKind.logs,
      label: name,
      fields: {'executionId': executionId ?? id},
    ),
    ComposerResourceType.integration => ChatContext.integration(id, name),
    ComposerResourceType.generic => ChatContext(
      kind: ChatContextKind.docs,
      label: name,
    ),
  };
}

/// One family of the inventory.
@immutable
class ComposerResourceGroup {
  const ComposerResourceGroup(this.type, this.items);

  final ComposerResourceType type;
  final List<ComposerResource> items;
}

/// A skill offered by the `/` menu (`SkillDefinition`).
@immutable
class ComposerSkill {
  const ComposerSkill({
    required this.id,
    required this.name,
    this.workspaceId,
    this.workspaceName,
    this.builtin = false,
  });

  final String id;
  final String name;
  final String? workspaceId;
  final String? workspaceName;

  /// `isBuiltinSkillId`: built-in skills carry no owner.
  final bool builtin;
}

/// An MCP server offered by the `/` menu.
@immutable
class ComposerMcpServer {
  const ComposerMcpServer({
    required this.id,
    required this.name,
    this.managedConnectorId,
  });

  final String id;
  final String name;
  final String? managedConnectorId;
}

/// An integration block the `@` auto-mention recognises
/// (`IntegrationDescriptor`, display name with `(Legacy)`/`V2` stripped).
@immutable
class ComposerIntegration {
  const ComposerIntegration({required this.blockType, required this.name});

  final String blockType;
  final String name;
}
