import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sim_seed/src/better_auth.dart';
import 'package:sim_seed/src/encryption.dart';
import 'package:sim_seed/src/ids.dart';
import 'package:sim_seed/src/sql.dart';
import 'package:sim_seed/src/workflows.dart';

/// The fixture inventory: every row the seed inserts, with fixed ids.
///
/// Mirrors `apps/sim/scripts/test-mobile-e2e.ts:208-262` (user, user_stats,
/// project, workspace, permissions, session, folder, workflow, table + rows,
/// execution snapshot + log, copilot chat + messages), `test-scim-e2e.ts:153-190`
/// (session row shape) and `test-cli-run-latency-e2e.ts:181-200` (api_key,
/// workflow_blocks/edges), extended with the credential `account` row, a second
/// folder, three workflows, a knowledge base with two documents, 50 table rows,
/// three executions and personal + workspace environment variables.
class SeedFixture {
  SeedFixture({
    required this.authSecret,
    this.encryptionKey,
    this.email = 'flutter-e2e@example.com',
    this.password = 'Flutter-e2e-Passw0rd!',
    this.userName = 'Flutter E2E',
  });

  final String authSecret;
  final List<int>? encryptionKey;
  final String email;
  final String password;
  final String userName;

  // Identity and tenancy.
  final String userId = fixedId('user');
  final String accountId = fixedId('account');
  final String userStatsId = fixedId('user_stats');
  final String workspaceId = fixedId('workspace');
  String get projectId => workspaceId;
  final String permissionId = fixedId('permission:workspace-admin');
  final String sessionId = fixedId('session');

  /// Better Auth tokens are opaque strings; this one is fixed so the cookie is too.
  final String sessionToken =
      'flutter-e2e-${fixedId('session:token').replaceAll('-', '')}';

  // Folders and workflows.
  final String folderRootId = fixedId('folder:root');
  final String folderNestedId = fixedId('folder:nested');
  final String workflowEmptyId = fixedId('workflow:empty');
  final String workflowMixedId = fixedId('workflow:mixed');
  final String workflowBenchmarkId = fixedId('workflow:benchmark');
  late final SeedWorkflowGraph mixedGraph = mixedWorkflow('workflow:mixed');
  late final SeedWorkflowGraph benchmarkGraph = benchmarkWorkflow(
    'workflow:benchmark',
  );

  // Knowledge base, table, executions, chat, keys, environment.
  final String knowledgeBaseId = fixedId('knowledge_base');
  final List<String> documentIds = [
    fixedId('document:1'),
    fixedId('document:2'),
  ];
  final String tableId = fixedId('table');
  static const tableRowCount = 50;
  late final List<String> tableRowIds = [
    for (var i = 1; i <= tableRowCount; i++) fixedId('table:row:$i'),
  ];
  final List<String> executionKeys = const [
    'completed-manual',
    'failed-api',
    'completed-chat',
  ];
  late final List<String> snapshotIds = [
    for (final k in executionKeys) fixedId('snapshot:$k'),
  ];
  late final List<String> logIds = [
    for (final k in executionKeys) fixedId('log:$k'),
  ];
  late final List<String> executionIds = [
    for (final k in executionKeys) fixedId('execution:$k'),
  ];
  final String chatId = fixedId('copilot_chat');
  final List<String> chatMessageIds = [
    fixedId('copilot_message:1'),
    fixedId('copilot_message:2'),
  ];
  final String apiKeyId = fixedId('api_key');
  final String apiKey =
      'sim_flutter_e2e_${fixedId('api_key:value').replaceAll('-', '')}';
  final String workspaceEnvironmentId = fixedId('workspace_environment');

  static const personalVariables = {
    'E2E_API_TOKEN': 'e2e-personal-token-value',
    'E2E_REGION': 'eu-west-1',
  };
  static const workspaceVariables = {'E2E_WORKSPACE_VAR': 'shared-value'};

  bool get seedsEnvironment => encryptionKey != null;

  String get cookieValue => sessionCookieValue(sessionToken, authSecret);
  String get cookieHeader => '$sessionCookieName=$cookieValue';

  String _encrypt(String name, String value) => encryptAesGcm(
    key: encryptionKey!,
    iv: fixedBytes('iv:$name', 12),
    plaintext: value,
  );

  /// Deletes exactly the seeded rows (by fixed id), in FK order:
  /// logs → snapshots (`workflow_id` only nulls on workflow delete) → chat →
  /// workflows (cascade blocks/edges/subflows) → folders → KB (cascade
  /// documents) → table rows (count trigger) → table → keys/env → session →
  /// permissions → workspace (`billed_account_user_id` is NO ACTION) →
  /// project (`owner_id` is RESTRICT) → account/stats → user.
  List<String> resetStatements() => [
    'delete from workflow_execution_logs where workspace_id = ${lit(workspaceId)} or id in (${idList(logIds)});',
    'delete from workflow_execution_snapshots where id in (${idList(snapshotIds)}) or workflow_id in (${idList(_workflowIds)});',
    'delete from copilot_chats where id = ${lit(chatId)}::uuid or workspace_id = ${lit(workspaceId)};',
    'delete from workflow where id in (${idList(_workflowIds)}) or workspace_id = ${lit(workspaceId)};',
    'delete from folder where id in (${lit(folderNestedId)}, ${lit(folderRootId)}) or workspace_id = ${lit(workspaceId)};',
    'delete from knowledge_base where id = ${lit(knowledgeBaseId)} or workspace_id = ${lit(workspaceId)};',
    'delete from user_table_rows where table_id = ${lit(tableId)} or workspace_id = ${lit(workspaceId)};',
    'delete from user_table_definitions where id = ${lit(tableId)} or workspace_id = ${lit(workspaceId)};',
    'delete from api_key where id = ${lit(apiKeyId)} or user_id = ${lit(userId)};',
    'delete from workspace_environment where workspace_id = ${lit(workspaceId)};',
    'delete from environment where user_id = ${lit(userId)};',
    'delete from session where user_id = ${lit(userId)};',
    'delete from permissions where user_id = ${lit(userId)};',
    'delete from workspace where id = ${lit(workspaceId)} or owner_id = ${lit(userId)};',
    'delete from project where id = ${lit(projectId)} or owner_id = ${lit(userId)};',
    'delete from account where user_id = ${lit(userId)};',
    'delete from user_stats where user_id = ${lit(userId)};',
    'delete from "user" where id = ${lit(userId)} or email = ${lit(email)};',
  ];

  List<String> get _workflowIds => [
    workflowEmptyId,
    workflowMixedId,
    workflowBenchmarkId,
  ];

  List<String> insertStatements() => [
    ..._identity(),
    ..._tenancy(),
    ..._folders(),
    ..._workflows(),
    ..._knowledge(),
    ..._table(),
    ..._executions(),
    ..._chat(),
    ..._apiKey(),
    if (seedsEnvironment) ..._environment(),
  ];

  /// Whole seed as one transaction: reset, then insert.
  String seedScript() => _script([...resetStatements(), ...insertStatements()]);

  String resetScript() => _script(resetStatements());

  /// Session-expired e2e (docs/port/04-test-plan.md §2): the cookie stays, the row is dead.
  String expireSessionScript() => _script([
    'update session set expires_at = now(), updated_at = now() where id = ${lit(sessionId)};',
  ]);

  String renewSessionScript() => _script([
    "update session set expires_at = now() + interval '30 days', updated_at = now() where id = ${lit(sessionId)};",
  ]);

  String _script(List<String> statements) =>
      ['begin;', ...statements, 'commit;'].join('\n');

  List<String> _identity() => [
    insert(
      '"user"',
      [
        'id',
        'name',
        'email',
        'normalized_email',
        'email_verified',
        'created_at',
        'updated_at',
        'role',
      ],
      [
        [
          lit(userId),
          lit(userName),
          lit(email),
          lit(email),
          'true',
          'now()',
          'now()',
          lit('user'),
        ],
      ],
    ),
    insert(
      'account',
      [
        'id',
        'account_id',
        'provider_id',
        'user_id',
        'password',
        'created_at',
        'updated_at',
      ],
      [
        [
          lit(accountId),
          lit(userId),
          lit('credential'),
          lit(userId),
          lit(hashPassword(password, salt: fixedBytes('password-salt', 16))),
          'now()',
          'now()',
        ],
      ],
    ),
    insert(
      'user_stats',
      ['id', 'user_id'],
      [
        [lit(userStatsId), lit(userId)],
      ],
    ),
    insert(
      'session',
      [
        'id',
        'token',
        'user_id',
        'expires_at',
        'created_at',
        'updated_at',
        'ip_address',
        'user_agent',
      ],
      [
        [
          lit(sessionId),
          lit(sessionToken),
          lit(userId),
          "now() + interval '30 days'",
          'now()',
          'now()',
          lit('127.0.0.1'),
          lit('sim-seed (Flutter e2e)'),
        ],
      ],
    ),
  ];

  List<String> _tenancy() => [
    insert(
      'project',
      ['id', 'name', 'owner_id'],
      [
        [lit(projectId), lit('Flutter E2E project'), lit(userId)],
      ],
    ),
    insert(
      'workspace',
      ['id', 'project_id', 'name', 'owner_id', 'billed_account_user_id'],
      [
        [
          lit(workspaceId),
          lit(projectId),
          lit('Flutter E2E workspace'),
          lit(userId),
          lit(userId),
        ],
      ],
    ),
    insert(
      'permissions',
      ['id', 'user_id', 'entity_type', 'entity_id', 'permission_type'],
      [
        [
          lit(permissionId),
          lit(userId),
          lit('workspace'),
          lit(workspaceId),
          lit('admin'),
        ],
      ],
    ),
  ];

  List<String> _folders() => [
    insert(
      'folder',
      [
        'id',
        'resource_type',
        'name',
        'user_id',
        'workspace_id',
        'parent_id',
        'sort_order',
      ],
      [
        [
          lit(folderRootId),
          lit('workflow'),
          lit('E2E folder'),
          lit(userId),
          lit(workspaceId),
          'null',
          '0',
        ],
        [
          lit(folderNestedId),
          lit('workflow'),
          lit('Nested folder'),
          lit(userId),
          lit(workspaceId),
          lit(folderRootId),
          '0',
        ],
      ],
    ),
  ];

  List<String> _workflows() {
    final rows = [
      _workflowRow(
        workflowEmptyId,
        'Empty workflow',
        'No blocks: the empty canvas state.',
        folderId: null,
        sortOrder: 0,
      ),
      _workflowRow(
        workflowMixedId,
        'Mixed 20 blocks',
        'Start, functions, agents, APIs, a loop and a parallel.',
        folderId: folderRootId,
        sortOrder: 0,
      ),
      _workflowRow(
        workflowBenchmarkId,
        'Benchmark 200 blocks',
        'Canvas performance fixture.',
        folderId: null,
        sortOrder: 1,
      ),
    ];
    return [
      insert(
        'workflow',
        [
          'id',
          'user_id',
          'workspace_id',
          'folder_id',
          'sort_order',
          'name',
          'description',
          'last_synced',
          'created_at',
          'updated_at',
          'variables',
        ],
        rows,
      ),
      ..._graph(workflowMixedId, mixedGraph),
      ..._graph(workflowBenchmarkId, benchmarkGraph),
    ];
  }

  List<String> _workflowRow(
    String id,
    String name,
    String description, {
    required String? folderId,
    required int sortOrder,
  }) => [
    lit(id),
    lit(userId),
    lit(workspaceId),
    if (folderId == null) 'null' else lit(folderId),
    '$sortOrder',
    lit(name),
    lit(description),
    'now()',
    'now()',
    'now()',
    json(const <String, Object?>{}),
  ];

  List<String> _graph(String workflowId, SeedWorkflowGraph graph) => [
    if (graph.blocks.isNotEmpty)
      insert(
        'workflow_blocks',
        [
          'id',
          'workflow_id',
          'type',
          'name',
          'position_x',
          'position_y',
          'advanced_mode',
          'sub_blocks',
          'outputs',
          'data',
        ],
        [
          for (final b in graph.blocks)
            [
              lit(b.id),
              lit(workflowId),
              lit(b.type),
              lit(b.name),
              '${b.x}',
              '${b.y}',
              boolean(value: b.advancedMode),
              jsonb(b.subBlocks),
              jsonb(b.outputs),
              jsonb(b.data),
            ],
        ],
      ),
    if (graph.edges.isNotEmpty)
      insert(
        'workflow_edges',
        [
          'id',
          'workflow_id',
          'source_block_id',
          'target_block_id',
          'source_handle',
          'target_handle',
        ],
        [
          for (final e in graph.edges)
            [
              lit(e.id),
              lit(workflowId),
              lit(e.source),
              lit(e.target),
              lit(e.sourceHandle),
              lit(e.targetHandle),
            ],
        ],
      ),
    if (graph.subflows.isNotEmpty)
      insert(
        'workflow_subflows',
        ['id', 'workflow_id', 'type', 'config'],
        [
          for (final s in graph.subflows)
            [lit(s.id), lit(workflowId), lit(s.type), jsonb(s.config)],
        ],
      ),
  ];

  static const List<({String filename, String mime, String body})>
  _documents = [
    (
      filename: 'getting-started.txt',
      mime: 'text/plain',
      body:
          'Sim e2e knowledge base.\nThis document explains how the Flutter port is tested against a seeded stack.\n',
    ),
    (
      filename: 'faq.md',
      mime: 'text/markdown',
      body:
          '# FAQ\n\n## Why fixed ids?\n\nSo every suite can deep-link to the same rows.\n',
    ),
  ];

  List<String> _knowledge() => [
    insert(
      'knowledge_base',
      [
        'id',
        'user_id',
        'workspace_id',
        'name',
        'description',
        'token_count',
        'embedding_model',
        'embedding_dimension',
        'chunking_config',
      ],
      [
        [
          lit(knowledgeBaseId),
          lit(userId),
          lit(workspaceId),
          lit('E2E knowledge base'),
          lit('Two small text documents, already processed.'),
          '64',
          lit('text-embedding-3-small'),
          '1536',
          json(const {'maxSize': 1024, 'minSize': 1, 'overlap': 200}),
        ],
      ],
    ),
    insert(
      'document',
      [
        'id',
        'knowledge_base_id',
        'filename',
        'file_url',
        'file_size',
        'mime_type',
        'chunk_count',
        'token_count',
        'character_count',
        'processing_status',
        'processing_started_at',
        'processing_completed_at',
        'enabled',
      ],
      [
        for (var i = 0; i < _documents.length; i++)
          [
            lit(documentIds[i]),
            lit(knowledgeBaseId),
            lit(_documents[i].filename),
            lit(
              'data:${_documents[i].mime};base64,${base64.encode(utf8.encode(_documents[i].body))}',
            ),
            '${utf8.encode(_documents[i].body).length}',
            lit(_documents[i].mime),
            '1',
            '32',
            '${_documents[i].body.length}',
            lit('completed'),
            "now() - interval '2 seconds'",
            "now() - interval '1 second'",
            'true',
          ],
      ],
    ),
  ];

  /// `generateNKeysBetween(null, null, 50)` of the fractional-indexing port:
  /// `a0`…`a9`, `aA`…`aZ`, `aa`… (base-62 digits, bytewise order).
  static List<String> tableOrderKeys(int count) {
    const digits =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    if (count > digits.length) {
      throw ArgumentError('tableOrderKeys supports up to 62 rows');
    }
    return [for (var i = 0; i < count; i++) 'a${digits[i]}'];
  }

  List<String> _table() {
    final keys = tableOrderKeys(tableRowCount);
    return [
      // row_count stays 0 here: the statement trigger on user_table_rows folds the 50 inserts in.
      insert(
        'user_table_definitions',
        ['id', 'workspace_id', 'name', 'description', 'schema', 'created_by'],
        [
          [
            lit(tableId),
            lit(workspaceId),
            lit('E2E table'),
            lit('Fifty rows for paging, sorting and filtering.'),
            jsonb(const {
              'columns': [
                {
                  'id': 'col_name',
                  'name': 'Name',
                  'type': 'string',
                  'required': true,
                },
                {'id': 'col_count', 'name': 'Count', 'type': 'number'},
                {'id': 'col_active', 'name': 'Active', 'type': 'boolean'},
              ],
            }),
            lit(userId),
          ],
        ],
      ),
      insert(
        'user_table_rows',
        [
          'id',
          'table_id',
          'workspace_id',
          'data',
          'position',
          'order_key',
          'created_by',
        ],
        [
          for (var i = 0; i < tableRowCount; i++)
            [
              lit(tableRowIds[i]),
              lit(tableId),
              lit(workspaceId),
              jsonb({
                'col_name': 'Row ${i + 1}',
                'col_count': i + 1,
                'col_active': i.isEven,
              }),
              '$i',
              lit(keys[i]),
              lit(userId),
            ],
        ],
      ),
    ];
  }

  List<String> _executions() {
    const emptyState = {
      'blocks': <String, Object?>{},
      'edges': <Object?>[],
      'loops': <String, Object?>{},
      'parallels': <String, Object?>{},
      'variables': <String, Object?>{},
    };
    final logs = [
      (
        level: 'info',
        status: 'completed',
        trigger: 'manual',
        durationMs: 1200,
        cost: '0.0012',
        models: const ['gpt-4o'],
        output: {'result': 'Mixed workflow complete'},
        error: null,
      ),
      (
        level: 'error',
        status: 'failed',
        trigger: 'api',
        durationMs: 300,
        cost: '0',
        models: const <String>[],
        output: <String, Object?>{},
        error: 'Function block "Merge" threw: TypeError: input is undefined',
      ),
      (
        level: 'info',
        status: 'completed',
        trigger: 'chat',
        durationMs: 2500,
        cost: '0.0031',
        models: const ['gpt-4o'],
        output: {'result': 'Chat run complete'},
        error: null,
      ),
    ];
    return [
      insert(
        'workflow_execution_snapshots',
        ['id', 'workflow_id', 'state_hash', 'state_data'],
        [
          for (final id in snapshotIds)
            [lit(id), lit(workflowMixedId), lit(id), jsonb(emptyState)],
        ],
      ),
      insert(
        'workflow_execution_logs',
        [
          'id',
          'workflow_id',
          'workspace_id',
          'execution_id',
          'state_snapshot_id',
          'level',
          'status',
          'trigger',
          'started_at',
          'ended_at',
          'total_duration_ms',
          'execution_data',
          'cost_total',
          'models_used',
        ],
        [
          for (var i = 0; i < logs.length; i++)
            [
              lit(logIds[i]),
              lit(workflowMixedId),
              lit(workspaceId),
              lit(executionIds[i]),
              lit(snapshotIds[i]),
              lit(logs[i].level),
              lit(logs[i].status),
              lit(logs[i].trigger),
              "now() - interval '${i + 1} hours'",
              "now() - interval '${i + 1} hours' + interval '${logs[i].durationMs} milliseconds'",
              '${logs[i].durationMs}',
              jsonb({
                'finalOutput': logs[i].output,
                'workflowInput': const <String, Object?>{},
                'traceSpans': const <Object?>[],
                if (logs[i].error != null) 'error': logs[i].error,
              }),
              logs[i].cost,
              'array[${logs[i].models.map(lit).join(', ')}]::text[]',
            ],
        ],
      ),
    ];
  }

  List<String> _chat() {
    const messages = [
      (role: 'user', content: 'Summarise the seeded workspace for me.'),
      (
        role: 'assistant',
        content:
            'Flutter E2E workspace\n\n| Resource | Count |\n| --- | --- |\n| Workflows | 3 |\n| Tables | 1 (50 rows) |\n| Knowledge bases | 1 (2 documents) |\n\n```json\n{"workspace":"Flutter E2E workspace","seeded":true}\n```',
      ),
    ];
    return [
      insert(
        'copilot_chats',
        ['id', 'user_id', 'workspace_id', 'type', 'title', 'resources'],
        [
          [
            '${lit(chatId)}::uuid',
            lit(userId),
            lit(workspaceId),
            lit('mothership'),
            lit('E2E conversation'),
            jsonb([
              {
                'type': 'table',
                'id': tableId,
                'title': 'E2E table',
                'workspaceId': workspaceId,
              },
            ]),
          ],
        ],
      ),
      insert(
        'copilot_messages',
        ['id', 'chat_id', 'message_id', 'role', 'content', 'seq'],
        [
          for (var i = 0; i < messages.length; i++)
            [
              '${lit(chatMessageIds[i])}::uuid',
              '${lit(chatId)}::uuid',
              lit('msg-${i + 1}-${chatMessageIds[i]}'),
              lit(messages[i].role),
              jsonb({
                'id': 'msg-${i + 1}-${chatMessageIds[i]}',
                'role': messages[i].role,
                'content': messages[i].content,
                'timestamp': '2026-10-21T00:00:0$i.000Z',
              }),
              '${i + 1}',
            ],
        ],
      ),
    ];
  }

  /// `API_ENCRYPTION_KEY` is empty in the local stack, so the key is stored in
  /// plain text (legacy `sim_` format) with its SHA-256 for the indexed lookup.
  List<String> _apiKey() => [
    insert(
      'api_key',
      ['id', 'user_id', 'created_by', 'name', 'key', 'key_hash', 'type'],
      [
        [
          lit(apiKeyId),
          lit(userId),
          lit(userId),
          lit('E2E personal key'),
          lit(apiKey),
          lit(sha256.convert(utf8.encode(apiKey)).toString()),
          lit('personal'),
        ],
      ],
    ),
  ];

  List<String> _environment() => [
    insert(
      'environment',
      ['id', 'user_id', 'variables'],
      [
        [
          lit(userId),
          lit(userId),
          json({
            for (final e in personalVariables.entries)
              e.key: _encrypt(e.key, e.value),
          }),
        ],
      ],
    ),
    insert(
      'workspace_environment',
      ['id', 'workspace_id', 'variables'],
      [
        [
          lit(workspaceEnvironmentId),
          lit(workspaceId),
          json({
            for (final e in workspaceVariables.entries)
              e.key: _encrypt('workspace:${e.key}', e.value),
          }),
        ],
      ],
    ),
  ];

  /// The `seed.json` contents: ids, cookie and URLs for the suites.
  Map<String, Object?> report({
    required String baseUrl,
    required String appUrl,
    required String socketUrl,
    required String mailpitUrl,
    required String database,
    required String composeProject,
  }) => {
    'schemaVersion': 1,
    'baseUrl': baseUrl,
    'appUrl': appUrl,
    'socketUrl': socketUrl,
    'mailpitUrl': mailpitUrl,
    'database': database,
    'composeProject': composeProject,
    'user': {
      'id': userId,
      'email': email,
      'name': userName,
      'password': password,
    },
    'session': {
      'id': sessionId,
      'token': sessionToken,
      'cookieName': sessionCookieName,
      'cookieValue': cookieValue,
      'cookieHeader': cookieHeader,
    },
    'workspaceId': workspaceId,
    'projectId': projectId,
    'folderIds': {'root': folderRootId, 'nested': folderNestedId},
    'workflowIds': {
      'empty': workflowEmptyId,
      'mixed': workflowMixedId,
      'benchmark': workflowBenchmarkId,
    },
    'workflows': {
      'mixed': {
        'blockCount': mixedGraph.blocks.length,
        'edgeCount': mixedGraph.edges.length,
        'startBlockId': mixedGraph.blocks.first.id,
        'loopId': mixedGraph.subflows.firstWhere((s) => s.type == 'loop').id,
        'parallelId': mixedGraph.subflows
            .firstWhere((s) => s.type == 'parallel')
            .id,
        'blockIds': {for (final b in mixedGraph.blocks) b.name: b.id},
      },
      'benchmark': {
        'blockCount': benchmarkGraph.blocks.length,
        'edgeCount': benchmarkGraph.edges.length,
        'startBlockId': benchmarkGraph.blocks.first.id,
      },
    },
    'knowledgeBaseId': knowledgeBaseId,
    'documentIds': documentIds,
    'tableId': tableId,
    'tableRowCount': tableRowCount,
    'tableRowIds': tableRowIds,
    'executions': [
      for (var i = 0; i < executionKeys.length; i++)
        {
          'key': executionKeys[i],
          'executionId': executionIds[i],
          'logId': logIds[i],
          'snapshotId': snapshotIds[i],
        },
    ],
    'chatId': chatId,
    'chatMessageIds': chatMessageIds,
    'apiKey': {'id': apiKeyId, 'key': apiKey},
    'environment': {
      'seeded': seedsEnvironment,
      'personalVariables': personalVariables.keys.toList(),
      'workspaceVariables': workspaceVariables.keys.toList(),
    },
  };
}
