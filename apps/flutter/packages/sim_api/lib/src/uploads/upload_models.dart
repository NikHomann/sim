import 'dart:typed_data';

/// How the bytes move: port of `v2UploadTransferSchema`.
sealed class UploadTransfer {
  const UploadTransfer();

  factory UploadTransfer.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('transfer: not an object');
    switch (json['method']) {
      case 'put':
        final headers = json['headers'];
        return PutUploadTransfer(
          url: '${json['url']}',
          headers: headers is Map
              ? headers.map((k, v) => MapEntry('$k', '$v'))
              : const {},
          expiresAt: DateTime.tryParse('${json['expiresAt']}'),
        );
      case 'multipart':
        final partSize = json['partSize'];
        final partCount = json['partCount'];
        if (partSize is! num || partCount is! num) {
          throw const FormatException(
            'transfer: multipart needs partSize and partCount',
          );
        }
        return MultipartUploadTransfer(
          partSize: partSize.toInt(),
          partCount: partCount.toInt(),
        );
      default:
        throw FormatException('transfer: unknown method ${json['method']}');
    }
  }
}

/// `PUT` the whole file to one signed URL with exactly these headers.
class PutUploadTransfer extends UploadTransfer {
  const PutUploadTransfer({
    required this.url,
    required this.headers,
    this.expiresAt,
  });

  final String url;
  final Map<String, String> headers;

  /// The signed URL's own expiry; the bytes must be uploaded before it.
  final DateTime? expiresAt;
}

/// Split into [partCount] parts of [partSize] bytes (the last may be shorter).
class MultipartUploadTransfer extends UploadTransfer {
  const MultipartUploadTransfer({
    required this.partSize,
    required this.partCount,
  });

  final int partSize;
  final int partCount;
}

/// A signed URL for one multipart part.
class UploadPartUrl {
  const UploadPartUrl({
    required this.partNumber,
    required this.url,
    required this.headers,
    this.expiresAt,
  });

  factory UploadPartUrl.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('part url: not an object');
    final partNumber = json['partNumber'];
    if (partNumber is! num) {
      throw const FormatException('part url: missing partNumber');
    }
    final headers = json['headers'];
    return UploadPartUrl(
      partNumber: partNumber.toInt(),
      url: '${json['url']}',
      headers: headers is Map
          ? headers.map((k, v) => MapEntry('$k', '$v'))
          : const {},
      expiresAt: DateTime.tryParse('${json['expiresAt']}'),
    );
  }

  final int partNumber;
  final String url;
  final Map<String, String> headers;
  final DateTime? expiresAt;
}

/// `{loaded, total, percent}`.
class UploadProgress {
  const UploadProgress({
    required this.loaded,
    required this.total,
    required this.percent,
  });

  final int loaded;
  final int total;
  final int percent;

  @override
  String toString() => 'UploadProgress($loaded/$total, $percent%)';
}

/// The bytes to upload. Reading by range keeps multipart uploads from
/// holding a whole file in memory twice.
abstract class UploadSource {
  String get name;
  int get size;

  /// Bytes `[start, end)`.
  Future<Uint8List> read(int start, int end);
}

/// An in-memory [UploadSource].
class BytesUploadSource implements UploadSource {
  BytesUploadSource({required this.name, required Uint8List bytes})
    : _bytes = bytes;

  final Uint8List _bytes;

  @override
  final String name;

  @override
  int get size => _bytes.length;

  @override
  Future<Uint8List> read(int start, int end) async =>
      Uint8List.sublistView(_bytes, start, end);
}

/// `POST /api/files/uploads` → `{data:{session, uploadToken, transfer}}`.
class CreatedUploadSession {
  const CreatedUploadSession({
    required this.uploadId,
    required this.uploadToken,
    required this.transfer,
    required this.session,
  });

  factory CreatedUploadSession.fromJson(Object? json) {
    final data = json is Map ? json['data'] : null;
    if (data is! Map) {
      throw const FormatException('upload session: missing data');
    }
    final session = data['session'];
    final token = data['uploadToken'];
    if (session is! Map || token is! String || token.isEmpty) {
      throw const FormatException('upload session: missing session or token');
    }
    return CreatedUploadSession(
      uploadId: '${session['id']}',
      uploadToken: token,
      transfer: UploadTransfer.fromJson(data['transfer']),
      session: Map<String, Object?>.from(session),
    );
  }

  final String uploadId;

  /// Goes out as the `upload-token` header on parts, complete and abort.
  final String uploadToken;
  final UploadTransfer transfer;
  final Map<String, Object?> session;
}
