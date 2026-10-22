// Failure modes (home-page.md States "Policy ...", "hideCopilot ...";
// permission-access-boundary.tsx:52-127):
// - Home renders (and opens a chat session) while the policy is loading,
//   failed, or hides Copilot with access requests enabled
// - "Try again" does not refetch the failed query
// - hideCopilot with access requests disabled blocks Home (the server is
//   the enforcement point; React renders the children)
// - the allowed / requestable / pending / restricted copies or actions
//   are mixed up

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/home/access/permission_access_boundary.dart';
import 'package:sim_design/sim_design.dart';

import 'support/home_harness.dart';

/// A boundary source the test steers.
class FakeAccessSource implements HomeAccessSource {
  final ValueNotifier<AccessQueryState<Map<String, Object?>>> policyState =
      ValueNotifier<AccessQueryState<Map<String, Object?>>>(
        const AccessQueryState(),
      );
  final ValueNotifier<AccessQueryState<AccessDiscovery>> discoveryState =
      ValueNotifier<AccessQueryState<AccessDiscovery>>(
        const AccessQueryState(),
      );
  int policyRefetches = 0;
  int discoveryRefetches = 0;

  @override
  ValueListenable<AccessQueryState<Map<String, Object?>>> policy(
    String workspaceId,
  ) => policyState;

  @override
  Future<void> refetchPolicy(String workspaceId) async => policyRefetches++;

  @override
  ValueListenable<AccessQueryState<AccessDiscovery>> discovery(
    String workspaceId,
  ) => discoveryState;

  @override
  Future<void> refetchDiscovery(String workspaceId) async =>
      discoveryRefetches++;
}

const AccessQueryState<Map<String, Object?>> _blocked = AccessQueryState(
  data: <String, Object?>{'hideCopilot': true},
  isPending: false,
);

void main() {
  late HomeHarness h;
  late FakeAccessSource access;

  setUp(() async {
    h = HomeHarness();
    await h.setUp();
    access = FakeAccessSource();
    h.accessOverride = access;
  });

  tearDown(() => h.tearDown());

  testWidgets('loading, then failure with a working retry', (tester) async {
    await h.pump(tester, homePath);
    expect(find.text('Checking access'), findsOneWidget);
    expect(find.text('Loading your organization access policy.'), findsOne);
    expect(byParityId('home.access'), findsOneWidget);
    expect(h.sessions, isEmpty);
    access.policyState.value = AccessQueryState(
      error: apiError(500, 'Policy service down'),
      isPending: false,
    );
    await settle(tester);
    expect(find.text('Unable to check access'), findsOneWidget);
    expect(find.text('Policy service down'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(access.policyRefetches, 1);
  });

  testWidgets('not blocked: Home', (tester) async {
    access.policyState.value = const AccessQueryState(
      data: <String, Object?>{},
      isPending: false,
    );
    await h.pump(tester, homePath);
    expect(byParityId('home.empty'), findsOneWidget);
    expect(h.sessions, hasLength(1));
  });

  testWidgets('blocked, access requests disabled: Home anyway', (
    tester,
  ) async {
    access
      ..policyState.value = _blocked
      ..discoveryState.value = const AccessQueryState(
        data: AccessDiscovery(enabled: false),
        isPending: false,
      );
    await h.pump(tester, homePath);
    expect(byParityId('home.empty'), findsOneWidget);
  });

  testWidgets('blocked: discovery loading and failing', (tester) async {
    access.policyState.value = _blocked;
    await h.pump(tester, homePath);
    expect(find.text('Checking access'), findsOneWidget);
    access.discoveryState.value = AccessQueryState(
      error: apiError(503, 'Discovery failed'),
      isPending: false,
    );
    await settle(tester);
    expect(find.text('Discovery failed'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(access.discoveryRefetches, 1);
    expect(access.policyRefetches, 0);
  });

  testWidgets('blocked, allowed since: Access updated with Refresh access', (
    tester,
  ) async {
    access
      ..policyState.value = _blocked
      ..discoveryState.value = const AccessQueryState(
        data: AccessDiscovery(
          enabled: true,
          entries: <AccessEntry>[
            AccessEntry(configKey: 'hideCopilot', state: 'allowed'),
          ],
        ),
        isPending: false,
      );
    await h.pump(tester, homePath);
    expect(find.text('Access updated'), findsOneWidget);
    expect(find.text('Refresh to load your latest permissions.'), findsOne);
    await tester.tap(find.text('Refresh access'));
    expect(access.policyRefetches, 1);
    access.policyState.value = const AccessQueryState(
      data: <String, Object?>{'hideCopilot': true},
      isPending: false,
      isFetching: true,
    );
    await settle(tester);
    expect(find.text('Refreshing your permissions...'), findsOneWidget);
    expect(h.sessions, isEmpty);
  });

  testWidgets('blocked and requestable: ask, then pending', (tester) async {
    access
      ..policyState.value = _blocked
      ..discoveryState.value = const AccessQueryState(
        data: AccessDiscovery(
          enabled: true,
          entries: <AccessEntry>[
            AccessEntry(
              configKey: 'hideCopilot',
              state: 'requestable',
              label: 'Chat',
            ),
          ],
        ),
        isPending: false,
      );
    await h.pump(tester, homePath);
    expect(find.text('Access required'), findsOneWidget);
    expect(find.text('Ask an administrator for access.'), findsOneWidget);
    expect(find.text('Request access'), findsOneWidget);
    access.discoveryState.value = const AccessQueryState(
      data: AccessDiscovery(
        enabled: true,
        entries: <AccessEntry>[
          AccessEntry(
            configKey: 'hideCopilot',
            state: 'requestable',
            label: 'Chat',
            pendingRequestId: 'req-1',
          ),
        ],
      ),
      isPending: false,
    );
    await settle(tester);
    expect(find.text('Your request is pending.'), findsOneWidget);
    await tester.tap(find.text('View request'));
    await settle(tester);
    expect(
      h.location,
      '/workspace/$workspaceId/settings/requests?view=requests&requestId=req-1',
    );
  });

  testWidgets('blocked and not requestable: the reason, no action', (
    tester,
  ) async {
    access
      ..policyState.value = _blocked
      ..discoveryState.value = const AccessQueryState(
        data: AccessDiscovery(
          enabled: true,
          entries: <AccessEntry>[
            AccessEntry(
              configKey: 'hideCopilot',
              state: 'denied',
              reason: 'Chat is disabled by your admin.',
            ),
          ],
        ),
        isPending: false,
      );
    await h.pump(tester, homePath);
    expect(find.text('Chat is disabled by your admin.'), findsOneWidget);
    expect(find.byType(SimChip), findsNothing);
    access.discoveryState.value = const AccessQueryState(
      data: AccessDiscovery(enabled: true),
      isPending: false,
    );
    await settle(tester);
    expect(
      find.text('Your organization restricts this feature.'),
      findsOneWidget,
    );
  });

  test('the HTTP source reads the config and the feature entries', () async {
    final http = FakeHomeHttp()
      ..answer('/api/permission-groups/user', <String, Object?>{
        'config': <String, Object?>{'hideCopilot': true},
      })
      ..answer('/api/access-requests/discovery', <String, Object?>{
        'enabled': true,
        'entries': <Object?>[
          <String, Object?>{
            'target': <String, Object?>{
              'kind': 'feature',
              'configKey': 'hideCopilot',
            },
            'state': 'requestable',
            'label': 'Chat',
          },
          <String, Object?>{
            'target': <String, Object?>{'kind': 'workflow', 'id': 'x'},
            'state': 'allowed',
          },
        ],
      });
    final source = HttpHomeAccessSource(http);
    final policy = source.policy('ws');
    final discovery = source.discovery('ws');
    await pumpEventQueue();
    expect(policy.value.data, <String, Object?>{'hideCopilot': true});
    expect(discovery.value.data!.enabled, isTrue);
    expect(discovery.value.data!.entries.single.state, 'requestable');
    expect(
      http.requests.last.query,
      <String, Object?>{
        'kind': 'workspace',
        'workspaceId': 'ws',
        'targetKind': 'feature',
        'limit': 100,
        'offset': 0,
      },
    );
    final offline = HttpHomeAccessSource(null).policy('ws');
    await pumpEventQueue();
    expect(offline.value.isPending, isFalse);
    expect(offline.value.data, isEmpty);
  });
}
