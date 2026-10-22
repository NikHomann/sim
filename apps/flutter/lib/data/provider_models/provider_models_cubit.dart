import 'dart:async';
import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// `shouldLoadProviderModels` (`provider-models-loader.tsx:22-39`): the
/// loader runs only on `/workspace/<id>`, `/home`, `/w[/…]`, `/chat[/…]`
/// of the current workspace, or while the search palette is open.
bool shouldLoadProviderModels({
  required String? pathname,
  required String? workspaceId,
  required bool isSearchModalOpen,
}) {
  if (workspaceId == null) return false;
  if (isSearchModalOpen) return true;
  final base = '/workspace/$workspaceId';
  return pathname == base ||
      pathname == '$base/home' ||
      pathname == '$base/w' ||
      (pathname?.startsWith('$base/w/') ?? false) ||
      pathname == '$base/chat' ||
      (pathname?.startsWith('$base/chat/') ?? false);
}

/// One provider's entry in the providers store.
class ProviderModelsEntry extends Equatable {
  const ProviderModelsEntry({
    this.models = const [],
    this.isLoading = false,
    this.error,
  });

  final List<String> models;
  final bool isLoading;
  final Object? error;

  @override
  List<Object?> get props => [models, isLoading, error];
}

/// State of [ProviderModelsCubit].
class ProviderModelsState extends Equatable {
  const ProviderModelsState({
    this.workspaceId,
    this.pathname,
    this.isSearchModalOpen = false,
    this.byProvider = const {},
    this.openRouterModelInfo = const {},
  });

  final String? workspaceId;
  final String? pathname;
  final bool isSearchModalOpen;
  final Map<ProviderName, ProviderModelsEntry> byProvider;
  final Map<String, ProviderModelInfo> openRouterModelInfo;

  bool get enabled => shouldLoadProviderModels(
    pathname: pathname,
    workspaceId: workspaceId,
    isSearchModalOpen: isSearchModalOpen,
  );

  ProviderModelsEntry entry(ProviderName provider) =>
      byProvider[provider] ?? const ProviderModelsEntry();

  List<String> models(ProviderName provider) => entry(provider).models;

  ProviderModelsState copyWith({
    String? workspaceId,
    bool clearWorkspace = false,
    String? pathname,
    bool? isSearchModalOpen,
    Map<ProviderName, ProviderModelsEntry>? byProvider,
    Map<String, ProviderModelInfo>? openRouterModelInfo,
  }) => ProviderModelsState(
    workspaceId: clearWorkspace ? null : (workspaceId ?? this.workspaceId),
    pathname: pathname ?? this.pathname,
    isSearchModalOpen: isSearchModalOpen ?? this.isSearchModalOpen,
    byProvider: byProvider ?? this.byProvider,
    openRouterModelInfo: openRouterModelInfo ?? this.openRouterModelInfo,
  );

  @override
  List<Object?> get props => [
    workspaceId,
    pathname,
    isSearchModalOpen,
    byProvider,
    openRouterModelInfo,
  ];
}

/// `ProviderModelsLoader` (spec §4.9, §7): nine model lists (stale 5 min),
/// enabled by the route gate or the open palette; errors are logged only
/// and never block the shell. The registry's option lists are fed by the
/// feature that owns the generated registry (it listens to this cubit).
class ProviderModelsCubit extends Cubit<ProviderModelsState> {
  ProviderModelsCubit({
    required BlocksRepository blocks,
    required QueryClient queryClient,
  }) : _blocks = blocks,
       _queryClient = queryClient,
       super(const ProviderModelsState());

  final BlocksRepository _blocks;
  final QueryClient _queryClient;
  final Map<ProviderName, QueryBinding<ProviderModels>> _bindings = {};

  /// The route and workspace the gate reads.
  void setRoute({required String? pathname, required String? workspaceId}) {
    final workspaceChanged = workspaceId != state.workspaceId;
    emit(
      state.copyWith(
        pathname: pathname,
        workspaceId: workspaceId,
        clearWorkspace: workspaceId == null,
      ),
    );
    if (workspaceChanged) _unbindAll();
    _sync();
  }

  /// The search palette's open flag (second half of the gate).
  void setSearchModalOpen({required bool open}) {
    emit(state.copyWith(isSearchModalOpen: open));
    _sync();
  }

  void _sync() {
    if (!state.enabled) return;
    ProviderName.values.forEach(_ensure);
  }

  void _ensure(ProviderName provider) {
    if (_bindings.containsKey(provider)) {
      final binding = _bindings[provider]!;
      if (binding.query.isStale && !binding.query.state.isFetching) {
        unawaited(
          binding.fetch().catchError((Object error) {
            _logFailure(provider, error);
            return const ProviderModels(models: []);
          }),
        );
      }
      return;
    }
    final workspaceId = provider.takesWorkspace ? state.workspaceId : null;
    final query = _queryClient.query<ProviderModels>(
      ProviderModelKeys.list(provider, workspaceId),
      (token) => _blocks.providerModels(
        provider,
        workspaceId: workspaceId,
        cancelToken: token,
      ),
      staleTime: StaleTimes.providerModels,
    );
    _bindings[provider] = QueryBinding(
      query,
      (queryState) => _onQueryState(provider, queryState),
    );
    _onQueryState(provider, query.state);
    unawaited(
      _bindings[provider]!.fetch().catchError((Object error) {
        _logFailure(provider, error);
        return const ProviderModels(models: []);
      }),
    );
  }

  static void _logFailure(ProviderName provider, Object error) => developer.log(
    '${provider.wireName} models failed',
    name: 'sim_app.provider_models',
    error: error,
  );

  void _onQueryState(ProviderName provider, QueryState<ProviderModels> s) {
    if (isClosed) return;
    final load = LoadState<ProviderModels>.fromQuery(s);
    final entry = ProviderModelsEntry(
      models: load.data?.models ?? const [],
      isLoading: load.isLoading || load.isFetching,
      error: load.error,
    );
    emit(
      state.copyWith(
        byProvider: {...state.byProvider, provider: entry},
        openRouterModelInfo: provider == ProviderName.openrouter
            ? (load.data?.modelInfo ?? state.openRouterModelInfo)
            : null,
      ),
    );
  }

  void _unbindAll() {
    for (final binding in _bindings.values) {
      binding.dispose();
    }
    _bindings.clear();
  }

  void reset() {
    _unbindAll();
    _queryClient.removeQueries(ProviderModelKeys.all);
    if (!isClosed) emit(const ProviderModelsState());
  }

  @override
  Future<void> close() {
    _unbindAll();
    return super.close();
  }
}
