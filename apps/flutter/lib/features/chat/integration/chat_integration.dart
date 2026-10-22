/// The chat services one app instance shares (the React module-level
/// stores and the query client): the mothership client, the per-tab queue,
/// the effort, drafts and handoff stores, and the request seams of the
/// Home chat surface that live outside the engine (chat resources,
/// feedback). Registered in the locator by [registerChatIntegration].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/integration/home_slots.dart';
import 'package:sim_app/features/home/slots.dart';

/// The chat-resource and feedback routes the Home chat calls besides the
/// engine (`POST/PATCH/DELETE /api/mothership/chat/resources`,
/// `POST /api/copilot/feedback`).
abstract class ChatSurfaceApi {
  Future<void> addResource(String chatId, Map<String, Object?> resource);
  Future<void> removeResource(String chatId, Map<String, Object?> address);
  Future<void> reorderResources(
    String chatId,
    List<Map<String, Object?>> resources,
  );
  Future<void> feedback(Map<String, Object?> body);
}

/// [ChatSurfaceApi] over the app's HTTP client.
class HttpChatSurfaceApi implements ChatSurfaceApi {
  HttpChatSurfaceApi(this._http);

  final SimHttpClient _http;

  @override
  Future<void> addResource(String chatId, Map<String, Object?> resource) =>
      _http.send(
        method: 'POST',
        path: '/api/mothership/chat/resources',
        body: {'chatId': chatId, 'resource': resource},
      );

  @override
  Future<void> removeResource(String chatId, Map<String, Object?> address) =>
      _http.send(
        method: 'DELETE',
        path: '/api/mothership/chat/resources',
        body: {'chatId': chatId, ...address},
      );

  @override
  Future<void> reorderResources(
    String chatId,
    List<Map<String, Object?>> resources,
  ) => _http.send(
    method: 'PATCH',
    path: '/api/mothership/chat/resources',
    body: {'chatId': chatId, 'resources': resources},
  );

  @override
  Future<void> feedback(Map<String, Object?> body) =>
      _http.send(method: 'POST', path: '/api/copilot/feedback', body: body);
}

/// No backend (tests without HTTP): every call succeeds and does nothing.
class NoopChatSurfaceApi implements ChatSurfaceApi {
  const NoopChatSurfaceApi();

  @override
  Future<void> addResource(String chatId, Map<String, Object?> resource) =>
      Future.value();

  @override
  Future<void> removeResource(String chatId, Map<String, Object?> address) =>
      Future.value();

  @override
  Future<void> reorderResources(
    String chatId,
    List<Map<String, Object?>> resources,
  ) => Future.value();

  @override
  Future<void> feedback(Map<String, Object?> body) => Future.value();
}

/// The shared chat services.
class ChatIntegration {
  ChatIntegration({
    required this.client,
    required this.queries,
    required this.storages,
    this.http,
    ChatSurfaceApi? api,
    this.browserReturns,
    this.onlineEvents,
    this.isOnline,
    this.idGenerator,
  }) : api =
           api ??
           (http == null
               ? const NoopChatSurfaceApi()
               : HttpChatSurfaceApi(http));

  final MothershipClient client;
  final QueryClient queries;
  final ChatStorages storages;

  /// The app's HTTP client: uploads, the composer's context menus, links.
  /// `null` in tests without a backend.
  final SimHttpClient? http;
  final ChatSurfaceApi api;

  /// Overrides of the engine's platform signals (tests).
  final Stream<BrowserReturnReason>? browserReturns;
  final Stream<void>? onlineEvents;
  final bool Function()? isOnline;
  final String Function()? idGenerator;

  late final MothershipQueueStore queue = MothershipQueueStore(
    storages.session,
  );
  late final MothershipEffortStore effort = MothershipEffortStore(
    storages.local,
    plan: false,
  );
  late final MothershipEffortStore planEffort = MothershipEffortStore(
    storages.local,
    plan: true,
  );
  late final SendHandoffStore handoffs = SendHandoffStore(
    session: storages.session,
    local: storages.local,
  );

  /// The one drafts store (`mothership-drafts:v1`); the composer reads it
  /// through `ComposerDraftStore`.
  late final MothershipDraftsStore drafts = MothershipDraftsStore(
    storages.local,
  );

  /// Live session cubits by workspace (the shell's resume hook recovers
  /// their streams on Windows).
  final Set<ChatSessionCubit> _sessions = {};

  @visibleForTesting
  Set<ChatSessionCubit> get sessions => Set.unmodifiable(_sessions);

  void attachSession(ChatSessionCubit cubit) => _sessions.add(cubit);
  void detachSession(ChatSessionCubit cubit) => _sessions.remove(cubit);

  /// `recoverActiveStream` of every mounted session (app resume off the
  /// web, where no `visibilitychange` reaches the engine).
  void recoverActiveStreams(BrowserReturnReason reason) {
    for (final cubit in _sessions.toList()) {
      unawaited(cubit.recoverActiveStream(reason));
    }
  }

  /// Sign-out (`clearUserData`): the per-user stores return to empty.
  void reset() {
    effort.reset();
    planEffort.reset();
    drafts.reset();
  }
}

/// Registers the chat services and the real Home slots in [gi] (once per
/// locator generation). [storages] defaults to the browser storages on web
/// and the key-value store elsewhere; `bootstrap` loads the latter before
/// the first read (see [loadChatStorage]).
void registerChatIntegration(GetIt gi, {ChatStorages? storages}) {
  if (!gi.isRegistered<ChatStorages>()) {
    gi.registerLazySingleton<ChatStorages>(
      () =>
          storages ??
          ChatStorages.forPlatform(
            fallback: gi.isRegistered<KeyValueStore>()
                ? KeyValueChatStorage(gi<KeyValueStore>())
                : MemoryChatStorage(),
          ),
    );
  }
  if (!gi.isRegistered<MothershipClient>()) {
    gi.registerLazySingleton<MothershipClient>(
      () => MothershipClient(gi<SimHttpClient>()),
    );
  }
  if (!gi.isRegistered<ChatIntegration>()) {
    gi.registerLazySingleton<ChatIntegration>(() {
      final integration = ChatIntegration(
        client: gi<MothershipClient>(),
        queries: gi.isRegistered<QueryClient>()
            ? gi<QueryClient>()
            : QueryClient.instance,
        storages: gi<ChatStorages>(),
        http: gi.isRegistered<SimHttpClient>() ? gi<SimHttpClient>() : null,
      );
      if (gi.isRegistered<UserDataResetRegistry>()) {
        gi<UserDataResetRegistry>().register(integration.reset);
      }
      return integration;
    });
  }
  if (!gi.isRegistered<HomeSlots>()) {
    gi.registerLazySingleton<HomeSlots>(() {
      // Without a backend client (a VM test that unregistered it) Home
      // keeps the placeholder slots instead of failing every mount.
      try {
        final integration = gi<ChatIntegration>();
        return integratedHomeSlots(() => integration);
      } on Object {
        return HomeSlots.placeholder();
      }
    });
  }
}

/// Fills the desktop chat storage cache before the first store reads it.
Future<void> loadChatStorage(GetIt gi) async {
  if (!gi.isRegistered<ChatStorages>()) return;
  final local = gi<ChatStorages>().local;
  if (local is KeyValueChatStorage) await local.load();
}
