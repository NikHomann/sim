/// The global command registry (`app/workspace/[workspaceId]/utils/commands.ts`
/// `COMMAND_DEFINITIONS`): every command id with its shortcut and whether it
/// fires while an editable target has focus.
library;

/// The 11 command ids of `COMMAND_DEFINITIONS`.
enum CommandId {
  acceptDiffChanges('accept-diff-changes'),
  addAgent('add-agent'),
  addWorkflow('add-workflow'),
  gotoLogs('goto-logs'),
  openSearch('open-search'),
  openWorkflowSearchReplace('open-workflow-search-replace'),
  runWorkflow('run-workflow'),
  clearTerminalConsole('clear-terminal-console'),
  focusToolbarSearch('focus-toolbar-search'),
  fitToView('fit-to-view'),
  toggleSidebar('toggle-sidebar')
  ;

  const CommandId(this.wireName);

  /// The upstream string id.
  final String wireName;
}

/// One registry entry (`CommandDefinition`).
class CommandDefinition {
  const CommandDefinition({
    required this.id,
    required this.shortcut,
    required this.allowInEditable,
  });

  final CommandId id;

  /// `Mod+K` style binding; `Mod` is Meta on macOS and Ctrl elsewhere.
  final String shortcut;
  final bool allowInEditable;
}

/// `COMMAND_DEFINITIONS`, in the upstream declaration order (the matcher's
/// first-match-wins order follows registration, not this list).
const Map<CommandId, CommandDefinition> commandDefinitions = {
  CommandId.acceptDiffChanges: CommandDefinition(
    id: CommandId.acceptDiffChanges,
    shortcut: 'Mod+Shift+Enter',
    allowInEditable: true,
  ),
  CommandId.addAgent: CommandDefinition(
    id: CommandId.addAgent,
    shortcut: 'Mod+Shift+A',
    allowInEditable: true,
  ),
  CommandId.addWorkflow: CommandDefinition(
    id: CommandId.addWorkflow,
    shortcut: 'Mod+Shift+P',
    allowInEditable: false,
  ),
  CommandId.gotoLogs: CommandDefinition(
    id: CommandId.gotoLogs,
    shortcut: 'Mod+L',
    allowInEditable: true,
  ),
  CommandId.openSearch: CommandDefinition(
    id: CommandId.openSearch,
    shortcut: 'Mod+K',
    allowInEditable: true,
  ),
  CommandId.openWorkflowSearchReplace: CommandDefinition(
    id: CommandId.openWorkflowSearchReplace,
    shortcut: 'Mod+F',
    allowInEditable: true,
  ),
  CommandId.runWorkflow: CommandDefinition(
    id: CommandId.runWorkflow,
    shortcut: 'Mod+Enter',
    allowInEditable: false,
  ),
  CommandId.clearTerminalConsole: CommandDefinition(
    id: CommandId.clearTerminalConsole,
    shortcut: 'Mod+D',
    allowInEditable: false,
  ),
  CommandId.focusToolbarSearch: CommandDefinition(
    id: CommandId.focusToolbarSearch,
    shortcut: 'Mod+Alt+F',
    allowInEditable: false,
  ),
  CommandId.fitToView: CommandDefinition(
    id: CommandId.fitToView,
    shortcut: 'Mod+Shift+F',
    allowInEditable: false,
  ),
  CommandId.toggleSidebar: CommandDefinition(
    id: CommandId.toggleSidebar,
    shortcut: 'Mod+B',
    allowInEditable: false,
  ),
};
