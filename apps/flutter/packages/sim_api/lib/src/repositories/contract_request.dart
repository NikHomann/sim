import 'package:dio/dio.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/json.dart';

/// Decodes a 2xx body with [decode]; a contract mismatch surfaces as
/// `ApiClientError{status: 2xx, message: 'Response failed contract
/// validation — field: reason'}` the way `requestJson` reports a zod
/// failure (`request.ts:229-242`), never as a bare exception.
T decodeContract<T>(
  ApiResponse<Object?> response,
  T Function(JsonObject json) decode,
) {
  try {
    return decode(asJsonObject(response.data));
  } on ContractDecodeError catch (error) {
    throw ApiClientError(
      status: response.status,
      message: 'Response failed contract validation — $error',
      body: response.data,
      requestId: response.requestId,
    );
  }
}

/// `requestJson(contract, …)` for the repositories: one call per contract,
/// decoded with the `decode` callback.
extension ContractRequests on SimHttpClient {
  Future<T> requestContract<T>({
    required String method,
    required String path,
    required T Function(JsonObject json) decode,
    Map<String, Object?>? params,
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    final response = await send(
      method: method,
      path: path,
      params: params,
      query: query,
      body: body,
      headers: headers,
      cancelToken: cancelToken,
    );
    return decodeContract(response, decode);
  }

  /// A contract whose only payload is `{success: true}`.
  Future<void> requestSuccess({
    required String method,
    required String path,
    Map<String, Object?>? params,
    Map<String, Object?>? query,
    Object? body,
    CancelToken? cancelToken,
  }) => requestContract(
    method: method,
    path: path,
    params: params,
    query: query,
    body: body,
    cancelToken: cancelToken,
    decode: (json) {
      if (json['success'] != true) {
        throw const ContractDecodeError('success', 'expected true');
      }
    },
  );
}
