// Failure modes for the serializer (port of apps/sim/serializer/index.ts):
//  1. An unknown block type throws UnknownBlockTypeError; an unresolvable
//     *custom* block (`custom_block_*`) is dropped together with every edge
//     touching it, in both serialize and deserialize.
//  2. Loop/parallel containers serialize with tool '' and `params = data`;
//     `loops`/`parallels` are regenerated from the blocks and only fall back
//     to the passed maps when there is no container block.
//  3. Params exclude tool-input-only, env-hidden, and trigger-mode sub-blocks
//     in action mode; in trigger mode only trigger fields survive and
//     `triggerMode: true` is added.
//  4. Canonical pairs collapse onto `canonicalParamId`: member ids are
//     removed; the active member wins; legacy `advancedMode` forces the
//     advanced member for pairs only; an explicit override is honoured; a
//     stale dormant value is dropped.
//  5. A value provider fills a null param only for a sub-block that would
//     serialize.
//  6. A checkbox-list expands to its option ids (untouched options omitted,
//     `defaultChecked` sent) and deserialize rebuilds the record.
//  7. Tool selection: decision table on `operation`; a throwing selector
//     falls back to `access[0]`; an agent with only custom tools gets '';
//     a trigger-mode block gets ''.
//  8. validateRequired throws MissingRequiredFieldsError listing titles;
//     collectBlockFieldIssues skips disabled and trigger-mode blocks; a tool
//     `required + user-only` param is reported under the sub-block title;
//     execution mode defers tool-declared params to the tool, lint mode does
//     not.
//  9. inactiveModeValues reports a stranded dormant value with its kind.
// 10. deserialize → serialize round trip keeps params and connections; edge
//     ids come from the injected generator; null handles are omitted.
// 11. Legacy agent systemPrompt/userPrompt migrate to `messages` on
//     deserialize, idempotently, unwrapping `{input}`.
// 12. privateInputIds collects hideFromCopilot ids plus their canonical ids;
//     canonicalModes are copied from block.data.
// 13. An enabled retry is clamped and emitted; a disabled one is omitted.
// 14. Starter `inputFormat` with rows and legacy agent fields are kept even
//     without a matching sub-block config.
// 15. Custom blocks: stored values without config are kept only when the
//     config is schema-agnostic; `workflowId`/`inputMapping` are never
//     carried forward but recomputed by their value providers.
// 16. SerializedWorkflow JSON round trip matches the upstream wire shape.
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

const _deep = DeepCollectionEquality();

final _registry = MapBlockRegistry([
  BlockConfig(
    type: 'starter',
    name: 'Start',
    description: 'Start',
    category: BlockCategory.blocks,
    bgColor: '#111',
    subBlocks: [
      SubBlockConfig(id: 'startWorkflow', type: 'dropdown'),
    ],
    tools: ToolsConfig(access: const ['start']),
  ),
  BlockConfig(
    type: 'agent',
    name: 'Agent',
    description: 'LLM',
    category: BlockCategory.blocks,
    bgColor: '#222',
    subBlocks: [
      SubBlockConfig(id: 'model', type: 'combobox', title: 'Model'),
      SubBlockConfig(id: 'messages', type: 'messages-input'),
      SubBlockConfig(id: 'tools', type: 'tool-input'),
    ],
    tools: ToolsConfig(access: const ['openai_chat', 'anthropic_chat']),
    inputs: {'model': ParamConfig(type: 'string')},
    outputs: const {
      'content': OutputFieldDefinition(type: PrimitiveValueType.string),
    },
  ),
  BlockConfig(
    type: 'table',
    name: 'Table',
    description: 'Tables',
    category: BlockCategory.tools,
    bgColor: '#333',
    subBlocks: [
      SubBlockConfig(
        id: 'operation',
        type: 'dropdown',
        title: 'Operation',
        required: SubBlockRequired.always,
        options: StaticOptions(const [
          SubBlockOption(id: 'query', label: 'Query'),
          SubBlockOption(id: 'insert', label: 'Insert'),
        ]),
      ),
      SubBlockConfig(
        id: 'tableSelector',
        type: 'table-selector',
        title: 'Table',
        canonicalParamId: 'tableId',
        required: SubBlockRequired.always,
      ),
      SubBlockConfig(
        id: 'manualTableId',
        type: 'short-input',
        title: 'Table ID',
        canonicalParamId: 'tableId',
        mode: SubBlockMode.advanced,
        required: SubBlockRequired.always,
      ),
      SubBlockConfig(
        id: 'rows',
        type: 'code',
        title: 'Rows',
        required: SubBlockRequired.when(
          StaticCondition(
            SubBlockCondition(field: 'operation', value: 'insert'),
          ),
        ),
        condition: StaticCondition(
          SubBlockCondition(field: 'operation', value: 'insert'),
        ),
      ),
      SubBlockConfig(
        id: 'secretScope',
        type: 'dropdown',
        context: 'tool-input',
      ),
      SubBlockConfig(id: 'apiKey', type: 'short-input', hideWhenHosted: true),
      SubBlockConfig(
        id: 'limit',
        type: 'short-input',
        valueProvider: (params) => params['operation'] == 'query' ? '50' : '0',
        condition: StaticCondition(
          SubBlockCondition(field: 'operation', value: 'query'),
        ),
      ),
      SubBlockConfig(
        id: 'webhookPath',
        type: 'short-input',
        mode: SubBlockMode.trigger,
      ),
      SubBlockConfig(
        id: 'options',
        type: 'checkbox-list',
        options: StaticOptions(const [
          SubBlockOption(id: 'noCache', label: 'No cache'),
          SubBlockOption(
            id: 'gatherLinks',
            label: 'Links',
            defaultChecked: true,
          ),
        ]),
      ),
      SubBlockConfig(
        id: 'credential',
        type: 'oauth-input',
        title: 'Credential',
        canonicalParamId: 'oauthCredential',
        hideFromCopilot: true,
      ),
      SubBlockConfig(
        id: 'manualCredential',
        type: 'short-input',
        canonicalParamId: 'oauthCredential',
        mode: SubBlockMode.advanced,
      ),
    ],
    tools: ToolsConfig(
      access: const ['table_query', 'table_insert'],
      toolSelector: DecisionTableToolSelector(
        paramKey: 'operation',
        cases: const {'query': 'table_query', 'insert': 'table_insert'},
      ),
    ),
    triggers: TriggersConfig(enabled: true, available: const ['table_row']),
  ),
  BlockConfig(
    type: 'webhook_trigger',
    name: 'Webhook',
    description: 'Trigger',
    category: BlockCategory.triggers,
    bgColor: '#444',
    subBlocks: [
      SubBlockConfig(
        id: 'path',
        type: 'short-input',
        mode: SubBlockMode.trigger,
      ),
      SubBlockConfig(id: 'tc', type: 'trigger-config'),
    ],
    tools: ToolsConfig(access: const []),
  ),
  BlockConfig(
    type: 'custom_block_known',
    name: 'Known custom',
    description: 'custom',
    category: BlockCategory.blocks,
    bgColor: '#555',
    subBlocks: [
      SubBlockConfig(
        id: 'workflowId',
        type: 'short-input',
        valueProvider: (_) => 'wf-child',
      ),
      SubBlockConfig(
        id: 'inputMapping',
        type: 'short-input',
        valueProvider: (params) => jsonEncode({'name': params['name']}),
      ),
      SubBlockConfig(id: 'name', type: 'short-input'),
    ],
    tools: ToolsConfig(access: const ['workflow_executor']),
  ),
  BlockConfig(
    type: 'custom_block_agnostic',
    name: 'Agnostic custom',
    description: 'custom',
    category: BlockCategory.blocks,
    bgColor: '#555',
    subBlocks: [
      SubBlockConfig(id: 'workflowId', type: 'short-input'),
      SubBlockConfig(id: 'inputMapping', type: 'short-input'),
    ],
    tools: ToolsConfig(access: const ['workflow_executor']),
  ),
]);

class _Tools implements ToolMetadataLookup {
  @override
  Map<String, ToolParamConfig>? getToolParams(String toolId) =>
      switch (toolId) {
        'table_query' => const {
          'tableId': ToolParamConfig(
            type: 'string',
            required: true,
            visibility: 'user-only',
          ),
          'operation': ToolParamConfig(type: 'string', required: true),
          'limit': ToolParamConfig(type: 'number'),
        },
        _ => null,
      };
}

var _nextId = 0;

WorkflowSerializer _serializer({SubBlockEnvironment? environment}) {
  _nextId = 0;
  return WorkflowSerializer(
    registry: _registry,
    toolMetadata: _Tools(),
    environment: environment ?? SubBlockEnvironment.selfHosted,
    idGenerator: () => 'edge-${++_nextId}',
  );
}

BlockState _block(
  String id,
  String type,
  Map<String, Object?> values, {
  bool enabled = true,
  bool? advancedMode,
  bool? triggerMode,
  BlockData? data,
  BlockRetryConfig? retry,
}) => BlockState(
  id: id,
  type: type,
  name: id,
  position: const Position(x: 1, y: 2),
  subBlocks: {
    for (final entry in values.entries)
      entry.key: SubBlockState(
        id: entry.key,
        type: 'short-input',
        value: entry.value,
      ),
  },
  outputs: const {},
  enabled: enabled,
  advancedMode: advancedMode,
  triggerMode: triggerMode,
  data: data,
  retry: retry,
);

Edge _edge(String id, String source, String target) =>
    Edge(id: id, source: source, target: target, sourceHandle: 'source');

void main() {
  test('1. unknown type throws; unresolvable custom block is dropped', () {
    final serializer = _serializer();
    expect(
      () => serializer.serializeWorkflow({
        'x': _block('x', 'ghost', const {}),
      }, const []),
      throwsA(isA<UnknownBlockTypeError>()),
    );
    final blocks = {
      's': _block('s', 'starter', const {'startWorkflow': 'manual'}),
      'c': _block('c', 'custom_block_deleted', const {}),
    };
    final edges = [_edge('e1', 's', 'c'), _edge('e2', 'c', 's')];
    final serialized = serializer.serializeWorkflow(blocks, edges);
    expect(serialized.blocks.map((b) => b.id), ['s']);
    expect(serialized.connections, isEmpty);

    final restored = serializer.deserializeWorkflow(
      SerializedWorkflow(
        version: '1.0',
        blocks: [
          ...serialized.blocks,
          SerializedBlock(
            id: 'c',
            position: Position.zero,
            config: const SerializedBlockConfig(tool: '', params: {}),
            inputs: const {},
            outputs: const {},
            metadata: const SerializedBlockMetadata(id: 'custom_block_deleted'),
            enabled: true,
          ),
        ],
        connections: const [
          SerializedConnection(source: 's', target: 'c'),
        ],
        loops: const {},
      ),
    );
    expect(restored.blocks.keys, ['s']);
    expect(restored.edges, isEmpty);
  });

  test('2. containers and regenerated loops', () {
    final serializer = _serializer();
    final loopData = BlockData(loopType: LoopType.forEach, collection: '<s.x>');
    final blocks = {
      'l': _block('l', 'loop', const {}, data: loopData),
      'p': _block('p', 'parallel', const {}, data: BlockData(count: 2)),
      'a': _block('a', 'agent', const {}, data: BlockData(parentId: 'l')),
    };
    final stale = {
      'l': Loop(
        id: 'l',
        nodes: const ['stale'],
        iterations: 1,
        loopType: LoopType.forLoop,
        enabled: true,
      ),
    };
    final serialized = serializer.serializeWorkflow(
      blocks,
      const [],
      loops: stale,
    );
    final loop = serialized.blocks.firstWhere((b) => b.id == 'l');
    expect(loop.config.tool, '');
    expect(_deep.equals(loop.config.params, loopData.toJson()), isTrue);
    expect(loop.metadata?.category, 'subflow');
    expect(loop.metadata?.color, '#3b82f6');
    expect(serialized.loops['l']!.nodes, ['a']);
    expect(serialized.parallels?['p']!.count, 2);

    final none = serializer.serializeWorkflow(
      {'a': _block('a', 'agent', const {})},
      const [],
      loops: stale,
    );
    expect(none.loops['l']!.nodes, ['stale']);
  });

  test('3. visibility filters in action and trigger mode', () {
    final values = {
      'operation': 'query',
      'tableSelector': 't1',
      'secretScope': 'x',
      'apiKey': 'k',
      'webhookPath': '/hook',
      'rows': '[]',
    };
    final hosted = _serializer(
      environment: const SubBlockEnvironment(hosted: true),
    );
    final params = hosted.extractBlockParams(_block('t', 'table', values));
    expect(params.containsKey('secretScope'), isFalse);
    expect(params.containsKey('apiKey'), isFalse);
    expect(params.containsKey('webhookPath'), isFalse);
    expect(params.containsKey('rows'), isFalse);
    expect(params['tableId'], 't1');
    expect(params['limit'], '50');

    final selfHosted = _serializer();
    expect(
      selfHosted.extractBlockParams(_block('t', 'table', values))['apiKey'],
      'k',
    );

    final trigger = selfHosted.serializeWorkflow(
      {'t': _block('t', 'table', values, triggerMode: true)},
      const [],
    );
    final triggerParams = trigger.blocks.single.config.params;
    expect(triggerParams['webhookPath'], '/hook');
    expect(triggerParams['triggerMode'], true);
    expect(triggerParams.containsKey('operation'), isFalse);
    expect(trigger.blocks.single.config.tool, '');
  });

  test('4. canonical pair collapse', () {
    final serializer = _serializer();
    Map<String, Object?> params(
      Map<String, Object?> values, {
      bool? advancedMode,
      Map<String, CanonicalMode>? modes,
    }) => serializer.extractBlockParams(
      _block(
        't',
        'table',
        {'operation': 'query', ...values},
        advancedMode: advancedMode,
        data: modes == null ? null : BlockData(canonicalModes: modes),
      ),
    );

    final basic = params(const {
      'tableSelector': 'picked',
      'manualTableId': 'stale',
    });
    expect(basic['tableId'], 'picked');
    expect(basic.containsKey('tableSelector'), isFalse);
    expect(basic.containsKey('manualTableId'), isFalse);

    expect(
      params(const {'manualTableId': 'typed'})['tableId'],
      'typed',
    );
    expect(
      params(
        const {'tableSelector': 'picked', 'manualTableId': 'typed'},
        advancedMode: true,
      )['tableId'],
      'typed',
    );
    expect(
      params(
        const {'tableSelector': 'picked', 'manualTableId': 'typed'},
        modes: {'tableId': CanonicalMode.advanced},
      )['tableId'],
      'typed',
    );
    expect(
      params(
        const {'tableSelector': '', 'manualTableId': 'typed'},
        modes: {'tableId': CanonicalMode.basic},
      ).containsKey('tableId'),
      isTrue,
    );
    expect(
      params(
        const {'tableSelector': '', 'manualTableId': 'typed'},
        modes: {'tableId': CanonicalMode.basic},
      )['tableId'],
      '',
    );
  });

  test('5. value providers fill only serializable null params', () {
    final serializer = _serializer();
    final query = serializer.extractBlockParams(
      _block('t', 'table', const {'operation': 'query', 'limit': null}),
    );
    expect(query['limit'], '50');
    final insert = serializer.extractBlockParams(
      _block('t', 'table', const {'operation': 'insert'}),
    );
    expect(insert.containsKey('limit'), isFalse);
    final explicit = serializer.extractBlockParams(
      _block('t', 'table', const {'operation': 'query', 'limit': '7'}),
    );
    expect(explicit['limit'], '7');
  });

  test('6. checkbox-list expands and collapses', () {
    final serializer = _serializer();
    final params = serializer.extractBlockParams(
      _block('t', 'table', const {
        'operation': 'query',
        'options': {'noCache': true},
      }),
    );
    expect(params['noCache'], true);
    expect(params['gatherLinks'], true);
    expect(params.containsKey('options'), isFalse);

    final untouched = serializer.extractBlockParams(
      _block('t', 'table', const {'operation': 'query', 'options': null}),
    );
    expect(untouched.containsKey('noCache'), isFalse);
    expect(untouched['gatherLinks'], true);

    final restored = serializer.deserializeWorkflow(
      SerializedWorkflow(
        version: '1.0',
        blocks: [
          SerializedBlock(
            id: 't',
            position: Position.zero,
            config: const SerializedBlockConfig(
              tool: 'table_query',
              params: {'operation': 'query', 'noCache': false},
            ),
            inputs: const {},
            outputs: const {},
            metadata: const SerializedBlockMetadata(id: 'table'),
            enabled: true,
          ),
        ],
        connections: const [],
        loops: const {},
      ),
    );
    expect(restored.blocks['t']!.subBlocks['options']!.value, {
      'noCache': false,
    });
    expect(restored.blocks['t']!.subBlocks['options']!.type, 'checkbox-list');
  });

  test('7. tool selection', () {
    final serializer = _serializer();
    SerializedBlock one(BlockState block) =>
        serializer.serializeWorkflow({block.id: block}, const []).blocks.single;

    expect(
      one(
        _block('t', 'table', const {
          'operation': 'insert',
          'rows': '[]',
          'tableSelector': 'x',
        }),
      ).config.tool,
      'table_insert',
    );
    expect(
      one(
        _block('t', 'table', const {
          'operation': 'bogus',
          'tableSelector': 'x',
        }),
      ).config.tool,
      'table_query',
    );
    expect(
      one(
        _block('a', 'agent', const {
          'tools': [
            {'type': 'custom-tool', 'title': 'x'},
          ],
        }),
      ).config.tool,
      '',
    );
    expect(
      one(
        _block('a', 'agent', const {
          'tools': '[{"type":"table"}]',
        }),
      ).config.tool,
      'openai_chat',
    );
    expect(
      one(_block('a', 'agent', const {'tools': 'not json'})).config.tool,
      'openai_chat',
    );
    expect(
      one(
        _block('t', 'table', const {'operation': 'query'}, triggerMode: true),
      ).config.tool,
      '',
    );
  });

  test('8. required-field validation', () {
    final serializer = _serializer();
    expect(
      () => serializer.serializeWorkflow(
        {
          't': _block('t', 'table', const {'operation': 'insert'}),
        },
        const [],
        validateRequired: true,
      ),
      throwsA(
        isA<MissingRequiredFieldsError>()
            .having((e) => e.missingFields, 'fields', ['Table', 'Rows'])
            .having((e) => e.blockName, 'block', 't'),
      ),
    );
    final table = _registry.getBlock('table')!;
    final disabled = _block('t', 'table', const {}, enabled: false);
    expect(
      serializer
          .collectBlockFieldIssues(disabled, table, const {})
          .missingRequiredFields,
      isEmpty,
    );
    expect(
      serializer.collectBlockFieldIssues(
        _block('t', 'table', const {}),
        table,
        const {'triggerMode': true},
      ).missingRequiredFields,
      isEmpty,
    );

    final queryBlock = _block('t', 'table', const {'operation': 'query'});
    final params = serializer.extractBlockParams(queryBlock);
    final execution = serializer.collectBlockFieldIssues(
      queryBlock,
      table,
      params,
    );
    expect(execution.missingRequiredFields, ['Table']);
    final lint = serializer.collectBlockFieldIssues(
      queryBlock,
      table,
      params,
      mode: BlockFieldIssueMode.lint,
    );
    expect(lint.missingRequiredFields, ['Table']);

    final noOperation = _block('t', 'table', const {'tableSelector': 'x'});
    final noOpParams = serializer.extractBlockParams(noOperation);
    expect(noOpParams['tableId'], 'x');
    expect(
      serializer
          .collectBlockFieldIssues(noOperation, table, noOpParams)
          .missingRequiredFields,
      isEmpty,
    );
    expect(
      serializer
          .collectBlockFieldIssues(
            noOperation,
            table,
            noOpParams,
            mode: BlockFieldIssueMode.lint,
          )
          .missingRequiredFields,
      ['Operation'],
    );
  });

  test('9. inactive mode values', () {
    final serializer = _serializer();
    final table = _registry.getBlock('table')!;
    final block = _block(
      't',
      'table',
      const {
        'operation': 'query',
        'manualTableId': 'typed',
        'manualCredential': 'c',
      },
      data: BlockData(
        canonicalModes: const {
          'tableId': CanonicalMode.basic,
          'oauthCredential': CanonicalMode.basic,
        },
      ),
    );
    final issues = serializer.collectBlockFieldIssues(
      block,
      table,
      serializer.extractBlockParams(block),
    );
    expect(issues.inactiveModeValues, hasLength(2));
    final tableIssue = issues.inactiveModeValues.firstWhere(
      (i) => i.canonicalId == 'tableId',
    );
    expect(tableIssue.activeMemberId, 'tableSelector');
    expect(tableIssue.inactiveMemberId, 'manualTableId');
    expect(tableIssue.kind, InactiveModeValueKind.resource);
    final credIssue = issues.inactiveModeValues.firstWhere(
      (i) => i.canonicalId == 'oauthCredential',
    );
    expect(credIssue.kind, InactiveModeValueKind.credential);
  });

  test('10. round trip and generated edge ids', () {
    final serializer = _serializer();
    final blocks = {
      's': _block('s', 'starter', const {'startWorkflow': 'manual'}),
      'a': _block('a', 'agent', const {'model': 'gpt-4o'}),
    };
    final edges = [
      Edge(
        id: 'orig',
        source: 's',
        target: 'a',
        sourceHandle: '',
      ),
    ];
    final serialized = serializer.serializeWorkflow(blocks, edges);
    expect(serialized.connections.single.sourceHandle, isNull);
    expect(serialized.blocks.last.inputs, {'model': 'string'});
    expect(serialized.blocks.last.metadata?.name, 'a');
    expect(serialized.blocks.last.metadata?.color, '#222');

    final restored = serializer.deserializeWorkflow(serialized);
    expect(restored.edges.single.id, 'edge-1');
    expect(restored.blocks['a']!.subBlocks['model']!.value, 'gpt-4o');
    expect(restored.blocks['a']!.subBlocks['tools']!.value, isNull);
    expect(restored.blocks['a']!.enabled, isTrue);
    expect(restored.blocks['a']!.position, const Position(x: 1, y: 2));

    // Deserialization materialises every configured sub-block, so the second
    // pass carries explicit nulls for `messages`/`tools` exactly as upstream
    // does; only the user-set values must survive unchanged.
    final again = serializer.serializeWorkflow(restored.blocks, restored.edges);
    final againParams = again.blocks.last.config.params;
    expect(againParams['model'], 'gpt-4o');
    expect(againParams.containsKey('messages'), isTrue);
    expect(againParams['messages'], isNull);
    expect(again.connections.single.source, 's');
  });

  test('11. legacy agent prompt migration', () {
    final serializer = _serializer();
    SerializedBlock agent(Map<String, Object?> params) => SerializedBlock(
      id: 'a',
      position: Position.zero,
      config: SerializedBlockConfig(tool: 'openai_chat', params: params),
      inputs: const {},
      outputs: const {},
      metadata: const SerializedBlockMetadata(id: 'agent'),
      enabled: true,
    );
    SerializedWorkflow wf(SerializedBlock block) => SerializedWorkflow(
      version: '1.0',
      blocks: [block],
      connections: const [],
      loops: const {},
    );

    final migrated = serializer.deserializeWorkflow(
      wf(
        agent(const {
          'systemPrompt': 'sys',
          'userPrompt': {'input': 'hi'},
        }),
      ),
    );
    expect(migrated.blocks['a']!.subBlocks['messages']!.value, [
      {'role': 'system', 'content': 'sys'},
      {'role': 'user', 'content': 'hi'},
    ]);
    expect(migrated.blocks['a']!.subBlocks['messages']!.type, 'messages-input');

    final kept = serializer.deserializeWorkflow(
      wf(
        agent(const {
          'systemPrompt': 'sys',
          'messages': [
            {'role': 'user', 'content': 'existing'},
          ],
        }),
      ),
    );
    expect(kept.blocks['a']!.subBlocks['messages']!.value, [
      {'role': 'user', 'content': 'existing'},
    ]);

    final objectPrompt = serializer.deserializeWorkflow(
      wf(
        agent(const {
          'userPrompt': {'other': 1},
        }),
      ),
    );
    expect(
      objectPrompt.blocks['a']!.subBlocks['messages']!.value,
      [
        {'role': 'user', 'content': '{"other":1}'},
      ],
    );
  });

  test('12. privateInputIds and canonicalModes', () {
    final serializer = _serializer();
    final block = _block(
      't',
      'table',
      const {'operation': 'query', 'tableSelector': 'x'},
      data: BlockData(
        canonicalModes: const {'tableId': CanonicalMode.advanced},
      ),
    );
    final serialized = serializer
        .serializeWorkflow({'t': block}, const [])
        .blocks
        .single;
    expect(serialized.privateInputIds, ['credential', 'oauthCredential']);
    expect(serialized.canonicalModes, {'tableId': CanonicalMode.advanced});
    final agent = serializer
        .serializeWorkflow({'a': _block('a', 'agent', const {})}, const [])
        .blocks
        .single;
    expect(agent.privateInputIds, isNull);
    expect(agent.canonicalModes, isNull);
  });

  test('13. retry is clamped or omitted', () {
    final serializer = _serializer();
    final enabled = serializer
        .serializeWorkflow(
          {
            'a': _block(
              'a',
              'agent',
              const {},
              retry: const BlockRetryConfig(
                enabled: true,
                maxTries: 50,
                waitBetweenTriesMs: -1,
              ),
            ),
          },
          const [],
        )
        .blocks
        .single;
    expect(
      enabled.retry,
      const BlockRetryConfig(enabled: true, maxTries: 5, waitBetweenTriesMs: 0),
    );
    final disabled = serializer
        .serializeWorkflow(
          {
            'a': _block(
              'a',
              'agent',
              const {},
              retry: const BlockRetryConfig(
                enabled: false,
                maxTries: 3,
                waitBetweenTriesMs: 1,
              ),
            ),
          },
          const [],
        )
        .blocks
        .single;
    expect(disabled.retry, isNull);
    expect(disabled.toJson().containsKey('retry'), isFalse);
  });

  test('14. starter inputFormat and legacy agent fields survive', () {
    final serializer = _serializer();
    final starter = serializer.extractBlockParams(
      _block('s', 'starter', const {
        'inputFormat': [
          {'name': 'q', 'type': 'string'},
        ],
        'stray': 'dropped',
      }),
    );
    expect(starter['inputFormat'], hasLength(1));
    expect(starter.containsKey('stray'), isFalse);
    final emptyFormat = serializer.extractBlockParams(
      _block('s', 'starter', const {'inputFormat': <Object?>[]}),
    );
    expect(emptyFormat.containsKey('inputFormat'), isFalse);

    final agent = serializer.extractBlockParams(
      _block('a', 'agent', const {'systemPrompt': 'legacy', 'memories': 'm'}),
    );
    expect(agent['systemPrompt'], 'legacy');
    expect(agent['memories'], 'm');
  });

  test('15. custom block wiring and schema-agnostic values', () {
    final serializer = _serializer();
    final declared = serializer.extractBlockParams(
      _block('c', 'custom_block_known', const {
        'workflowId': 'stale-wf',
        'inputMapping': '{"stale":1}',
        'name': 'n',
        'deleted': 'gone',
      }),
    );
    expect(declared['workflowId'], 'wf-child');
    expect(declared['inputMapping'], '{"name":"n"}');
    expect(declared.containsKey('deleted'), isFalse);

    final agnostic = serializer.extractBlockParams(
      _block('c', 'custom_block_agnostic', const {
        'workflowId': 'stale-wf',
        'anything': 'kept',
      }),
    );
    expect(agnostic['anything'], 'kept');
    expect(agnostic.containsKey('workflowId'), isFalse);
  });

  test('16. SerializedWorkflow JSON shape', () {
    final serializer = _serializer();
    final serialized = serializer.serializeWorkflow(
      {
        's': _block('s', 'starter', const {'startWorkflow': 'manual'}),
        'l': _block(
          'l',
          'loop',
          const {},
          data: BlockData(loopType: LoopType.forLoop, count: 2),
        ),
      },
      [_edge('e', 's', 'l')],
    );
    final json =
        jsonDecode(jsonEncode(serialized.toJson())) as Map<String, Object?>;
    expect(
      json.keys,
      unorderedEquals([
        'version',
        'blocks',
        'connections',
        'loops',
        'parallels',
      ]),
    );
    expect(json['version'], '1.0');
    final block =
        (json['blocks']! as List<Object?>).first! as Map<String, Object?>;
    expect(
      block.keys,
      unorderedEquals([
        'id',
        'position',
        'config',
        'inputs',
        'outputs',
        'metadata',
        'enabled',
      ]),
    );
    expect(
      (block['config']! as Map<String, Object?>).keys,
      unorderedEquals(['tool', 'params']),
    );
    final connection =
        (json['connections']! as List<Object?>).single! as Map<String, Object?>;
    expect(connection, {
      'source': 's',
      'target': 'l',
      'sourceHandle': 'source',
    });
    final parsed = SerializedWorkflow.fromJson(json);
    expect(_deep.equals(parsed.toJson(), json), isTrue);
  });
}
