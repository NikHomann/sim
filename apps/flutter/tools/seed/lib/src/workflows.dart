import 'package:sim_seed/src/ids.dart';

/// One `workflow_blocks` row. Children of a loop/parallel container carry
/// `data.parentId` + `data.extent: 'parent'` and positions relative to the
/// container, as `apps/sim/stores/workflows/utils.ts` writes them.
class SeedBlock {
  const SeedBlock({
    required this.id,
    required this.type,
    required this.name,
    required this.x,
    required this.y,
    this.subBlocks = const {},
    this.outputs = const {},
    this.data = const {},
    this.advancedMode = false,
  });

  final String id;
  final String type;
  final String name;
  final double x;
  final double y;
  final Map<String, Object?> subBlocks;
  final Map<String, Object?> outputs;
  final Map<String, Object?> data;
  final bool advancedMode;

  String? get parentId => data['parentId'] as String?;
}

class SeedEdge {
  const SeedEdge({
    required this.id,
    required this.source,
    required this.target,
    this.sourceHandle = 'source',
    this.targetHandle = 'target',
  });

  final String id;
  final String source;
  final String target;
  final String sourceHandle;
  final String targetHandle;
}

/// One `workflow_subflows` row; `config` mirrors what
/// `packages/workflow-persistence/src/load.ts` reads back into a Loop/Parallel.
class SeedSubflow {
  const SeedSubflow({
    required this.id,
    required this.type,
    required this.config,
  });

  final String id;
  final String type;
  final Map<String, Object?> config;
}

class SeedWorkflowGraph {
  const SeedWorkflowGraph({
    required this.blocks,
    required this.edges,
    required this.subflows,
  });

  final List<SeedBlock> blocks;
  final List<SeedEdge> edges;
  final List<SeedSubflow> subflows;

  static const empty = SeedWorkflowGraph(blocks: [], edges: [], subflows: []);
}

Map<String, Object?> _sub(String id, String type, Object? value) => {
  'id': id,
  'type': type,
  'value': value,
};

Map<String, Object?> _functionSubBlocks(String code) => {
  'language': _sub('language', 'dropdown', 'javascript'),
  'code': _sub('code', 'code', code),
};

Map<String, Object?> _agentSubBlocks(String system, String user) => {
  'systemPrompt': _sub('systemPrompt', 'long-input', system),
  'userPrompt': _sub('userPrompt', 'long-input', user),
  'model': _sub('model', 'combobox', 'gpt-4o'),
};

const _functionOutputs = {'result': 'any', 'stdout': 'string'};
const _agentOutputs = {'content': 'string', 'model': 'string', 'tokens': 'any'};

/// 20 blocks: start, functions, agents, APIs, a response, one `for` loop with
/// three children and one `count` parallel with two children (docs/port/04-test-plan.md §2).
SeedWorkflowGraph mixedWorkflow(String workflowKey) {
  String id(String name) => fixedId('$workflowKey:block:$name');
  String edgeId(String name) => fixedId('$workflowKey:edge:$name');

  final loopId = id('loop');
  final parallelId = id('parallel');

  SeedBlock fn(
    String key,
    String name,
    double x,
    double y, {
    String? parent,
  }) => SeedBlock(
    id: id(key),
    type: 'function',
    name: name,
    x: x,
    y: y,
    subBlocks: _functionSubBlocks('return { step: ${jsString(name)}, input }'),
    outputs: _functionOutputs,
    data: parent == null ? const {} : {'parentId': parent, 'extent': 'parent'},
  );

  SeedBlock agent(
    String key,
    String name,
    double x,
    double y, {
    String? parent,
  }) => SeedBlock(
    id: id(key),
    type: 'agent',
    name: name,
    x: x,
    y: y,
    subBlocks: _agentSubBlocks(
      'You are the $name step of an e2e fixture. Answer in one sentence.',
      'Input: <start.input>',
    ),
    outputs: _agentOutputs,
    data: parent == null ? const {} : {'parentId': parent, 'extent': 'parent'},
  );

  SeedBlock api(String key, String name, double x, double y) => SeedBlock(
    id: id(key),
    type: 'api',
    name: name,
    x: x,
    y: y,
    subBlocks: {
      'url': _sub(
        'url',
        'short-input',
        'https://example.test/${key.toLowerCase()}',
      ),
      'method': _sub('method', 'dropdown', 'GET'),
    },
    outputs: const {'data': 'any', 'status': 'number', 'headers': 'json'},
  );

  final blocks = <SeedBlock>[
    SeedBlock(
      id: id('start'),
      type: 'start_trigger',
      name: 'Start',
      x: 0,
      y: 0,
      subBlocks: {
        'inputFormat': _sub('inputFormat', 'input-format', [
          {'name': 'input', 'type': 'string', 'value': 'hello'},
        ]),
        'runMetadata': _sub('runMetadata', 'switch', false),
      },
      outputs: const {'input': 'string'},
    ),
    fn('prepare', 'Prepare input', 350, 0),
    agent('classify', 'Classify', 700, 0),
    api('fetch-profile', 'Fetch profile', 1050, 0),
    fn('merge', 'Merge', 1400, 0),
    SeedBlock(
      id: loopId,
      type: 'loop',
      name: 'Retry loop',
      x: 1750,
      y: -100,
      data: const {'width': 600, 'height': 360, 'count': 3, 'loopType': 'for'},
    ),
    fn('loop-1', 'Loop step 1', 40, 80, parent: loopId),
    fn('loop-2', 'Loop step 2', 240, 80, parent: loopId),
    fn('loop-3', 'Loop step 3', 440, 80, parent: loopId),
    SeedBlock(
      id: parallelId,
      type: 'parallel',
      name: 'Fan out',
      x: 2450,
      y: -100,
      data: const {
        'width': 600,
        'height': 360,
        'count': 2,
        'parallelType': 'count',
      },
    ),
    agent('branch-a', 'Branch A', 40, 80, parent: parallelId),
    agent('branch-b', 'Branch B', 240, 80, parent: parallelId),
    fn('collect', 'Collect', 3150, 0),
    agent('summarise', 'Summarise', 3500, 0),
    fn('format', 'Format', 3850, 0),
    SeedBlock(
      id: id('respond'),
      type: 'response',
      name: 'Respond',
      x: 4200,
      y: 0,
      subBlocks: {
        'dataMode': _sub('dataMode', 'dropdown', 'json'),
        'data': _sub('data', 'code', '{ "summary": "<format.result>" }'),
        'status': _sub('status', 'short-input', '200'),
      },
      outputs: const {'data': 'json', 'status': 'number', 'headers': 'json'},
    ),
    fn('metrics', 'Metrics', 3150, 300),
    fn('cleanup', 'Cleanup', 3500, 300),
    fn('audit', 'Audit log', 3850, 300),
    api('notify', 'Notify', 4200, 300),
  ];

  SeedEdge chain(String from, String to, {String sourceHandle = 'source'}) =>
      SeedEdge(
        id: edgeId('$from->$to'),
        source: id(from),
        target: id(to),
        sourceHandle: sourceHandle,
      );

  final edges = <SeedEdge>[
    chain('start', 'prepare'),
    chain('prepare', 'classify'),
    chain('classify', 'fetch-profile'),
    chain('fetch-profile', 'merge'),
    chain('merge', 'loop'),
    chain('loop', 'loop-1', sourceHandle: 'loop-start-source'),
    chain('loop-1', 'loop-2'),
    chain('loop-2', 'loop-3'),
    chain('loop', 'parallel', sourceHandle: 'loop-end-source'),
    chain('parallel', 'branch-a', sourceHandle: 'parallel-start-source'),
    chain('parallel', 'branch-b', sourceHandle: 'parallel-start-source'),
    chain('parallel', 'collect', sourceHandle: 'parallel-end-source'),
    chain('collect', 'summarise'),
    chain('summarise', 'format'),
    chain('format', 'respond'),
    chain('collect', 'metrics'),
    chain('metrics', 'cleanup'),
    chain('cleanup', 'audit'),
    chain('audit', 'notify'),
  ];

  final subflows = <SeedSubflow>[
    SeedSubflow(
      id: loopId,
      type: 'loop',
      config: {
        'id': loopId,
        'nodes': [id('loop-1'), id('loop-2'), id('loop-3')],
        'iterations': 3,
        'loopType': 'for',
        'forEachItems': '',
        'whileCondition': '',
        'doWhileCondition': '',
      },
    ),
    SeedSubflow(
      id: parallelId,
      type: 'parallel',
      config: {
        'id': parallelId,
        'nodes': [id('branch-a'), id('branch-b')],
        'count': 2,
        'distribution': '',
        'parallelType': 'count',
        'batchSize': 20,
      },
    ),
  ];

  return SeedWorkflowGraph(blocks: blocks, edges: edges, subflows: subflows);
}

/// Start + 199 function blocks on a 10-column grid, chained linearly: the
/// canvas benchmark fixture (≥55 fps pan, docs/port/04-test-plan.md Phase 2).
SeedWorkflowGraph benchmarkWorkflow(
  String workflowKey, {
  int blockCount = 200,
}) {
  String id(String name) => fixedId('$workflowKey:block:$name');
  const columns = 10;
  const columnWidth = 350.0;
  const rowHeight = 200.0;

  final blocks = <SeedBlock>[
    SeedBlock(
      id: id('start'),
      type: 'start_trigger',
      name: 'Start',
      x: 0,
      y: 0,
      subBlocks: {
        'inputFormat': _sub('inputFormat', 'input-format', <Object?>[]),
        'runMetadata': _sub('runMetadata', 'switch', false),
      },
    ),
    for (var i = 1; i < blockCount; i++)
      SeedBlock(
        id: id('fn-$i'),
        type: 'function',
        name: 'Function $i',
        x: (i % columns) * columnWidth,
        y: (i ~/ columns) * rowHeight,
        subBlocks: _functionSubBlocks('return { n: $i }'),
        outputs: _functionOutputs,
      ),
  ];

  final edges = <SeedEdge>[
    for (var i = 1; i < blocks.length; i++)
      SeedEdge(
        id: fixedId('$workflowKey:edge:$i'),
        source: blocks[i - 1].id,
        target: blocks[i].id,
      ),
  ];

  return SeedWorkflowGraph(blocks: blocks, edges: edges, subflows: const []);
}

/// A JavaScript single-quoted string literal for seeded function code.
String jsString(String value) => "'${value.replaceAll("'", r"\'")}'";
