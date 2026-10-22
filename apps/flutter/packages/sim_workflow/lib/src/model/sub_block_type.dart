/// Port of `SubBlockType` from
/// `packages/workflow-types/src/blocks.ts` (upstream 27b53561).
///
/// The 48 sub-block type ids. The wire carries these as strings; a stored
/// sub-block may carry an id this enum does not know (`trigger-config` is
/// referenced by name in `apps/sim/lib/workflows/subblocks/visibility.ts`),
/// which is why `SubBlockState.type` stays a `String` and [fromId] is nullable.
enum SubBlockType {
  shortInput('short-input'),
  longInput('long-input'),
  dropdown('dropdown'),
  combobox('combobox'),
  slider('slider'),
  table('table'),
  code('code'),
  switch_('switch'),
  toolInput('tool-input'),
  skillInput('skill-input'),
  checkboxList('checkbox-list'),
  groupedCheckboxList('grouped-checkbox-list'),
  conditionInput('condition-input'),
  evalInput('eval-input'),
  timeInput('time-input'),
  oauthInput('oauth-input'),
  webhookConfig('webhook-config'),
  scheduleInfo('schedule-info'),
  fileSelector('file-selector'),
  sheetSelector('sheet-selector'),
  projectSelector('project-selector'),
  channelSelector('channel-selector'),
  userSelector('user-selector'),
  folderSelector('folder-selector'),
  knowledgeBaseSelector('knowledge-base-selector'),
  knowledgeTagFilters('knowledge-tag-filters'),
  documentSelector('document-selector'),
  documentTagEntry('document-tag-entry'),
  mcpServerSelector('mcp-server-selector'),
  mcpToolSelector('mcp-tool-selector'),
  mcpDynamicArgs('mcp-dynamic-args'),
  inputFormat('input-format'),
  responseFormat('response-format'),
  filterBuilder('filter-builder'),
  sortBuilder('sort-builder'),
  fileUpload('file-upload'),
  inputMapping('input-mapping'),
  variablesInput('variables-input'),
  messagesInput('messages-input'),
  workflowSelector('workflow-selector'),
  workflowOutputSelector('workflow-output-selector'),
  workflowInputMapper('workflow-input-mapper'),
  text('text'),
  routerInput('router-input'),
  tableSelector('table-selector'),
  modelFallbackList('model-fallback-list'),
  columnSelector('column-selector'),
  modal('modal')
  ;

  const SubBlockType(this.id);

  /// The upstream string id.
  final String id;

  static final Map<String, SubBlockType> _byId = {
    for (final type in values) type.id: type,
  };

  /// The type for an upstream id, or null when the id is not one of the 48.
  static SubBlockType? fromId(String? id) => id == null ? null : _byId[id];
}

/// Port of `PrimitiveValueType` from `packages/workflow-types/src/blocks.ts`.
enum PrimitiveValueType {
  string('string'),
  number('number'),
  boolean('boolean'),
  json('json'),
  array('array'),
  file('file'),
  fileList('file[]'),
  any('any')
  ;

  const PrimitiveValueType(this.id);

  final String id;

  static final Map<String, PrimitiveValueType> _byId = {
    for (final type in values) type.id: type,
  };

  static PrimitiveValueType? fromId(String? id) =>
      id == null ? null : _byId[id];
}
