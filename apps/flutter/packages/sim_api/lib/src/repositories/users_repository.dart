import 'package:dio/dio.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/user.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// The profile and settings contracts of `hooks/queries/user-profile.ts`
/// and `general-settings.ts` (spec §4.2, §4.8).
class UsersRepository {
  UsersRepository(this._http);

  final SimHttpClient _http;

  /// `GET /api/users/me/profile` → `{user}`.
  Future<UserProfile> profile({CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/users/me/profile',
        decode: (json) => UserProfile.fromJson(json.object('user')),
        cancelToken: cancelToken,
      );

  /// `PATCH /api/users/me/profile` `{name?, image?}` (at least one) →
  /// `{success, user}`. [clearImage] sends `image: null`.
  Future<UserProfile> updateProfile({
    String? name,
    String? image,
    bool clearImage = false,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'PATCH',
    path: '/api/users/me/profile',
    body: {
      'name': ?name,
      if (clearImage || image != null) 'image': clearImage ? null : image,
    },
    decode: (json) => UserProfile.fromJson(json.object('user')),
    cancelToken: cancelToken,
  );

  /// `GET /api/users/me/settings` → `{data}`.
  Future<UserSettings> settings({CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/users/me/settings',
        decode: (json) => UserSettings.fromJson(json.object('data')),
        cancelToken: cancelToken,
      );

  /// `PATCH /api/users/me/settings` `{<key>: value}` → `{success: true}`.
  /// One key per call, as `useUpdateGeneralSetting` sends it; `null` clears
  /// a nullable setting (`timezone`).
  Future<void> updateSetting(
    String key,
    Object? value, {
    CancelToken? cancelToken,
  }) => updateSettings({key: value}, cancelToken: cancelToken);

  /// `PATCH /api/users/me/settings` with several keys.
  Future<void> updateSettings(
    Map<String, Object?> patch, {
    CancelToken? cancelToken,
  }) => _http.requestSuccess(
    method: 'PATCH',
    path: '/api/users/me/settings',
    body: patch,
    cancelToken: cancelToken,
  );
}
