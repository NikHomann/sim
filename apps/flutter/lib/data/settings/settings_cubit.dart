import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// State of [SettingsCubit]: the general settings with the selector
/// defaults of `general-settings.ts` until loaded.
class SettingsState extends Equatable {
  const SettingsState({this.settings = const LoadState()});

  final LoadState<UserSettings> settings;

  UserSettings get current => settings.data ?? const UserSettings();
  bool get isLoaded => settings.hasData;
  Object? get error => settings.error;

  bool get autoConnect => current.autoConnect;
  num get snapToGridSize => current.snapToGridSize;
  bool get showActionBar => current.showActionBar;
  bool get autoFocusOnClick => current.autoFocusOnClick;
  bool get billingUsageNotifications =>
      current.billingUsageNotificationsEnabled;
  ThemeSetting get theme => current.theme;
  String? get timezone => current.timezone;

  SettingsState copyWith({LoadState<UserSettings>? settings}) =>
      SettingsState(settings: settings ?? this.settings);

  @override
  List<Object?> get props => [settings];
}

/// `SettingsLoader` + `useGeneralSettings` / `useUpdateGeneralSetting`
/// (spec §4.2, §4.8, §7): `['generalSettings','settings']`, stale 60 min;
/// `theme` is written to `localStorage['sim-theme']` on load and on every
/// optimistic change and rollback; [updateSetting] patches one key.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required UsersRepository users,
    required QueryClient queryClient,
    required SharedWebState sharedState,
  }) : _users = users,
       _queryClient = queryClient,
       _sharedState = sharedState,
       super(const SettingsState());

  final UsersRepository _users;
  final QueryClient _queryClient;
  final SharedWebState _sharedState;
  QueryBinding<UserSettings>? _binding;

  QueryKey get _key => GeneralSettingsKeys.settings();

  Query<UserSettings> _query() {
    final existing = _binding;
    if (existing != null) return existing.query;
    final query = _queryClient.query<UserSettings>(
      _key,
      (token) => _users.settings(cancelToken: token),
      staleTime: StaleTimes.generalSettings,
    );
    _binding = QueryBinding(query, _onQueryState);
    _onQueryState(query.state);
    return query;
  }

  void _onQueryState(QueryState<UserSettings> queryState) {
    if (isClosed) return;
    final previousTheme = state.settings.data?.theme;
    emit(state.copyWith(settings: LoadState.fromQuery(queryState)));
    final theme = queryState.data?.theme;
    if (theme != null && theme != previousTheme) _syncTheme(theme);
  }

  /// `syncThemeToNextThemes`: the shared `sim-theme` key both apps read.
  void _syncTheme(ThemeSetting theme) => _sharedState.writeTheme(theme.name);

  Future<UserSettings?> load() async {
    try {
      _query();
      return await _binding!.fetch();
    } on Object {
      return null;
    }
  }

  /// `refreshGeneralSettings`.
  Future<void> refresh() async {
    try {
      _query();
      await _binding!.refetch();
    } on Object {
      // Surfaced on the state.
    }
  }

  /// `useUpdateGeneralSetting`: optimistic `{...previous, [key]: value}`;
  /// the theme is synced immediately and again on rollback; the settings
  /// key is invalidated once settled. Throws the request error.
  Future<void> updateSetting(String key, Object? value) {
    _query();
    final previous = _queryClient.getQueryData<UserSettings>(_key);
    return optimisticMutation<UserSettings, void>(
      _queryClient,
      key: _key,
      update: (old) => (old ?? const UserSettings()).withSetting(key, value),
      mutation: () => _users.updateSetting(key, value),
      onError: (snapshot) {
        if (snapshot != null) {
          _queryClient.setQueryData<UserSettings>(_key, snapshot);
          if (key == 'theme') _syncTheme(snapshot.theme);
        } else {
          _queryClient.removeQueries(_key);
          if (key == 'theme' && previous != null) _syncTheme(previous.theme);
        }
      },
      onApplied: () => _binding?.sync(),
      invalidate: [_key],
    );
  }

  Future<void> setTheme(ThemeSetting theme) =>
      updateSetting('theme', theme.name);

  void reset() {
    _binding?.dispose();
    _binding = null;
    _queryClient.removeQueries(GeneralSettingsKeys.all);
    if (!isClosed) emit(const SettingsState());
  }

  @override
  Future<void> close() {
    _binding?.dispose();
    return super.close();
  }
}
