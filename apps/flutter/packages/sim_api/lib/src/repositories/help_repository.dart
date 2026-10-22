import 'package:dio/dio.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/common.dart';

/// `POST /api/help` (`help-modal.tsx:91-116`, `help/route.ts:29-117`): a raw
/// multipart form, not a JSON contract. Text fields first, then one
/// `image_<n>` part per screenshot.
class HelpRepository {
  HelpRepository(this._http);

  final SimHttpClient _http;

  /// Sends the form; 401 `{error:'Authentication required'}`, 400
  /// `{error, details}` and 413 (oversized) arrive as `ApiClientError`.
  Future<void> submit(HelpRequest request, {CancelToken? cancelToken}) async {
    final form = FormData();
    request.toJson().forEach((key, value) {
      form.fields.add(MapEntry(key, value));
    });
    for (var i = 0; i < request.images.length; i++) {
      final image = request.images[i];
      form.files.add(
        MapEntry(
          'image_$i',
          MultipartFile.fromBytes(
            image.bytes,
            filename: image.filename,
            contentType: DioMediaType.parse(image.contentType),
          ),
        ),
      );
    }
    try {
      await _http.dio.post<String>(
        '/api/help',
        data: form,
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw await _http.mapDioException(error);
    }
  }
}
