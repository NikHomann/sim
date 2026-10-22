// Parity table for the tool-title port (tool_display.dart) against the React
// sources it mirrors: apps/sim/lib/mothership/tools/display.ts,
// home/hooks/stream/stream-helpers.ts and agent-group/tool-call-title.ts.
// React ships no display.test.ts, so each expectation below is the string
// the TypeScript implementation produces for the same input.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/integration/tool_display.dart';
import 'package:sim_app/features/chat/integration/tool_icons.dart';
import 'package:sim_design/sim_design.dart';

void main() {
  group('getToolStatusDisplayTitle', () {
    final cases =
        <
          ({
            String title,
            String status,
            String? tool,
            String? description,
            String expected,
          })
        >[
          // success: known verb → past tense; unknown → unchanged.
          (
            title: 'Querying logs for X',
            status: 'success',
            tool: null,
            description: null,
            expected: 'Queried logs for X',
          ),
          (
            title: 'Running Lead Router',
            status: 'success',
            tool: null,
            description: null,
            expected: 'Ran Lead Router',
          ),
          (
            title: 'Workflow Agent',
            status: 'success',
            tool: null,
            description: null,
            expected: 'Workflow Agent',
          ),
          (
            title: 'constructor of things',
            status: 'success',
            tool: null,
            description: null,
            expected: 'constructor of things',
          ),
          (
            title: 'Waiting for you: log in',
            status: 'success',
            tool: 'browser_request_takeover',
            description: null,
            expected: 'Resumed browser control',
          ),
          // A model description replaces the title before the tense applies.
          (
            title: 'Reading file',
            status: 'success',
            tool: null,
            description: '  Checking   the   config ',
            expected: 'Checked the config',
          ),
          // error / rejected: neutral action, outcome prefixes stripped.
          (
            title: 'Reading file',
            status: 'error',
            tool: null,
            description: null,
            expected: 'Reading file',
          ),
          (
            title: 'Failed: reading file',
            status: 'error',
            tool: null,
            description: null,
            expected: 'Reading file',
          ),
          (
            title: 'Stopped searching docs',
            status: 'rejected',
            tool: null,
            description: null,
            expected: 'Searching docs',
          ),
          (
            title: 'Completed',
            status: 'error',
            tool: null,
            description: null,
            expected: 'Tool activity',
          ),
          // cancelled / aborted / interrupted: "Stopped …".
          (
            title: 'Reading file',
            status: 'cancelled',
            tool: null,
            description: null,
            expected: 'Stopped reading file',
          ),
          (
            title: 'Workflow Agent',
            status: 'interrupted',
            tool: null,
            description: null,
            expected: 'Stopped: Workflow Agent',
          ),
          (
            title: 'Stopped by user',
            status: 'cancelled',
            tool: null,
            description: null,
            expected: 'Stopped by user',
          ),
          (
            title: 'Skipped reading file',
            status: 'aborted',
            tool: null,
            description: null,
            expected: 'Skipped reading file',
          ),
          (
            title: 'Reading file',
            status: 'cancelled',
            tool: null,
            description: 'Skipped the read',
            expected: 'Stopped the read',
          ),
          // skipped.
          (
            title: 'Deploying as API',
            status: 'skipped',
            tool: null,
            description: null,
            expected: 'Skipped deploying as API',
          ),
          (
            title: 'Gateway',
            status: 'skipped',
            tool: null,
            description: null,
            expected: 'Skipped: Gateway',
          ),
          // awaiting_approval prefix, applied once.
          (
            title: 'Deleting table',
            status: 'awaiting_approval',
            tool: null,
            description: null,
            expected: 'Waiting for approval: Deleting table',
          ),
          (
            title: 'Waiting for approval: Deleting table',
            status: 'awaiting_approval',
            tool: null,
            description: null,
            expected: 'Waiting for approval: Deleting table',
          ),
          // executing: unchanged.
          (
            title: 'Reading file',
            status: 'executing',
            tool: null,
            description: null,
            expected: 'Reading file',
          ),
        ];
    for (final c in cases) {
      test('${c.status}: "${c.title}"', () {
        expect(
          getToolStatusDisplayTitle(
            c.title,
            c.status,
            toolName: c.tool,
            activityDescription: c.description,
          ),
          c.expected,
        );
      });
    }
  });

  group('getToolInProgressTitle', () {
    final cases = <(String, String, String)>[
      ('Searched files', 'success', 'Searching files'),
      ('Searching files', 'success', 'Searching files'),
      ('Reading file', 'executing', 'Reading file'),
      ('Reading file', 'cancelled', 'Stopped reading file'),
      (
        'Deleting table',
        'awaiting_approval',
        'Waiting for approval: Deleting table',
      ),
    ];
    for (final (title, status, expected) in cases) {
      test('$status: "$title"', () {
        expect(getToolInProgressTitle(title, status), expected);
      });
    }
  });

  group('getToolCompletedTitle', () {
    test('rewrites the leading gerund only', () {
      expect(
        getToolCompletedTitle('Searching online for x'),
        'Searched online for x',
      );
      expect(getToolCompletedTitle('Run Agent'), isNull);
    });
  });

  group('getToolDisplayTitle', () {
    final cases = <(String, Map<String, Object?>?, String)>[
      ('run_workflow', {'workflowName': 'Lead Router'}, 'Running Lead Router'),
      ('run_workflow', null, 'Running workflow'),
      (
        'run_workflow',
        {'name': '5bae7849-ffa5-4f57-984f-feab73e513df'},
        'Running workflow',
      ),
      ('deploy_as_api', {'workflowName': 'Bot'}, 'Deploying Bot as API'),
      ('deploy_as_chat', {'action': 'undeploy'}, 'Undeploying as chat'),
      (
        'query_logs',
        {'view': 'stats', 'workflowName': 'Bot'},
        'Analyzing run stats for Bot',
      ),
      ('query_logs', {'executionId': 'e1'}, 'Reading execution trace'),
      (
        'table_rows',
        {'operation': 'batch_insert_rows', 'tableName': 'Leads'},
        'Adding rows to Leads',
      ),
      (
        'table_columns',
        {
          'operation': 'add_column',
          'columnName': 'Email',
          'tableName': 'Leads',
        },
        'Adding column Email in Leads',
      ),
      (
        'user_table',
        {
          'operation': 'delete',
          'args': {
            'tableIds': ['a', 'b'],
          },
        },
        'Deleting 2 tables',
      ),
      (
        'user_table',
        {
          'operation': 'delete_column',
          'args': {
            'columnNames': ['a', 'b', 'c'],
          },
        },
        'Deleting a, b, and 1 more',
      ),
      (
        'manage_knowledge_base',
        {
          'operation': 'query',
          'args': {'query': 'refunds'},
        },
        'Searching knowledge base for refunds',
      ),
      (
        'web_search',
        {'query': 'the quick brown fox jumps over the lazy dog'},
        'Searching online for "the quick brown fox jumps over t..."',
      ),
      ('task', {'title': 'Research'}, 'Delegating: Research'),
      (
        'mv',
        {
          'sources': ['files/a.md'],
          'destination': 'files/b.md',
        },
        'Renaming a.md to b.md',
      ),
      (
        'mv',
        {
          'sources': ['files/apple.md'],
          'destination': 'fruits/',
        },
        'Moving apple.md to fruits',
      ),
      ('rm', {'paths': <String>[]}, 'Deleting resource'),
      (
        'read',
        {'path': 'workflows/Bot/lint.json'},
        'Validating workflow state',
      ),
      (
        'read',
        {'path': 'components/blocks/google_sheets_v2.json'},
        'Loading Google Sheets',
      ),
      ('read', {'path': 'workflows/Bot/meta.json'}, 'Reading Bot meta'),
      ('read', {'path': 'files/My%20Doc.md'}, 'Reading My Doc.md'),
      ('read', null, 'Reading file'),
      (
        'browser_navigate',
        {'url': 'https://example.com/a/b?q=1'},
        'Opening example.com/a/b',
      ),
      (
        'browser_navigate',
        {'url': 'https://example.com/'},
        'Opening example.com',
      ),
      ('browser_set_checked', {'checked': false}, 'Unchecking control'),
      ('browser_type', {'text': 'hello'}, 'Typing "hello"'),
      (
        'browser_request_takeover',
        {'reason': 'log in'},
        'Waiting for you: log in',
      ),
      (
        'terminal',
        {
          'operation': 'run',
          'args': {'command': 'npm   test'},
        },
        'Running npm test',
      ),
      ('terminal', {'operation': 'panes'}, 'Listing tmux panes'),
      ('terminal', null, 'Using terminal'),
      (
        'wait',
        {'seconds': 30, 'reason': 'the build'},
        'Waiting 30s for the build',
      ),
      ('wait', null, 'Waiting'),
      (
        'wait_agents',
        {
          'agent_ids': ['digest-workflow-build-4', 'x-2'],
          'mode': 'any',
        },
        'Waiting for the first of Digest Workflow Build + 1',
      ),
      ('tail_agent', {'agent_id': 'scout-3'}, 'Checking on Scout'),
      ('load_deployment', {'version': 3}, 'Loading deployment version 3'),
      ('load_deployment', {'version': 'live'}, 'Loading live deployment'),
      (
        'set_global_workflow_variables',
        {
          'operations': [
            {'operation': 'add', 'name': 'x'},
          ],
        },
        'Adding workflow variable x',
      ),
      (
        'manage_custom_tool',
        {'operation': 'list'},
        'Viewing custom tools',
      ),
      (
        'manage_credential',
        {
          'operation': 'rename',
          'previousDisplayName': 'Old',
          'displayName': 'New',
        },
        'Renaming Old to New',
      ),
      (
        'prepare_file_edit',
        {'operation': 'patch', 'title': 'intro'},
        'Editing intro',
      ),
      ('prepare_file_edit', null, 'Editing file'),
      (
        'create_empty_file',
        {
          'outputs': {
            'files': [
              {'path': 'docs/report.md', 'mode': 'overwrite'},
            ],
          },
        },
        'Overwriting report.md',
      ),
      ('context_compaction', null, 'Summarizing context'),
      ('respond', null, 'Gathering thoughts'),
      ('mcp-server1-list_open_issues', null, 'List Open Issues'),
      ('manage_folder', null, 'Manage Folder'),
      ('oauth_api_thing_v2', null, 'OAuth API Thing'),
      ('cli_workflows_list', null, 'Listing workflows'),
      (
        'cli_blocks_get',
        {
          'args': [
            'blocks',
            'get',
            'slack',
            '--operation',
            'slack_send_message',
          ],
        },
        'Reading Slack Send Message configuration',
      ),
      (
        'cli_workflows_operations_apply',
        {
          'args': ['workflows', 'operations', 'apply', '--dry-run'],
        },
        'Validating workflow changes',
      ),
      (
        'cli_settings_workspace_get',
        {
          'args': ['settings', 'workspace', 'get', 'api-keys'],
        },
        'Reading workspace settings: API keys',
      ),
      (
        'cli_files_read',
        {
          'args': ['files', 'read', 'docs/My%20Plan.md'],
        },
        'Reading My Plan.md',
      ),
    ];
    for (final (name, args, expected) in cases) {
      test('$name $args', () {
        expect(getToolDisplayTitle(name, args), expected);
      });
    }
  });

  group('helpers', () {
    test('humanizeDisplayIdentifier sentence casing', () {
      expect(
        humanizeDisplayIdentifier(
          'api-keys_list',
          casing: IdentifierCasing.sentence,
        ),
        'API keys list',
      );
    });

    test('blockDisplayName prefers the registry name', () {
      expect(blockDisplayName('google_sheets_v2'), 'Google Sheets');
      expect(
        blockDisplayName('gmail_v2', lookup: (_) => 'Gmail'),
        'Gmail',
      );
    });

    test('mvDisplayVerb', () {
      expect(mvDisplayVerb('a/b.md', 'a/c.md'), 'Renaming');
      expect(mvDisplayVerb('a/b.md', 'c/b.md'), 'Moving');
      expect(mvDisplayVerb('a/b.md', 'a/'), 'Moving');
      expect(mvDisplayVerb('a/My%20b.md', 'a/My b.md'), 'Moving');
    });

    test('cliFirstPositional skips global flags', () {
      expect(
        cliFirstPositional('cli_workflows_get', {
          'args': ['-w', 'ws1', 'workflows', 'get', 'wf-1'],
        }),
        'wf-1',
      );
      expect(
        cliFlagValues({
          'args': ['logs', 'list', '--workflow', 'a', 'b', '--limit=5'],
        }, '--workflow'),
        ['a', 'b'],
      );
    });

    test('refineStreamingCliToolName', () {
      expect(
        refineStreamingCliToolName('{"args": ["workflows", "list", "--li'),
        'cli_workflows_list',
      );
      expect(
        refineStreamingCliToolName('{"args": ["workflows", "--help"'),
        'cli_help',
      );
      expect(
        refineStreamingCliToolName('{"args": ["settings", "workspace", "get"'),
        'cli_settings_workspace_get',
      );
      expect(refineStreamingCliToolName('{"args": ["nope"'), isNull);
      expect(refineStreamingCliToolName('{"args": ["workf'), isNull);
    });
  });

  group('getWaitCountdownTitle', () {
    final args = <String, Object?>{'seconds': 10, 'reason': 'the deploy'};
    final cases = <(int, String)>[
      (0, 'Waiting 10s for the deploy'),
      (999, 'Waiting 10s for the deploy'),
      (1000, 'Waiting 9s for the deploy'),
      (9500, 'Waiting 1s for the deploy'),
      (10000, 'Waiting for the deploy'),
      (60000, 'Waiting for the deploy'),
      (-5000, 'Waiting 10s for the deploy'),
    ];
    for (final (elapsed, expected) in cases) {
      test('$elapsed ms', () {
        expect(getWaitCountdownTitle(args, elapsed), expected);
      });
    }
    test('without seconds or reason', () {
      expect(getWaitCountdownTitle(null, 3000), 'Waiting');
    });
  });

  group('toolCallTitle', () {
    test('a running wait counts down and ignores the description', () {
      final title = toolCallTitle(
        toolName: 'wait',
        status: 'executing',
        displayTitle: 'Waiting 30s',
        activityDescription: 'Pausing for the build',
        params: {'seconds': 30},
        elapsedMs: 12000,
      );
      expect(title.label, 'Waiting 18s');
      expect(title.activeLabel, 'Waiting 18s');
    });

    test('a settled wait keeps its title', () {
      final title = toolCallTitle(
        toolName: 'wait',
        status: 'success',
        displayTitle: 'Waiting 30s',
        params: {'seconds': 30},
        elapsedMs: 31000,
      );
      expect(title.label, 'Waited 30s');
      expect(title.activeLabel, 'Waiting 30s');
    });

    test('a streaming file edit names its file from the live args', () {
      final title = toolCallTitle(
        toolName: 'prepare_file_edit',
        status: 'executing',
        displayTitle: 'Editing file',
        streamingArgs: r'{"operation": "append", "title": "Q3 \"notes\"", "con',
      );
      expect(title.label, 'Adding Q3 "notes"');
    });

    test('the live file edit flips to past tense on success', () {
      final title = toolCallTitle(
        toolName: 'prepare_file_edit',
        status: 'success',
        streamingArgs: '{"operation": "rename", "title": "plan.md"}',
      );
      expect(title.label, 'Renamed plan.md');
      expect(title.activeLabel, 'Renaming plan.md');
    });

    test('an unknown operation writes; a partial title waits', () {
      expect(
        toolCallTitle(
          toolName: 'prepare_file_edit',
          status: 'executing',
          streamingArgs: '{"operation": "zap", "title": "a"}',
        ).label,
        'Writing a',
      );
      expect(
        toolCallTitle(
          toolName: 'prepare_file_edit',
          status: 'executing',
          displayTitle: 'Editing file',
          streamingArgs: '{"title": "unfinish',
        ).label,
        'Editing file',
      );
    });

    test('the activity description wins over the display title', () {
      final title = toolCallTitle(
        toolName: 'read',
        status: 'error',
        displayTitle: 'Reading file',
        activityDescription: 'Looking up the pricing page',
      );
      expect(title.label, 'Looking up the pricing page');
    });

    test('without a display title the fallback resolves one', () {
      final title = toolCallTitle(
        toolName: 'run_workflow',
        status: 'success',
        params: {'workflowId': 'wf-1'},
        context: ToolTitleContext(workflowName: (id) => 'Lead Router'),
      );
      expect(title.label, 'Ran Lead Router');
    });
  });

  group('fallbackToolTitle', () {
    final context = ToolTitleContext(
      workflowName: (id) => id == 'wf-1' ? 'Lead Router' : null,
      blockName: (id) => id == 'b-1' ? 'Agent 1' : null,
      resourceName: (type, id) => switch ((type, id)) {
        ('table', 't-1') => 'Leads',
        ('workflow', 'wf-2') => 'Digest',
        ('workspace', 'ws-2') => 'Ops',
        _ => null,
      },
      blockTypeName: (type) => type == 'slack_v2' ? 'Slack (Bot)' : null,
      currentWorkflowId: 'wf-1',
      workspaceId: 'ws-1',
    );

    final cases = <(String, Map<String, Object?>?, String?, String)>[
      (
        'call_integration_tool',
        {'description': 'Send the weekly digest'},
        null,
        'Send the weekly digest',
      ),
      (
        'call_integration_tool',
        null,
        '{"toolId": "gmail_send", "description": "Email Bob", "par',
        'Email Bob',
      ),
      ('call_integration_tool', null, null, 'Calling integration'),
      (
        'run_from_block',
        {'workflowId': 'wf-1', 'startBlockId': 'b-1'},
        null,
        'Running Lead Router from Agent 1',
      ),
      ('edit_workflow', <String, Object?>{}, null, 'Editing Lead Router'),
      (
        'get_deployment_status',
        <String, Object?>{},
        null,
        'Checking Lead Router deployment status',
      ),
      (
        'run_block',
        {'blockId': 'b-1'},
        null,
        'Running Agent 1 in Lead Router',
      ),
      (
        'table_rows',
        {
          'operation': 'update_rows',
          'args': {'tableId': 't-1'},
        },
        null,
        'Updating rows in Leads',
      ),
      (
        'cli_workflows_get',
        {
          'args': ['workflows', 'get', 'wf-2'],
        },
        null,
        'Reading Digest',
      ),
      (
        'cli_workflows_get',
        {
          'args': ['-w', 'ws-2', 'workflows', 'get', 'wf-2'],
        },
        null,
        'Reading Digest in Ops',
      ),
      (
        'cli_blocks_get',
        {
          'args': ['blocks', 'get', 'slack_v2'],
        },
        null,
        'Reading Slack (Bot) configuration',
      ),
      (
        'create_workflow',
        null,
        '{"name": "Onboarding", "desc',
        'Creating Onboarding',
      ),
      (
        'mv',
        null,
        '{"sources": ["files/a.md"], "destination": "files/b.md", "toolTitle": "a.md"}',
        'Renaming a.md to b.md',
      ),
      ('unknown_tool_name', null, null, 'Unknown Tool Name'),
    ];
    for (final (name, params, streaming, expected) in cases) {
      test('$name $params $streaming', () {
        expect(
          fallbackToolTitle(
            name,
            params,
            context: context,
            streamingArgs: streaming,
          ),
          expected,
        );
      });
    }

    test('without context nothing is enriched', () {
      expect(
        fallbackToolTitle('run_workflow', {'workflowId': 'wf-1'}),
        'Running workflow',
      );
      expect(
        resolveToolDisplayTitle('edit_workflow', {'workflowId': 'wf-1'}),
        'Editing workflow',
      );
    });
  });

  group('resolveStreamingToolDisplayTitle', () {
    final cases = <(String, String, String?)>[
      ('run_function', '{"code": "x', 'Running code'),
      ('task', '{"title": "Research pricing"', 'Delegating: Research pricing'),
      (
        'prepare_file_edit',
        '{"operation": "patch", "fileName": "a.md"',
        'Editing a.md',
      ),
      ('web_scrape', '{"url": "https://x.dev"', 'Scraping https://x.dev'),
      (
        'manage_skill',
        '{"operation": "add", "name": "Triage"',
        'Creating Triage',
      ),
      ('manage_skill', '{"name": "Triage"', null),
      ('grep', r'{"toolTitle": "TODO\u0020items"', 'Searching for TODO items'),
    ];
    for (final (name, args, expected) in cases) {
      test('$name $args', () {
        expect(resolveStreamingToolDisplayTitle(name, args), expected);
      });
    }
  });

  group('tool icons', () {
    test('known tools and agents map to emcn icons', () {
      expect(toolIconFor('run_workflow'), SimEmcnIcons.playOutline);
      expect(toolIconFor('query_user_table'), SimEmcnIcons.table);
      expect(toolIconFor('wait'), SimEmcnIcons.clock);
      expect(agentIconFor('mothership'), SimEmcnIcons.blimp);
      expect(agentIconFor('workflow'), SimEmcnIcons.hammer);
    });

    test('unknown names fall through to the renderer default', () {
      expect(toolIconFor('not_a_tool'), isNull);
      expect(agentIconFor('constructor'), isNull);
    });
  });
}
